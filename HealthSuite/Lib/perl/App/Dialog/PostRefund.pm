##############################################################################
package App::Dialog::PostRefund;
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
	my $self = CGI::Dialog::new(@_, id => 'adjustment', heading => 'Post Refund');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Overpaid Invoices', name => 'credit_heading'),
		new App::Dialog::Field::CreditInvoices(name =>'credit_invoices_list'),

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

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	#apply refund
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $refundAmt = $page->param("_f_invoice_$line\_refund");
		next if $refundAmt eq '';

		my $totalAdjustForItemAndItemAdjust = $refundAmt;

		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");
		my $totalDummyItems = $STMTMGR_INVOICE->getRowCount($page, STMTMGRFLAG_NONE, 'selInvoiceItemCountByType', $invoiceId, $itemType);
		my $itemSeq = $totalDummyItems + 1;

		my $itemBalance = $totalAdjustForItemAndItemAdjust;	# because this is a "dummy" item that is made for the sole purpose of applying a general
															# payment, there is no charge and the balance should be negative.
		my $itemId = $page->schemaAction(
				'Invoice_Item', 'add',
				parent_id => $invoiceId,
				item_type => defined $itemType ? $itemType : undef,
				total_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
				balance => defined $itemBalance ? $itemBalance : undef,
				data_num_c => $itemSeq,
				_debug => 0
			);




		# Create adjustment for the item

		my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;

		$page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				#adjustment_type => defined $adjType ? $adjType : undef,
				adjustment_amount => defined $refundAmt ? $refundAmt : undef,
				parent_id => $itemId || undef,
				pay_date => $todaysDate || undef,
				net_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
				#writeoff_code => undef,
				#comments => undef,
				_debug => 0
			);



		#Update the invoice

		my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);

		my $totalAdjustForInvoice = $invoice->{total_adjust} + $totalAdjustForItemAndItemAdjust;
		my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;

		$page->schemaAction(
				'Invoice', 'update',
				invoice_id => $invoiceId || undef,
				total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
				balance => defined $invoiceBalance ? $invoiceBalance : undef,
				_debug => 0
			);





		#Create history attribute for this adjustment

		my $description = 'Refund due to credit on balance';

		$page->schemaAction(
				'Invoice_Attribute', 'add',
				parent_id => $invoiceId || undef,
				item_name => 'Invoice/History/Item',
				value_type => defined $historyValueType ? $historyValueType : undef,
				value_text => $description,
				value_textB => $page->field('comments') || undef,
				value_date => $todaysDate,
				_debug => 0
			);
	}
}

1;
