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

use Date::Manip;
use Date::Calc qw(:all);
use Text::Abbrev;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;
	my $schema = $self->{schema};

	$self->addContent(

		new CGI::Dialog::Field(type => 'hidden', name => 'trans_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'condition_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'prior_auth_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'deduct_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'assignment_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'accept_assignment'),
		new CGI::Dialog::Field(type => 'hidden', name => 'illness_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'disability_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'hospital_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'cntrl_num_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'bill_contact_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'pay_to_org_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'pay_to_org_tax_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'pay_to_org_phone_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_filing_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'fee_schedules_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'batch_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'parent_event_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'insuranceIsSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'eventFieldsAreSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'invoiceFieldsAreSet'),
		new CGI::Dialog::Field(type => 'hidden', name => 'invoice_flags'),	#to check if this claim has been submitted already
		new CGI::Dialog::Field(type => 'hidden', name => 'old_invoice_id'),	#the invoice id of the claim that is being modified after submission
		
		new CGI::Dialog::Field(type => 'hidden', name => 'current_status'),
		new CGI::Dialog::Field(type => 'hidden', name => 'submission_order'),

		new CGI::Dialog::Field(type => 'hidden', name => 'old_person_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'payer_chosen'),
		new CGI::Dialog::Field(type => 'hidden', name => 'primary_payer'),
		new CGI::Dialog::Field(type => 'hidden', name => 'secondary_payer'),
		new CGI::Dialog::Field(type => 'hidden', name => 'tertiary_payer'),
		new CGI::Dialog::Field(type => 'hidden', name => 'quaternary_payer'),
		new CGI::Dialog::Field(type => 'hidden', name => 'third_party_payer_ins_id'),
		#new CGI::Dialog::Field(type => 'hidden', name => 'third_party_payer_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'copay_amt'),
		new CGI::Dialog::Field(type => 'hidden', name => 'claim_type'),
		new CGI::Dialog::Field(type => 'hidden', name => 'dupCheckin_returnUrl'),
		new CGI::Dialog::Field(type => 'hidden', name => 'ins_ffs'), # Contains the insurance FFS 
		new CGI::Dialog::Field(type => 'hidden', name => 'work_ffs'), # Contains the works comp
		new CGI::Dialog::Field(type => 'hidden', name => 'org_ffs'), # Contains the Org FFS 
		new CGI::Dialog::Field(type => 'hidden', name => 'prov_ffs'), # Contains the Provider FFS
		
		#BatchDateId Needs the name of the Org.  So it can check if the org has a close date.
		#Batch Date must be > then close Date to pass validation
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',orgInternalIdFieldName=>'service_facility_id'),
		new App::Dialog::Field::Person::ID(caption => 'Patient ID', name => 'attendee_id', options => FLDFLAG_REQUIRED,
			#readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			types => ['Patient']),



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

		#new CGI::Dialog::MultiField(caption => 'Deductible Balance/Insurance Phone', name => 'deduct_fields',
		#	fields => [
				new CGI::Dialog::Field(type => 'currency', caption => 'Deductible Balance', name => 'deduct_balance'),
		#		new CGI::Dialog::Field(caption => 'Contact Phone for Primary Insurance', name => 'primary_ins_phone', options => FLDFLAG_READONLY),
		#	]),
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



		#new CGI::Dialog::MultiField(caption => 'Org Service/Billing/Pay To', name => 'org_fields',
		#	hints => 'Service Org is the org in which services were rendered.<br>
		#				Billing org is the org in which the billing should be tracked.<br>
		#				Pay To org is the org which should receive payment.',
		new CGI::Dialog::MultiField(caption => 'Org Service/Billing', name => 'org_fields',
			hints => 'Service Org is the org in which services were rendered.<br>
						Billing org is the org in which the billing should be tracked.',
			fields => [
				new App::Dialog::Field::OrgType(
							caption => 'Service Facility',
							name => 'service_facility_id',
							options => FLDFLAG_REQUIRED,
							types => "'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'"),
				new App::Dialog::Field::OrgType(
							caption => 'Billing Org',
							name => 'billing_facility_id',
							options => FLDFLAG_REQUIRED,
							types => "'PRACTICE'"),
				#new App::Dialog::Field::OrgType(
				#			caption => 'Pay To Org',
				#			name => 'pay_to_org_id',
				#			options => FLDFLAG_REQUIRED,
				#			types => "'PRACTICE'"),
			]),
		new CGI::Dialog::Field(caption => 'Billing Contact', name => 'billing_contact'),
		new CGI::Dialog::Field(type=>'phone', caption => 'Billing Phone', name => 'billing_phone'),

		new App::Dialog::Field::Person::ID(caption => 'Referring Physician ID', name => 'ref_id', types => ['Physician']),

		new CGI::Dialog::MultiField(caption =>'Similar/Current Illness Dates', name => 'illness_dates',
			fields => [
				new CGI::Dialog::Field(name => 'illness_begin_date', type => 'date', defaultValue => ''),
				new CGI::Dialog::Field(name => 'illness_end_date', type => 'date', defaultValue => '')
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

		new CGI::Dialog::Field(type => 'memo',
				caption => 'Comments',
				name => 'comments'),
		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Yes;No',
				caption => 'Have you confirmed Personal Information/Insurance Coverage?',
				preHtml => "<B><FONT COLOR=DARKRED>",
				postHtml => "</FONT></B>",
				name => 'confirmed_info',
				options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Subhead(heading => 'Procedure Entry', name => 'procedures_heading'),
		new App::Dialog::Field::Procedures(name =>'procedures_list', lineCount => 3),
	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$command ||= 'add';

	#keep third party other invisible unless it is chosen (see customValidate)
	my $payer = $page->field('payer');
	unless($payer eq 'Third-Party Payer')
	{
		$self->setFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);
	}

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
	#my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	#my $invoiceFlags = $invoiceInfo->{flags};

	my $submitOrder = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Submission Order');
	unless($submitOrder->{value_int} == 0 || $invoiceInfo->{invoice_status} > App::Universal::INVOICESTATUS_SUBMITTED)
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
		$self->setFieldFlags('ref_id', FLDFLAG_READONLY);
		$self->setFieldFlags('billing_contact', FLDFLAG_READONLY);
		$self->setFieldFlags('billing_phone', FLDFLAG_READONLY);
		$self->setFieldFlags('illness_dates', FLDFLAG_READONLY);
		$self->setFieldFlags('disability_dates', FLDFLAG_READONLY);
		$self->setFieldFlags('hosp_dates', FLDFLAG_READONLY);
		$self->setFieldFlags('prior_auth', FLDFLAG_READONLY);
		$self->setFieldFlags('comments', FLDFLAG_READONLY);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	$page->field('dupCheckin_returnUrl', $self->getReferer($page)) 
		if $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
		
	my $invoiceId = $page->param('invoice_id');
	my $eventId = $page->param('event_id') || $page->field('parent_event_id');

	if(! $page->field('eventFieldsAreSet') && $eventId)
	{
		$page->field('checkin_stamp', $page->getTimeStamp());
		$page->field('checkout_stamp', $page->getTimeStamp());
		$page->field('parent_event_id', $eventId);
		$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 
			'selEncountersCheckIn/Out', $eventId);
		my $careProvider = $page->field('care_provider_id');
		$page->field('provider_id', $careProvider); 	#default billing 'provider_id' to the 'care_provider_id'

		$invoiceId = $page->param('invoice_id', $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceIdByEventId', $eventId));

		$page->field('eventFieldsAreSet', 1);
	}

	if(! $page->field('invoiceFieldsAreSet') && $invoiceId ne '')
	{
		my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
		$page->field('attendee_id', $invoiceInfo->{client_id});
		$page->field('old_person_id', $invoiceInfo->{client_id});
		#$page->field('reference', $invoiceInfo->{reference});
		$page->field('current_status', $invoiceInfo->{invoice_status});
		$page->param('_f_proc_diags', $invoiceInfo->{claim_diags});
		$page->field('invoice_flags', $invoiceInfo->{flags});
		$page->field('old_invoice_id', $invoiceId);	#this is needed if the current claim is being edited but has already been submitted. if this is the case, a new claim is being
											#created that is an exact copy of the submitted claim.

		my $invoiceCopayItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_COPAY);
		$page->field('copay_amt', $invoiceCopayItem->{extended_cost});

		my $procedures = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, App::Universal::INVOICEITEMTYPE_SERVICE, App::Universal::INVOICEITEMTYPE_LAB);
		
		#taken off the UI
		#my $servPlaceCode = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceById', $procedures->[0]->{hcfa_service_place});
		#$page->param('_f_proc_service_place', $servPlaceCode);
		
		my $totalProcs = scalar(@{$procedures});
		foreach my $idx (0..$totalProcs-1)
		{
			#NOTE: data_text_a stores the indexes of the rel_diags (which are actual codes, not pointers)
			
			my $servTypeCode = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeById', $procedures->[$idx]->{hcfa_service_type});

			my $line = $idx + 1;			
			$page->param("_f_proc_$line\_item_id", $procedures->[$idx]->{item_id});
			$page->param("_f_proc_$line\_dos_begin", $procedures->[$idx]->{service_begin_date});
			$page->param("_f_proc_$line\_dos_end", $procedures->[$idx]->{service_end_date});
			$page->param("_f_proc_$line\_service_type", $servTypeCode);
			$page->param("_f_proc_$line\_procedure", $procedures->[$idx]->{code});
			$page->param("_f_proc_$line\_modifier", $procedures->[$idx]->{modifier});
			$page->param("_f_proc_$line\_units", $procedures->[$idx]->{quantity});
			#$page->param("_f_proc_$line\_charges", $procedures->[$idx]->{unit_cost});	#don't want to populate this in the event fee schedules should change
			$page->param("_f_proc_$line\_emg", @{[ ($procedures->[$idx]->{emergency} == 1 ? 'on' : '' ) ]});
			$page->param("_f_proc_$line\_comments", $procedures->[$idx]->{comments});
			$page->param("_f_proc_$line\_diags", $procedures->[$idx]->{data_text_a});
			$page->param("_f_proc_$line\_actual_diags", $procedures->[$idx]->{rel_diags});
			$page->param("_f_proc_$line\_ffs_flag", $procedures->[$idx]->{data_num_a});
		}


		$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $invoiceInfo->{main_transaction});
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrIllness',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrDisability',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrHospitalization',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAttrAssignment',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceAuthNumber',$invoiceId);
		$STMTMGR_INVOICE->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selInvoiceDeductible',$invoiceId);

		my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');
		$page->field('batch_item_id', $batchInfo->{item_id});
		$page->field('batch_id', $batchInfo->{value_text});
		$page->field('batch_date', $batchInfo->{value_date});

		my $feeSchedules = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Fee Schedules');
		$page->field('fee_schedules_item_id', $feeSchedules->{item_id});
		$page->param("_f_proc_default_catalog", $feeSchedules->{value_text});

		my $cntrlData = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Patient/Control Number');
		$page->field('cntrl_num_item_id', $cntrlData->{item_id});
		$page->field('control_number', $cntrlData->{value_text});

		my $billContactData = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Billing Facility/Contact');
		$page->field('bill_contact_item_id', $billContactData->{item_id});
		$page->field('billing_contact', $billContactData->{value_text});
		$page->field('billing_phone', $billContactData->{value_textb});

		my $payToOrg = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Pay To Org/Name');
		$page->field('pay_to_org_item_id', $payToOrg->{item_id});
		$page->field('pay_to_org_id', $payToOrg->{value_textb});

		my $payToOrgTaxId = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Pay To Org/Tax ID');
		$page->field('pay_to_org_tax_item_id', $payToOrgTaxId->{item_id});

		my $payToOrgPhone = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Pay To Org/Phone');
		$page->field('pay_to_org_phone_item_id', $payToOrgPhone->{item_id});

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

	if( my $personId = $page->field('attendee_id') || $page->param('person_id') )
	{
		if($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $personId))
		{
			setPayerFields($self, $page, $command, $activeExecMode, $flags, $invoiceId, $personId);
		}
	}
	#return unless $flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL;
}

sub getFS
{
	my ($self,$page,@planIds) = @_;
	my $product_id;
	my $plan_id;
	my $fsList=undef;
	foreach my $id (@planIds)
	{
		#
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
			$fsList .= $fsList ? ",$fs->{'internal_catalog_id'}" : $fs->{'internal_catalog_id'} ;	
		}
	}
	#Store FS internal id(s)
	$page->field('ins_ffs',$fsList);
}

sub setPayerFields
{
	my ($self, $page, $command, $activeExecMode, $flags, $invoiceId, $personId) = @_;

	#Create drop-down of Payers

	my $payers = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selPayerChoicesByOwnerPersonId', $personId, $personId, $personId);
	my @insurPlans = ();
	my @wkCompPlans = ();
	my @thirdParties = ();
	my @planIds  = ();
	my $insurance;
	my $ins_type;
	foreach my $ins (@{$payers})
	{
		if($ins->{group_name} eq 'Insurance')
		{
			push(@insurPlans, "$ins->{bill_seq}($ins->{plan_name})");
			#Get Insurnace Fee Schedule if insurance is primary
			#This code should match the code in Procedures.pm that also gets FFS for insurance 
			$insurance = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 
			'selInsuranceByBillSequence', App::Universal::INSURANCE_PRIMARY, $personId);					
			$ins_type="$ins->{bill_seq}";
			
			#Added to store plan internal Ids for getFS
			push(@planIds,$insurance->{'ins_internal_id'});
		}
		elsif($ins->{group_name} eq 'Workers Compensation')
		{
			push(@wkCompPlans, "Work Comp($ins->{plan_name}):$ins->{ins_internal_id}");
			#Get Work Comp Insurnace Fee Schedule
			#This code should match the code in Procedures.pm that also gets FFS for insurance 
			$insurance = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 
			'selInsuranceByPlanNameAndPersonAndInsType', $ins->{plan_name}, $personId,
			App::Universal::CLAIMTYPE_WORKERSCOMP);
			$ins_type="Work Comp";
			
			#Added to store plan internal Ids for getFS
			push(@planIds,$insurance->{'ins_internal_id'});			
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
	getFS($self,$page,@planIds);
	my @payerList = ();

	my $insurances = join(' / ', @insurPlans) if @insurPlans;
	$insurances = "$insurances" if $insurances;
	push(@payerList, $insurances) if $insurances;

	my $workComp = join(';', @wkCompPlans) if @wkCompPlans;
	$workComp = "$workComp" if $workComp;
	push(@payerList, $workComp) if $workComp;

	my $thirdParty = join(';', @thirdParties) if @thirdParties;
	$thirdParty = "$thirdParty" if $thirdParty;
	push(@payerList, $thirdParty) if $thirdParty;

	my $thirdPartyOther = 'Third-Party Payer';
	push(@payerList, $thirdPartyOther);

	my $selfPay = 'Self-Pay';
	push(@payerList, $selfPay);
	
	@payerList = join(';', @payerList);

	$self->getField('payer')->{selOptions} = "@payerList";

	my $payer = $page->field('payer');
	$page->field('payer', $payer);

	my $patientId = $page->field('attendee_id');
	$page->field('old_person_id', $patientId);

}

sub voidInvoicePostSubmit
{
	my ($self, $page, $command, $flags, $oldInvoiceId) = @_;

	#In this case, all of the submitted claims information (which includes the transaction, invoice, invoice_items, and invoice_billing and excludes adjustments) is replicated
	#into a voided claim where it's parent is the submitted claim and where the new transaction is of type 'VOID' and it's parent is the submitted claim's transaction.
	#History attributes are created for both claims at the end.


	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $personId = $page->field('attendee_id');
	my $parentTransId = $page->field('trans_id');
	my $timeStamp = $page->getTimeStamp();

	#CONSTANTS -------------------------------------------

	my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transType = App::Universal::TRANSTYPEACTION_VOID;

	#-------------------------------------------------------------

	my $transInfo = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selTransCreateClaim', $parentTransId);
	my $billType = $transInfo->{bill_type};
	my $transId = $page->schemaAction(
		'Transaction', 'add',
		trans_type => defined $transType ? $transType : undef,
		trans_status => defined $transStatus ? $transStatus : undef,
		parent_event_id => $transInfo->{parent_event_id} || undef,
		parent_trans_id => $parentTransId || undef,
		trans_owner_type => defined $entityTypePerson ? $entityTypePerson : undef,
		trans_owner_id => $personId || undef,
		trans_begin_stamp => $timeStamp || undef,
		caption => $transInfo->{subject} || undef,
		provider_id => $transInfo->{provider_id} || undef,
		care_provider_id => $transInfo->{care_provider_id} || undef,
		service_facility_id => $transInfo->{service_facility_id} || undef,
		billing_facility_id => $transInfo->{billing_facility_id} || undef,
		bill_type => defined $billType ? $billType : undef,
		data_text_a => $transInfo->{ref_id} || undef,
		data_text_b => $transInfo->{comments} || undef,
		_debug => 0
	);

	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $oldInvoiceId);
	my @claimDiags = split(/\s*,\s*/, $invoiceInfo->{claim_diags});
	my $invoiceType = $invoiceInfo->{invoice_type};
	my $claimType = $invoiceInfo->{invoice_subtype};
	my $invoiceId = $page->schemaAction(
		'Invoice', 'add',
		parent_invoice_id => $oldInvoiceId || undef,
		invoice_type => defined $invoiceType ? $invoiceType : undef,
		invoice_subtype => defined $claimType ? $claimType : undef,
		invoice_status => App::Universal::INVOICESTATUS_VOID,
		invoice_date => $page->getDate() || undef,
		main_transaction => $transId || undef,
		submitter_id => $invoiceInfo->{submitter_id} || undef,
		claim_diags => join(', ', @claimDiags) || undef,
		owner_type => $invoiceInfo->{owner_type} || undef,
		owner_id => $invoiceInfo->{owner_id} || undef,
		client_type => defined $entityTypePerson ? $entityTypePerson : undef,
		client_id => $invoiceInfo->{client_id} || undef,
		billing_id => $invoiceInfo->{billing_id} || undef,
		_debug => 0
	);

	my $lineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $oldInvoiceId);
	foreach my $item (@{$lineItems})
	{
		my $itemType = $item->{item_type};

		next if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;

		my $extCost = 0 - $item->{extended_cost};
		my $emg = $item->{emergency};
		$page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $invoiceId || undef,
			flags => $item->{flags} || undef,
			service_begin_date => $item->{service_begin_date} || undef,
			service_end_date => $item->{service_end_date} || undef,
			hcfa_service_place => defined $item->{hcfa_service_place} ? $item->{hcfa_service_place} : undef,
			hcfa_service_type => defined $item->{hcfa_service_type} ? $item->{hcfa_service_type} : undef,
			modifier => $item->{modifier} || undef,
			quantity => $item->{quantity} || undef,
			emergency => defined $emg ? $emg : undef,
			item_type => defined $itemType ? $itemType : undef,
			code => $item->{code} || undef,
			code_type => $item->{code_type} || undef,
			caption => $item->{caption} || undef,
			comments =>  $item->{comments} || undef,
			unit_cost => $item->{unit_cost} || undef,
			rel_diags => $item->{rel_diags} || undef,
			data_text_a => $item->{data_text_a} || undef,
			data_num_a => $item->{data_num_a} || undef,
			extended_cost => $extCost || undef,
			_debug => 0
		);
	}

	#add old invoice's billing records	
	my $billingInfo = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceBillingRecs', $oldInvoiceId);
	foreach my $billingRec (@{$billingInfo})
	{
		my $billSeq = $billingRec->{bill_sequence};
		my $billPartyType = $billingRec->{bill_party_type};
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			invoice_item_id => $billingRec->{invoice_item_id} || undef,
			assoc_bill_id => $billingRec->{assoc_bill_id} || undef,
			bill_sequence => defined $billSeq ? $billSeq : undef,
			bill_party_type => defined $billPartyType ? $billPartyType : undef,
			bill_to_id => $billingRec->{bill_to_id} || undef,
			bill_ins_id => $billingRec->{bill_ins_id} || undef,
			bill_amount => $billingRec->{bill_amount} || undef,
			bill_pct => $billingRec->{bill_pct} || undef,
			bill_date => $billingRec->{bill_date} || undef,
			bill_status => $billingRec->{bill_status} || undef,
			bill_result => $billingRec->{bill_result} || undef,
			_debug => 0
		);
	}

	#add history attribute for void copy
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => defined $historyValueType ? $historyValueType : undef,
		value_text => "This invoice is a voided copy of invoice $oldInvoiceId",
		value_date => $todaysDate,
		_debug => 0
	);

	#add history attribute for original (submitted) copy
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $oldInvoiceId,
		item_name => 'Invoice/History/Item',
		value_type => defined $historyValueType ? $historyValueType : undef,
		value_text => "Invoice $invoiceId is a voided copy of this invoice",
		value_date => $todaysDate,
		_debug => 0
	);

	#void original claim
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $oldInvoiceId || undef,
		invoice_status => App::Universal::INVOICESTATUS_VOID,
	);
}

