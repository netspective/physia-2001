##############################################################################
package App::Dialog::Invoice;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use App::Statements::Transaction;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Catalog;

use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Invoice;
use App::Dialog::Field::Organization;
use App::Universal;
use App::Dialog::Field::BatchDateID;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'invoice' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'invoice', heading => '$Command Invoice');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'trans_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'current_status'),
		new CGI::Dialog::Field(type => 'hidden', name => 'batch_item_id'),


		#BatchDateId Needs the name of the Org.  So it can check if the org has a close date.
		#Batch Date must be > then close Date to pass validation
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',orgInternalIdFieldName=>'owner_id'),

		new App::Dialog::Field::Person::ID(caption => 'Patient ID', name => 'client_id', options => FLDFLAG_REQUIRED, types => ['Patient']),
		new CGI::Dialog::MultiField(caption => 'Payer ID/Type', name => 'other_payer_fields', hints => "If left blank, invoice will be billed to the 'Patient ID'",
			fields => [
				new CGI::Dialog::Field(caption => 'Payer ID', name => 'bill_to_id', findPopup => '/lookup/itemValue', findPopupControlField => '_f_bill_to_type'),
				new CGI::Dialog::Field(type => 'select', selOptions => 'Person:person;Organization:org', caption => 'Payer Type', name => 'bill_to_type'),
			]),


		new CGI::Dialog::Field(
				caption => 'Provider',
				name => 'provider_id',
				fKeyStmtMgr => $STMTMGR_PERSON,
				fKeyStmt => 'selPersonBySessionOrgAndCategory',
				fKeyDisplayCol => 0,
				fKeyValueCol => 0,
				options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::OrgType(
				caption => 'Pay To Org',
				name => 'owner_id'),
		new App::Dialog::Field::InvoiceItems(caption => 'Items', name => 'invoice_items'),
	);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $sessOrg = $page->session('org_internal_id');
	$self->getField('provider_id')->{fKeyStmtBindPageParams} = [$sessOrg, 'Physician'];

	#Set attendee_id field and make it read only if person_id exists
	if(my $personId = $page->param('person_id'))
	{
		$page->field('client_id', $personId);
		$self->setFieldFlags('client_id', FLDFLAG_READONLY);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$page->field('batch_id', $page->session('batch_id')) if $page->field('batch_id') eq '';

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $invoiceId = $page->param('invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	$page->field('client_id', $invoiceInfo->{client_id});
	$page->field('current_status', $invoiceInfo->{invoice_status});
	$page->field('claim_type', $invoiceInfo->{invoice_subtype});
	$page->field('owner_id', $invoiceInfo->{owner_id});
	$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $invoiceInfo->{main_transaction});

	my $invoiceBilling = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingCurrent', $invoiceInfo->{billing_id});
	my $billToId = $invoiceBilling->{bill_to_id};
	my $billPartyType = $invoiceBilling->{bill_party_type};
	if($billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS || $billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
	{
		my $orgId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billToId);
		$billToId = $orgId->{org_id};
	}

	$page->field('bill_to_id', $billToId);
	my $billToType = $billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG || $invoiceBilling->{bill_party_type} == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS 
					? 'org' : 'person';
	$page->field('bill_to_type', $billToType);

	my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');
	$page->field('batch_item_id', $batchInfo->{item_id});
	$page->field('batch_id', $batchInfo->{value_text});
	$page->field('batch_date', $batchInfo->{value_date});

	my $items = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_INVOICE);
	my $totalItems = scalar(@{$items});
	foreach my $idx (0..$totalItems)
	{
		my $line = $idx + 1;
		$page->param("_f_item_$line\_dos_begin", $items->[$idx]->{service_begin_date});
		$page->param("_f_item_$line\_dos_end", $items->[$idx]->{service_end_date});
		$page->param("_f_item_$line\_item_id", $items->[$idx]->{item_id});
		$page->param("_f_item_$line\_unit_cost", $items->[$idx]->{unit_cost});
		$page->param("_f_item_$line\_quantity", $items->[$idx]->{quantity});
		$page->param("_f_item_$line\_code", $items->[$idx]->{code});
		$page->param("_f_item_$line\_comments", $items->[$idx]->{comments});
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;
	addTransactionAndInvoice($self, $page, $command, $flags);
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;
	addTransactionAndInvoice($self, $page, $command, $flags);
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $sessUser = $page->session('user_id');
	my $invoiceId = $page->param('invoice_id');

	my $lineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $item (@{$lineItems})
	{
		my $itemType = $item->{item_type};
		my $itemId = $item->{item_id};
		my $voidItemType = App::Universal::INVOICEITEMTYPE_VOID;

		next if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;
		next if $itemType == $voidItemType;
		next if $item->{data_text_b} eq 'void';

		my $extCost = 0 - $item->{extended_cost};
		my $itemBalance = $extCost;
		my $emg = $item->{emergency};
		$page->schemaAction(
			'Invoice_Item', 'add',
			parent_item_id => $itemId || undef,
			parent_id => $invoiceId || undef,
			item_type => defined $voidItemType ? $voidItemType : undef,
			service_begin_date => $item->{service_begin_date} || undef,
			service_end_date => $item->{service_end_date} || undef,
			hcfa_service_place => $item->{hcfa_service_place} || undef,
			hcfa_service_type => $item->{hcfa_service_type} || undef,
			modifier => $item->{modifier} || undef,
			quantity => $item->{quantity} || undef,
			emergency => defined $emg ? $emg : undef,
			code => $item->{code} || undef,
			caption => $item->{caption} || undef,
			#comments =>  $item->{} || undef,
			unit_cost => $item->{unit_cost} || undef,
			rel_diags => $item->{rel_diags} || undef,
			data_text_a => $item->{data_text_a} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			_debug => 0
		);

		$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId || undef,
			data_text_b => 'void',
			_debug => 0
		);
	}

	my $invoiceStatus = App::Universal::INVOICESTATUS_VOID;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		_debug => 0
	);
	

	#CREATE NEW VOID TRANSACTION FOR VOIDED CLAIM
	my $transType = App::Universal::TRANSTYPEACTION_VOID;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	$page->schemaAction(
		'Transaction', 'add',
		parent_trans_id => $page->field('trans_id') || undef,
		parent_event_id => $page->field('parent_event_id') || undef,
		trans_type => defined $transType ? $transType : undef,
		trans_status => defined $transStatus ? $transStatus : undef,	
		trans_status_reason => "Claim $invoiceId has been voided by $sessUser",
		_debug => 0
	);


	#ADD HISTORY ATTRIBUTE
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => defined $historyValueType ? $historyValueType : undef,
		value_text => 'Voided claim',
		value_date => $todaysDate,
		_debug => 0
	);

	$page->redirect("/invoice/$invoiceId/summary");
}

