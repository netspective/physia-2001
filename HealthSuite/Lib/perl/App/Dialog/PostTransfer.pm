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
use App::Dialog::Field::BatchDateID;
use App::Universal;
use App::InvoiceUtilities;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'posttransfer' => {},
	);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'transfer', heading => 'Post Transfer');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',listInvoiceFieldName=>'list_invoices'),		

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

	my $personId = $page->param('person_id');
	$page->redirect("/person/$personId/account");
}

sub handleTransferFromInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $transferAmt = 0 - $page->field('trans_from_amt');
	my $fromInvoiceId = $page->field('trans_from_invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $fromInvoiceId);
	if($invoice->{invoice_status} == App::Universal::INVOICESTATUS_CLOSED)
	{
		$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $fromInvoiceId || undef,
			invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
			flags => 0,
			_debug => 0
		);

		## Add history item
		addHistoryItem($page, $fromInvoiceId,
			value_text => 'Reopened due to refund',
			value_date => $todaysDate,
		);
	}


	my $itemId = $page->schemaAction(
		'Invoice_Item', 'add',
		parent_id => $fromInvoiceId,
		item_type => defined $itemType ? $itemType : undef,
		_debug => 0
	);


	# Create adjustment for the item
	my $adjType = App::Universal::ADJUSTMENTTYPE_TRANSFER;
	my $comments = $page->field('from_comments');
	my $adjItemId = $page->schemaAction(
		'Invoice_Item_Adjust', 'add',
		adjustment_type => defined $adjType ? $adjType : undef,
		adjustment_amount => defined $transferAmt ? $transferAmt : undef,
		parent_id => $itemId || undef,
		pay_date => $todaysDate || undef,
		comments => $comments || undef,
		_debug => 0
	);

	#Add batch attribute
	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $fromInvoiceId || undef,
		item_name => 'Invoice/Payment/Batch ID',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $batchId || undef,
		value_date => $batchDate || undef,
		value_int => $adjItemId || undef,
		_debug => 0
	);
	$page->session('batch_id', $batchId);


	#Create history item for this adjustment
	my $toInvoiceId = $page->field('trans_to_invoice_id');
	addHistoryItem($page, $fromInvoiceId,
		value_text => "Payment transfer of  \$$transferAmt to invoice <A HREF='/invoice/$toInvoiceId/summary'>$toInvoiceId</A>",
		value_textB => "$comments " . "Batch ID: $batchId",
		value_date => $todaysDate,
	);
}

sub handleTransferToInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $transferAmt = $page->field('trans_from_amt');
	my $toInvoiceId = $page->field('trans_to_invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $toInvoiceId);
	if($invoice->{invoice_status} == App::Universal::INVOICESTATUS_CLOSED)
	{
		$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $toInvoiceId || undef,
			invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
			flags => 0,
			_debug => 0
		);

		## Add history item
		addHistoryItem($page, $toInvoiceId,
			value_text => 'Reopened due to refund',
			value_date => $todaysDate,
		);
	}


	my $itemId = $page->schemaAction(
		'Invoice_Item', 'add',
		parent_id => $toInvoiceId,
		item_type => defined $itemType ? $itemType : undef,
		_debug => 0
	);


	# Create adjustment for the item

	my $adjType = App::Universal::ADJUSTMENTTYPE_TRANSFER;
	my $comments = $page->field('to_comments');
	my $adjItemId = $page->schemaAction(
		'Invoice_Item_Adjust', 'add',
		adjustment_type => defined $adjType ? $adjType : undef,
		adjustment_amount => defined $transferAmt ? $transferAmt : undef,
		parent_id => $itemId || undef,
		pay_date => $todaysDate || undef,
		comments => $comments || undef,
		_debug => 0
	);


	#Add batch attribute
	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $toInvoiceId || undef,
		item_name => 'Invoice/Payment/Batch ID',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $batchId || undef,
		value_date => $batchDate || undef,
		value_int => $adjItemId || undef,
		_debug => 0
	);
	$page->session('batch_id', $batchId);


	#Create history item for this adjustment
	my $fromInvoiceId = $page->field('trans_from_invoice_id');
	addHistoryItem($page, $toInvoiceId,
		value_text => "Credit of \$$transferAmt transferred from invoice <A HREF='/invoice/$fromInvoiceId/summary'>$fromInvoiceId</A>",
		value_textB => "$comments " . "Batch ID: $batchId",
		value_date => $todaysDate,
	);
}

1;
