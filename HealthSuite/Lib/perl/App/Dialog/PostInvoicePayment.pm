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
use App::Utilities::Invoice;
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
		new CGI::Dialog::Field(type => 'hidden', name => 'alert_off'),
		new CGI::Dialog::Field(type => 'hidden', name => 'client_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'product_ins_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'next_payer_exists'),

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
				enum => 'Payment_Type',
				),

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

		new CGI::Dialog::Field(type => 'select', style => 'radio', selOptions => 'Yes:1;No:2', name => 'next_payer_alert', caption => 'Submit to Next Payer?'),


	);

	#$self->addFooter(new CGI::Dialog::Buttons(
	#					name => 'next_action',
	#					nextActions_add => [
	#						['Submit to Next Payer (Electronically)', "/invoice/%param.invoice_id%/submit?resubmit=2", 1],
	#						['Submit to Next Payer (Print HCFA)', "/invoice/%param.invoice_id%/submit?resubmit=2&print=1"],
	#						['Return to Claim Summary', "/invoice/%param.invoice_id%/summary"],
	#					],
	#					cancelUrl => $self->{cancelUrl} || undef));

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "'#param.paidBy#' post invoice payment to claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};

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
	$self->setFieldFlags('next_payer_alert', FLDFLAG_INVISIBLE, 1);
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
		$self->updateFieldFlags('prepay_comments', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_items_list', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('next_action', FLDFLAG_INVISIBLE, 1);
	}
     	elsif($invoiceId)
	{
		$self->updateFieldFlags('sel_invoice_id', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('total_amount', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_type', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('check_fields', FLDFLAG_INVISIBLE, $isPersonal);
		$self->updateFieldFlags('prepay_comments', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('next_action', FLDFLAG_INVISIBLE, $isPersonal);
	}

	my $batchId = $page->param('_p_batch_id') || $page->field('batch_id');
	my $batchDate = $page->param('_p_batch_date') || $page->field('batch_date');
	if( $batchId && $batchDate )
	{
#		$self->setFieldFlags('batch_fields', FLDFLAG_READONLY, 1);
	}

	$self->getField('pay_type')->{fKeyWhere} = "id != @{[ App::Universal::ADJUSTMENTPAYTYPE_COPAYPREPAY ]} and caption != 'Pre-payment' and (group_name is NULL or group_name = 'personal')";
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$page->field('batch_id', $page->session('batch_id')) if $page->field('batch_id') eq '';

	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	$page->field('sel_invoice_id', $invoiceId);
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
			#populate payer info
			my $orgId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billToId);
			$page->field('payer_id', $orgId->{org_id});
			$page->field('orgpayer_internal_id', $billToId);

			#populate product ins internal id for getting plan allow
			my $coverage = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $currentPayer->{bill_ins_id});
			my $coverageParent = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $coverage->{parent_ins_id});
			if($coverageParent->{record_type} == App::Universal::RECORDTYPE_INSURANCEPRODUCT)
			{
				$page->field('product_ins_id', $coverageParent->{ins_internal_id});
			}
			else
			{	
				my $product = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $coverageParent->{parent_ins_id});
				$page->field('product_ins_id', $product->{ins_internal_id});
			}
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

	$page->field('batch_date', $page->param('_p_batch_date'));

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
	my $sessOrg = $page->session('org_id');
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $paidBy = $page->param('paidBy');
	my $nextPayerExists = $page->field('next_payer_exists');
	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $todaysDate = $page->getDate();
	my $payerType = $paidBy eq 'insurance' ? App::Universal::ENTITYTYPE_ORG : App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $payMethod = $paidBy eq 'insurance' ? App::Universal::ADJUSTMENTPAYMETHOD_CHECK : $page->field('pay_method');
	my $payerId = $paidBy eq 'insurance' ? $page->field('orgpayer_internal_id') : $page->field('payer_id');
	my $payerIdDisplay = $page->field('payer_id');
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
		my $writeoffCode = $writeoffAmt eq '' ? undef : $page->param("_f_item_$line\_writeoff_code");
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
			writeoff_code => defined $writeoffCode ? $writeoffCode : undef,
			writeoff_amount => $writeoffAmt || undef,
			comments => $comments || undef,
			_debug => 0
		);


		#Create attribute for batchId
		addBatchPaymentAttr($page, $invoiceId, value_text => $batchId || undef, value_int => $adjItemId, value_date => $batchDate || undef);
	}


	#Reset session batch id
	$page->session('batch_id', $batchId);

	#Create history attribute for total payment
	addHistoryItem($page, $invoiceId, value_text => "\u$paidBy payment of \$$totalAmtRecvd made by '$payerIdDisplay'", value_textB => "Batch ID: $batchId");

	#Update the invoice status
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
	my $invoiceBalance = $invoice->{balance};
	my $invoiceStatus = $invoice->{invoice_status};
	my $claimType = $invoice->{invoice_subtype};
	my $newStatus;
	if($invoiceStatus == App::Universal::INVOICESTATUS_ONHOLD)
	{
		$newStatus = App::Universal::INVOICESTATUS_ONHOLD;
		addHistoryItem($page, $invoiceId, value_text => 'On Hold');
	}
	elsif($invoiceStatus == App::Universal::INVOICESTATUS_CLOSED && $claimType != App::Universal::CLAIMTYPE_SELFPAY)
	{
		reopenInsuranceClaim($page, $invoiceId);
	}
	elsif($invoiceStatus == App::Universal::INVOICESTATUS_SUBMITTED)
	{
		#if payments are applied to a submitted claim, don't want to change status because otherwise it will not be picked up for transfer/billing
		$newStatus = App::Universal::INVOICESTATUS_SUBMITTED;
	}
	elsif($invoiceBalance == 0 && 
			($claimType == App::Universal::CLAIMTYPE_SELFPAY || ($invoice->{flags} & App::Universal::INVOICEFLAG_DATASTOREATTR && ! $nextPayerExists)) 
		)
	{
		$newStatus = App::Universal::INVOICESTATUS_CLOSED;
		addHistoryItem($page, $invoiceId, value_text => 'Closed');
		handleDataStorage($page, $invoiceId);
	}
	else
	{
		$newStatus = App::Universal::INVOICESTATUS_PAYAPPLIED;
	}

	changeInvoiceStatus($page, $invoiceId, $newStatus) if defined $newStatus;


	#Redirect
	my $newInvoiceId;
	if($page->field('next_payer_alert') == 1)
	{
		$newInvoiceId = handleDataStorage($page, $invoiceId, App::Universal::RESUBMIT_NEXTPAYER);
	}

	if(my $paramBatchId = $page->param('_p_batch_id'))
	{
		$page->param('_dialogreturnurl', "/org/$sessOrg/dlg-add-batch?_p_batch_id=$paramBatchId&_p_batch_type=$paidBy");
	}
	elsif($newInvoiceId)
	{
		$page->param('_dialogreturnurl', "/invoice/$newInvoiceId/summary");
	}
	else
	{
		$page->param('_dialogreturnurl', "/invoice/$invoiceId/summary");
	}

	$self->handlePostExecute($page, $command, $flags);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $paidBy = $page->param('paidBy');
	my $invoiceId = $page->param('invoice_id') || $page->param('_sel_invoice_id') || $page->field('sel_invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $billingInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingCurrent', $invoiceInfo->{billing_id});
	my $nextBillingInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingByInvoiceIdAndBillSeq', $invoiceId, $billingInfo->{bill_sequence} + 1);
	my $nextPayer = $nextBillingInfo->{bill_id};
	my $invoiceStat = $invoiceInfo->{invoice_status};

	#indicate that a next payer does exist in hidden field (used in sub execute to determine if claim should be closed or not)
	$page->field('next_payer_exists', 1) if defined $nextPayer;


	#ask if claim should be sent to next payer
	if($paidBy eq 'insurance')	#this 'if' will never occur for self-pay invoices
	{
		if( 
			 $nextPayer && ! $page->field('next_payer_alert') && 
			(
				($invoiceStat >= App::Universal::INVOICESTATUS_INTNLREJECT && $invoiceStat <= App::Universal::INVOICESTATUS_MTRANSFERRED) ||
				$invoiceStat == App::Universal::INVOICESTATUS_EXTNLREJECT || $invoiceStat == App::Universal::INVOICESTATUS_AWAITINSPAYMENT ||
				$invoiceStat == App::Universal::INVOICESTATUS_PAYAPPLIED || $invoiceStat == App::Universal::INVOICESTATUS_PAPERCLAIMPRINTED ||
				$invoiceStat == App::Universal::INVOICESTATUS_CLOSED
			) 
		    )
		{
			my $getNextPayerAlert = $self->getField('next_payer_alert');
			$self->updateFieldFlags('next_payer_alert', FLDFLAG_INVISIBLE, 0);
			$getNextPayerAlert->invalidate($page, "Would you like to submit this claim to the next payer?");
		}
	}
}

1;