sub handlePayer
{
	my ($self, $page, $command, $flags) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	my $personId = $page->field('client_id');

	#CONSTANTS -------------------------------------------

	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	my $typeSelfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $typeClient = App::Universal::CLAIMTYPE_CLIENT;

	# ------------------------------------------------------------


	my $payerId = $page->field('bill_to_id');
	my $payerType = $page->field('bill_to_type');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $sessOrgIntId, $payerId) if $payerType eq 'org';
	$payerId = $orgIntId ? $orgIntId : $payerId;
	if($payerId eq $personId || $payerId eq '')
	{
		$page->field('claim_type', $typeSelfPay);
	}
	else
	{
		if(my $insurancePayer = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByPersonAndInsOrg', $personId, $orgIntId))
		{
			$page->field('claim_type', $insurancePayer->{ins_type});
		}
		elsif($STMTMGR_INSURANCE->recordExists($page, STMTMGRFLAG_NONE, 'selInsuranceByPersonOwnerAndGuarantorAndInsType', $personId, $payerId, $typeClient))
		{
			$page->field('claim_type', $typeClient);
		}
		elsif(! $STMTMGR_INSURANCE->recordExists($page, STMTMGRFLAG_NONE, 'selInsuranceByPersonOwnerAndGuarantorAndInsType', $personId, $payerId, $typeClient))
		{
			$page->field('claim_type', $typeClient);

			my $addr = undef;
			my $insPhone = undef;
			my $guarantorType = undef;

			if($payerType eq 'person')
			{
				$guarantorType = App::Universal::ENTITYTYPE_PERSON;
				$addr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $payerId);
				$insPhone = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $payerId, 'Home', $phoneAttrType);
			}
			else
			{
				$guarantorType = App::Universal::ENTITYTYPE_ORG;
				$addr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selOrgAddressByAddrName', $payerId, 'Mailing');
				$insPhone = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $payerId, 'Primary', $phoneAttrType);
			}

			my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
			my $insIntId = $page->schemaAction(
				'Insurance', 'add',
				owner_person_id => $personId || undef,
				record_type => defined $recordType ? $recordType : undef,
				ins_type => defined $typeClient ? $typeClient : undef,
				guarantor_id => $payerId,
				guarantor_type => defined $guarantorType ? $guarantorType : undef,
				_debug => 0
			);

			$page->schemaAction(
				'Insurance_Address', 'add',
				parent_id => $insIntId || undef,
				address_name => 'Billing',
				line1 => $addr->{line1} || undef,
				line2 => $addr->{line2} || undef,
				city => $addr->{city} || undef,
				county => $addr->{county} || undef,
				state => $addr->{state} || undef,
				zip => $addr->{zip} || undef,
				country => $addr->{country} || undef,
				_debug => 0
			);

			$page->schemaAction(
				'Insurance_Attribute', 'add',
				parent_id => $insIntId || undef,
				item_name => 'Contact Method/Telephone/Primary',
				value_type => defined $phoneAttrType ? $phoneAttrType : undef,
				value_text => $insPhone->{value_text} || undef,
				_debug => 0
			);
		}
	}
}

