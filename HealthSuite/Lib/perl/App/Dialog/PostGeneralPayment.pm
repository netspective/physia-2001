##############################################################################
package App::Dialog::PostGeneralPayment;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Statements::BillingStatement;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Dialog::Field::Invoice;
use App::Universal;
use App::Utilities::Invoice;
use App::Dialog::Field::BatchDateID;
use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA %RESOURCE_MAP);
use constant NEXTACTION_PATIENTSUMMARY => "/person/%field.payer_id%/profile";
use constant NEXTACTION_PATIENTACCT => "/person/%field.payer_id%/account";
use constant NEXTACTION_PATIENTWORKLIST => "/worklist/patientflow";

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'postpersonalpayment' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, heading => 'Add Personal Payment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'list_invoices'),
		new CGI::Dialog::Field(type => 'hidden', name => 'credit_warning_flag'),
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',listInvoiceFieldName=>'list_invoices'),

		new App::Dialog::Field::Person::ID(caption => 'Patient/Person ID', name => 'payer_id', options => FLDFLAG_REQUIRED, incSimpleName=>1),

		new CGI::Dialog::Field(type => 'currency',
					caption => 'Total Payment Received',
					name => 'total_amount',
					options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(
					name => 'pay_type',
					caption => 'Payment Type',
					enum => 'Payment_Type',
					fKeyWhere => "group_name is NULL or group_name = 'personal'"),

		new CGI::Dialog::MultiField(caption =>'Payment Method/Check Number', name => 'pay_method_fields',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method'),
				new CGI::Dialog::Field(caption => 'Check Number', name => 'pay_ref'),
				]),

		new CGI::Dialog::Field(caption => 'Authorization/Reference Number', name => 'auth_ref'),

		new CGI::Dialog::Field(
				caption => 'Provider ID',
				name => 'provider_id',
				options => FLDFLAG_PREPENDBLANK,
				fKeyStmtMgr => $STMTMGR_PERSON,
				fKeyStmt => 'selPersonBySessionOrgAndCategory',
				fKeyDisplayCol => 0,
				fKeyValueCol => 0),

		new CGI::Dialog::Subhead(heading => 'Outstanding Invoices', name => 'outstanding_heading'),
		new App::Dialog::Field::OutstandingInvoices(name =>'outstanding_invoices_list'),

	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.person_id#",
		data => "personal payment of '#field.total_amount#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions => [
							['Go to Patient Summary', NEXTACTION_PATIENTSUMMARY, 1],
							['Go to Patient Account', NEXTACTION_PATIENTACCT],
							['Return to Patient Flow Work List', NEXTACTION_PATIENTWORKLIST],
							['Go to Work List', "/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $payType = $page->field('pay_type');
	if($payType == App::Universal::ADJUSTMENTPAYTYPE_PREPAY || $payType == App::Universal::ADJUSTMENTPAYTYPE_COPAYPREPAY)
	{
		$self->setFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('outstanding_invoices_list', FLDFLAG_INVISIBLE, 1);
	}


	#make payment fields and list of invoices invisible unless person id exists
	$self->setFieldFlags('payer_id', FLDFLAG_READONLY, 1);
	unless(my $personId = $page->param('person_id') || $page->param('_payer_id') || $page->field('payer_id'))
	{
		$self->updateFieldFlags('payer_id', FLDFLAG_READONLY, 0);
		$self->setFieldFlags('batch_fields', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('total_amount', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('pay_type', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('auth_ref', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('outstanding_invoices_list', FLDFLAG_INVISIBLE, 1);
	}

	my $batchId = $page->param('_p_batch_id') || $page->field('batch_id');
	my $batchDate = $page->param('_p_batch_date') || $page->field('batch_date');
	if( $batchId && $batchDate )
	{
		#$self->setFieldFlags('batch_fields', FLDFLAG_READONLY, 1);
	}


	#pass in bind params to populate provide field
	$self->getField('provider_id')->{fKeyStmtBindPageParams} = [$page->session('org_internal_id'), 'Physician'];

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$page->field('batch_id', $page->session('batch_id')) if $page->field('batch_id') eq '';

	if(my $batchId = $page->param('_p_batch_id'))
	{
		my $batchDate = $page->param('_p_batch_date');
		$page->field('batch_id', $batchId);
		$page->field('batch_date', $batchDate);
	}

	my $personId = $page->param('person_id') || $page->param('_payer_id');
	$page->field('payer_id', $personId);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $payType = $page->field('pay_type');
	my $payWasApplied;
	my $lineCount = $page->param('_f_line_count');
	my $list='';
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_invoice_$line\_payment");
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");
		next if $payAmt eq '';
		$list .= $invoiceId.",";
		$payWasApplied = 1;
	}
	$page->field('list_invoices',$list);

	if($payWasApplied == 1 && ($payType == App::Universal::ADJUSTMENTPAYTYPE_PREPAY || $payType == App::Universal::ADJUSTMENTPAYTYPE_COPAYPREPAY) )
	{
		my $payTypeField = $self->getField('pay_type');
		$payTypeField->invalidate($page, "Cannot choose 'Pre-payment' or 'Copay Pre-paid' when applying payment to invoices.");
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $payType = $page->field('pay_type');
	if($payType == App::Universal::ADJUSTMENTPAYTYPE_PREPAY || $payType == App::Universal::ADJUSTMENTPAYTYPE_COPAYPREPAY)
	{
		#$page->addError("Pre: $payType < 1");
		executePrePayment($self, $page, $command, $flags);
	}
	else
	{
		#$page->addError("Pre: $payType > 1");
		executePostPayment($self, $page, $command, $flags);
	}

	$self->handlePostExecute($page, $command, $flags);

}

sub executePrePayment
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $timeStamp = $page->getTimeStamp();
	my $sessOrgIntId = $page->session('org_internal_id');

	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $payerType = App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
	my $entityTypeOrg = App::Universal::ENTITYTYPE_ORG;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;

	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $payerId = $page->field('payer_id');
	my $payMethod = $page->field('pay_method');
	my $payType = $page->field('pay_type');
	my $payRef = $page->field('pay_ref');
	my $authRef = $page->field('auth_ref');
	my $providerId = $page->field('provider_id');
	my $totalAmtRecvd = $page->field('total_amount') || 0;

	my $transId = $page->schemaAction(
		'Transaction', 'add',
		trans_type => App::Universal::TRANSTYPEACTION_PAYMENT,
		trans_status => defined $transStatus ? $transStatus : undef,
		service_facility_id => $sessOrgIntId || undef,
		billing_facility_id => $sessOrgIntId || undef,
		provider_id => $providerId || undef,
		care_provider_id => $providerId || undef,
		trans_owner_type => defined $entityTypePerson ? $entityTypePerson : undef,
		trans_owner_id => $payerId || undef,
		initiator_type => defined $entityTypePerson ? $entityTypePerson : undef,
		initiator_id => $payerId || undef,
		receiver_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		receiver_id => $sessOrgIntId || undef,
		bill_type => 0,
		trans_begin_stamp => $timeStamp || undef,
		_debug => 0
	);


	#add invoice
	my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $invoiceStatus = App::Universal::INVOICESTATUS_CREATED;
	my $invoiceId = $page->schemaAction(
		'Invoice', 'add',
		invoice_type => defined $invoiceType ? $invoiceType : undef,
		invoice_subtype => App::Universal::CLAIMTYPE_SELFPAY,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		invoice_date => $page->getDate() || undef,
		submitter_id => $page->session('user_id') || undef,
		main_transaction => $transId || undef,
		owner_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		owner_id => $sessOrgIntId || undef,
		client_type => defined $entityTypePerson ? $entityTypePerson : undef,
		client_id => $payerId || undef,
		_debug => 0
	);


	#add invoice billing and update invoice with new billing id
	my $billPartyType = App::Universal::INVOICEBILLTYPE_CLIENT;
	my $billId = $page->schemaAction(
		'Invoice_Billing', 'add',
		invoice_id => $invoiceId || undef,
		bill_sequence => App::Universal::PAYER_PRIMARY,
		bill_party_type => defined $billPartyType ? $billPartyType : undef,
		bill_to_id => $payerId || undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		billing_id => $billId,
	);


	#add invoice item
	my $itemId = $page->schemaAction(
		'Invoice_Item', 'add',
		parent_id => $invoiceId,
		item_type => App::Universal::INVOICEITEMTYPE_ADJUST,
		_debug => 0
	);

	#Add adjustment for the item
	my $comments = $page->param('prepay_comments');
	my $adjItemId = $page->schemaAction(
		'Invoice_Item_Adjust', 'add',
		adjustment_type => defined $adjType ? $adjType : undef,
		adjustment_amount => defined $totalAmtRecvd ? $totalAmtRecvd : undef,
		parent_id => $itemId || undef,
		pay_date => $todaysDate || undef,
		pay_method => defined $payMethod ? $payMethod : undef,
		pay_ref => $payRef || undef,
		payer_type => $payerType || 0,
		payer_id => $payerId || undef,
		pay_type => defined $payType ? $payType : undef,
		data_text_a => $authRef || undef,
		comments => $comments || undef,
		_debug => 0
	);

	#Create history item for this adjustment and batch id attribute
	addHistoryItem($page, $invoiceId, value_text => "Prepayment of $totalAmtRecvd made by $payerId", value_textB => "$comments " . "Batch ID: $batchId");
	addBatchPaymentAttr($page, $invoiceId, value_text => $batchId || undef, value_int => $adjItemId, value_date => $batchDate || undef);

	$page->session('batch_id', $batchId);
}

sub executePostPayment
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $payerType = App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $payerId = $page->field('payer_id');
	my $payMethod = $page->field('pay_method');
	my $payType = $page->field('pay_type');
	my $payRef = $page->field('pay_ref');
	my $authRef = $page->field('auth_ref');

	my $totalAmtRecvd = $page->field('total_amount') || 0;
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_invoice_$line\_payment");
		next if $payAmt eq '';

		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");

		my $itemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $invoiceId,
			item_type => defined $itemType ? $itemType : undef,
			_debug => 0
		);

		# Create adjustment for the item
		my $comments = $page->param("_f_invoice_$line\_comments");
		my $adjItemId = $page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			adjustment_type => defined $adjType ? $adjType : undef,
			adjustment_amount => defined $payAmt ? $payAmt : undef,
			parent_id => $itemId || undef,
			pay_date => $todaysDate || undef,
			pay_method => defined $payMethod ? $payMethod : undef,
			pay_ref => $payRef || undef,
			payer_type => $payerType || 0,
			payer_id => $payerId || undef,
			data_text_a => $authRef || undef,
			pay_type => defined $payType ? $payType : undef,
			comments => $comments || undef,
			_debug => 0
		);


		#Create history item for this adjustment
		addHistoryItem($page, $invoiceId, value_text => "Personal payment of $totalAmtRecvd made by $payerId", value_textB => "$comments " . "Batch ID: $batchId");


		#Update the invoice
		my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
		my $invoiceBalance = $invoice->{balance};
		my $invoiceStatus = $invoice->{invoice_status};
		my $newStatus = $invoiceBalance == 0 ? App::Universal::INVOICESTATUS_CLOSED : App::Universal::INVOICESTATUS_PAYAPPLIED;
		$newStatus = $invoiceStatus == App::Universal::INVOICESTATUS_SUBMITTED ? App::Universal::INVOICESTATUS_SUBMITTED : $newStatus;
		$newStatus = $invoiceStatus == App::Universal::INVOICESTATUS_ONHOLD ? App::Universal::INVOICESTATUS_ONHOLD : $newStatus;
		$newStatus = $invoiceStatus == App::Universal::INVOICESTATUS_CLOSED ? App::Universal::INVOICESTATUS_ONHOLD : $newStatus;
		changeInvoiceStatus($page, $invoiceId, $newStatus) if defined $newStatus;

		if($newStatus == App::Universal::INVOICESTATUS_CLOSED)
		{
			handleDataStorage($page, $invoiceId);
			addHistoryItem($page, $invoiceId, value_text => 'Closed');
		}

		#Add batch id attribute
		addBatchPaymentAttr($page, $invoiceId, value_text => $batchId || undef, value_int => $adjItemId, value_date => $batchDate || undef);
		$page->session('batch_id', $batchId);


		if ($page->field('pay_type') == 9) # Budget Payment
		{
			my $paymentPlan = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE,
				'sel_paymentPlan', $page->field('payer_id'), $page->session('org_internal_id'));

			if (my $planId = $paymentPlan->{plan_id})
			{
				$page->schemaAction(
					'Payment_Plan', 'update',
					plan_id => $planId,
					lastpay_amount => $totalAmtRecvd,
					lastpay_date => $todaysDate,
					balance => $paymentPlan->{balance} - $totalAmtRecvd,
					next_due => nextDueDate($paymentPlan),
				);
				$page->schemaAction(
					'Payment_History', 'add',
					parent_id => $planId,
					value_stamp => $page->getTimeStamp(),
					value_float => $totalAmtRecvd,
					value_text => "$comments " . "Batch ID: $batchId",
				);
			}
		}
	}
}

sub nextDueDate
{
	my ($paymentPlan) = @_;

	my $dateFormat = '%m/%d/%Y';
	my $planDueDate = $paymentPlan->{next_due};
	my $billingCycle = $paymentPlan->{payment_cycle};

	my $nextDueDate = $billingCycle == 30 ? DateCalc($planDueDate, "+ 1 month") :
		DateCalc($planDueDate, "+ $billingCycle days");

	while (Delta_Days(Today(), Decode_Date_US(UnixDate($nextDueDate, $dateFormat))) < 0)
	{
		$nextDueDate = $billingCycle == 30 ? DateCalc($nextDueDate, "+ 1 month") :
			DateCalc($nextDueDate, "+ $billingCycle days");
	}

	return UnixDate($nextDueDate, $dateFormat);
}

1;