sub handlePayers
{
	my ($self, $page, $command, $flags) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	my $invoiceFlags = $page->field('invoice_flags');
	my $currStatus = $page->field('current_status');
	if($command eq 'update' && ($invoiceFlags & $attrDataFlag))
	{
		$command = 'add';
		my $oldInvoiceId = $page->field('old_invoice_id');
		voidInvoicePostSubmit($self, $page, $command, $flags, $oldInvoiceId);
	}


	my $personId = $page->field('attendee_id');

	#CONSTANTS -------------------------------------------
	
	my $phoneAttrType = App::Universal::ATTRTYPE_PHONE;
	
	#bill sequences
	my $primary = App::Universal::INSURANCE_PRIMARY;
	my $secondary = App::Universal::INSURANCE_SECONDARY;
	my $tertiary = App::Universal::INSURANCE_TERTIARY;
	my $quaternary = App::Universal::INSURANCE_QUATERNARY;
	my $workerscomp = App::Universal::INSURANCE_WORKERSCOMP;

	#claim types
	my $typeSelfPay = App::Universal::CLAIMTYPE_SELFPAY;
	my $typeWorkComp = App::Universal::CLAIMTYPE_WORKERSCOMP;
	my $typeClient = App::Universal::CLAIMTYPE_CLIENT;

	#fake values for self-pay and third party payers
	my $fakeProdNameThirdParty = App::Universal::INSURANCE_FAKE_CLIENTBILL;
	my $fakeProdNameSelfPay = App::Universal::INSURANCE_FAKE_SELFPAY;

	# ------------------------------------------------------------


	my $payer = $page->field('payer');
	if($payer eq 'Self-Pay')
	{
		$page->field('primary_payer', $fakeProdNameSelfPay);
		$page->field('claim_type', $typeSelfPay);
	}
	elsif($payer eq 'Third-Party Payer')
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
		
		$page->field('primary_payer', $fakeProdNameThirdParty);
		$page->field('third_party_payer_ins_id', $insIntId);
		$page->field('claim_type', $typeClient);
	}
	else
	{
		if($payer =~ '\/')
		{
			my @payerSeq = split(' \/ ', $payer);
			foreach (@payerSeq)
			{
				my @singlePayer = split('\(', $_);
				if($singlePayer[0] eq 'Primary')
				{
					my $primIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $primary, $personId);

					$page->field('claim_type', $primIns->{ins_type});
					$page->field('primary_payer', $primIns->{product_name});
				}
				elsif($singlePayer[0] eq 'Secondary')
				{
					my $secIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $secondary, $personId);
					$page->field('secondary_payer', $secIns->{product_name});
				}
				elsif($singlePayer[0] eq 'Tertiary')
				{
					my $tertIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $tertiary, $personId);
					$page->field('tertiary_payer', $tertIns->{product_name});
				}
				elsif($singlePayer[0] eq 'Quaternary')
				{
					my $quatIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $quaternary, $personId);
					$page->field('quaternary_payer', $quatIns->{product_name});
				}
			}
		}
		else
		{
			my @nonInsPayer = split('\(', $payer);
			if($nonInsPayer[0] eq 'Primary')
			{
				my @primaryPlan = split('\)', $nonInsPayer[1]);
				my $primIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', $primary, $personId);

				$page->field('claim_type', $primIns->{ins_type});
				$page->field('primary_payer', $primIns->{product_name});
			}
			else
			{
				my $wcOrThirdPartyPlanInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $nonInsPayer[0]);
				my $claimType = $wcOrThirdPartyPlanInfo->{ins_type};
				$page->field('claim_type', $claimType);
				
				if($claimType == $typeClient)
				{				
					$page->field('primary_payer', $fakeProdNameThirdParty);
					$page->field('third_party_payer_ins_id', $wcOrThirdPartyPlanInfo->{ins_internal_id});
				}
				elsif($claimType == $typeWorkComp)
				{
					$page->field('primary_payer', $wcOrThirdPartyPlanInfo->{product_name});
				}
			}
		}
	}

	addTransactionAndInvoice($self, $page, $command, $flags);
}

