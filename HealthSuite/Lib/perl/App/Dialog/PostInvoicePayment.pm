##############################################################################
package App::Dialog::PostInvoicePayment;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Invoice;
use App::Universal;
use App::Dialog::Field::BatchDateID;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'postinvoicepayment' => {},
	);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'postinvoicepayment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'orgpayer_internal_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'credit_warning_flag'),
		new CGI::Dialog::Field(type => 'hidden', name => 'client_id'),
		new CGI::Dialog::Field(caption => 'Invoice ID', name => 'sel_invoice_id', options => FLDFLAG_REQUIRED, findPopup => '/lookup/claim'),


		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',invoiceIdFieldName=>'sel_invoice_id'),		
		new CGI::Dialog::Field(type => 'hidden', name => 'list_invoices'),
		#fields for insurance payment

		new CGI::Dialog::Field::TableColumn(
							caption => 'Payer',
							schema => $schema,
							column => 'Invoice_Item_Adjust.payer_id',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							options => FLDFLAG_REQUIRED),

		new CGI::Dialog::MultiField(caption => 'Check Amount/Number', name => 'check_fields',
			fields => [
					new CGI::Dialog::Field(caption => 'Check Amount', 
						name => 'check_amount',
						type => 'currency',
						options => FLDFLAG_REQUIRED,
					),
					new CGI::Dialog::Field::TableColumn(
						caption => 'Check Number/Pay Reference',
						schema => $schema,
						column => 'Invoice_Item_Adjust.pay_ref',
						type => 'text',
						readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					]),

		
		#fields for personal payment

		new CGI::Dialog::Field(caption => 'Total Amount', 
			name => 'total_amount',
			type => 'currency',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field(
				name => 'pay_type',
				caption => 'Payment Type', 
				enum => 'Payment_Type'),

		new CGI::Dialog::MultiField(caption =>'Pay Method/Check No. or Auth. Code', name => 'pay_method_fields',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method'),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_ref',
							type => 'text')
						]),


		#list of items (used for both insurance and personal payments)

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

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	my $paidBy = $page->param('paidBy');
	my $isPersonal = $paidBy eq 'personal';
	my $isInsurance = $paidBy eq 'insurance';

	$page->param('_p_batch_id') ? $self->heading('Add Batch Insurance Payments') : $self->heading("Add \u$paidBy Payment");
	
	$self->updateFieldFlags('payer_id', FLDFLAG_READONLY, 1);
	if(! $invoiceId || ($isInsurance && $invoiceInfo->{invoice_subtype} == App::Universal::CLAIMTYPE_SELFPAY))
	{
		#if($invoiceId)
		#{
			#$self->getField('sel_invoice_id')->invalidate($page, "Claim $invoiceId is 'Self-Pay'. Cannot apply insurance payment to this claim.");
		#}

		$self->updateFieldFlags('payer_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('total_amount', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('pay_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('check_fields', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_items_list', FLDFLAG_INVISIBLE, 1);
	}
     	elsif($invoiceId)
	{
		$self->updateFieldFlags('sel_invoice_id', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('total_amount', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_type', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('check_fields', FLDFLAG_INVISIBLE, $isPersonal);
	}

	my $batchId = $page->param('_p_batch_id') || $page->field('batch_id');
	my $batchDate = $page->param('_p_batch_date') || $page->field('batch_date');
	if( $batchId && $batchDate )
	{
#		$self->setFieldFlags('batch_fields', FLDFLAG_READONLY, 1);
	}

	$self->getField('pay_type')->{fKeyWhere} = "group_name is NULL or group_name = '$paidBy'";
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	$page->field('sel_invoice_id', $invoiceId);
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $clientId = $invoiceInfo->{client_id};
	$page->field('client_id', $clientId);
	my $paidBy = $page->param('paidBy');
	if($paidBy eq 'insurance' || $invoiceInfo->{invoice_type} == App::Universal::INVOICETYPE_SERVICE)
	{
		my $currentPayer = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingCurrent', $invoiceInfo->{billing_id});
		my $billToId = $currentPayer->{bill_to_id};
		my $billPartyType = $currentPayer->{bill_party_type};
		if($billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS || $billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
		{
			my $orgId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billToId);
			$page->field('payer_id', $orgId->{org_id});
			$page->field('orgpayer_internal_id', $billToId);
		}
		else
		{
			$page->field('payer_id', $billToId);
		}
	}
	elsif($paidBy eq 'personal')
	{	
		$page->field('payer_id', $clientId);
	}

	if(my $batchId = $page->param('_p_batch_id'))
	{
		my $batchDate = $page->param('_p_batch_date');
		$page->field('batch_id', $batchId);
		$page->field('batch_date', $batchDate);
	}

	my $procedures = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, App::Universal::INVOICEITEMTYPE_SERVICE, App::Universal::INVOICEITEMTYPE_LAB);
	my $totalProcs = scalar(@{$procedures});
	foreach my $idx (0..$totalProcs-1)
	{
		#NOTE: data_num_b indicates that the line item was suppressed
		my $line = $idx + 1;			
		$page->param("_f_item_$line\_suppress", $procedures->[$idx]->{data_num_b});
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	my $paidBy = $page->param('paidBy');
	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	my $batchID = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $todaysDate = $page->getDate();
	my $payerType = $paidBy eq 'insurance' ? App::Universal::ENTITYTYPE_ORG : App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $payMethod = $paidBy eq 'insurance' ? App::Universal::ADJUSTMENTPAYMETHOD_CHECK : $page->field('pay_method');
	my $payerId = $paidBy eq 'insurance' ? $page->field('orgpayer_internal_id') : $page->field('payer_id');
	my $payRef = $page->field('pay_ref');
	my $payType = $page->field('pay_type');

	my $totalAmtRecvd = $page->field('total_amount') || $page->field('check_amount') || 0;

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $itemId = $page->param("_f_item_$line\_item_id");

		#update item if it is being suppressed
		if($itemId)
		{
			my $isSuppressed = $page->param("_f_item_$line\_suppress") ? 1 : 0;
			$page->schemaAction(
				'Invoice_Item', 'update',
				item_id => $itemId || undef,
				data_num_b => defined $isSuppressed ? $isSuppressed : undef,
				_debug => 0
			);
		}

		my $planPaid = $page->param("_f_item_$line\_plan_paid");
		my $amtApplied = $page->param("_f_item_$line\_amount_applied");
		my $writeoffAmt = $page->param("_f_item_$line\_writeoff_amt");
		next if $planPaid eq '' && $writeoffAmt eq '' && $amtApplied eq '';

		# Create adjustment for the item
		my $planAllow = $page->param("_f_item_$line\_plan_allow");
		my $writeoffCode = $page->param("_f_item_$line\_writeoff_code");
		$writeoffCode = $writeoffAmt eq '' || $writeoffCode == App::Universal::ADJUSTWRITEOFF_FAKE_NONE ? undef : $writeoffCode;

		my $comments = $page->param("_f_item_$line\_comments");
		my $adjItemId = $page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			adjustment_type => defined $adjType ? $adjType : undef,
			adjustment_amount => defined $amtApplied ? $amtApplied : undef,
			parent_id => $itemId || undef,
			plan_allow => $planAllow || undef,
			plan_paid => $planPaid || undef,
			pay_date => $todaysDate,
			pay_type => defined $payType ? $payType : undef,
			pay_method => defined $payMethod ? $payMethod : undef,
			pay_ref => $payRef || undef,
			payer_type => defined $payerType ? $payerType : undef,
			payer_id => $payerId || undef,
			writeoff_code => defined $writeoffCode ? $writeoffCode : 'NULL',
			writeoff_amount => $writeoffAmt || undef,
			comments => $comments || undef,
			_debug => 0
		);


		#Create history attribute for this adjustment
		my $itemCPT = $page->param("_f_item_$line\_item_adjustments");
		my $payerIdDisplay = $page->field('payer_id');
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => "\u$paidBy payment of \$$totalAmtRecvd made by '$payerIdDisplay'",
			value_textB => "$comments " . "Batch ID: $batchID"|| undef,
			value_date => $todaysDate,
			_debug => 0
		);

		#Create attribute for batchId
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/Payment/Batch ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $batchID || undef,
			value_date => $batchDate || undef,
			value_int => $adjItemId || undef,
			_debug => 0
		);
	}



	#Update the invoice
	my $updatedLineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	my $totalAdjustForInvoice = 0;
	foreach my $item (@{$updatedLineItems})
	{
		$totalAdjustForInvoice += $item->{total_adjust};
	}

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
	my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;
	my $newStatus = '';
	if($invoiceBalance == 0)
	{
		$newStatus = App::Universal::INVOICESTATUS_CLOSED;
	}
	else
	{
		$newStatus = $paidBy eq 'insurance' ? App::Universal::INVOICESTATUS_PAYAPPLIED : $invoice->{invoice_status};
	}
	
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		invoice_status => $newStatus,
		_debug => 0
	);

	if($invoiceBalance == 0)
	{
		App::Dialog::Procedure::execAction_submit($page, 'add', $invoiceId);
	}


	$page->redirect("/invoice/$invoiceId/summary");
}

1;