sub addTransactionAndInvoice
{
	my ($self, $page, $command, $flags) = @_;

	handlePayer($self, $page, $command, $flags);

	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $timeStamp = $page->getTimeStamp();
	my $sessOrg = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');

	# Constants -----------------------------------------------------------------

	my $invoiceStatusCreate = App::Universal::INVOICESTATUS_CREATED;
	my $invoiceType = App::Universal::INVOICETYPE_SERVICE;
	my $itemType = App::Universal::INVOICEITEMTYPE_INVOICE;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $personType = App::Universal::ENTITYTYPE_PERSON;
	my $orgType = App::Universal::ENTITYTYPE_ORG;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transType = App::Universal::TRANSTYPEVISIT_FACILITY;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	# ------------------------------------------------------------------------------

	my $personId = $page->field('client_id');
	my $claimType = $page->field('claim_type');

	my $editTransId = $page->field('trans_id');
	my $transId = $page->schemaAction(
		'Transaction', $command,
		trans_id => $editTransId || undef,
		trans_type => defined $transType ? $transType : undef,
		trans_status => defined $transStatus ? $transStatus : undef,
		service_facility_id => $page->field('owner_id') || undef,
		billing_facility_id => $page->field('owner_id') || undef,
		provider_id => $page->field('provider_id') || undef,
		trans_owner_type => defined $personType ? $personType : undef,
		trans_owner_id => $personId || undef,
		initiator_type => defined $personType ? $personType : undef,
		initiator_id => $personId || undef,
		bill_type => defined $claimType ? $claimType : undef,
		trans_begin_stamp => $timeStamp || undef,
		_debug => 0
	);

	$transId = $command eq 'add' ? $transId : $editTransId;
	my $invoiceStatus = $command eq 'add' ? $invoiceStatusCreate : $page->field('current_status');
	my $editInvoiceId = $page->param('invoice_id');
	my $invoiceId = $page->schemaAction(
		'Invoice', $command,
		invoice_id => $editInvoiceId || undef,
		invoice_type => defined $invoiceType ? $invoiceType : undef,
		invoice_subtype => defined $claimType ? $claimType : undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		invoice_date => $todaysDate || undef,
		main_transaction => $transId || undef,
		submitter_id => $sessUser || undef,
		owner_type => defined $orgType ? $orgType : undef,
		owner_id => $sessOrg || undef,
		client_type => defined $personType ? $personType : undef,
		client_id => $personId || undef,
		_debug => 0
	);

	$invoiceId = $command eq 'add' ? $invoiceId : $editInvoiceId;

	my $itemCount = 0;
	my $invoiceTotal = 0;
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $quantity = $page->param("_f_item_$line\_quantity") eq '' ? 1 : $page->param("_f_item_$line\_quantity");
		my $unitCost = $page->param("_f_item_$line\_unit_cost");
		my $code = $page->param("_f_item_$line\_code");

		next if $code eq '';
		next if $unitCost eq '';

		my $extCost = $quantity * $unitCost;
		my $itemId = $page->param("_f_item_$line\_item_id");

		my $removeProc = $page->param("_f_item_$line\_remove");
		my $itemCommand = $command;
		if(! $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId))
		{
			$itemCommand = 'add';
		}
		elsif($removeProc)
		{
			#$itemCommand = 'remove';
			App::Dialog::Encounter::voidProcedureItem($self, $page, $command, $flags, $invoiceId, $itemId);
			next;
		}
		
		my $codeInfo = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selMiscProcedureBySessionOrgAndCode', $code, $sessOrg);
		$page->schemaAction(
			'Invoice_Item', $itemCommand,
			item_id => $itemId || undef,
			parent_id => $invoiceId || undef,
			item_type => defined $itemType ? $itemType : undef,
			service_begin_date => $page->param("_f_item_$line\_dos_begin") || undef,		#default for service start date is today
			service_end_date => $page->param("_f_item_$line\_dos_end") || undef,			#default for service end date is today
			caption => $codeInfo->{name} || undef,
			code => $code || undef,
			quantity => defined $quantity ? $quantity : undef,
			unit_cost => defined $unitCost ? $unitCost : undef,
			extended_cost => defined $extCost ? $extCost : undef,
			comments => $page->param("_f_item_$line\_comments") || undef,
			_debug => 0
		);

		$invoiceTotal += $extCost;
		$itemCount += 1;
	}



	## Add history and batch creation attribute and reset session batch id with batch id in field
	my $batchId = $page->field('batch_id');
	$page->session('batch_id', $batchId);
	my $description = $command eq 'add' ? "Created" : 'Modified';
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => defined $historyValueType ? $historyValueType : undef,
		value_text => $description,
		value_textB => "Batch ID: $batchId",
		value_date => $todaysDate,
		_debug => 0
	);


	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('batch_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Invoice/Creation/Batch ID',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $batchId || undef,
		value_date => $page->field('batch_date') || undef,
		_debug => 0
	);

	handleBillingInfo($self, $page, $command, $flags, $invoiceId);
}

