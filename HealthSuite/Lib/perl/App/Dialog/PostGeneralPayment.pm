##############################################################################
package App::Dialog::PostGeneralPayment;
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
	my $self = CGI::Dialog::new(@_, id => 'adjustment', heading => 'Post Personal Payment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'payer_id'),

		new CGI::Dialog::Field(type => 'currency',
					caption => 'Total Payment Received',
					name => 'total_amount',
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
					options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field::TableColumn(caption => 'Payment Type', schema => $schema,	column => 'Invoice_Item_Adjust.pay_type', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::MultiField(caption =>'Payment Method/Check Number', name => 'pay_method_fields',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field(caption => 'Check Number', name => 'pay_ref', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				]),

		new CGI::Dialog::Field(caption => 'Authorization/Reference Number', name => 'auth_ref'),



		new CGI::Dialog::Subhead(heading => 'This Visit', name => 'visit_heading'),

		new CGI::Dialog::Field(caption => 'Claim Number', name => 'invoice_id', options => FLDFLAG_READONLY),
		new CGI::Dialog::MultiField(caption =>'Service Date(s)/Balance', options => FLDFLAG_READONLY, name => 'dates_and_balance',
			fields => [
				new CGI::Dialog::Field(caption => 'Dates of Service', name => 'service_dates', options => FLDFLAG_READONLY),
				new CGI::Dialog::Field(type => 'currency', caption => 'Balance', name => 'balance', options => FLDFLAG_READONLY),
			]),

		new CGI::Dialog::Field(caption => 'Office Visit Co-pay Due', name => 'copay_due', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(type => 'currency', caption => "Payment for Today's Visit", name => 'adjustment_amount'),

		new CGI::Dialog::Subhead(heading => 'Outstanding Invoices', name => 'outstanding_heading'),
		new App::Dialog::Field::OutstandingInvoices(name =>'outstanding_invoices_list'),

	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postpayment '#param.item_id#' claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	#if param invoice id is NULL, don't want to show invoice-specific fields
	unless($page->param('invoice_id'))
	{
		$self->updateFieldFlags('visit_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('invoice_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('dates_and_balance', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('copay_due', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('adjustment_amount', FLDFLAG_INVISIBLE, 1);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if($page->param('posting_action') ne 'refund')
	{
		if(my $invoiceId = $page->param('invoice_id'))
		{
			my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page,STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
			$page->field('invoice_id', $invoiceId);
			my $balanceDisplay = $invoiceInfo->{balance} ? "\$$invoiceInfo->{balance}" : "\$0";
			$page->field('balance', $balanceDisplay);
			$page->field('payer_id', $invoiceInfo->{client_id});

			my $itemServDates = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selServiceDateRangeForAllItems', $invoiceId);
			my $endDateDisplay = '';
			if($itemServDates->{service_end_date})
			{
				$endDateDisplay = $itemServDates->{service_end_date} ne  $itemServDates->{service_begin_date} ? "- $itemServDates->{service_end_date}" : '';
			}
			my $dateDisplay = "$itemServDates->{service_begin_date} $endDateDisplay";
			$page->field('service_dates', $dateDisplay);

			my $invoiceCopayItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_COPAY);
			my $copayDisplay = $invoiceCopayItem->{balance} ? "\$$invoiceCopayItem->{balance}" : "\$0";
			$page->field('copay_due', $copayDisplay);
		}
		elsif(my $personId = $page->param('person_id'))
		{
			$page->field('payer_id', $personId);	
		}
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	if($page->field('total_amount') > 0)
	{
		#APPLY PAYMENT TO "THIS VISIT" INVOICE
		my $payment = $page->field('adjustment_amount');
		if($payment > 0)
		{
			my $totalAdjustForItemAndItemAdjust = 0 - $payment;

			my $invoiceId = $page->param('invoice_id');
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

			my $payerIs = $page->param('payment');
			my $payerType = App::Universal::ENTITYTYPE_PERSON;
			my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
			my $payMethod = $page->field('pay_method');
			my $payerId = $page->field('payer_id');			#this is a hidden field for now, it is populated with invoice.client_id
			my $payType = $page->field('pay_type');

			$page->schemaAction(
					'Invoice_Item_Adjust', 'add',
					adjustment_type => defined $adjType ? $adjType : undef,
					adjustment_amount => $payment || undef,
					parent_id => $itemId || undef,
					pay_date => $todaysDate || undef,
					pay_method => defined $payMethod ? $payMethod : undef,
					pay_ref => $page->field('pay_ref') || undef,
					payer_type => $payerType || 0,
					payer_id => $payerId || undef,
					net_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
					data_text_a => $page->field('auth_ref') || undef,
					pay_type => defined $payType ? $payType : undef,
					#plan_allow => undef,
					#plan_paid => undef,
					#writeoff_code => undef,
					#writeoff_amount => undef,
					#adjust_codes => undef,
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

			$payerIs = "\u$payerIs";
			my $description = "$payerIs payment/adjustment made";

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


		#APPLY PAYMENTS TO LIST OF OUTSTANDING INVOICES

		my $lineCount = $page->param('_f_line_count');
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			my $payAmt = $page->param("_f_invoice_$line\_payment");
			next if $payAmt eq '';

			my $totalAdjustForItemAndItemAdjust = 0 - $payAmt;

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

			my $payerIs = $page->param('payment');
			my $payerType = App::Universal::ENTITYTYPE_PERSON;
			my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
			my $payMethod = $page->field('pay_method');
			my $payerId = $page->field('payer_id');			#this is a hidden field for now, it is populated with invoice.client_id
			my $payType = $page->field('pay_type');

			$page->schemaAction(
					'Invoice_Item_Adjust', 'add',
					adjustment_type => defined $adjType ? $adjType : undef,
					adjustment_amount => defined $payAmt ? $payAmt : undef,
					parent_id => $itemId || undef,
					pay_date => $todaysDate || undef,
					pay_method => defined $payMethod ? $payMethod : undef,
					pay_ref => $page->field('pay_ref') || undef,
					payer_type => $payerType || 0,
					payer_id => $payerId || undef,
					net_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
					data_text_a => $page->field('auth_ref') || undef,
					pay_type => defined $payType ? $payType : undef,
					#plan_allow => undef,
					#plan_paid => undef,
					#writeoff_code => undef,
					#writeoff_amount => undef,
					#adjust_codes => undef,
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

			$payerIs = "\u$payerIs";
			my $description = "$payerIs payment/adjustment made";

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
	
	$self->handlePostExecute($page, $command, $flags);

}

1;
