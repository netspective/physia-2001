##############################################################################
package App::Dialog::Encounter;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Invoice;
use App::Statements::Scheduling;
use App::Statements::Component::Scheduling;
use App::Statements::Catalog;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Invoice;
use App::Dialog::Field::BatchDateID;
use App::Dialog::Field::Procedures;
use App::Universal;
use App::Utilities::Invoice;
use App::Schedule::Utilities;
use App::IntelliCode;
use App::Component::WorkList::PatientFlow;

use Date::Manip;
use Date::Calc qw(:all);
use Text::Abbrev;

use vars qw(@ISA %RESOURCE_MAP);
use constant FAKESELFPAY_INSINTID => -1111;
use constant FAKENEW3RDPARTY_INSINTID => -2222;
@ISA = qw(CGI::Dialog);
%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;
	my $schema = $self->{schema};

	$self->addContent(

		#item ids for updating the attributes
		new CGI::Dialog::Field(type => 'hidden', name => 'batch_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'condition_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'prior_auth_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'resub_number_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'deduct_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'assignment_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'accept_assignment'),
		new CGI::Dialog::Field(type => 'hidden', name => 'illness_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'disability_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'hospital_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'cntrl_num_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'bill_contact_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_filing_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'fee_schedules_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'payer_selected_item_id'),
		#---------------------------------------------------------------------------------------------
		new CGI::Dialog::Field(type => 'hidden', name => 'trans_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'parent_event_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'insuranceIsSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'eventFieldsAreSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'hospFieldsAreSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'invoiceFieldsAreSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'invoice_flags'),		#to check if this claim has been submitted already
		new CGI::Dialog::Field(type => 'hidden', name => 'old_invoice_id'),	#the invoice id of the claim that is being modified after submission
		new CGI::Dialog::Field(type => 'hidden', name => 'old_person_id'),		#if user changes patient id while adding a claim, need to refresh payer list for the new patient id

		new CGI::Dialog::Field(type => 'hidden', name => 'claim_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'current_status'),
		new CGI::Dialog::Field(type => 'hidden', name => 'submission_order'),

		new CGI::Dialog::Field(type => 'hidden', name => 'provider_pair'), # for hosp claims, the service and billing provider ids are concatenated and checked in the handleProcedureItems function
		new CGI::Dialog::Field(type => 'hidden', name => 'copay_amt'),
		new CGI::Dialog::Field(type => 'hidden', name => 'dupCheckin_returnUrl'),

		new CGI::Dialog::Field(type => 'hidden', name => 'ins_ffs'), # Contains the insurance FFS
		new CGI::Dialog::Field(type => 'hidden', name => 'work_ffs'), # Contains the works comp
		new CGI::Dialog::Field(type => 'hidden', name => 'org_ffs'), # Contains the Org FFS
		new CGI::Dialog::Field(type => 'hidden', name => 'prov_ffs'), # Contains the Provider FFS


		#BatchDateId Needs the name of the Org.  So it can check if the org has a close date.
		#Batch Date must be > then close Date to pass validation
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',orgInternalIdFieldName=>'service_facility_id'),
		new App::Dialog::Field::Person::ID(caption => 'Patient ID', name => 'attendee_id', options => FLDFLAG_REQUIRED, types => ['Patient']),

		new CGI::Dialog::Field(type => 'stamp', caption => 'Appointment Time',
			name => 'start_time', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(type => 'stamp', caption => 'Check-in Time',
			name => 'checkin_stamp', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(type => 'stamp', caption => 'Check-out Time',
			name => 'checkout_stamp', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field::TableColumn(
			caption => 'Type of Visit',
			schema => $schema,
			column => 'Transaction.trans_type',
			typeRange => '2000..2999'),
		new CGI::Dialog::Field::TableColumn(
			name => 'appt_type',
			options => FLDFLAG_READONLY,
			caption => 'Appointment Type',
			schema => $schema,
			column => 'Event.appt_type'),
		new CGI::Dialog::Field(caption => 'Reason for Visit', name => 'subject', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'memo', caption => 'Symptoms', name => 'remarks'),

		new CGI::Dialog::Field(name => 'accident',
				caption => 'Accident?',
				fKeyStmtMgr => $STMTMGR_INVOICE,
				fKeyStmt => 'selAccidentDropDown',
				fKeyDisplayCol => 0,
				fKeyValueCol => 1),
		new CGI::Dialog::Field(caption => 'Place of Auto Accident (State)', name => 'accident_state', size => 2, maxLength => 2),

		new CGI::Dialog::Field(caption => 'Primary Payer', type => 'select', name => 'payer'),

		new CGI::Dialog::MultiField(caption => 'Payer for Today ID/Type', name => 'other_payer_fields',
			fields => [
				new CGI::Dialog::Field(
						caption => 'Payer for Today ID',
						name => 'other_payer_id',
						findPopup => '/lookup/itemValue',
						findPopupControlField => '_f_other_payer_type'),
				new CGI::Dialog::Field(type => 'select', selOptions => 'Person:person;Organization:org', caption => 'Payer for Today Type', name => 'other_payer_type'),
			]),

		new CGI::Dialog::Field(type => 'currency', caption => 'Deductible Balance', name => 'deduct_balance'),
		new CGI::Dialog::Field(caption => 'Contact Phone for Primary Insurance', name => 'primary_ins_phone', options => FLDFLAG_READONLY),

		new CGI::Dialog::MultiField(caption => 'Provider Service/Billing', name => 'provider_fields',
			fields => [
				new CGI::Dialog::Field(
						caption => 'Service Provider',
						name => 'care_provider_id',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selPersonBySessionOrgAndCategory',
						fKeyDisplayCol => 0,
						fKeyValueCol => 0,
						options => FLDFLAG_REQUIRED
						),
				new CGI::Dialog::Field(
						caption => 'Billing Provider',
						name => 'provider_id',
						fKeyStmtMgr => $STMTMGR_PERSON,
						fKeyStmt => 'selPersonBySessionOrgAndCategory',
						fKeyDisplayCol => 0,
						fKeyValueCol => 0,
						options => FLDFLAG_REQUIRED
						),
			]),


		new CGI::Dialog::MultiField(caption => 'Org Service/Billing', name => 'org_fields',
			hints => 'Service Org is the org in which services were rendered.<br>
						Billing org is the org in which the billing should be tracked.',
			fields => [
				new App::Dialog::Field::OrgType(
							caption => 'Service Facility',
							name => 'service_facility_id',
							options => FLDFLAG_REQUIRED,
							types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'"),
				new App::Dialog::Field::OrgType(
							caption => 'Billing Org',
							name => 'billing_facility_id',
							options => FLDFLAG_REQUIRED,
							types => "'PRACTICE'"),
			]),
		new CGI::Dialog::MultiField(caption => 'Hospital/Billing Facility', name => 'hosp_org_fields',
			hints => 'Hospital is the org in which services were rendered.<br>
						Billing org is the org in which the billing should be tracked.',
			fields => [
				new App::Dialog::Field::OrgType(
							caption => 'Hospital',
							name => 'hospital_id',
							options => FLDFLAG_REQUIRED,
							types => "'HOSPITAL'"	),
				new App::Dialog::Field::OrgType(
							caption => 'Billing Org',
							name => 'billing_facility_id',
							options => FLDFLAG_REQUIRED,
							types => "'PRACTICE'"),
			]),


		new CGI::Dialog::Field(caption => 'Billing Contact', name => 'billing_contact'),
		new CGI::Dialog::Field(type=>'phone', caption => 'Billing Phone', name => 'billing_phone'),

		new App::Dialog::Field::Person::ID(caption => 'Referring Physician ID', name => 'ref_id', types => ['Referring-Doctor'], incSimpleName=>1),

		new CGI::Dialog::MultiField(caption =>'Current/Similar Illness Dates', name => 'illness_dates',
			fields => [
				new CGI::Dialog::Field(name => 'illness_end_date', type => 'date', defaultValue => ''),
				new CGI::Dialog::Field(name => 'illness_begin_date', type => 'date', defaultValue => '')
			]),
		new CGI::Dialog::MultiField(caption =>'Begin/End Disability Dates', name => 'disability_dates',
			fields => [
				new CGI::Dialog::Field(name => 'disability_begin_date', type => 'date', defaultValue => ''),
				new CGI::Dialog::Field(name => 'disability_end_date', type => 'date', defaultValue => '')
			]),
		new CGI::Dialog::MultiField(caption =>'Admission/Discharge Hospitalization Dates', name => 'hosp_dates',
			fields => [
				new CGI::Dialog::Field(name => 'hospitalization_begin_date', type => 'date', defaultValue => ''),
				new CGI::Dialog::Field(name => 'hospitalization_end_date', type => 'date', defaultValue => '')
			]),

		new CGI::Dialog::Field(caption => 'Prior Authorization Number', name => 'prior_auth'),
		new CGI::Dialog::MultiField(caption =>'Medicaid Resubmission Code/Original Ref. No.', name => 'medicaid_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Medicaid Resubmission Code', name => 'resub_number'),
				new CGI::Dialog::Field(caption => 'Original Reference No.', name => 'orig_ref'),
			]),

		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Yes;No',
				caption => 'Have you confirmed Personal Information/Insurance Coverage?',
				preHtml => "<B><FONT COLOR=DARKRED>",
				postHtml => "</FONT></B>",
				name => 'confirmed_info',
				options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(type => 'memo', caption => 'Place Claim(s) On Hold', name => 'on_hold', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Subhead(heading => 'Procedure Entry', name => 'procedures_heading'),
		new App::Dialog::Field::Procedures(name =>'procedures_list'),
	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$command ||= 'add';

	#keep third party other invisible unless it is chosen (see customValidate)
	$self->setFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);

	#Set attendee_id field and make it read only if person_id exists
	if(my $personId = $page->param('person_id'))
	{
		$page->field('attendee_id', $personId);
		$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);
	}

	#Populate provider id field and org fields with session org's providers
	my $sessOrgIntId = $page->session('org_internal_id');
	$self->getField('provider_fields')->{fields}->[0]->{fKeyStmtBindPageParams} = [$sessOrgIntId, 'Physician'];
	$self->getField('provider_fields')->{fields}->[1]->{fKeyStmtBindPageParams} = [$sessOrgIntId, 'Physician'];


	#Don't want to show opt proc entry when deleting
	if($command eq 'remove')
	{
		$self->updateFieldFlags('procedures_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('procedures_list', FLDFLAG_INVISIBLE, 1);
	}

	#Don't show these fields when adding a hospital claim
	my $hospClaim = $page->param('isHosp');
	if($hospClaim)
	{
		$self->updateFieldFlags('trans_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('provider_fields', FLDFLAG_INVISIBLE, 1);
	}

	#Billing Org Contact Information
	if($command ne 'remove')
	{
		my $billingOrg = $page->field('billing_facility_id');
		my $billingContact = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttribute', $billingOrg, 'Contact Information');
		if($billingOrg eq '' || $billingContact->{value_text} ne '')
		{
			$self->updateFieldFlags('billing_contact', FLDFLAG_INVISIBLE, 1);
			$self->updateFieldFlags('billing_phone', FLDFLAG_INVISIBLE, 1);
		}
		elsif($billingOrg ne '' && $billingContact->{value_text} eq '')
		{
			my $billContactField = $self->getField('billing_contact');
			my $billPhoneField = $self->getField('billing_phone');

			if($page->field('billing_contact') eq '')
			{
				$billContactField->invalidate($page, "This Billing Facility does not have '$billContactField->{caption}' on file. Please provide one.");
			}
			if($page->field('billing_phone') eq '')
			{
				$billPhoneField->invalidate($page, "This Billing Facility does not have '$billPhoneField->{caption}' on file. Please provide one.");
			}
		}
	}

	my $invoiceId = $page->param('invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $invoiceStatus = $invoiceInfo->{invoice_status};

	my $submitOrder = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Submission Order');
	unless($submitOrder->{value_int} == 0)
	{
		$self->setFieldFlags('batch_fields', FLDFLAG_READONLY);
		$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);
		$self->setFieldFlags('trans_type', FLDFLAG_READONLY);
		$self->setFieldFlags('accident', FLDFLAG_READONLY);
		$self->setFieldFlags('accident_state', FLDFLAG_READONLY);
		$self->setFieldFlags('deduct_balance', FLDFLAG_READONLY);
		$self->setFieldFlags('payer', FLDFLAG_READONLY);
		$self->setFieldFlags('primary_ins_phone', FLDFLAG_READONLY);
		$self->setFieldFlags('provider_fields', FLDFLAG_READONLY);
		$self->setFieldFlags('org_fields', FLDFLAG_READONLY);
		$self->setFieldFlags('hosp_org_fields', FLDFLAG_READONLY);
		#$self->setFieldFlags('ref_id', FLDFLAG_READONLY);
		$self->setFieldFlags('billing_contact', FLDFLAG_READONLY);
		$self->setFieldFlags('billing_phone', FLDFLAG_READONLY);
		#$self->setFieldFlags('illness_dates', FLDFLAG_READONLY);
		$self->setFieldFlags('disability_dates', FLDFLAG_READONLY);
		#$self->setFieldFlags('hosp_dates', FLDFLAG_READONLY);
		#$self->setFieldFlags('prior_auth', FLDFLAG_READONLY);
	}

	unless($invoiceInfo->{invoice_subtype} == App::Universal::CLAIMTYPE_MEDICAID && ($invoiceStatus == App::Universal::INVOICESTATUS_PAYAPPLIED || $invoiceStatus == App::Universal::INVOICESTATUS_CLOSED) )
	{
		$self->setFieldFlags('medicaid_fields', FLDFLAG_INVISIBLE, 0);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('dupCheckin_returnUrl', $self->getReferer($page)) if $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	$page->field('batch_id', $page->session('batch_id')) if $page->field('batch_id') eq '';

	my $invoiceId = $page->param('invoice_id');
	my $eventId = $page->param('event_id') || $page->field('parent_event_id');
	my $hospTransId = $page->param('hospId');

	if(! $page->field('eventFieldsAreSet') && $eventId)
	{
		$page->field('checkin_stamp', $page->getTimeStamp());
		$page->field('checkout_stamp', $page->getTimeStamp());
		$page->field('parent_event_id', $eventId);

		$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
			'selEncountersCheckIn/Out', $page->session('GMT_DAYOFFSET'), $eventId);

		my $careProvider = $page->field('care_provider_id');
		$page->field('provider_id', $careProvider); 	#default billing 'provider_id' to the 'care_provider_id'

		$invoiceId = $page->param('invoice_id', $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceIdByEventId', $eventId));

		$page->field('eventFieldsAreSet', 1);
	}

	#if coming from the hospitalization component, prefill fields with ones entered from hosp component dialog
	if(! $page->field('hospFieldsAreSet') && $hospTransId)
	{
		my $hospTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransactionById', $hospTransId);
		$page->field('hospital_id', $hospTransData->{service_facility_id});
		$page->field('hospitalization_begin_date', $hospTransData->{trans_begin_stamp});
		$page->field('hospitalization_end_date', $hospTransData->{trans_end_stamp});
		$page->field('prior_auth', $hospTransData->{auth_ref});
		$page->field('ref_id', $hospTransData->{data_text_b});
		$page->param('_f_proc_diags', $hospTransData->{detail});

		$page->field('hospFieldsAreSet', 1);
	}

	if(! $page->field('invoiceFieldsAreSet') && $invoiceId)
	{
		my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
		$page->field('attendee_id', $invoiceInfo->{client_id});
		$page->field('old_person_id', $invoiceInfo->{client_id});
		$page->field('current_status', $invoiceInfo->{invoice_status});
		$page->param('_f_proc_diags', $invoiceInfo->{claim_diags});
		$page->field('invoice_flags', $invoiceInfo->{flags});

		#this is needed if the current claim is being edited but has already been transferred (see Encounter/CreateClaim.pm for conditions).
		#if this is the case, a new claim is being created that is an exact copy of the submitted claim.
		$page->field('old_invoice_id', $invoiceId);

		#Get payer
		#my $invoiceBilling = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingCurrent', $invoiceInfo->{billing_id});
		#my $billToId = $invoiceBilling->{bill_to_id};
		#my $billPartyType = $invoiceBilling->{bill_party_type};
		#if($billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS || $billPartyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
		#{
		#	my $orgId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billToId);
		#	$billToId = $orgId->{org_id};
		#}
		#$page->field('payer', $billToId);

		#Get copay
		my $invoiceCopayItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_COPAY);
		$page->field('copay_amt', $invoiceCopayItem->{extended_cost});

		#Get all procedure and lab items for the claim
		my $procedures = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, App::Universal::INVOICEITEMTYPE_SERVICE, App::Universal::INVOICEITEMTYPE_LAB);

		#For regular procedures (not children of explosion codes)
		my $line;
		my $totalProcs = scalar(@{$procedures});
		foreach my $idx (0..$totalProcs-1)
		{
			next if $procedures->[$idx]->{data_text_c} eq 'explosion';							#data_text_c indicates if the line item is a child of an explosion code

			$line = $idx + 1;
			$page->param("_f_proc_$line\_item_id", $procedures->[$idx]->{item_id});
			$page->param("_f_proc_$line\_dos_begin", $procedures->[$idx]->{service_begin_date});
			$page->param("_f_proc_$line\_dos_end", $procedures->[$idx]->{service_end_date});
			#$page->param("_f_proc_$line\_service_type", );									#this is set in Procedures.pm by fee schedule and intellicode
			$page->param("_f_proc_$line\_procedure", $procedures->[$idx]->{code});
			$page->param("_f_proc_$line\_modifier", $procedures->[$idx]->{modifier});
			$page->param("_f_proc_$line\_units", $procedures->[$idx]->{quantity});
			#$page->param("_f_proc_$line\_charges", $procedures->[$idx]->{unit_cost});			#don't want to populate this in the event fee schedules should change
			$page->param("_f_proc_$line\_emg", @{[ ($procedures->[$idx]->{emergency} == 1 ? 'on' : '' ) ]});
			$page->param("_f_proc_$line\_comments", $procedures->[$idx]->{comments});
			$page->param("_f_proc_$line\_diags", $procedures->[$idx]->{data_text_a});			#data_text_a stores the diag code pointers
			$page->param("_f_proc_$line\_actual_diags", $procedures->[$idx]->{rel_diags});
			$page->param("_f_proc_$line\_ffs_flag", $procedures->[$idx]->{data_num_a});
		}

		#For children of explosion codes
		$line = 0;
		my $parentCode;
		my $prevCode;
		foreach my $idx (0..$totalProcs-1)
		{
			$parentCode = $procedures->[$idx]->{parent_code};
			next if $parentCode eq '';
			next if $procedures->[$idx]->{data_text_c} ne 'explosion';							#data_text_c indicates if the line item is a child of an explosion code
			next if $prevCode eq $parentCode;			
			$prevCode = $parentCode;

			$line = $idx + 1;
			$page->param("_f_proc_$line\_item_id", $procedures->[$idx]->{item_id});
			$page->param("_f_proc_$line\_dos_begin", $procedures->[$idx]->{service_begin_date});
			$page->param("_f_proc_$line\_dos_end", $procedures->[$idx]->{service_end_date});
			#$page->param("_f_proc_$line\_service_type", );									#this is set in Procedures.pm by fee schedule and intellicode
			$page->param("_f_proc_$line\_procedure", $parentCode);
			$page->param("_f_proc_$line\_prev_code", $parentCode);
			$page->param("_f_proc_$line\_modifier", $procedures->[$idx]->{modifier});
			$page->param("_f_proc_$line\_units", $procedures->[$idx]->{quantity});
			#$page->param("_f_proc_$line\_charges", $procedures->[$idx]->{unit_cost});			#don't want to populate this in the event fee schedules should change
			$page->param("_f_proc_$line\_emg", @{[ ($procedures->[$idx]->{emergency} == 1 ? 'on' : '' ) ]});
			$page->param("_f_proc_$line\_comments", $procedures->[$idx]->{comments});
			$page->param("_f_proc_$line\_diags", $procedures->[$idx]->{data_text_a});			#data_text_a stores the diag code pointers
			$page->param("_f_proc_$line\_actual_diags", $procedures->[$idx]->{rel_diags});
			$page->param("_f_proc_$line\_ffs_flag", $procedures->[$idx]->{data_num_a});
		}


		$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $invoiceInfo->{main_transaction});
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrIllness',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrDisability',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrHospitalization',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrAssignment',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAuthNumber',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceMedicaidResubNumber',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceDeductible',$invoiceId);


		my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');
		$page->field('batch_item_id', $batchInfo->{item_id});
		$page->field('batch_id', $batchInfo->{value_text});
		$page->field('batch_date', $batchInfo->{value_date});
		$self->updateFieldFlags('batch_fields', FLDFLAG_READONLY, 0) unless $page->field('batch_id');

		my $feeSchedules = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Fee Schedules');
		$page->field('fee_schedules_item_id', $feeSchedules->{item_id});
		$page->param('_f_proc_default_catalog', $feeSchedules->{value_textb});

		my $cntrlData = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Patient/Control Number');
		$page->field('cntrl_num_item_id', $cntrlData->{item_id});
		$page->field('control_number', $cntrlData->{value_text});

		my $billContactData = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Billing Facility/Contact');
		$page->field('bill_contact_item_id', $billContactData->{item_id});
		$page->field('billing_contact', $billContactData->{value_text});
		$page->field('billing_phone', $billContactData->{value_textb});

		my $claimFiling = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Claim Filing/Indicator');
		$page->field('claim_filing_item_id', $claimFiling->{item_id});

		my $submitOrder = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Submission Order');
		my $subOrderValue = $submitOrder->{value_int} == 0 ? 0 : 1;
		$page->field('submission_order', $subOrderValue);

		my $assignment = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Assignment of Benefits');
		my $value = $assignment->{value_int} ? 1 : 0;
		$page->field('assignment_item_id', $assignment->{item_id});
		$page->field('accept_assignment', $value);

		my $condRelTo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttrCondition', $invoiceId);
		my @condRelToIds = ();
		my @condRelToCaps = split(', ', $condRelTo->{value_text});
		foreach my $condition (@condRelToCaps)
		{
			my $conditionIds = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceConditionId', $condition);

			push(@condRelToIds, $conditionIds);
		}
		$page->field('condition_item_id', $condRelTo->{condition_item_id});
		$page->field('accident', @condRelToIds);
		$page->field('accident_state', $condRelTo->{value_textb});

		$page->field('invoiceFieldsAreSet', 1);
	}


	#if person id, create drop down of his/her payers
	if( my $personId = $page->field('attendee_id') || $page->param('person_id') )
	{
		if($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $personId))
		{
			createPayerDropDown($self, $page, $command, $activeExecMode, $flags, $invoiceId, $personId);
		}
		$page->field('old_person_id', $personId);
	}


	#verify flags
	my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

	my $verifyFlags = $eventAttribute->{value_intb};

	$page->field('confirmed_info', 'Yes')
		if $verifyFlags & App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE;
}

sub createPayerDropDown
{
	my ($self, $page, $command, $activeExecMode, $flags, $invoiceId, $personId) = @_;
	#this function called from populateData

	my $insurRecs = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selPayerChoicesByOwnerPersonId', $personId);
	my @insurPlans = ();
	my @insurIntIds = ();
	my @wkCompPlans = ();
	my @thirdParties = ();
	my @allIntIds  = ();
	my $prevSeq = 0;
	my $insSeq;
	my $badSeq;
	foreach my $ins (@{$insurRecs})
	{
		next unless $ins->{ins_internal_id};

		if($ins->{group_name} eq 'Insurance')
		{
			$insSeq = $ins->{bill_seq_id};
			if($insSeq == $prevSeq + 1)
			{
				push(@insurPlans, "$ins->{bill_seq}($ins->{plan_name})");
				push(@insurIntIds, $ins->{ins_internal_id});
				$prevSeq = $insSeq;
			}
			else
			{
				$badSeq = 1;
			}

			#Added to store plan internal Ids for getFS if insurance is primary
			push(@allIntIds,$ins->{ins_internal_id}) if $insSeq == App::Universal::INSURANCE_PRIMARY;
		}
		elsif($ins->{group_name} eq 'Workers Compensation')
		{
			push(@wkCompPlans, "Work Comp($ins->{plan_name}):$ins->{ins_internal_id}");

			#Added to store plan internal Ids for getFS
			push(@allIntIds,$ins->{ins_internal_id});
		}
		elsif($ins->{group_name} eq 'Third-Party')
		{
			#here the plan_name is actually the guarantor_id (the query says "select guarantor_id as plan_name, ...")
			my $thirdPartyId = $ins->{plan_name};
			if($ins->{guarantor_type} == App::Universal::ENTITYTYPE_ORG)
			{
				my $org = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $thirdPartyId);
				$thirdPartyId = $org->{org_id};
			}
			push(@thirdParties, "$ins->{group_name}($thirdPartyId):$ins->{ins_internal_id}");
		}
	}

	#get Fee Schedules for Insurance and Work Comps Plan
	getFS($self,$page,@allIntIds);

	#create payer drop down
	my @payerList = ();

	my $insurIntIds = join(',', @insurIntIds);
	my $insurances = join(' / ', @insurPlans) . ":$insurIntIds" unless $badSeq;		#if insurance sequence is out of order, do not include in payer drop down
	push(@payerList, $insurances) if $insurIntIds && $insurances;

	my $workComp = join(';', @wkCompPlans) if @wkCompPlans;
	push(@payerList, $workComp) if $workComp;

	my $thirdParty = join(';', @thirdParties) if @thirdParties;
	push(@payerList, $thirdParty) if $thirdParty;

	my $thirdPartyOther = "Third-Party Payer:@{[FAKENEW3RDPARTY_INSINTID]}";
	push(@payerList, $thirdPartyOther);

	my $selfPay = "Self-Pay:@{[FAKESELFPAY_INSINTID]}";
	push(@payerList, $selfPay);

	@payerList = join(';', @payerList);

	$self->getField('payer')->{selOptions} = "@payerList";

	my $payer = $page->field('payer');
	$page->field('payer', $payer);
}

