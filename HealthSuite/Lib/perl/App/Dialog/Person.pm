##############################################################################
package App::Dialog::Person;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Association;

use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;

use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);


sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'acct_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'chart_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'resp_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'blood_item_id'),
		#GENERAL INFORMATION

		#new App::Dialog::Field::Person::ID::New(caption => 'Person ID',
		#					name => 'person_id',
		#					options => FLDFLAG_REQUIRED,
		#					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#					postHtml => $postHtml),

		new CGI::Dialog::Field(name => 'nurse_title',
						caption => 'Person Title/Job Code',
						choiceDelim =>',',
						selOptions => "RN:1, LVN/LPN:2, OTHER:3",
						type => 'select',
						style => 'multicheck',
						hints => "You may choose more than one 'Person Title'."
				),

		new CGI::Dialog::Field(name => 'physician_type',
						caption => 'Person Type',
						choiceDelim =>',',
						selOptions => "Physician:1, Physician Extender (direct billing):2, Other Clinical Service Provider (direct billing):3, Other Clinical Services Provider (alternate billing):4",
						type => 'select',
						style => 'multicheck',
						hints => "You may choose more than one 'Person Type'."
				),

		new CGI::Dialog::MultiField(caption =>'Job Title/Code', name => 'job_code',
			fields => [
					new CGI::Dialog::Field(caption => 'Job Title', name => 'job_title'),
					new CGI::Dialog::Field(caption => 'Code', name => 'job_code'),
				]),

		new CGI::Dialog::MultiField(caption =>'Account/Chart Number', name => 'acct_chart_num',
			fields => [
					new CGI::Dialog::Field(caption => 'Account Number', name => 'acct_number', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					new CGI::Dialog::Field(caption => 'Chart Number', name => 'chart_number', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				]),

		new CGI::Dialog::Subhead(heading => 'General Information', name => 'gen_info_heading'),

		# Person::Name is a 5-part multifield, w/fields named "name_*" where * is prefix|first|middle|last|suffix
		new App::Dialog::Field::Person::Name(),
		new CGI::Dialog::Field(type => 'bool', name => 'create_record', caption => 'Create record',	style => 'check'),

		new CGI::Dialog::MultiField(caption =>'SSN / Birthdate',name => 'ssndatemf',
			fields => [
				new CGI::Dialog::Field(type=> 'ssn', caption => 'Social Security', name => 'ssn'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Birth', name => 'date_of_birth', defaultValue => '', futureOnly => 0),
				]),

		new CGI::Dialog::MultiField(caption =>'Gender / Marital Status',
			fields => [
					new CGI::Dialog::Field(type=> 'enum', enum => 'Gender', caption => 'Gender', name => 'gender', options => FLDFLAG_REQUIRED),
					new CGI::Dialog::Field(type=> 'enum', enum => 'Marital_Status', caption => 'Marital Status', name => 'marital_status'),
				]),

		new CGI::Dialog::Field(type=> 'enum', enum => 'Blood_Type', caption => 'Blood Type', name => 'blood_type', invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE),
		new CGI::Dialog::Field( type => 'memo', caption => 'Misc Notes', name => 'misc_notes'),


		# CONTACT METHODS
		new CGI::Dialog::Subhead(heading => 'Contact Methods', name => 'contact_methods_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::MultiField(caption =>'Home/Work Phone', name => 'home_work_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => 'Home Phone', name => 'home_phone', options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field(type => 'phone', caption => 'Work Phone', name => 'work_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			]),

		new CGI::Dialog::MultiField(caption =>'Cell Phone/Pager', name => 'home_pager_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => 'Cell Phone', name => 'cell_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field(type => 'phone', caption => 'Primary Pager', name => 'primary_pager', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
			]),

		new CGI::Dialog::Field(type => 'phone', caption => 'Alternate', name => 'alternate_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new App::Dialog::Field::Address(caption=>'Home Address', options => FLDFLAG_REQUIRED, invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'address'),

		new CGI::Dialog::Field(type => 'email', caption => 'Email', name => 'email', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $orgId = $page->session('org_id');

	if($page->param('_lcm_ispopup'))
	{
		$self->updateFieldFlags('occup_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('rel_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('value_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('rel_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('phone_number', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('begin_date', FLDFLAG_INVISIBLE, 1);
	}

	my $personId = $page->param('person_id');
	my $firstName = $self->getField('person_id')->{fields}->[0];
	my $lastName = $self->getField('person_id')->{fields}->[2];
	my $createRecField = $self->getField('create_record');

	my $names = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selFirstLastName', $orgId);
	foreach my $nameFirstLast (@{$names})
	{
		my $checkfirst = $nameFirstLast->{'name_first'};
		my $checklast = $nameFirstLast->{'name_last'};
		my $ssnNum = $nameFirstLast->{ssn};
		my $nameFirst = $page->field('name_first');
		my $nameLast = $page->field('name_last');
		my $perId = $nameFirstLast->{person_id};
		my $itemLastName = 'Person/Name/LastFirst';
		my $attrflag = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemLastName);
		$page->field('create_record', 1) if $attrflag->{value_int} ne '';

		if ($nameFirst eq $checkfirst && $nameLast eq $checklast && $personId ne $perId && $attrflag->{value_int} eq '')
		{
			$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 0);
			unless ($page->field('create_record'))
			{
				$createRecField->invalidate($page, "A person record with the same '$lastName->{caption}' and '$firstName->{caption}' exists with SSN as '$ssnNum'.
				If you still want to create the record, enter the check-box 'Create Record'.");
			}

		}
		else
		{
			$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 1);
		}
	}

	if($personId && $command eq 'add')
	{
		$page->field('person_id', $personId);
		#$self->setFieldFlags('person_id', FLDFLAG_READONLY);
	}

	$self->updateFieldFlags('job_code', FLDFLAG_INVISIBLE, 1) if $command eq 'remove' || $command eq 'update';
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	my $itemName11 = 'Patient/Preferred/Day';
	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my $preferredDay = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemName11);
	$page->field('prefer_day', $preferredDay->{value_text});
	my @ethnicity = split(', ', $personInfo->{ethnicity});
	$page->field('ethnicity', @ethnicity);

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}

	my $itemName = 'Patient/Account Number';
	my $acctNum = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemName);
	$page->field('acct_number', $acctNum->{'value_text'});
	$page->field('acct_item_id', $acctNum->{'item_id'});

	my $itemName1 = 'Patient/Chart Number';
	my $chartNum  = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemName1);
	$page->field('chart_number', $chartNum->{'value_text'});
	$page->field('chart_item_id', $chartNum->{'item_id'});

	#my $itemName2 = 'Nurse/Title';
	#my $nurseTitle  = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemName2);
	#$page->field('nurse_title', $nurseTitle->{'value_text'});
	#$page->field('nurse_title_item_id', $nurseTitle->{'item_id'});

	#my $itemName3 = 'Physician/Type';
	#my $physicianType  = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemName3);
	#my @phyType = split(',', $physicianType->{'value_text'});
	#$page->field('physician_type', @phyType);
	#$page->field('phy_type_item_id', $physicianType->{'item_id'});

	my $guarantor = 'Guarantor';
	my $guarantorName =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $guarantor);
	$guarantorName->{'value_text'} eq $personId ? $page->field('resp_self', 1) : $page->field('party_name', $guarantorName->{'value_text'});
	$page->field('resp_item_id', $guarantorName->{'item_id'});

	my $bloodType = 'BloodType';
	my $bloodTypecap =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $bloodType);
	$page->field('blood_item_id', $bloodTypecap->{'item_id'});
	$page->field('blood_type', $bloodTypecap->{'value_text'});
}

sub handleContactInfo
{
	my ($self, $page, $command, $flags, $personType) = @_;

	my $personId = $page->field('person_id');
	my $preferDay = $page->field('prefer_day');

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Home',
			value_type => 10,
			value_text => $page->field('home_phone'),
			_debug => 0
		) if $page->field('home_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Work',
			value_type => 10,
			value_text => $page->field('work_phone'),
			_debug => 0
		) if $page->field('work_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Alternate',
			value_type => 10,
			value_text => $page->field('alternate_phone'),
			_debug => 0
		) if $page->field('alternate_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Cellular',
			value_type => 10,
			value_text => $page->field('cell_phone'),
			_debug => 0
		) if $page->field('cell_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Primary',
			value_type => 20,
			value_text => $page->field('primary_pager'),
			_debug => 0
		) if $page->field('primary_pager') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Primary',
			value_type => 40,
			value_text => $page->field('email'),
			_debug => 0
		) if $page->field('email') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Personal/Preferred/Day',
			value_type => 0,
			value_text => $preferDay || undef,
			_debug => 0
		)if $page->field('prefer_day') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Person/Name/LastFirst',
			value_type => 0,
			value_int => $page->field('create_record'),
			_debug => 0
	) if $page->field('create_record') ne '';

	$page->schemaAction(
			'Person_Address', $command,
			parent_id => $personId,
			address_name => 'Home',
			line1 => $page->field('addr_line1'),
			line2 => $page->field('addr_line2') || undef,
			city => $page->field('addr_city'),
			state => $page->field('addr_state'),
			zip => $page->field('addr_zip'),
			_debug => 0
		) if $page->field('addr_line1') ne '';

	$self->handlePostExecute($page, $command, $flags);

	return '';

}