sub addTransactionAndInvoice
{
	my ($self, $page, $command, $flags) = @_;
	$command ||= 'add';

	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $personId = $page->field('attendee_id');
	my $claimType = $page->field('claim_type');
	my $editInvoiceId = $page->param('invoice_id');
	my $editTransId = $page->field('trans_id');
	my $timeStamp = $page->getTimeStamp();

	#CONSTANTS -------------------------------------------

	#invoice constants
	my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $invoiceStatusCreate = App::Universal::INVOICESTATUS_CREATED;

	#entity types
	my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
	my $entityTypeOrg = App::Universal::ENTITYTYPE_ORG;

	#trans status
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;

	# other
	my $condRelToFakeNone = App::Universal::CONDRELTO_FAKE_NONE;

	#-------------------------------------------------------------------------------------------------------------------------------

	my $billingFacility = $page->field('billing_facility_id');
	my $confirmedInfo = $page->field('confirmed_info') eq 'Yes' ? 1 : 0;
	my $relTo = $page->field('accident') == $condRelToFakeNone ? '' : $page->field('accident');
	
	my $transId = $page->schemaAction(
		'Transaction', $command,
		trans_id => $editTransId || undef,
		trans_type => $page->field('trans_type'),
		trans_status => defined $transStatus ? $transStatus : undef,
		parent_event_id => $page->field('parent_event_id') || $page->param('event_id') || undef,
		caption => $page->field('subject') || undef,
		service_facility_id => $page->field('service_facility_id') || undef,
		billing_facility_id => $billingFacility || undef,
		provider_id => $page->field('provider_id') || undef,
		care_provider_id => $page->field('care_provider_id') || undef,
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
		data_text_b => $page->field('comments') || undef,
		data_num_a => defined $confirmedInfo ? $confirmedInfo : undef,
		trans_begin_stamp => $timeStamp || undef,
		_debug => 0
	);

	$transId = $command eq 'add' ? $transId : $editTransId;


	my @claimDiags = split(/\s*,\s*/, $page->param('_f_proc_diags'));
	#App::IntelliCode::incrementUsage($page, 'Icd', \@claimDiags, $sessUser, $sessOrgIntId);

	my $invoiceStatus = $command eq 'add' ? $invoiceStatusCreate : $page->field('current_status');
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

	$invoiceId = $command eq 'add' ? $invoiceId : $editInvoiceId;
	$page->param('invoice_id', $invoiceId);

	handleInvoiceAttrs($self, $page, $command, $flags, $invoiceId);
}