sub getFS
{
	my ($self,$page,@insIntIds) = @_;
	my $product_id;
	my $plan_id;
	my $fsList=undef;
	foreach my $id (@insIntIds)
	{
		#Get Parent Id for Plan
		my $insurance = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceData', $id);

		#Get Parent record for coverage could be a plan or a product
		my $coverage_id = $insurance->{'parent_ins_id'};
		my $coverage_parent = $STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selInsuranceData',$coverage_id);

		#If record type is product then a plan does not exist
		if ($coverage_parent->{'record_type'} eq App::Universal::RECORDTYPE_INSURANCEPRODUCT)
		{
			$product_id = $coverage_parent->{'ins_internal_id'};
			$plan_id=undef;
		}
		#Otherwise get the product info
		else
		{

			$plan_id = $coverage_parent->{'ins_internal_id'};
			#Get Parent of Plan which will be the product
			my $product_info =$STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selInsuranceData',$coverage_parent->{'parent_ins_id'});
			$product_id = $product_info->{'ins_internal_id'};
		}

		#Get Fee Schedule Internal ID for the Insurance
		my $getFeeScheds = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE,'selFSLinkedProductPlan', $plan_id,$product_id);
		foreach my $fs (@{$getFeeScheds})
		{
			$fsList .= $fsList ? ",$fs->{'catalog_id'}" : $fs->{'catalog_id'} ;
		}
	}
	#Store FS internal id(s)
	$page->field('ins_ffs',$fsList);
	$page->param('_f_proc_default_catalog',$fsList) unless $page->param('_f_proc_default_catalog');
}

