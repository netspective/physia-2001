##############################################################################
package App::Dialog::Person::Nurse;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use App::Page::Search::Session;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(App::Dialog::Person);

sub initialize
{
	my $self = shift;

	$self->heading('$Command Nursing Staff');

	$self->SUPER::initialize();
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'nurse_title_item_id'),
		
		new CGI::Dialog::Subhead(heading => 'Certification', name => 'cert_for_nurse', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,),

		new CGI::Dialog::MultiField(caption =>'Nursing License/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'RN #', name => 'rn_number', options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'rn_number_exp_date', defaultValue => '', options => FLDFLAG_REQUIRED),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty1', name => 'specialty1'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty1_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty2', name => 'specialty2'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty2_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty3', name => 'specialty3'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty3_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Employee ID/Exp Date',
			fields => [
				new CGI::Dialog::Field(caption => 'Employee ID', name => 'emp_id'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'emp_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::Field(caption => 'Associated Physician Name',
												#type => 'foreignKey',
												name => 'value_text',
												#fKeyTable => 'person p, person_org_category pcat',
												#fKeySelCols => "distinct p.person_id, p.complete_name",
												#fKeyDisplayCol => 1,
												#fKeyValueCol => 0,
												fKeyStmtMgr => $STMTMGR_PERSON,
												fKeyStmt => 'selAssocNurse',
												fKeyDisplayCol => 1,
												fKeyValueCol => 0
												#fKeyStmtBindPageParams => "$sessOrgId"
												),
												#fKeyWhere => "p.person_id=pcat.person_id and pcat.org_id='$sessOrg' and category='Physician'",

		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE)
	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Nurse Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Nurse', '/org/#session.org_id#/dlg-add-nurse'],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Home', "/person/#session.user_id#/home"],
							['Go to Work List', "person/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef)

	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	
	$self->updateFieldFlags('acct_chart_num', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);	
	$self->updateFieldFlags('nurse_title', FLDFLAG_INVISIBLE, 1) if $command eq 'update' || $command eq 'remove';	

	my $personId = $page->param('person_id');

	$self->updateFieldFlags('ssndatemf', FLDFLAG_REQUIRED, 1);
	$self->getField('ssndatemf')->{fields}->[0]->{options} |= FLDFLAG_REQUIRED;
	$self->getField('ssndatemf')->{fields}->[1]->{options} |= FLDFLAG_REQUIRED;

	#$self->updateFieldFlags('ssn', FLDFLAG_REQUIRED, 1);
	#$self->updateFieldFlags('date_of_birth', FLDFLAG_REQUIRED, 1);

	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Nurse '$personId'?");
	}

	my $sessOrgId = $page->session('org_id');

	$self->getField('value_text')->{fKeyStmtBindPageParams} = "$sessOrgId";
	#$page->addDebugStmt("Test: $self->getField('value_text')->{fKeyStmtBindPageParams} = $sessOrgId");
	#$self->getField('value_text')->{fKeyWhere} = "p.person_id=pcat.person_id and pcat.org_id = '@{[ $page->session('org_id') ]}' and category='Physician'";

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	$page->schemaAction(
			'Person_Attribute',	$command,
			parent_id => $page->field('person_id'),
			item_name => 'Physician',
			value_type => 250,
			value_text => $page->field('value_text') || undef,
			#parent_org_id => $page->session('org_id') || undef,
			_debug => 0
	);
	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'RN',
			value_type => 500,
			value_text => $page->field('rn_number')  || undef,
			value_dateA=> $page->field('rn_number_exp_date') || undef,
			_debug => 0
	) if $page->field('rn_number') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => 500,
			value_text => $page->field('specialty1')  || undef,
			value_dateA=> $page->field('specialty1_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty1') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => 500,
			value_text => $page->field('specialty2')  || undef,
			value_dateA=> $page->field('specialty2_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty2') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => 500,
			value_text => $page->field('specialty3')  || undef,
			value_dateA=> $page->field('specialty3_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty3') ne '';


	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id')  || undef,
			item_name => 'Employee',
			value_type => 500,
			value_text => $page->field('emp_id')  || undef,
			value_dateA=> $page->field('emp_exp_date') || undef,
			_debug => 0
	) if $page->field('emp_id') ne '';

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->field('person_id'),
		item_name => 'Physician',
		value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
		value_text => $page->field('value_text') || undef,
		parent_org_id => $page->session('org_id') || undef,
		_debug => 0
	);
	
	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $personId || undef,
		item_id => $page->field('nurse_title_item_id') || undef,
		parent_org_id => $page->session('org_id') ||undef,
		item_name => 'Nurse/Title',
		value_type => 0,
		value_text => $page->field('nurse_title') || undef,
		_debug => 0
	) if $page->field('nurse_title') ne '';

	$self->handleContactInfo($page, $command, $flags, 'nurse');

}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Nurse';

	$self->SUPER::execute_remove($page, $command, $flags, $member);

}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#

use constant NURSE_DIALOG => 'Dialog/Nurse';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/14/1999', 'MAF',
		NURSE_DIALOG,
		'Added entry for nursing license and specialties in the Nurse dialog.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '02/23/2000', 'RK',
		NURSE_DIALOG,
		'Added a dropdown list in the Nurse dialog that has the list of physicians.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/29/2000', 'RK',
		NURSE_DIALOG,
		'Changed the urls from create/... to org/.... '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/16/2000', 'RK',
		NURSE_DIALOG,
		'Replaced fkeyxxx select in the dialog with Sql statement from Statement Manager.'],
);

1;
