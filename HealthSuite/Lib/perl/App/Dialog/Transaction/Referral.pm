##############################################################################
package App::Dialog::Transaction::Referral;
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

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'login', heading => 'Add Referral');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Subhead(heading => 'Patient Information', name => 'patient_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new App::Dialog::Field::Person::ID(caption =>'Person/Patient ID ', name => 'person_id', options => FLDFLAG_READONLY),
		new App::Dialog::Field::Person::Name(),
		new CGI::Dialog::MultiField(caption =>'SSN / Birthdate',name => 'ssndatemf',  options => FLDFLAG_READONLY,
			fields => [
				new CGI::Dialog::Field(type=> 'ssn', caption => 'Social Security', name => 'ssn', options => FLDFLAG_READONLY),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Birth', name => 'date_of_birth', defaultValue => '', futureOnly => 0, options => FLDFLAG_READONLY),
		]),
		new CGI::Dialog::Subhead(heading => 'Problem Information', name => 'Problem_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::MultiField(caption =>'ICD Code /Diagnosis',name => 'icd_diag',
			fields => [
					new App::Dialog::Field::Diagnoses(caption => 'ICD-9 Codes', name => 'code', options => FLDFLAG_TRIM, hints => 'Enter ICD-9 codes in a comma separated list'),
					new App::Dialog::Field::Diagnoses(caption => 'Diagnosis Codes', name => 'code', options => FLDFLAG_TRIM)
				]),
		new CGI::Dialog::Field(caption => 'Date Of Injury', name => 'trans_end_stamp', type => 'date', options => FLDFLAG_REQUIRED, pastOnly => 0, defaultValue => ''),
		new CGI::Dialog::Field(name => 'value_text', caption => 'Comments', type => 'memo'),

		new CGI::Dialog::Subhead(heading => 'Referral Information', name => 'referral_heading'),
		#new App::Dialog::Field::Person::ID(caption =>'Physician/Provider ID ', name => 'provider_id'),
		#new App::Dialog::Field::Person::Name(),
		new CGI::Dialog::MultiField(caption =>'Physician Name ',name => 'phy_name', options => FLDFLAG_READONLY,
			fields => [
					new CGI::Dialog::Field(caption => 'First Name', name => 'phy_first_name', options => FLDFLAG_READONLY),
					new CGI::Dialog::Field(caption => 'Last Name', name => 'phy_last_name', options => FLDFLAG_READONLY)
				]),

		new CGI::Dialog::Field(caption =>'Requested Service ', name => 'value_textC',  options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption =>'Date Of Request ', name => 'trans_begin_stamp',  options => FLDFLAG_REQUIRED, type => 'date', options => FLDFLAG_REQUIRED, pastOnly => 1),


	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
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
	$self->setFieldFlags('person_id', FLDFLAG_READONLY);
	$self->setFieldFlags('ssn', FLDFLAG_READONLY);
	$self->setFieldFlags('name_last', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('name_first', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('name_middle', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('name_suffix', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('date_of_birth', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('phy_first_name', FLDFLAG_READONLY, 1);
	$self->setFieldFlags('phy_last_name', FLDFLAG_READONLY, 1);
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);

	my $personId = $page->param('person_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	#my $contactInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);


	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPrimaryPhysicianOrProvider', $personId);

	my $physician = $physicianData->{'value_text'};
	my $physicianName = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $physician);

	$page->field('phy_first_name', $physicianName->{'name_first'});
	$page->field('phy_last_name', $physicianName->{'name_last'});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $transaction = $self->{transaction};
	my $transId = $page->param('_trne_trans_id') || $page->param('trans_id');
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;

	$page->schemaAction(
			'Transaction',
			$command,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $page->param('person_id'),
			trans_id => $transId || undef,
			trans_type => $page->field('trans_type') || undef,
			trans_begin_stamp => $page->field('trans_begin_stamp') || undef,
			related_data => $page->field('related_data') || undef,
			trans_status_reason => $page->field('trans_status_reason') || undef,
			provider_id => $page->field('provider_id') || undef,
			data_text_a => $page->field('data_text_a') || undef,
			data_text_b => $page->field('data_text_b') || undef,
			data_text_c => $page->field('data_text_c') || undef,
			consult_id => $page->field('consult_id') || undef,
			trans_substatus_reason => $page->field('trans_substatus_reason') || undef,
			detail => $page->field('detail') || undef,
			caption => $page->field('caption') || undef,
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}




1;