###############################################################
# The following functions are run during execution
###############################################################

sub handlePayers
{
	my ($self, $page, $command, $flags) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');
	my $personId = $page->field('attendee_id');

	#CONSTANTS -------------------------------------------

	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	my $typeSelfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $typeClient = App::Universal::CLAIMTYPE_CLIENT;

	# ------------------------------------------------------------

	my $payer = $page->field('payer');
	if($payer == FAKESELFPAY_INSINTID)
	{
		$page->field('claim_type', $typeSelfPay);
	}
	elsif($payer == FAKENEW3RDPARTY_INSINTID)
	{
		my $otherPayerId = $page->field('other_payer_id');
		$otherPayerId = uc($otherPayerId);
		my $otherPayerType = $page->field('other_payer_type');
		my $addr = undef;
		my $insPhone = undef;
		my $guarantorType = undef;
		if($otherPayerType eq 'person')
		{
			$guarantorType = App::Universal::ENTITYTYPE_PERSON;
			$addr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $otherPayerId);
			$insPhone = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $otherPayerId, 'Home', $phoneAttrType);
		}
		else
		{
			my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $sessOrgIntId, $otherPayerId);
			$guarantorType = App::Universal::ENTITYTYPE_ORG;
			$addr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selOrgAddressByAddrName', $orgIntId, 'Mailing');
			$insPhone = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $orgIntId, 'Primary', $phoneAttrType);
			$otherPayerId = $orgIntId; #convert value of otherPayerId to orgIntId because this is an org
		}

		my $recordType = App::Universal::RECORDTYPE_PERSONALCOVERAGE;
		my $insIntId = $page->schemaAction(
				'Insurance', 'add',
				owner_person_id => $personId || undef,
				record_type => defined $recordType ? $recordType : undef,
				ins_type => defined $typeClient ? $typeClient : undef,
				guarantor_id => $otherPayerId,
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

		$page->field('payer', $insIntId);
		$page->field('claim_type', $typeClient);
	}
	else
	{
		my @insurIntIds = split(/\s*,\s*/, $payer);
		my $insRecord = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insurIntIds[0]);
		$page->field('claim_type', $insRecord->{ins_type});
	}

	if($page->param('isHosp') == 1)
	{
		my $lineCount = $page->param('_f_line_count');
		my %uniqueClaims = ();
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			my $dosBegin = $page->param("_f_proc_$line\_dos_begin");
			my $dosEnd = $page->param("_f_proc_$line\_dos_end");

			next if $dosBegin eq 'From' || $dosEnd eq 'To';
			next unless $dosBegin && $dosEnd;

			my $servProviderId = $page->param("_f_proc_$line\_service_provider_id");
			my $billProviderId = $page->param("_f_proc_$line\_billing_provider_id");
			my $providerPair = $servProviderId . $billProviderId;

			unless (exists $uniqueClaims{$providerPair})
			{
				$uniqueClaims{$providerPair} = 1;
				$page->field('care_provider_id', $servProviderId);
				$page->field('provider_id', $billProviderId);
				$page->field('provider_pair', $providerPair);

				addTransactionAndInvoice($self, $page, $command, $flags);
			}
		}
	}
	else
	{
		addTransactionAndInvoice($self, $page, $command, $flags);
	}
}