sub handleInvoiceAttrs
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	$command ||= 'add';

	my $todaysDate = $page->getDate();
	my $personId = $page->field('attendee_id');
	my $billingFacility = $page->field('billing_facility_id');

	#CONSTANTS
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $intValueType = App::Universal::ATTRTYPE_INTEGER;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $boolValueType = App::Universal::ATTRTYPE_BOOLEAN;
	my $currencyValueType = App::Universal::ATTRTYPE_CURRENCY;
	my $durationValueType = App::Universal::ATTRTYPE_DURATION;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;

	## Then, create invoice attribute indicating that this is the first (primary) claim
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Submission Order',
			value_type => defined $intValueType ? $intValueType : undef,
			value_int => 0,
			_debug => 0
		) if $command ne 'update';

	## Then, create invoice attribute for history of invoice status
	my $action = $command eq 'add' ? 'Created claim' : 'Updated claim';


	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => $action,
			value_textB => $page->field('comments') || undef,
			value_date => $todaysDate,
			_debug => 0
	);

	## Then, create some invoice attributes for HCFA (the rest are found in the Procedure dialog):
	#	 Accident Related To, Prior Auth Num, Deduct Balance, Accept Assignment, Ref Physician Name/Id,
	#	 Illness/Disability/Hospitalization Dates



	my $condRelToId = $page->field('accident');
	my $condition = '';
	my $state = '';
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
	if(my $refPhysId = $page->field('ref_id'))
	{
		my $refPhysInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $refPhysId);
		my $refPhysUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $refPhysId, 'UPIN', App::Universal::ATTRTYPE_LICENSE);
		my $refPhysState = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPhysStateLicense', $refPhysId, 1);
		$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delRefProviderAttrs', $invoiceId);

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


	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('prior_auth_item_id') || undef,
			parent_id => $invoiceId || undef,
			item_name => 'Prior Authorization Number',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $page->field('prior_auth') || undef,
			_debug => 0
		);

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
	my $contactName = $page->field('billing_contact') eq '' ? $billingContact->{value_text} : $page->field('billing_contact');
	my $contactPhone = $page->field('billing_phone') eq '' ? $billingContact->{value_textb} : $page->field('billing_phone');

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


	if($page->field('billing_contact') && $page->field('billing_phone'))
	{
		$page->schemaAction(
				'Org_Attribute', $command,
				parent_id => $billingFacility,
				item_name => 'Contact Information',
				value_type => defined $textValueType ? $textValueType : undef,
				value_text => $page->field('billing_contact') || undef,
				value_textB => $page->field('billing_phone') || undef,
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

	my $payToOrgIntId = $page->field('billing_facility_id');
	my $payToFacilityInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $payToOrgIntId);
	my $payToFacilityPhone = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByItemNameAndValueTypeAndParent', $payToOrgIntId, 'Primary', App::Universal::ATTRTYPE_PHONE);
	my $payToOrgId = $payToFacilityInfo->{org_id};
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('pay_to_org_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Pay To Org/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $payToFacilityInfo->{name_primary} || undef,
			value_textB => $payToOrgId || undef,
			value_int => $payToOrgIntId || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('pay_to_org_tax_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Pay To Org/Tax ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $payToFacilityInfo->{tax_id} || undef,
			value_textB => $payToOrgId || undef,
			value_int => $payToOrgIntId || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('pay_to_org_phone_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Pay To Org/Phone',
			value_type => defined $phoneValueType ? $phoneValueType : undef,
			value_text => $payToFacilityPhone->{value_text} || undef,
			value_textB => $payToOrgId || undef,
			value_int => $payToOrgIntId || undef,
			_debug => 0
	);

	my $feeSchedules = $page->param("_f_proc_active_catalogs");
	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('fee_schedules_item_id') || undef,
			parent_id => $invoiceId,
			item_name => 'Fee Schedules',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $feeSchedules || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			item_id => $page->field('batch_item_id') || undef,
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/Creation/Batch ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $page->field('batch_id') || undef,
			value_date => $page->field('batch_date') || undef,
			_debug => 0
	);

	my $invoiceFlags = $page->field('invoice_flags');
	if($invoiceFlags & $attrDataFlag)
	{
		my $oldInvoiceId = $page->field('old_invoice_id');
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => "This invoice is a new copy of invoice $oldInvoiceId which has been submitted and voided",
			value_textB => $page->field('comments') || undef,
			value_date => $todaysDate,
			_debug => 0
		);

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $oldInvoiceId,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => "Invoice $invoiceId is a new copy of this invoice",
			value_date => $todaysDate,
			_debug => 0
		);

		#update original claim - make it's parent_invoice the new invoice
		$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $oldInvoiceId || undef,
			parent_invoice_id => $invoiceId,
		);
	}

	handleProcedureItems($self, $page, $command, $flags, $invoiceId);
	if($page->field('submission_order') == 0 || $command eq 'add')
	{
		handleBillingInfo($self, $page, $command, $flags, $invoiceId) if $command ne 'remove';
	}
}