sub handleRegistry
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $personId = $page->field('person_id');
	my $gender = $page->field('gender');
	my $maritalStatus = $page->field('marital_status');

	#GENDER CONSTANTS
	my $male = App::Universal::GENDER_MALE;
	my $female = App::Universal::GENDER_FEMALE;

	#MARITAL STATUS CONSTANTS
	my $maritalUnknown = App::Universal::MARITALSTATUS_UNKNOWN;
	my $single = App::Universal::MARITALSTATUS_SINGLE;
	my $married = App::Universal::MARITALSTATUS_MARRIED;
	my $separated = App::Universal::MARITALSTATUS_LEGALLYSEPARATED;
	my $divorced = App::Universal::MARITALSTATUS_DIVORCED;
	my $widowed = App::Universal::MARITALSTATUS_WIDOWED;
	my $notApplicable = App::Universal::MARITALSTATUS_NOTAPPLICABLE;

	my $namePrefix = '';
	if($member eq 'Physician')
	{
		$namePrefix = 'Dr.';
	}
	elsif($gender == $male && $member ne 'Physician')
	{
		$namePrefix = 'Mr.';
	}
	elsif($gender == $female && $member ne 'Physician' && ($maritalStatus == $married || $maritalStatus == $separated || $maritalStatus == $widowed))
	{
		$namePrefix = 'Mrs.';
	}
	elsif($gender == $female && $member ne 'Physician' && ($maritalStatus == $single || $maritalStatus == $divorced || $maritalStatus == $maritalUnknown || $maritalStatus == $notApplicable))
	{
		$namePrefix = 'Ms.';
	}

	my @ethnicity = $page->field('ethnicity');
	$page->schemaAction(
			'Person', $command,
			person_id => $personId || undef,
			name_prefix => $namePrefix || undef,
			name_first => $page->field('name_first') || undef,
			name_middle => $page->field('name_middle') || undef,
			name_last => $page->field('name_last') || undef,
			name_suffix => $page->field('name_suffix') || undef,
			date_of_birth => $page->field('date_of_birth') || undef,
			ssn => $page->field('ssn') || undef,
			gender => defined $gender ? $gender : undef,
			marital_status => defined $maritalStatus ? $maritalStatus : undef,
			ethnicity => join(', ', @ethnicity) || undef,
			_debug => 0
		);

	if($command eq 'add')
	{
		$page->schemaAction(
				'Person_Org_Category', $command,
				person_id => $personId || undef,
				org_id => $page->session('org_id') || undef,
				category => $member || undef,
				_debug => 0
			);

		$page->schemaAction(
				'Person_Attribute', $command,
				parent_id => $personId,
				item_name => $member,
				value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
				value_text => $page->param('org_id') || $page->session('org_id'),
				parent_org_id => $page->param('org_id') || $page->session('org_id'),
				_debug => 0
			) if $member ne 'patient';
	}

	handleAttrs($self, $page, $command, $flags, $member, $personId);

	$member = lc($member);
	if($page->field('delete_record'))
	{
		$page->redirect("/person/$personId/dlg-remove-$member/$personId");
	}


	else
	{
		$page->redirect("/person/$personId/profile");
	}




}