sub addTransactionAndInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command ||= 'add';

	my $timeStamp = $page->getTimeStamp();
	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $personId = $page->field('attendee_id');
	my $claimType = $page->field('claim_type');
	my $editInvoiceId = $page->param('invoice_id');
	my $editTransId = $page->field('trans_id');
	my $onHold = $page->field('on_hold');
	my $submissionOrder = $page->field('submission_order');

	#CONSTANTS -------------------------------------------
		#invoice constants
		my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
		my $invoiceStatus = $onHold ? App::Universal::INVOICESTATUS_ONHOLD : App::Universal::INVOICESTATUS_CREATED;
		$invoiceStatus = $command eq 'add' ? $invoiceStatus : $page->field('current_status');

		#entity types
		my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
		my $entityTypeOrg = App::Universal::ENTITYTYPE_ORG;

		#trans status
		my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;

		# other
		my $condRelToFakeNone = App::Universal::CONDRELTO_FAKE_NONE;
	#-------------------------------------------------------------------------------------------------------------------------------

	my $serviceProvider = $page->field('care_provider_id');
	my $altBillProvider =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $serviceProvider, 'Bill Provider');
	my $billingProvider = $altBillProvider->{value_text} || $page->field('provider_id');

	my $billingFacility = $page->field('billing_facility_id');
	my $confirmedInfo = $page->field('confirmed_info') eq 'Yes' ? 1 : 0;
	my $relTo = $page->field('accident') == $condRelToFakeNone ? '' : $page->field('accident');
	my $hospClaim = $page->param('isHosp');
	my $transType = $hospClaim ? App::Universal::TRANSTYPEVISIT_HOSPITAL : $page->field('trans_type');

	my $transId = $page->schemaAction(
		'Transaction', $command,
		trans_id => $editTransId || undef,
		trans_type => $transType,
		trans_status => defined $transStatus ? $transStatus : undef,
		parent_event_id => $page->field('parent_event_id') || $page->param('event_id') || undef,
		caption => $page->field('subject') || undef,
		service_facility_id => $page->field('service_facility_id') || $page->field('hospital_id') || undef,
		billing_facility_id => $billingFacility || undef,
		provider_id => $billingProvider || undef,
		care_provider_id => $serviceProvider || undef,
		trans_owner_type => defined $entityTypePerson ? $entityTypePerson : undef,
		trans_owner_id => $personId || undef,
		initiator_type => defined $entityTypePerson ? $entityTypePerson : undef,
		initiator_id => $personId || undef,
		receiver_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		receiver_id => $sessOrgIntId || undef,
		init_onset_date => $page->field('illness_begin_date') || undef,
		curr_onset_date => $page->field('illness_end_date') || undef,
		bill_type => defined $claimType ? $claimType : undef,
		related_to => $relTo || undef,
		data_text_a => $page->field('ref_id') || undef,
		data_num_a => defined $confirmedInfo ? $confirmedInfo : undef,
		trans_begin_stamp => $timeStamp || undef,
		_debug => 0
	);

	$transId = $command eq 'add' ? $transId : $editTransId;


	my @claimDiags = split(/\s*,\s*/, $page->param('_f_proc_diags'));
	#App::IntelliCode::incrementUsage($page, 'Icd', \@claimDiags, $sessUser, $sessOrgIntId);

	my $invoiceId = $page->schemaAction(
		'Invoice', $command,
		invoice_id => $editInvoiceId || undef,
		invoice_type => defined $invoiceType ? $invoiceType : undef,
		invoice_subtype => defined $claimType ? $claimType : undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		invoice_date => $page->getDate() || undef,
		main_transaction => $transId || undef,
		submitter_id => $page->session('user_id') || undef,
		claim_diags => join(', ', @claimDiags) || undef,
		owner_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		owner_id => $sessOrgIntId || undef,
		client_type => defined $entityTypePerson ? $entityTypePerson : undef,
		client_id => $personId || undef,
		_debug => 0
	);

	#create history items when adding new invoice and/or placing it on hold
	my $batchId = $page->field('batch_id');
	addHistoryItem($page, $invoiceId, value_text => 'Created', value_textB => "Creation Batch ID: $batchId") if $command eq 'add';
	addHistoryItem($page, $invoiceId, value_text => 'On Hold', value_textB => $onHold) if $onHold;

	#reset session batch id with batch id in field
	$page->session('batch_id', $batchId);

	
	$invoiceId = $command eq 'add' ? $invoiceId : $editInvoiceId;
	$page->param('invoice_id', $invoiceId);

	#create attributes, items, billing info, handle hmo cap, then redirect
	handleInvoiceAttrs($self, $page, $command, $flags, $invoiceId);
	handleProcedureItems($self, $page, $command, $flags, $invoiceId);
	handleBillingInfo($self, $page, $command, $flags, $invoiceId) if $submissionOrder == 0 || $command eq 'add';
	handleHmoCapChanges($self, $page, $command, $invoiceId);
	handleRedirect($self, $page, $command, $flags, $invoiceId);
}

