##############################################################################
package App::Dialog::PostInsurancePayment;
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
	my $self = CGI::Dialog::new(@_, id => 'postinspayment', heading => 'Post Insurance Payment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field::TableColumn(
							caption => 'Payer',
							schema => $schema,
							column => 'Invoice_Item_Adjust.payer_id',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							options => FLDFLAG_REQUIRED),

		new CGI::Dialog::MultiField(caption => 'Check Amount/Number', name => 'check_fields',
			fields => [
					new CGI::Dialog::Field(caption => 'Check Amount', name => 'check_amount', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, options => FLDFLAG_REQUIRED),
					new CGI::Dialog::Field::TableColumn(
						caption => 'Check Number/Pay Reference',
						schema => $schema,
						column => 'Invoice_Item_Adjust.pay_ref',
						type => 'text',
						readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					]),


		#new CGI::Dialog::Field(caption => 'Comments', name => 'comments', type => 'memo', cols => 25, rows => 4, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Subhead(heading => 'Outstanding Items', name => 'outstanding_heading'),
		new App::Dialog::Field::OutstandingItems(name =>'outstanding_items_list'),

	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postinspayment claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

#sub makeStateChanges
#{
#	my ($self, $page, $command, $dlgFlags) = @_;
#	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
#}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if(my $invoiceId = $page->param('invoice_id'))
	{
		my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page,STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
		my $primaryPayer = $STMTMGR_INVOICE->getRowAsHash($page,STMTMGRFLAG_NONE, 'selInvoiceBillingPrimary', $invoiceId);

		$page->field('payer_id', $primaryPayer->{bill_to_id});
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $payerType = App::Universal::ENTITYTYPE_ORG;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $payMethod = App::Universal::ADJUSTMENTPAYMETHOD_CHECK;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	my $invoiceId = $page->param('invoice_id');
	my $payerId = $page->field('payer_id');

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_item_$line\_plan_paid");
		my $writeoffAmt = $page->param("_f_item_$line\_writeoff_amt");
		next if $payAmt eq '' && $writeoffAmt eq '';

		my $itemId = $page->param("_f_item_$line\_item_id");
		my $planAllow = $page->param("_f_item_$line\_plan_allow");

		my $totalItemAdjust = $page->param("_f_item_$line\_item_adjustments");
		my $newTotalAdjust = $totalItemAdjust - ($payAmt + $writeoffAmt);
		my $itemBalance = $page->param("_f_item_$line\_item_balance") + $newTotalAdjust;
		$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId,
			total_adjust => defined $newTotalAdjust ? $newTotalAdjust : undef,
			balance => defined $itemBalance ? $itemBalance : undef,
			_debug => 0
		);


		# Create adjustment for the item
		my $netAdjust = 0 - ($payAmt + $writeoffAmt);
		my $comments = $page->param("_f_item_$line\_comments");
		$page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			parent_id => $itemId || undef,
			adjustment_type => defined $adjType ? $adjType : undef,
			pay_date => $todaysDate || undef,
			pay_method => defined $payMethod ? $payMethod : undef,
			pay_ref => $page->field('pay_ref') || undef,
			payer_type => $payerType || 1,
			payer_id => $payerId || undef,
			plan_allow => $planAllow || 'NULL',
			plan_paid => $payAmt || 'NULL',
			writeoff_amount => defined $writeoffAmt ? $writeoffAmt : undef,
			net_adjust => defined $netAdjust ? $netAdjust : undef,
			comments => $comments || undef,
			_debug => 0
		);



		#Update the invoice

		my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
		my $totalAdjustForInvoice = $invoice->{total_adjust} + $newTotalAdjust;
		my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;

		$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId || undef,
			total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
			balance => defined $invoiceBalance ? $invoiceBalance : undef,
			_debug => 0
		);



		#Create history attribute for this adjustment

		my $description = "Insurance payment made by '$payerId'";
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => $description,
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
		);
	}
	
	$page->redirect("/invoice/$invoiceId/summary");
	#$self->handlePostExecute($page, $command, $flags);

}

1;
