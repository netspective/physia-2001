##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::Referral;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use vars qw(@ISA);

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	#my $self = CGI::Dialog::new(@_, id => 'referral', heading => 'Add Referral');

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id'),
		new CGI::Dialog::Subhead(heading => 'Insurance Information', name => 'insurance_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(caption => 'Primary Payer', type => 'select', name => 'payer'),
		new CGI::Dialog::MultiField(caption => 'Payer for Today ID/Type', name => 'other_payer_fields',
			fields => [
				new CGI::Dialog::Field(
						caption => 'Payer for Today ID',
						name => 'other_payer_id',
						findPopup => '/lookup/itemValue',
						findPopupControlField => '_f_other_payer_type'),
				new CGI::Dialog::Field(type => 'select', selOptions => 'Person:person;Organization:org', caption => 'Payer for Today Type', name => 'other_payer_type')
			]),


		#new CGI::Dialog::Subhead(heading => 'Patient Information', name => 'patient_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		#new App::Dialog::Field::Person::ID(caption =>'Person/Patient ID ', name => 'person_id', options => FLDFLAG_READONLY),
		#new App::Dialog::Field::Person::Name(),
		#new CGI::Dialog::MultiField(caption =>'SSN / Birthdate',name => 'ssndatemf',  options => FLDFLAG_READONLY,
		#	fields => [
		#		new CGI::Dialog::Field(type=> 'ssn', caption => 'Social Security', name => 'ssn', options => FLDFLAG_READONLY),
		#		new CGI::Dialog::Field(type=> 'date', caption => 'Date of Birth', name => 'date_of_birth', defaultValue => '', futureOnly => 0, options => FLDFLAG_READONLY),
		#]),
		new CGI::Dialog::Subhead(heading => 'Problem Information', name => 'Problem_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::MultiField(caption =>'ICD Code',name => 'icd_code',
			fields => [
					new App::Dialog::Field::Diagnoses(caption => 'ICD-9 Codes', name => 'icd_code1', options => FLDFLAG_TRIM, size => 6),
					new App::Dialog::Field::Diagnoses(caption => 'ICD-9 Codes', name => 'icd_code2', options => FLDFLAG_TRIM, size => 6)
				]),
		new CGI::Dialog::MultiField(caption =>'CPT Code',name => 'cpt-code',
					fields => [
							new CGI::Dialog::Field(caption => 'CPT Codes', name => 'cpt_code1', findPopup => '/lookup/cpt', size => 6),
							new CGI::Dialog::Field(caption => 'CPT Codes', name => 'cpt_code2', findPopup => '/lookup/cpt',, size => 6)
				]),
		new CGI::Dialog::Field(caption => 'Date Of Injury', name => 'trans_begin_stamp', type => 'date', options => FLDFLAG_REQUIRED, pastOnly => 0, defaultValue => ''),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo'),

		new CGI::Dialog::Subhead(heading => 'Referral Information', name => 'referral_heading'),
		new App::Dialog::Field::Person::ID(caption =>'Referred By ', name => 'provider_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::MultiField(caption =>'Referred To/Referral Type',name => 'referredto_type',
			fields => [
					new App::Dialog::Field::Person::ID(caption =>'Referred To ', name => 'referral_id', options => FLDFLAG_REQUIRED),
					new CGI::Dialog::Field(caption =>'Type ',
									   name => 'referral_type',
									   options => FLDFLAG_REQUIRED,
									   type => 'select',
									   selOptions => 'Physician;Non-Physician;Laboratory;Radiology;Mental Health;Social Services;DME Rental;DME Purchase;None Of The Above'

									   )
				]),
		new CGI::Dialog::Field(type => 'select',
				style => 'radio',
				selOptions => 'Internal;External;Either',
				caption => 'Internal/External Flag',
				postHtml => "</FONT></B>",
				name => 'int_ext_flag',
				defaultValue => 'Internal'),

		#new App::Dialog::Field::Person::Name(),
		#new CGI::Dialog::MultiField(caption =>'Physician Name ',name => 'phy_name', options => FLDFLAG_READONLY,
		#	fields => [
		#			new CGI::Dialog::Field(caption => 'First Name', name => 'phy_first_name', options => FLDFLAG_READONLY),
		#			new CGI::Dialog::Field(caption => 'Last Name', name => 'phy_last_name', options => FLDFLAG_READONLY)
		#	]),

		new CGI::Dialog::Field(caption =>'Requested Service ',
			name => 'request_service',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selReferralReason',
			fKeyDisplayCol => 1,
			fKeyValueCol => 1,
			options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption =>'Service Details ', name => 'details', type => 'memo'),

		new CGI::Dialog::Field(caption =>'Date Of Request ', name => 'trans_end_stamp',  options => FLDFLAG_REQUIRED, type => 'date', options => FLDFLAG_REQUIRED, pastOnly => 1),


	);

}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;
	my $personId = $page->param('person_id');

	$page->param('person_id', $personId);

	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
				#component.stpd-person.contactMethodsAndAddresses#<BR>
				#component.stpd-person.extendedHealthCoverage#<BR>
				#component.stpd-person.careProviders#<BR>
		});

	return $self->SUPER::getSupplementaryHtml($page, $command);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	#$self->setFieldFlags('person_id', FLDFLAG_READONLY);
	#$self->setFieldFlags('ssn', FLDFLAG_READONLY);
	#$self->setFieldFlags('name_last', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('name_first', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('name_middle', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('name_suffix', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('date_of_birth', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('phy_first_name', FLDFLAG_READONLY, 1);
	#$self->setFieldFlags('phy_last_name', FLDFLAG_READONLY, 1);


	my  $otherPayer = $self->getField('other_payer_fields');

	$self->updateFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 1);
	my $payer = $page->field('payer');
	if($payer eq 'Third-Party Payer')
	{
		$self->updateFieldFlags('other_payer_fields', FLDFLAG_INVISIBLE, 0);
		$otherPayer->invalidate($page, "Please provide existing ID for Third-Pary") if $page->field('other_payer_id') eq '';

	}

	my $personId = $page->param('person_id');
	my $orgId = $page->session('org_id');
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($page, STMTMGRFLAG_CACHE, 'selCategory', $personId, $orgId);
	my $category = $personCategories->[0];
	$self->updateFieldFlags('person_id', FLDFLAG_INVISIBLE, 1)if $category eq 'Patient';
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);

	my $personId = $page->param('person_id');

	#$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	#my $contactInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);


	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPrimaryPhysicianOrProvider', $personId);

	#my $physician = $physicianData->{'value_text'};
	#my $physicianName = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $physician);

	$page->field('provider_id', $physicianData->{'value_text'});
	#$page->field('phy_last_name', $physicianName->{'name_last'});
	App::Dialog::Encounter::setPayerFields($self, $page, $command, $activeExecMode, $flags, '', $personId);

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $transaction = $self->{transaction};
	my $transId = $page->param('_trne_trans_id') || $page->param('trans_id');
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $icd1 = $page->field('icd_code1');
	my $icd2 = $page->field('icd_code2');
	my $cpt1 = $page->field('cpt_code1');
	my $cpt2 = $page->field('cpt_code2');
	my @cpt = ();
	my @icd = ();

	push(@icd, $icd1) if $icd1 ne '';
	 push(@icd, $icd2) if $icd2 ne '';
	my $dataTextB = join (', ', @icd);
	push(@cpt, $cpt1) if $cpt1 ne '';
	push(@cpt, $cpt2) if $cpt2 ne '';;
	my $dataTextC = join (', ', @cpt);
	my $personId = $page->param('person_id') ne '' ? $page->param('person_id') : $page->field('person_id');

	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL;



	$page->schemaAction(
			'Transaction',
			$command,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $personId,
			trans_id => $transId || undef,
			trans_type => $transType || undef,
			trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
			trans_end_stamp => $page->field('trans_end_stamp') || undef,
			related_data => $page->field('comments') || undef,
			trans_substatus_reason => $page->field('request_service') || undef,
			trans_status_reason => $page->field('payer') || undef,
			provider_id => $page->field('provider_id') || undef,
			care_provider_id => $page->field('referral_id') || undef,
			data_text_a => $page->field('referral_type') || undef,
			data_text_b => $dataTextB || undef,
			data_text_c => $dataTextC || undef,
			#consult_id => $page->field('referral_id') || undef,
			detail => $page->field('details') || undef,
			caption => $page->field('int_ext_flag') || undef,
			_debug => 0
	);

	$page->param('_dialogreturnurl', "/person/$personId/profile");

	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}





1;