sub handleInvoiceAttrs
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	$command ||= 'add';

	my $sessOrgId = $page->session('org_id');
	my $claimType = $page->field('claim_type');
	my $personId = $page->field('attendee_id');
	my $billingFacility = $page->field('billing_facility_id');
	my $serviceFacility = $page->field('service_facility_id') || $page->field('hospital_id');

	#CONSTANTS
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $intValueType = App::Universal::ATTRTYPE_INTEGER;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $boolValueType = App::Universal::ATTRTYPE_BOOLEAN;
	my $currencyValueType = App::Universal::ATTRTYPE_CURRENCY;
	my $durationValueType = App::Universal::ATTRTYPE_DURATION;

	## Then, create invoice attribute indicating that this is the first (primary) claim
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId || undef,
		item_name => 'Submission Order',
		value_type => defined $intValueType ? $intValueType : undef,
		value_int => 0,
		_debug => 0
	) if $command ne 'update';


	## Then, create some invoice attributes for HCFA (the rest are found in the Procedure dialog):
	#	 Accident Related To, Prior Auth Num, Deduct Balance, Accept Assignment, Ref Physician Name/Id,
	#	 Illness/Disability/Hospitalization Dates

	my $condRelToId = $page->field('accident');
	my $condition;
	my $state;
	unless($condRelToId == App::Universal::CONDRELTO_FAKE_NONE)
	{
		$condition = $STMTMGR_TRANSACTION->getSingleValue($page, STMTMGRFLAG_NONE, 'selCondition', $condRelToId);
		$state = $page->field('accident_state') if $condRelToId == App::Universal::CONDRELTO_AUTO;
	}

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('condition_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Condition/Related To',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $condition || undef,
		value_textB => $state || undef,
		_debug => 0
	);


	#referring physician information
	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delRefProviderAttrs', $invoiceId);
	if(my $refPhysId = $page->field('ref_id'))
	{
		my $refPhysInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $refPhysId);
		#my $refPhysUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $refPhysId, 'UPIN', App::Universal::ATTRTYPE_LICENSE);
		my $refPhysUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $refPhysId, 'UPIN', $serviceFacility);
		my $upin = $refPhysUpin->{value_text};
		if($upin eq '')
		{
			$refPhysUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $refPhysId, 'UPIN', $sessOrgId);
			$upin = $refPhysUpin->{value_text};
		}

		my $refPhysState = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPhysStateLicense', $refPhysId, 1);

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Ref Provider/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $refPhysInfo->{name_first} || undef,
			value_textB => $refPhysId || undef,
			_debug => 0
		);

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Ref Provider/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $refPhysInfo->{name_middle} || undef,
			value_textB => $refPhysId || undef,
			_debug => 0
		) if $refPhysInfo->{name_middle} ne '';

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Ref Provider/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $refPhysInfo->{name_last} || undef,
			value_textB => $refPhysId || undef,
			_debug => 0
		);

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Ref Provider/Identification',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $refPhysUpin->{value_text} || undef,
			value_textB => $refPhysState->{value_textb} || undef,
			_debug => 0
		);
		#end referring phys attrs
	}

	my $existsBatchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');
	my $batchCommand = $existsBatchInfo->{item_id} ? 'update' : 'add';
	$page->schemaAction(
		'Invoice_Attribute', $batchCommand,
		item_id => $page->field('batch_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Invoice/Creation/Batch ID',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $page->field('batch_id') || undef,
		value_date => $page->field('batch_date') || undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('prior_auth_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Prior Authorization Number',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $page->field('prior_auth') || undef,
		_debug => 0
	);

	if($claimType == App::Universal::CLAIMTYPE_MEDICAID)
	{
		my $resubCommand = 'add';
		if($page->field('resub_number_item_id'))
		{
			$resubCommand = 'update';
		}
		$page->schemaAction(
			'Invoice_Attribute', $resubCommand,
			item_id => $page->field('resub_number_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Medicaid/Resubmission',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $page->field('resub_number') || undef,
			value_textB => $page->field('orig_ref') || undef,
			_debug => 0
		);
	}

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('deduct_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Patient/Deductible/Balance',
		value_type => defined $currencyValueType ? $currencyValueType : undef,
		value_text => $page->field('deduct_balance') || undef,
		_debug => 0
	);

	#for now, we will always default it to 'YES' 8-3-00 MAF (Bug 498)
	my $acceptAssign = 1; 	#$page->field('accept_assignment') eq '' ? 0 : 1;
	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('assignment_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Assignment of Benefits',
		value_type => defined $boolValueType ? $boolValueType : undef,
		value_int => defined $acceptAssign ? $acceptAssign : undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('illness_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Patient/Illness/Dates',
		value_type => defined $durationValueType ? $durationValueType : undef,
		value_date => $page->field('illness_begin_date') || undef,
		value_dateEnd => $page->field('illness_end_date') || undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('disability_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Patient/Disability/Dates',
		value_type => defined $durationValueType ? $durationValueType : undef,
		value_date => $page->field('disability_begin_date') || undef,
		value_dateEnd => $page->field('disability_end_date') || undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('hospital_item_id') || undef,
		parent_id => $invoiceId || undef,
		item_name => 'Patient/Hospitalization/Dates',
		value_type => defined $durationValueType ? $durationValueType : undef,
		value_date => $page->field('hospitalization_begin_date') || undef,
		value_dateEnd => $page->field('hospitalization_end_date') || undef,
		_debug => 0
	);

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('cntrl_num_item_id') || undef,
		parent_id => $invoiceId,
		item_name => 'Patient/Control Number',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $invoiceId || undef,
		_debug => 0
	);


	my $billingContact = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttribute', $billingFacility, 'Contact Information');
	my $contactName = $billingContact->{value_text} || $page->field('billing_contact');
	my $contactPhone = $billingContact->{value_textb} || $page->field('billing_phone');

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('bill_contact_item_id') || undef,
		parent_id => $invoiceId,
		item_name => 'Billing Facility/Contact',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $contactName || undef,
		value_textB => $contactPhone || undef,
		_debug => 0
	);


	unless($billingContact->{item_id})
	{
		$page->schemaAction(
			'Org_Attribute', 'add',
			parent_id => $billingFacility,
			item_name => 'Contact Information',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $contactName || undef,
			value_textB => $contactPhone || undef,
			_debug => 0
		);
	}



	my $secondaryIns = App::Universal::INSURANCE_SECONDARY;
	my $personSecInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPersonInsurance', $personId, $secondaryIns);
	my $claimFiling = 'P';
	$claimFiling = 'M' if $personSecInsur->{ins_internal_id} ne '';

	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('claim_filing_item_id') || undef,
		parent_id => $invoiceId,
		item_name => 'Claim Filing/Indicator',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $claimFiling,
		_debug => 0
	);


	my $activeCatalogs = uc($page->param('_f_proc_active_catalogs'));
	my $defaultCatalogs = uc($page->param('_f_proc_default_catalog'));
	$page->schemaAction(
		'Invoice_Attribute', $command,
		item_id => $page->field('fee_schedules_item_id') || undef,
		parent_id => $invoiceId,
		item_name => 'Fee Schedules',
		value_type => defined $textValueType ? $textValueType : undef,
		value_text => $activeCatalogs || undef,
		value_textB => $defaultCatalogs || undef,
		_debug => 0
	);


	#if this new claim is a result of an original submitted claim being voided, create history items to link the two
	my $invoiceFlags = $page->field('invoice_flags');
	if($invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR && $claimType != App::Universal::CLAIMTYPE_SELFPAY)
	{
		my $oldInvoiceId = $page->field('old_invoice_id');
		addHistoryItem($page, $invoiceId, value_text => "This invoice is a new copy of invoice <A HREF='/invoice/$oldInvoiceId/summary'>$oldInvoiceId</A> which has been submitted and voided"	);

		#update original claim - make it's parent_invoice the new invoice and add history item
		$page->schemaAction('Invoice', 'update', invoice_id => $oldInvoiceId || undef, parent_invoice_id => $invoiceId);

		addHistoryItem($page, $oldInvoiceId, value_text => "Invoice <A HREF='/invoice/$invoiceId/summary'>$invoiceId</A> is a new copy of this invoice");
	}
}

sub handleBillingInfo
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	my $personId = $page->field('attendee_id');
	my @insurIntIds = split(/\s*,\s*/, $page->field('payer'));

	#delete all payers then re-add when updating or removing
	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delInvoiceBillingParties', $invoiceId) if $command ne 'add';

	#create invoice billing records
	my %data = ();
	my $insInfo;
	my $insIntIdCount = @insurIntIds;

	#if self pay is not selected
	if($insurIntIds[0] != FAKESELFPAY_INSINTID)
	{
		foreach my $idx (0..$insIntIdCount-1)
		{
			$insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insurIntIds[$idx]);
			if($insInfo->{ins_type} == App::Universal::CLAIMTYPE_CLIENT)
			{
				%data = (
					bill_party_type => $insInfo->{guarantor_type} == App::Universal::ENTITYTYPE_PERSON ? App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON : App::Universal::INVOICEBILLTYPE_THIRDPARTYORG,
					bill_to_id => $insInfo->{guarantor_id},
				);
			}
			else
			{
				%data = (
					bill_party_type => App::Universal::INVOICEBILLTYPE_THIRDPARTYINS,
					bill_to_id => $insInfo->{ins_org_id},
					bill_pct => $insInfo->{percentage_pay},
				);

				#set copay amount (if any)
				$page->field('copay_amt', $insInfo->{copay_amt});
			}

			$data{bill_ins_id} = $insurIntIds[$idx];

			#create invoice billing record
			my $billId = $page->schemaAction(
				'Invoice_Billing', 'add',
				invoice_id => $invoiceId || undef,
				bill_sequence => $idx + 1,
				%data,
			);

			#set current payer
			if($idx == 0)
			{
				$page->schemaAction('Invoice', 'update', invoice_id => $invoiceId, billing_id => $billId);
			}
		}

		#add self pay as last payer
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => $insIntIdCount + 1,
			bill_party_type => App::Universal::INVOICEBILLTYPE_CLIENT || 0,
			bill_to_id => $personId,
		);
	}
	elsif($insurIntIds[0] == FAKESELFPAY_INSINTID)
	{
		#add self pay as primary payer if chosen
		my $billId = $page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => App::Universal::INSURANCE_PRIMARY,
			bill_party_type => App::Universal::INVOICEBILLTYPE_CLIENT || 0,
			bill_to_id => $personId,
		);
		
		$page->schemaAction('Invoice', 'update', invoice_id => $invoiceId, billing_id => $billId);
	}
}