sub handleBillingInfo
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;
	my $personId = $page->field('attendee_id');


	#CONSTANTS ---------------------------------------------------------------

	#fake values for self-pay and third party payers
	my $fakeProdNameThirdParty = App::Universal::INSURANCE_FAKE_CLIENTBILL;
	my $fakeProdNameSelfPay = App::Universal::INSURANCE_FAKE_SELFPAY;

	#bill party types
	my $billPartyTypeClient = App::Universal::INVOICEBILLTYPE_CLIENT;
	my $billPartyTypePerson = App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON;
	my $billPartyTypeOrg = App::Universal::INVOICEBILLTYPE_THIRDPARTYORG;
	my $billPartyTypeIns = App::Universal::INVOICEBILLTYPE_THIRDPARTYINS;


	#------DELETE ALL PAYERS WHEN UPDATING OR REMOVING

	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delInvoiceBillingParties', $invoiceId) if $command ne 'add';

	my $billId = '';

	#------PRIMARY PAYER

	my $primPayer = $page->field('primary_payer');
	if($primPayer)
	{
		my $billParty = '';
		my $billToId = '';
		my $billInsId = '';
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		if($primPayer == $fakeProdNameSelfPay)
		{
			$billParty = $billPartyTypeClient;
			$billToId = $personId;
			#$billAmt = '';
			#$billPct = '';
			#$billDate = '';
			#$billStatus = '';
			#$billResult = '';
		}
		elsif($primPayer == $fakeProdNameThirdParty)
		{
			my $thirdPartyInsId = $page->field('third_party_payer_ins_id');
			my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $thirdPartyInsId);

			$billParty = $insInfo->{guarantor_type} == App::Universal::ENTITYTYPE_PERSON ? $billPartyTypePerson : $billPartyTypeOrg;
			$billToId = $insInfo->{guarantor_id};
			$billInsId = $insInfo->{ins_internal_id};
			#$billAmt = '';
			#$billPct = '';
			#$billDate = '';
			#$billStatus = '';
			#$billResult = '';
		}
		else
		{
			my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByOwnerAndProductName', $primPayer, $personId);
			$billParty = $billPartyTypeIns;
			$billToId = $insInfo->{ins_org_id};
			$billInsId = $insInfo->{ins_internal_id};
			#$billAmt = '';
			$billPct = $insInfo->{percentage_pay};
			#$billDate = '';
			#$billStatus = '';
			#$billResult = '';

			$page->field('copay_amt', $insInfo->{copay_amt});
		}

		my $primBillSeq = App::Universal::PAYER_PRIMARY;
		$billId = $page->schemaAction(
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
	}


	#------SECONDARY PAYER

	my $secondPayer = $page->field('secondary_payer');
	if($secondPayer ne '' && $secondPayer ne $primPayer)
	{
		my $billParty = '';
		my $billToId = '';
		my $billInsId = '';
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByOwnerAndProductName', $secondPayer, $personId);
		$billParty = $billPartyTypeIns;
		$billToId = $insInfo->{ins_org_id};
		$billInsId = $insInfo->{ins_internal_id};
		#$billAmt = '';
		$billPct = $insInfo->{percentage_pay};
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';


		my $secBillSeq = App::Universal::PAYER_SECONDARY;
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => defined $secBillSeq ? $secBillSeq : undef,
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
	}



	#------TERTIARY PAYER

	my $tertPayer = $page->field('tertiary_payer');
	if($tertPayer ne '' && $tertPayer ne $secondPayer && $tertPayer ne $primPayer)
	{
		my $billParty = '';
		my $billToId = '';
		my $billInsId = '';
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByOwnerAndProductName', $tertPayer, $personId);
		$billParty = $billPartyTypeIns;
		$billToId = $insInfo->{ins_org_id};
		$billInsId = $insInfo->{ins_internal_id};
		#$billAmt = '';
		$billPct = $insInfo->{percentage_pay};
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';


		my $tertBillSeq = $secondPayer ne '' && $secondPayer ne $primPayer ? App::Universal::PAYER_TERTIARY : App::Universal::PAYER_SECONDARY;
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => defined $tertBillSeq ? $tertBillSeq : undef,
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
	}



	#------QUATERNARY PAYER

	my $quatPayer = $page->field('quaternary_payer');
	if($quatPayer ne '' && $quatPayer ne $tertPayer && $quatPayer ne $secondPayer && $quatPayer ne $primPayer)
	{
		my $billParty = '';
		my $billToId = '';
		my $billInsId = '';
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		my $insInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByOwnerAndProductName', $quatPayer, $personId);
		$billParty = $billPartyTypeIns;
		$billToId = $insInfo->{ins_org_id};
		$billInsId = $insInfo->{ins_internal_id};
		#$billAmt = '';
		$billPct = $insInfo->{percentage_pay};
		#$billDate = '';
		#$billStatus = '';
		#$billResult = '';


		my $quatBillSeq = App::Universal::PAYER_QUATERNARY;
		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => defined $quatBillSeq ? $quatBillSeq : undef,
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
	}

	#------BY DEFAULT, ADD SELF-PAY AS THE LAST POSSIBLE PAYER IF IT HAS NOT ALREADY BEEN SELECTED

	if($primPayer != $fakeProdNameSelfPay && $quatPayer eq '')
	{
		my $billParty = '';
		my $billToId = '';
		my $billInsId = '';
		my $billAmt = '';
		my $billPct = '';
		my $billDate = '';
		my $billStatus = '';
		my $billResult = '';

		my $lastBillSeq = '';
		if( ($secondPayer eq '' && $tertPayer eq '') || ($secondPayer eq $primPayer && $tertPayer eq $primPayer) )
		{
			$lastBillSeq = App::Universal::PAYER_SECONDARY;
		}
		elsif( ($secondPayer ne '' && $secondPayer ne $primPayer) && ($tertPayer eq '' || $tertPayer eq $primPayer || $tertPayer eq $secondPayer) )
		{
			$lastBillSeq = App::Universal::PAYER_TERTIARY;
		}
		else
		{
			$lastBillSeq = App::Universal::PAYER_QUATERNARY;
		}

		$page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $invoiceId || undef,
			bill_sequence => defined $lastBillSeq ? $lastBillSeq : undef,
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

	setCurrentPayer($self, $page, $invoiceId, $billId);


	#redirect to next function according to copay due
	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	my $invoiceFlags = $page->field('invoice_flags');
	my $copayAmt = $page->field('copay_amt');
	my $copayItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceItemsByType', $invoiceId, App::Universal::INVOICEITEMTYPE_COPAY);
	my $copayItemId = $copayItem->{item_id};
	my $claimType = $page->field('claim_type');
	if($claimType != App::Universal::CLAIMTYPE_HMO)
	{
		#delete copay item if claim is updated to a non-cap claim type
		if($copayItemId && $copayItem->{data_text_b} ne 'void')
		{
			voidProcedureItem($self, $page, $command, $flags, $invoiceId, $copayItemId);
		}
	}
	
	if($copayAmt && $claimType == App::Universal::CLAIMTYPE_HMO && ($copayItemId eq '' || $copayItem->{data_text_b} eq 'void'))
	{
		my $lineCount = $page->param('_f_line_count');
		my $existsOfficeVisitCPT = '';
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			if( $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'checkOfficeVisitCPT', $page->param("_f_proc_$line\_procedure")) )
			{			
				$existsOfficeVisitCPT = 1;
			}		
		}
		
		if($existsOfficeVisitCPT)
		{
			billCopay($self, $page, 'add', $flags, $invoiceId);
		}
		else
		{
			$self->handlePostExecute($page, $command, $flags);
		}
	}
	elsif( $command eq 'update' || ($command eq 'add' && ($invoiceFlags & $attrDataFlag)) )
	{
		$page->redirect("/invoice/$invoiceId/summary");
	}
	elsif($command eq 'add')
	{
		$self->handlePostExecute($page, $command, $flags);
	}
}