sub handleBillingInfo
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	#delete all payers when updating or removing
	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delInvoiceBillingParties', $invoiceId) if $command ne 'add';

	#constants ---------------------------------------------------------------

	my $billPartyTypeClient = App::Universal::INVOICEBILLTYPE_CLIENT;
	my $billPartyTypePerson = App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON;
	my $billPartyTypeOrg = App::Universal::INVOICEBILLTYPE_THIRDPARTYORG;
	my $billPartyTypeInsurance = App::Universal::INVOICEBILLTYPE_THIRDPARTYINS;

	#-----------------------------------------------------------------------------

	my $personId = $page->field('client_id');
	my $payerId = $page->field('bill_to_id');
	my $payerType = $page->field('bill_to_type');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $sessOrgIntId, $payerId) if $payerType eq 'org';
	$payerId = $orgIntId ? $orgIntId : $payerId;

	my $billParty = '';
	my $billToId = '';
	my $billInsId = '';
	my $billAmt = '';
	my $billPct = '';
	my $billDate = '';
	my $billStatus = '';
	my $billResult = '';


	#primary payer
	if($payerId eq $personId || $payerId eq '')
	{
		$billParty = $billPartyTypeClient;
		$billToId = $personId;
		#$billAmt = '';
		#$billPct = '';
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';
	}
	elsif(my $thirdPartyInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByPersonOwnerAndGuarantorAndInsType', $personId, $payerId, App::Universal::CLAIMTYPE_CLIENT))
	{
		$billParty = $payerType eq 'person' ? $billPartyTypePerson : $billPartyTypeOrg;
		$billToId = $payerId;
		$billInsId = $thirdPartyInfo->{ins_internal_id};
		#$billAmt = '';
		#$billPct = '';
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';
	}
	elsif(my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByPersonAndInsOrg', $personId, $orgIntId))
	{
		$billParty = $billPartyTypeInsurance;
		$billToId = $payerId;
		$billInsId = $insInfo->{ins_internal_id};
		#$billAmt = '';
		#$billPct = '';
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';
	}


	my $primBillSeq = App::Universal::PAYER_PRIMARY;
	my $billId = $page->schemaAction(
		'Invoice_Billing', 'add',
		invoice_id => $invoiceId || undef,
		bill_sequence => defined $primBillSeq ? $primBillSeq : undef,
		bill_party_type => defined $billParty ? $billParty : undef,
		bill_to_id => $billToId || undef,
		bill_ins_id => $billInsId || undef,
		bill_amount => $billAmt || undef,
		bill_pct => $billPct || undef,
		bill_date => $billDate || undef,
		bill_status => $billStatus || undef,
		bill_result => $billResult || undef,
		_debug => 0
	);


	#secondary payer (this will only be added (as a self-pay) if the patient and payer are not the same)
	if($payerId ne $personId && $payerId ne '')
	{
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		my $secBillSeq = App::Universal::PAYER_SECONDARY;
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => defined $secBillSeq ? $secBillSeq : undef,
			bill_party_type => defined $billPartyTypeClient ? $billPartyTypeClient : undef,
			bill_to_id => $personId || undef,
			#bill_amount => $billAmt || undef,
			#bill_pct => $billPct || undef,
			#bill_date => $billDate || undef,
			#bill_status => $billStatus || undef,
			#bill_result => $billResult || undef,
			_debug => 0
		);
	}

	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		billing_id => $billId,
	);

	$self->handlePostExecute($page, $command, $flags, "/invoice/$invoiceId/summary");
}