sub handleAttrs
{
	my ($self, $page, $command, $flags, $member, $personId) = @_;

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_id => $page->field('phy_type_item_id') || undef,
			parent_org_id => $page->session('org_id') ||undef,
			item_name => 'Physician/Type',
			value_type => 0,
			value_text => $page->field('physician_type') || undef,
			_debug => 0
			) if $page->field('physician_type') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			parent_org_id => $page->session('org_id') ||undef,
			item_name => 'Misc Notes' ,
			value_text => $page->field('misc_notes') || undef,
			_debug => 0
			) if $page->field('misc_notes') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			parent_org_id => $page->session('org_id') ||undef,
			item_name => 'Job Code' ,
			value_text => $page->field('job_code') || undef,
			value_textB => $page->field('job_title') || undef,
			_debug => 0
			) if ($page->field('job_code') ne '' || $page->field('job_title') ne '');

	my $partyName =  $page->field('resp_self') ne '' ? $personId : $page->field('party_name');



	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_id => $page->field('resp_item_id') || undef,
			item_name => 'Guarantor' || undef,
			value_type => App::Universal::ATTRTYPE_EMERGENCY || undef,
			value_text => $partyName || undef,
			value_int => 1,
			_debug => 0
			)if $partyName ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_id => $page->field('blood_item_id') || undef,
			item_name => 'BloodType' || undef,
			value_type => 0,
			value_text => $page->field('blood_type') || undef,
			_debug => 0
		);

}