sub setCurrentPayer
{
	my ($self, $page, $invoiceId, $billId) = @_;
	
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		billing_id => $billId,
	);

}

sub billCopay
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;

	my $todaysDate = $page->getDate();
	my $personId = $page->field('attendee_id');
	my $personType = App::Universal::ENTITYTYPE_PERSON;
	my $copayAmt = $page->field('copay_amt');


	#ADD COPAY ITEM

	my $itemType = App::Universal::INVOICEITEMTYPE_COPAY;
	my $copayItemId = $page->schemaAction(
		'Invoice_Item', $command,
		parent_id => $invoiceId || undef,
		item_type => defined $itemType ? $itemType : undef,
		extended_cost => defined $copayAmt ? $copayAmt : undef,
		_debug => 0
	);


	#ADD INVOICE BILLING RECORD FOR COPAY ITEM

	my $billSeq = App::Universal::PAYER_PRIMARY;
	my $billPartyType = App::Universal::INVOICEBILLTYPE_CLIENT;
	$page->schemaAction(
		'Invoice_Billing', $command,
		invoice_id => $invoiceId || undef,
		invoice_item_id => $copayItemId || undef,
		bill_sequence => defined $billSeq ? $billSeq : undef,
		bill_party_type => defined $billPartyType ? $billPartyType : undef,
		bill_to_id => $personId || undef,
		bill_amount => defined $copayAmt ? $copayAmt : undef,
		bill_date => $todaysDate || undef,
		#bill_status => 'Not paid',
		_debug => 0
	);



	#Need to set invoice id as a param in order for 'Add Procedure' and 'Go to Claim Summary' next actions to work
	$page->param('invoice_id', $invoiceId) if $command eq 'add';

	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	my $invoiceFlags = $page->field('invoice_flags');
	if( $command eq 'update' || ($command eq 'add' && ($invoiceFlags & $attrDataFlag)) )
	{
		$page->redirect("/invoice/$invoiceId/summary");
	}
	elsif($command eq 'add')
	{
		$self->handlePostExecute($page, $command, $flags);
	}
}