sub customValidate
{
	my ($self, $page) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	my $payer = $page->field('bill_to_id');
	return () if $payer eq '';

	#validation for third party person or org
	my $payerType = $page->field('bill_to_type');

	$payer = uc($payer);
	$page->field('bill_to_id', $payer);
	my $payerField = $self->getField('other_payer_fields')->{fields}->[0];

	if($payerType eq 'person')
	{
		my $createHref = "javascript:doActionPopup('/org-p/#session.org_internal_id#/dlg-add-guarantor/$payer');";
		$payerField->invalidate($page, qq{
			Person Id '$payer' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			<a href="$createHref">Add Third Party Person Id '$payer' now</a>
			})
			unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $payer);
	}
	elsif($payerType eq 'org')
	{
		my $createOrgHrefPre = "javascript:doActionPopup('/org-p/#session.org_internal_id#/dlg-add-org-";
		my $createOrgHrefPost = "/$payer');";
		my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $sessOrgIntId, $payer);

		$payerField->invalidate($page, qq{
			Org Id '$payer' does not exist.<br>
			<img src="/resources/icons/arrow_right_red.gif">
			Add '$payer' Organization now as an
			<a href="${createOrgHrefPre}insurance${createOrgHrefPost}">Insurance</a> or
			<a href="${createOrgHrefPre}employer${createOrgHrefPost}">Employer</a>
			})
			unless $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $orgIntId);
	}
}

1;