sub customValidate
{
	my ($self, $page) = @_;

	if($page->field('delete_record'))
	{
		return ();
	}
	else
	{
		my $orgId = $page->session('org_id');
		my $ssNum = $self->getField('ssndatemf')->{fields}->[0];
		my $firstName = $self->getField('person_id')->{fields}->[0];
		my $lastName = $self->getField('person_id')->{fields}->[2];
		my $personId = $page->field('person_id');

		my $personssn = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selssn', $orgId);
		#my $name = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selFirstLastName',$orgId );
		foreach my $perssn (@{$personssn})
		{
			my $ssn = $perssn->{ssn};
			my $perId = $perssn->{person_id};
			my $ssnFieldVal = $page->field('ssn');
			if ($ssnFieldVal eq $ssn && $ssnFieldVal ne '' && $personId ne $perId)
			{
				$ssNum->invalidate($page, "This Social Security Number '$ssnFieldVal' already exists.");
			}
		}
	}
}

sub execute_remove
{
	my ($self, $page, $command, $flags, $member) = @_;

	my $personId = $page->field('person_id');
	my $orgId = $page->session('org_id');

	$page->schemaAction(
			'Person', $command,
			person_id => $personId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Person_Org_Category', $command,
			person_id => $personId || undef,
			category => $member || undef,
			org_id => $orgId || undef,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags);

	return '';
}
use constant PERSON_DIALOG => 'Dialog/Person';
use constant PERSON_SESSION => 'Session/Person';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '12/28/1999', 'MAF',
		PERSON_DIALOG,
		'Moved the patient, physician, nurse dialogs code to this file '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '12/28/1999', 'RK',
		PERSON_DIALOG,
		'Moved the customvalidation subroutine from patient.pm, physician.pm, nurse.pm to this file'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '12/30/1999', 'RK',
		PERSON_DIALOG,
		'Updated the field Employment Status (ie added Unknown Status to the Status list).'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/31/1999', 'RK',
		PERSON_DIALOG,
		'Added a new multi field called Preferred Day/Time.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/31/1999', 'RK',
		PERSON_DIALOG,
		'Added a validation in the custom Validate subroutine to inform the user that a person with the same First and Last name already exists. It displays the SSN of the existing record.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/03/2000', 'RK',
			PERSON_DIALOG,
		'Made minor code changes to fix the  Personal Data pane updating '],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/04/2000', 'RK',
			PERSON_SESSION,
		'Added the execute function in handle registry sub-routine to display the list of session-activities in the session tab '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/17/2000', 'RK',
			PERSON_SESSION,
		'Updated the subroutine makeStateChanges to make the complete_name field as updatable.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/18/2000', 'RK',
			PERSON_DIALOG,
		'Added fields called Specialty 2, Specialty 3 and Affiliation/Other Affiliations/Exp Date in Physician Dialog '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/20/2000', 'RK',
			PERSON_DIALOG,
		'Updated the subroutine customValidate and shifted the added the field Create Record to the function name() in the package Person::Name. '],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '02/06/2000', 'MAF',
			PERSON_DIALOG,
		'Added a Delete Record checkbox when in update mode. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/07/2000', 'MAF',
			PERSON_DIALOG,
		'Cleaned up and reorganized code in all the person dialogs. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/07/2000', 'MAF',
			PERSON_DIALOG,
		'Customized code (headings, updates, removes, next actions, etc.) according to person type. '],
);

1;