sub billCopay
{
	my ($self, $page, $command, $invoiceId) = @_;

	my $personType = App::Universal::ENTITYTYPE_PERSON;
	my $copayAmt = $page->field('copay_amt');

	#add copay item
	my $copayItemId = $page->schemaAction(
		'Invoice_Item', 'add',
		parent_id => $invoiceId || undef,
		item_type => App::Universal::INVOICEITEMTYPE_COPAY,
		caption => 'Co-Pay',
		extended_cost => defined $copayAmt ? $copayAmt : undef,
		_debug => 0
	);

	#add invoice billing record for copay item
	my $billPartyType = App::Universal::INVOICEBILLTYPE_CLIENT;
	$page->schemaAction(
		'Invoice_Billing', 'add',
		invoice_id => $invoiceId || undef,
		invoice_item_id => $copayItemId || undef,
		bill_sequence => App::Universal::PAYER_PRIMARY,
		bill_party_type => defined $billPartyType ? $billPartyType : undef,
		bill_to_id => $page->field('attendee_id') || undef,
		bill_amount => defined $copayAmt ? $copayAmt : undef,
		bill_date => $page->getDate() || undef,
		_debug => 0
	);
}

sub handleHmoCapChanges
{
	my ($self, $page, $command, $invoiceId) = @_;

	my $copayAmt = $page->field('copay_amt');
	my $copayItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_COPAY);
	my $copayItemId = $copayItem->{item_id};
	my $claimType = $page->field('claim_type');
	if($claimType != App::Universal::CLAIMTYPE_HMO && $command eq 'update')
	{
		#delete the auto writeoffs if the claim has been changed from hmocap to something else
		deleteHmoCapWriteoff($page, $invoiceId);

		#delete copay item if claim is updated to a non-cap claim type
		if($copayItemId && $copayItem->{data_text_b} ne 'void')
		{
			voidInvoiceItem($page, $copayItemId);
		}
	}
	elsif($copayAmt && $claimType == App::Universal::CLAIMTYPE_HMO && ($copayItemId eq '' || $copayItem->{data_text_b} eq 'void'))
	{
		my $lineCount = $page->param('_f_line_count');
		my $existsOfficeVisitCPT;
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			if( $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'checkOfficeVisitCPT', $page->param("_f_proc_$line\_procedure")) )
			{
				$existsOfficeVisitCPT = 1;
			}
		}

		if($existsOfficeVisitCPT)
		{
			billCopay($self, $page, $command, $invoiceId);
		}
	}
}

