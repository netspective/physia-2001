##############################################################################
package App::Dialog::PostTransfer;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Invoice;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'transfer', heading => 'Post Transfer');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Transfer From', name => 'transfer_from_heading'),
		new CGI::Dialog::MultiField(caption => 'Invoice ID/Amount', name => 'trans_from_fields',
			fields => [				
				new CGI::Dialog::Field(caption => 'Invoice ID', name => 'trans_from_invoice_id', options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(type => 'currency', caption => 'Transfer Amount', name => 'trans_from_amt', options => FLDFLAG_REQUIRED),
			]),
		new CGI::Dialog::Field(type => 'memo', caption => 'Comments',	name => 'from_comments'),
			

		new CGI::Dialog::Subhead(heading => 'Transfer To', name => 'transfer_to_heading'),
		new CGI::Dialog::Field(caption => 'Invoice ID', name => 'trans_to_invoice_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'memo', caption => 'Comments',	name => 'to_comments'),
	
		
		new CGI::Dialog::Subhead(heading => 'Invoices', name => 'transfer_invoices_heading'),
		new App::Dialog::Field::AllInvoices(name =>'transfer_invoices_list'),
	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postrefund '#param.item_id#' claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

#sub makeStateChanges
#{
#	my ($self, $page, $command, $dlgFlags) = @_;
#	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
#}

#sub populateData
#{
#	my ($self, $page, $command, $activeExecMode, $flags) = @_;
#}

sub customValidate
{
	my ($self, $page) = @_;
	
	my $personId = $page->param('person_id');
	my $fromInvoiceAmt = $page->field('trans_from_amt');
	my $fromInvoiceField = $self->getField('trans_from_fields')->{fields}->[0];
	my $fromInvoiceId = $page->field('trans_from_invoice_id');
	my $fromInvoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceByIdAndClient', $fromInvoiceId, $personId);
	if($fromInvoice->{invoice_id})
	{
		my $fromInvoiceBal = $fromInvoice->{balance};
		
		my $diffAmt = $fromInvoiceBal + $fromInvoiceAmt;
		if($fromInvoiceBal >= 0)
		{
			$fromInvoiceField->invalidate($page, "There is no credit on this invoice. Cannot transfer.");
		}
		elsif($diffAmt > 0)
		{
			$fromInvoiceField->invalidate($page, "Transfer amount is too much.");		
		}
	}
	elsif($fromInvoiceId ne '')
	{
		$fromInvoiceField->invalidate($page, "Invalid Invoice Id. This invoice does not exist for this patient.");
	}


	my $toInvoiceField = $self->getField('trans_to_invoice_id');
	my $toInvoiceId = $page->field('trans_to_invoice_id');
	my $toInvoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceByIdAndClient', $toInvoiceId, $personId);
	if($toInvoice->{invoice_id})
	{
		my $toInvoiceBal = $toInvoice->{balance};
		my $diffAmt = $toInvoiceBal - $fromInvoiceAmt;
		if($toInvoiceBal <= 0)
		{
			$toInvoiceField->invalidate($page, "There is a credit on this balance. Cannot transfer amount to a credited balance.");
		}
		elsif($diffAmt < 0)
		{
			$toInvoiceField->invalidate($page, "Transfer amount is too great. Cannot put a credit on balance.");
		}
	}
	elsif($toInvoiceId ne '')
	{
		$toInvoiceField->invalidate($page, "Invalid Invoice Id. This invoice does not exist for this patient.");
	}	
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';
	
	handleTransferFromInvoice($self, $page, $command, $flags);
	handleTransferToInvoice($self, $page, $command, $flags);

	$self->handlePostExecute($page, $command, $flags);
}

sub handleTransferFromInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	my $transferAmt = $page->field('trans_from_amt');
	my $fromInvoiceId = $page->field('trans_from_invoice_id');
	my $totalDummyItems = $STMTMGR_INVOICE->getRowCount($page, STMTMGRFLAG_NONE, 'selInvoiceItemCountByType', $fromInvoiceId, $itemType);
	my $itemSeq = $totalDummyItems + 1;

	my $itemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $fromInvoiceId,
			item_type => defined $itemType ? $itemType : undef,
			total_adjust => defined $transferAmt ? $transferAmt : undef,
			balance => defined $transferAmt ? $transferAmt : undef,
			data_num_c => $itemSeq,
			_debug => 0
	);


	# Create adjustment for the item

	my $adjType = App::Universal::ADJUSTMENTTYPE_TRANSFER;
	my $comments = $page->field('from_comments');
	$page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			adjustment_type => defined $adjType ? $adjType : undef,
			adjustment_amount => defined $transferAmt ? $transferAmt : undef,
			parent_id => $itemId || undef,
			pay_date => $todaysDate || undef,
			net_adjust => defined $transferAmt ? $transferAmt : undef,
			comments => $comments || undef,
			_debug => 0
	);



	#Update the invoice

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $fromInvoiceId);

	my $totalAdjustForInvoice = $invoice->{total_adjust} + $transferAmt;
	my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;

	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $fromInvoiceId || undef,
			total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
			balance => defined $invoiceBalance ? $invoiceBalance : undef,
			_debug => 0
	);



	#Create history attribute for this adjustment
	my $toInvoiceId = $page->field('trans_to_invoice_id');
	my $description = "Credit of \$$transferAmt transferred to invoice $toInvoiceId";

	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $fromInvoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => $description,
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
	);
}

sub handleTransferToInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	my $transferAmt = $page->field('trans_from_amt');
	my $totalAdjust = 0 - $transferAmt;
	my $toInvoiceId = $page->field('trans_to_invoice_id');
	my $totalDummyItems = $STMTMGR_INVOICE->getRowCount($page, STMTMGRFLAG_NONE, 'selInvoiceItemCountByType', $toInvoiceId, $itemType);
	my $itemSeq = $totalDummyItems + 1;

	my $itemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $toInvoiceId,
			item_type => defined $itemType ? $itemType : undef,
			total_adjust => defined $totalAdjust ? $totalAdjust : undef,
			balance => defined $totalAdjust ? $totalAdjust : undef,
			data_num_c => $itemSeq,
			_debug => 0
	);


	# Create adjustment for the item

	my $adjType = App::Universal::ADJUSTMENTTYPE_TRANSFER;
	my $comments = $page->field('to_comments');
	$page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			adjustment_type => defined $adjType ? $adjType : undef,
			adjustment_amount => defined $transferAmt ? $transferAmt : undef,
			parent_id => $itemId || undef,
			pay_date => $todaysDate || undef,
			net_adjust => defined $totalAdjust ? $totalAdjust : undef,
			comments => $comments || undef,
			_debug => 0
	);



	#Update the invoice

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $toInvoiceId);

	my $totalAdjustForInvoice = $invoice->{total_adjust} + $totalAdjust;
	my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;

	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $toInvoiceId || undef,
			total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
			balance => defined $invoiceBalance ? $invoiceBalance : undef,
			_debug => 0
	);



	#Create history attribute for this adjustment
	my $fromInvoiceId = $page->field('trans_from_invoice_id');
	my $description = "Amount \$$transferAmt was transferred from invoice $fromInvoiceId";

	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $toInvoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => $description,
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
	);
}

1;