sub handleProcedureItems
{
	my ($self, $page, $command, $flags, $invoiceId) = @_;

	my $servItemType = App::Universal::INVOICEITEMTYPE_SERVICE;
	my $labItemType = App::Universal::INVOICEITEMTYPE_LAB;

	my @feeSchedules = $page->param('_f_proc_default_catalog');
	
	#convert place to it's foreign key id
	my $svcFacility = $page->field('service_facility_id');
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');
	my $servPlaceId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlaceByAbbr', $svcPlaceCode->{value_text});

	my $lineCount = $page->param('_f_line_count');

	for(my $line = 1; $line <= $lineCount; $line++)
	{
		next if $page->param("_f_proc_$line\_dos_begin") eq 'From' || $page->param("_f_proc_$line\_dos_end") eq 'To';
		next unless $page->param("_f_proc_$line\_dos_begin") && $page->param("_f_proc_$line\_dos_end");

		my $removeProc = $page->param("_f_proc_$line\_remove");
		my $itemId = $page->param("_f_proc_$line\_item_id");
		if(! $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId))
		{
			$command = 'add';
		}
		elsif($removeProc)
		{
			voidProcedureItem($self, $page, $command, $flags, $invoiceId, $itemId);
			next;
		}

		my $cptCode = $page->param("_f_proc_$line\_procedure");
		my $cptShortName = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $cptCode);

		#convert type to it's foreign key id
		my $servType = $page->param("_f_proc_$line\_service_type");
		my $servTypeId = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceTypeByAbbr', $servType);

		my $emg = $page->param("_f_proc_$line\_emg") eq 'on' ? 1 : 0;
		my %record = (
			item_id => $itemId || undef,
			service_begin_date => $page->param("_f_proc_$line\_dos_begin") || undef,		#default for service start date is today
			service_end_date => $page->param("_f_proc_$line\_dos_end") || undef,			#default for service end date is today
			hcfa_service_place => defined $servPlaceId ? $servPlaceId : undef,			#
			hcfa_service_type => defined $servTypeId ? $servTypeId : undef,				#default for service type is 2 for consultation
			modifier => $page->param("_f_proc_$line\_modifier") || undef,				#default for modifier is "mandated services"
			quantity => $page->param("_f_proc_$line\_units") || undef,					#default for units is 1
			emergency => defined $emg ? $emg : undef,								#default for emergency is 0 or 1
			item_type => App::Universal::INVOICEITEMTYPE_SERVICE || undef,			#default for item type is service
			code => $cptCode || undef,
			code_type => $page->param("_f_proc_$line\_code_type") || undef,
			caption => $cptShortName->{name} || undef,
			comments =>  $page->param("_f_proc_$line\_comments") || undef,
			unit_cost => $page->param("_f_proc_$line\_charges") || undef,
			rel_diags => $page->param("_f_proc_$line\_actual_diags") || undef,		#the actual icd (diag) codes
			data_text_a => $page->param("_f_proc_$line\_diags") || undef,			#the diag code pointers
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

sub voidProcedureItem
{
	my ($self, $page, $command, $flags, $invoiceId, $itemId) = @_;

	my $sessUser = $page->session('user_id');
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);

	my $voidItemType = App::Universal::INVOICEITEMTYPE_VOID;
	my $extCost = 0 - $invItem->{extended_cost};
	my $itemBalance = $extCost + $invItem->{total_adjust};
	my $emg = $invItem->{emergency};
	my $cptCode = $invItem->{code};
	my $voidItemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => defined $voidItemType ? $voidItemType : undef,
			flags => $invItem->{flags} || undef,
			code => $cptCode || undef,
			code_type => $invItem->{code_type} || undef,
			caption => $invItem->{caption} || undef,
			modifier => $invItem->{modifier} || undef,
			rel_diags => $invItem->{rel_diags} || undef,
			unit_cost => $invItem->{unit_cost} || undef,
			quantity => $invItem->{quantity} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			emergency => defined $emg ? $emg : undef,
			#comments => $comments || undef,
			hcfa_service_place => defined $invItem->{hcfa_service_place} ? $invItem->{hcfa_service_place} : undef,
			hcfa_service_type => defined $invItem->{hcfa_service_type} ? $invItem->{hcfa_service_type} : undef,
			service_begin_date => $invItem->{service_begin_date} || undef,
			service_end_date => $invItem->{service_end_date} || undef,
			data_text_a => $invItem->{data_text_a} || undef,
			data_num_a => $invItem->{data_num_a} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId || undef,
			data_text_b => 'void',
			_debug => 0
		);


	## ADD HISTORY ATTRIBUTE
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => "Voided $cptCode",
			value_date => $todaysDate || undef,
			_debug => 0
	);
}

sub customValidate
{
	my ($self, $page) = @_;

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
	if($payer eq 'Third-Party Payer')
	{
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

sub checkEventStatus
{
	my ($self, $page, $eventId) = @_;
	
	my $checkStatus = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_eventInfo', $eventId);

	my ($status, $person, $stamp);
	
	if ($checkStatus->{event_status} == 2)
	{
		$status = 'out';
		$person = $checkStatus->{checkout_by_id};
		$stamp  = $checkStatus->{checkout_stamp};

	} 
	elsif ($checkStatus->{event_status} == 1)
	{
		$status = 'in';
		$person = $checkStatus->{checkin_by_id};
		$stamp  = $checkStatus->{checkin_stamp};
	}

	return ($status, $person, $stamp);
}

1;