sub handleProcedureItems
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	my $servItemType = App::Universal::INVOICEITEMTYPE_SERVICE;
	my $labItemType = App::Universal::INVOICEITEMTYPE_LAB;

	my $isHospClaim = $page->param('isHosp');
	my $setProviderPair = $page->field('provider_pair');
	my $servProviderId;
	my $billProviderId;
	my $currProviderPair;

	#convert place to it's foreign key id
	my $svcFacility = $page->field('service_facility_id') || $page->field('hospital_id');
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');
	my $servPlaceId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceByAbbr', $svcPlaceCode->{value_text});

	my $cptShortName;
	my $hcpcsShortName;
	my $epsdtShortName;
	my $codeShortName;

	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		next if $page->param("_f_proc_$line\_dos_begin") eq 'From' || $page->param("_f_proc_$line\_dos_end") eq 'To';
		next unless $page->param("_f_proc_$line\_dos_begin") && $page->param("_f_proc_$line\_dos_end");

		my $removeProc = $page->param("_f_proc_$line\_remove");
		my $cptCode = $page->param("_f_proc_$line\_procedure");
		my $prevCptCode = $page->param("_f_proc_$line\_prev_code");
		my $itemId = $page->param("_f_proc_$line\_item_id");

		$command = 'add' if ! $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);

		if($isHospClaim)
		{
			$servProviderId = $page->param("_f_proc_$line\_service_provider_id");
			$billProviderId = $page->param("_f_proc_$line\_billing_provider_id");

			$currProviderPair = $servProviderId . $billProviderId;
			next unless $setProviderPair eq $currProviderPair;
			#$page->addError("Line $line: $setProviderPair eq $currProviderPair");
		}

		#if cpt is a misc procedure code, get children and create invoice item for each child
		my $miscProcChildren = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selMiscProcChildren', $sessOrgIntId, $cptCode);
		if($miscProcChildren->[0]->{code} && ! $removeProc)
		{
			if($cptCode ne $prevCptCode && $prevCptCode ne '')
			{
				my $prevExplCodeInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selExplCodeInvItems', $invoiceId, $prevCptCode);
				foreach my $prevExplCodeItem (@{$prevExplCodeInvItems})
				{
					voidInvoiceItem($page, $prevExplCodeItem->{item_id});
				}
				$command = 'add';
			}

			handleExplosionItems($self, $page, $command, $line, $invoiceId, $cptCode, $miscProcChildren);
			next;
		}
		elsif($cptCode ne $prevCptCode && $prevCptCode ne '' && ! $removeProc)
		{
			my $prevExplCodeInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selExplCodeInvItems', $invoiceId, $prevCptCode);
			foreach my $prevExplCodeItem (@{$prevExplCodeInvItems})
			{
				voidInvoiceItem($page, $prevExplCodeItem->{item_id});
			}
			$command = 'add';
		}

		if($removeProc)
		{
			if($miscProcChildren->[0]->{code})
			{
				my $explCodeInvItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selExplCodeInvItems', $invoiceId, $cptCode);
				foreach my $explCodeItem (@{$explCodeInvItems})
				{
					voidInvoiceItem($page, $explCodeItem->{item_id});
				}
				next;
			}
			else
			{
				voidInvoiceItem($page, $itemId);
				next;
			}
		}

		#get caption for cpt code
		$cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);
		$hcpcsShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericHCPCSCode', $cptCode);
		$epsdtShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericEPSDTCode', $cptCode);
		$codeShortName = $cptShortName->{name} || $hcpcsShortName->{name} || $epsdtShortName->{name};

		#convert service type to it's foreign key id
		my $servType = $page->param("_f_proc_$line\_service_type");
		my $servTypeId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeByAbbr', $servType);

		my $emg = $page->param("_f_proc_$line\_emg") eq 'on' ? 1 : 0;
		my %record = (
			item_id => $command eq 'add' ? undef : $itemId,
			service_begin_date => $page->param("_f_proc_$line\_dos_begin") || undef,	#default for service start date is today
			service_end_date => $page->param("_f_proc_$line\_dos_end") || undef,		#default for service end date is today
			hcfa_service_place => defined $servPlaceId ? $servPlaceId : undef,			#
			hcfa_service_type => defined $servTypeId ? $servTypeId : undef,			#default for service type is 2 for consultation
			modifier => $page->param("_f_proc_$line\_modifier") || undef,				#default for modifier is "mandated services"
			quantity => $page->param("_f_proc_$line\_units") || undef,					#default for units is 1
			emergency => defined $emg ? $emg : undef,								#default for emergency is 0 or 1
			item_type => App::Universal::INVOICEITEMTYPE_SERVICE || undef,			#default for item type is service
			code => $cptCode || undef,
			code_type => $page->param("_f_proc_$line\_code_type") || undef,
			caption => $codeShortName || undef,
			comments =>  $page->param("_f_proc_$line\_comments") || undef,
			unit_cost => $page->param("_f_proc_$line\_charges") || undef,
			rel_diags => $page->param("_f_proc_$line\_actual_diags") || undef,			#the actual icd (diag) codes
			data_text_a => $page->param("_f_proc_$line\_diags") || undef,				#the diag code pointers
			data_num_a => $page->param("_f_proc_$line\_ffs_flag") || undef,			#flag indicating if item is ffs
		);


		$record{extended_cost} = $record{unit_cost} * $record{quantity};


		# IMPORTANT: ADD VALIDATION FOR FIELD ABOVE (TALK TO RADHA/MUNIR/SHAHID)
		$page->schemaAction('Invoice_Item', $command,
			%record,
			parent_id => $invoiceId,
			_debug => 0,
		);
	}
}

sub handleExplosionItems
{
	my ($self, $page, $command, $line, $invoiceId, $explCode, $miscProcChildren) = @_;

	my $svcFacility = $page->field('service_facility_id') || $page->field('hospital_id');
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');
	my $servPlaceId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceByAbbr', $svcPlaceCode->{value_text});

	my $cptShortName;
	my $hcpcsShortName;
	my $epsdtShortName;
	my $codeShortName;

	my $childCount = scalar(@{$miscProcChildren});
	foreach my $child (@{$miscProcChildren})
	{
		my $servBeginDate = $page->param("_f_proc_$line\_dos_begin");
		my $cptCode = $child->{code};
		my $modifier = $child->{modifier};

		$cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);
		$hcpcsShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericHCPCSCode', $cptCode);
		$epsdtShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericEPSDTCode', $cptCode);
		$codeShortName = $cptShortName->{name} || $hcpcsShortName->{name} || $epsdtShortName->{name};

		my $quantity = $page->param("_f_proc_$line\_units");
		my $emg = $page->param("_f_proc_$line\_emg") eq 'on' ? 1 : 0;
		my @listFeeSchedules = ($page->param("_f_proc_$line\_fs_used"));

		my $fs_entry = App::IntelliCode::getFSEntry($page, $cptCode, $modifier || undef,$servBeginDate,\@listFeeSchedules);
		#my $use_fee;
		#my $count = 0;
		my $count_type = scalar(@$fs_entry);
		foreach(@$fs_entry)
		{
			my $servType = $_->[$INTELLICODE_FS_SERV_TYPE];
			my $codeType = $_->[$INTELLICODE_FS_CODE_TYPE];
			my $unitCost = $_->[$INTELLICODE_FS_COST];
			my $ffsFlag = $_->[$INTELLICODE_FS_FFS_CAP];
			my $servTypeId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeByAbbr', $servType);

			my $extCost = $unitCost * $quantity;
			$page->schemaAction('Invoice_Item', $command,
				item_id => $page->param("_f_proc_$line\_item_id") || undef,
				parent_id => $invoiceId,
				service_begin_date => $servBeginDate || undef,							#default for service start date is today
				service_end_date => $page->param("_f_proc_$line\_dos_end") || undef,		#default for service end date is today
				hcfa_service_place => defined $servPlaceId ? $servPlaceId : undef,			#
				hcfa_service_type => defined $servTypeId ? $servTypeId : undef,			#default for service type is 2 for consultation
				modifier => $modifier || undef,
				quantity => $quantity || undef,
				emergency => defined $emg ? $emg : undef,								#default for emergency is 0 or 1
				item_type => App::Universal::INVOICEITEMTYPE_SERVICE || undef,			#default for item type is service
				code => $cptCode || undef,
				code_type => $codeType || undef,
				caption => $codeShortName || undef,
				comments => $page->param("_f_proc_$line\_comments") || undef,
				unit_cost => $unitCost || undef,
				extended_cost => $extCost || undef,
				rel_diags => $page->param("_f_proc_$line\_actual_diags") || undef,			#the actual icd (diag) codes
				parent_code => $explCode || undef,										#store explosion code
				data_text_a => $page->param("_f_proc_$line\_diags") || undef,				#the diag code pointers
				data_text_c => 'explosion',												#indicates this procedure comes from an explosion (misc) code
				data_num_a => $ffsFlag || undef,										#flag indicating if item is ffs
			);
		}
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	my $sessOrgIntId = $page->session('org_internal_id');

	#VALIDATION FOR 'ACCIDENT?' FIELD
	my $condRelToAuto = App::Universal::CONDRELTO_AUTO;
	my $accident = $self->getField('accident');
	my $state = $self->getField('accident_state');
	my @condRelToIds = $page->field('accident');

	my $autoSet = '';
	foreach my $relToId (@condRelToIds)
	{
		next if $relToId != $condRelToAuto;

		if($page->field('accident_state') eq '')
		{
			$state->invalidate($page, "Must provide '$state->{caption}' when selecting 'Auto Accident'");
		}

		$autoSet = 1;
	}

	if($autoSet eq '' && $page->field('accident_state') ne '')
	{
		$accident->invalidate($page, "Must select 'Auto Accident' when indicating a '$state->{caption}'");
	}



	#VALIDATION FOR THIRD PARTY PERSON OR ORG
	my $payer = $page->field('payer');
	if($payer == FAKENEW3RDPARTY_INSINTID)
	{
		$self->updateFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 0);

		my $otherPayer = $page->field('other_payer_id');
		$otherPayer = uc($otherPayer);
		$page->field('other_payer_id', $otherPayer);
		my $otherPayerType = $page->field('other_payer_type');
		my $otherPayerField = $self->getField('other_payer_fields')->{fields}->[0];

		if($otherPayer eq '')
		{
			$otherPayerField->invalidate($page, "Please provide existing Id for 'Third-Party'");
		}
		elsif($otherPayerType eq 'person')
		{
			my $createHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-guarantor/$otherPayer');";
			$otherPayerField->invalidate($page, qq{
				Person Id '$otherPayer' does not exist.<br>
				<img src="/resources/icons/arrow_right_red.gif">
				<a href="$createHref">Add Third Party Person Id '$otherPayer' now</a>
				})
				unless $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $otherPayer);
		}
		elsif($otherPayerType eq 'org')
		{
			my $createOrgHrefPre = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-org-";
			my $createOrgHrefPost = "/$otherPayer');";
			$otherPayerField->invalidate($page, qq{
				Org Id '$otherPayer' does not exist.<br>
				<img src="/resources/icons/arrow_right_red.gif">
				Add Third Party Organization Id '$otherPayer' now as an
				<a href="${createOrgHrefPre}insurance${createOrgHrefPost}">Insurance</a> or
				<a href="${createOrgHrefPre}employer${createOrgHrefPost}">Employer</a>
				})
				unless $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selOrgId', $page->session('org_internal_id'), $otherPayer);
		}
	}

	my $oldPersonId = $page->field('old_person_id');
	my $personId = $page->field('attendee_id');
	if($personId ne $oldPersonId && $oldPersonId ne '')
	{
		my $payerField = $self->getField('payer');
		$payerField->invalidate($page, 'Please choose payer for new Patient ID.');
		$page->field('old_person_id', $personId);
	}
}

sub checkIntellicodeErrors
{
	my ($self, $page, $invoiceId) = @_;

	my @diags = split(/\s*,\s*/, $page->param("_f_proc_diags"));
	my @procs = ();
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $cpt = $page->param("_f_proc_$line\_procedure");
		next unless $cpt && $cpt ne 'Procedure';
		my $modifier = $page->param("_f_proc_$line\_modifier");
		my $relDiags = $page->param("_f_proc_$line\_actual_diags");
		push(@procs, [$cpt, $modifier || undef, split(/,/, $relDiags)]);
	}

	my $personId = $page->field('attendee_id');
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $personId);
	my $sex = 'M' if $personInfo->{gender_caption} eq 'Male';
	$sex = 'F' if $personInfo->{gender_caption} eq 'Female';

	my @errors = App::IntelliCode::validateCodes
		(
			$page, 0,
			sex => $sex,
			dateOfBirth => $personInfo->{date_of_birth},
			diags => \@diags,
			procs => \@procs,
			invoiceId => $invoiceId,
			personId => $personId,
		);

	return @errors;
}

sub handleRedirect
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;

	my $invoiceFlags = $page->field('invoice_flags');
	my $hospClaim = $page->param('isHosp');

	my @errors = checkIntellicodeErrors($self, $page, $invoiceId);
	if(@errors && $hospClaim != 1)
	{
		$page->redirect("/invoice/$invoiceId/error");
	}
	elsif( $command eq 'update' || ($command eq 'add' && ($invoiceFlags & App::Universal::INVOICEFLAG_DATASTOREATTR)) )
	{
		if ($page->param('encounterDialog') eq 'checkout')
		{
			$self->handlePostExecute($page, $command, $flags);
		}
		else
		{
			$page->redirect("/invoice/$invoiceId/summary");
		}
	}
	elsif($command eq 'add')
	{
		$self->handlePostExecute($page, $command, $flags);
	}
}

1;
