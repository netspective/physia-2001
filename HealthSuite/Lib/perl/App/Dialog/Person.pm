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
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);
%RESOURCE_MAP = ();

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'acct_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'chart_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'resp_item_id'),
		#new CGI::Dialog::Field(type => 'hidden', name => 'blood_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'job_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'driver_license_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'nurse_emp_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'assoc_phy_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'bill_provider_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'inactive_patient_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'language_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'ethnicity_item_id'),

		#GENERAL INFORMATION

		#new App::Dialog::Field::Person::ID::New(caption => 'Person ID',
		#					name => 'person_id',
		#					options => FLDFLAG_REQUIRED,
		#					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
		#					postHtml => $postHtml),

		new CGI::Dialog::Field(name => 'nurse_title',
						caption => 'Person Title/Job Code',
						selOptions => "LVN/LPN;RN;OTHER",
						type => 'select',
						style => 'multicheck',
						hints => "You may choose more than one 'Person Title'."
				),

		new CGI::Dialog::Field(name => 'physician_type',
						caption => 'Person Type',
						selOptions => "Physician;Physician Extender (direct billing);Other Clinical Service Provider (direct billing);Other Clinical Services Provider (alternate billing)",
						type => 'select',
						style => 'multicheck',
						hints => "You may choose more than one 'Person Type'."
				),

		new App::Dialog::Field::Person::ID(caption => 'Doctor to bill for this provider', name => 'bill_provider', types => ['Physician']),

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

		new CGI::Dialog::Subhead(heading => 'Profile Information', name => 'gen_info_heading'),

		# Person::Name is a 5-part multifield, w/fields named "name_*" where * is prefix|first|middle|last|suffix
		new App::Dialog::Field::Person::Name(options => FLDFLAG_HOME),
		new CGI::Dialog::Field(type => 'bool', name => 'create_record', caption => 'Add record', style => 'check'),

		new CGI::Dialog::MultiField(name => 'ssndatemf',
			fields => [
				new CGI::Dialog::Field(type=> 'ssn', caption => 'Social Security', name => 'ssn'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Birth', name => 'date_of_birth',
							defaultValue => '', options => FLDFLAG_REQUIRED, futureOnly => 0),
				]),

		new CGI::Dialog::MultiField(
			fields => [
				new CGI::Dialog::Field(
						selOptions => 'Male:1;Female:2',
						caption => 'Gender',
						type => 'select',
						name => 'gender',
						options => FLDFLAG_REQUIRED|FLDFLAG_PREPENDBLANK
						),

				new CGI::Dialog::Field(type=> 'enum', enum => 'Marital_Status', caption => 'Marital Status', name => 'marital_status'),
			]),

		new CGI::Dialog::Field(type=> 'enum', enum => 'Blood_Type', caption => 'Blood Type', name => 'blood_type', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(name => 'ethnicity',
						lookup => 'ethnicity',
						style => 'multicheck',
						caption => 'Ethnicity',
						hints => 'You may choose more than one ethnicity type.'),
		new CGI::Dialog::Field(	caption => 'Other Ethnicity',name => 'other_ethnicity'),
		new CGI::Dialog::Field(
						selOptions => "English;Spanish;French;German;Italian;Chinese;Japanese;Korean;Vietnamese;Other",
						caption => 'Language Spoken',
						style => 'multicheck',
						type => 'select',
						name => 'language',
						),
		new CGI::Dialog::Field(	caption => 'Other Language',name => 'other_language'),
		new App::Dialog::Field::Person::ID(caption => 'Responsible Party', name => 'party_name', types => ['Guarantor', 'Patient', 'Physician', 'Nurse', 'Staff']),
							#hints => "Please provide either an existing Person ID or leave the field 'Responsible Party' as blank and select 'Self' as 'Relationship'"),
		new App::Dialog::Field::Association(caption => 'Relationship To Responsible Party/Other Relationship Name', name => 'relation', options => FLDFLAG_REQUIRED),
		#
		new CGI::Dialog::MultiField(caption =>"Driver's License Number/State", name => 'license_num_state',
				fields => [
						new CGI::Dialog::Field(caption => 'License Number', name => 'license_number'),
						new CGI::Dialog::Field(caption => 'State', name => 'license_state', size => 2, maxLength => 2,)
			]),
		new CGI::Dialog::Field( type => 'memo', caption => 'Misc Notes', name => 'misc_notes'),

		# CONTACT METHODS
		new CGI::Dialog::Subhead(heading => 'Contact Methods', name => 'contact_methods_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::MultiField(name => 'home_work_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(type => 'phone', caption => 'Home Phone', name => 'home_phone', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
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

	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');

	my $delRec = $self->getField('delete_record');
	if ($page->field('delete_record'))
	{
		$delRec->invalidate($page, "The ability to delete person records has been disabled");
	}

	if($page->param('_lcm_ispopup'))
	{
		$self->updateFieldFlags('occup_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('rel_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('value_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('rel_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('phone_number', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('begin_date', FLDFLAG_INVISIBLE, 1);
	}

	my $personId = $command eq 'add' ? $page->field('person_id') : $page->param('person_id');
	my $firstName = $self->getField('person_id')->{fields}->[1];
	my $lastName = $self->getField('person_id')->{fields}->[0];
	my $createRecField = $self->getField('create_record');
	my $itemLastName = 'Person/Name/LastFirst';
	my $names = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selFirstLastName', $orgIntId);
	my $attrflag = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $itemLastName);
	$page->field('create_record', 1) if $attrflag->{value_int} ne '';

	foreach my $nameFirstLast (@{$names})
	{
		my $checkfirst = $nameFirstLast->{'name_first'};
		my $checklast = $nameFirstLast->{'name_last'};
		my $ssnNum = $nameFirstLast->{ssn};
		my $nameFirst = $page->field('name_first');
		my $nameLast = $page->field('name_last');
		my $perId = $nameFirstLast->{person_id};

		if ($nameFirst eq $checkfirst && $nameLast eq $checklast && $personId ne $perId && $attrflag->{value_int} eq '' && $command eq 'add')
		{
			$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 0);
			unless ($page->field('create_record'))
			{
				$createRecField->invalidate($page, "A person record with the same '$lastName->{caption}' and '$firstName->{caption}' exists with SSN as '$ssnNum'.
				If you still want to add the record, enter the check-box 'Add Record'.");
			}

			last;

		}

		else
		{
			$self->updateFieldFlags('create_record', FLDFLAG_INVISIBLE, 1);
		}
	}
	if($personId && $command eq 'add')
	{
		$page->field('person_id', $personId);
	}

	my $phyType = $page->field('physician_type');
	my $billProvider = 'Bill Provider';
	my $providerId = '';
	if ($command ne 'add')
	{
		my $billProviderData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $billProvider);
		$page->field('bill_provider_item_id', $billProviderData->{'item_id'});
		$providerId = $billProviderData->{'value_text'};
	}

	if ($phyType ne "Other Clinical Services Provider (alternate billing)" && $command eq 'add' )
	{
		$self->updateFieldFlags('bill_provider', FLDFLAG_INVISIBLE, 1);
	}
	if ($providerId eq '')
	{
		$self->updateFieldFlags('bill_provider', FLDFLAG_INVISIBLE, 1);
	}

	my $billRecField = $self->getField('bill_provider');
		my $personType = $page->field('physician_type');

	if ($page->field('physician_type') eq "Other Clinical Services Provider (alternate billing)" && $page->field('bill_provider') eq '')
	{
		$self->updateFieldFlags('bill_provider', FLDFLAG_INVISIBLE, 0);
		$billRecField->invalidate($page, "'$billRecField->{caption}' is a required field when the 'Person Type' is '$personType'");
	}

	my @ethnicity = $page->field('ethnicity');
	my @languages = $page->field('language');
	my $ethnicityLength = @ethnicity;
	my $languageLength = @languages;
	my $lastEthnicity = $ethnicity[$ethnicityLength-1];
	my $lastLanguage = $languages[$languageLength-1];
	my $otherLanguage = $self->getField('other_language');
	my $otherEthnicity = $self->getField('other_ethnicity');
	my $language = $self->getField('language');
	my $ethnicity = $self->getField('ethnicity');

	if($page->field('other_ethnicity') eq '' &&  $lastEthnicity eq 'Other')
	{
		$otherEthnicity->invalidate($page, "'$otherEthnicity->{caption}' is a required field when the 'Other' checkbox in the 'Ethnicity' field is checked.");
	}
	elsif($page->field('other_ethnicity') ne '' && $lastEthnicity ne 'Other')
	{
		$ethnicity->invalidate($page, "The 'Other' checkbox should be checked when the 'Other Ethnicity' field is not blank");
	}

	if($page->field('other_language') eq '' &&  $lastLanguage eq 'Other')
	{
		$otherLanguage->invalidate($page, "'$otherLanguage->{caption}' is a required field when the 'Other' checkbox in the 'Language Spoken' field is checked.");
	}
	elsif($page->field('other_language') ne '' && $lastLanguage ne 'Other')
	{
		$language->invalidate($page, "The 'Other' checkbox should be checked when the 'Other Language' field is not blank");
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	my $itemName11 = 'Patient/Preferred/Day';
	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	my @languages = split(', ', $personInfo->{language});
	$page->field('language', @languages);
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

	my $PhysicianType = 'Physician/Type';
	my $physicianType  = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $PhysicianType);
	my @phyType = split(',', $physicianType->{'value_text'});
	$page->field('physician_type', @phyType);
	$page->field('phy_type_item_id', $physicianType->{'item_id'});

	my $guarantor = 'Guarantor';
	my $guarantorName =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $guarantor);
	$guarantorName->{'value_text'} eq $personId ? $page->field('party_name', '') : $page->field('party_name', $guarantorName->{'value_text'});
	$guarantorName->{'value_text'} eq $personId ? $page->field('resp_self', $personId) : $page->field('resp_self', '');
	$page->field('resp_item_id', $guarantorName->{'item_id'});
	my $relation = $guarantorName->{'value_textb'};
	my @itemNamefragments = split('/', $relation);

		if($itemNamefragments[0] eq 'Other')
		{
			$page->field('rel_type', $itemNamefragments[0]);
			$page->field('other_rel_type', $itemNamefragments[1]);
		}

		else
		{
			$page->field('rel_type', $itemNamefragments[0]);
		}

	#my $bloodType = 'BloodType';
	#my $bloodTypecap =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $bloodType);
	#$page->field('blood_item_id', $bloodTypecap->{'item_id'});
	#$page->field('blood_type', $bloodTypecap->{'value_text'});

	my $nurseTitle = 'Nurse/Title';
	my $nurseTitleData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $nurseTitle);
	$page->field('nurse_title_item_id', $nurseTitleData->{'item_id'});
	my @titles = split(',', $nurseTitleData->{'value_text'});
	$page->field('nurse_title', @titles);

	my $jobCode = 'Job Code';
	my $jobCodeData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $jobCode);
	$page->field('job_item_id', $jobCodeData->{'item_id'});
	$page->field('job_code', $jobCodeData->{'value_textb'});
	$page->field('job_title', $jobCodeData->{'value_text'});

	my $driverLicense = 'Driver/License';
	my $driverLicenseData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $driverLicense);
	$page->field('driver_license_item_id', $driverLicenseData->{'item_id'});
	$page->field('license_number', $driverLicenseData->{'value_text'});
	$page->field('license_state', $driverLicenseData->{'value_textb'});

	my $nurseEmp = 'Employee';
	my $nurseEmpData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $nurseEmp);
	$page->field('nurse_emp_item_id', $nurseEmpData->{'item_id'});
	$page->field('emp_id', $nurseEmpData->{'value_text'});
	$page->field('emp_exp_date', $nurseEmpData->{'value_datea'});

	my $billProvider = 'Bill Provider';
	my $billProviderData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $billProvider);
	$page->field('bill_provider_item_id', $billProviderData->{'item_id'});
	$page->field('bill_provider', $billProviderData->{'value_text'});

	my $inactivePatient = 'Inactive Patient';
	my $inactiveData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $inactivePatient);
	$page->field('inactive_patient_item_id', $inactiveData->{'item_id'});
	$page->field('inactivate_record', $inactiveData->{'value_int'});
	$page->field('inactivate_date', $inactiveData->{'value_date'});
	#my $assocPhysician = 'Physician';
	#my $assocPhysicianData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $assocPhysician);
	#$page->field('assoc_phy_item_id', $assocPhysicianData->{'item_id'});
	#$page->field('value_text', $assocPhysicianData->{'value_text'});

	my $otherLanguage = 'Other Language';
	my $otherLanguageData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $otherLanguage);
	$page->field('language_item_id', $otherLanguageData->{'item_id'});
	$page->field('other_language', $otherLanguageData->{'value_text'});

	my $otherEthnicity = 'Other Ethnicity';
	my $otherEthnicityData =  $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $personId, $otherEthnicity);
	$page->field('ethnicity_item_id', $otherEthnicityData->{'item_id'});
	$page->field('other_ethnicity', $otherEthnicityData->{'value_text'});
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
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $page->field('home_phone'),
			_debug => 0
		) if $page->field('home_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Work',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $page->field('work_phone'),
			_debug => 0
		) if $page->field('work_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Alternate',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $page->field('alternate_phone'),
			_debug => 0
		) if $page->field('alternate_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Cellular',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $page->field('cell_phone'),
			_debug => 0
		) if $page->field('cell_phone') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Primary',
			value_type =>  App::Universal::ATTRTYPE_PAGER,
			value_text => $page->field('primary_pager'),
			_debug => 0
		) if $page->field('primary_pager') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId,
			item_name => 'Primary',
			value_type =>  App::Universal::ATTRTYPE_EMAIL,
			value_text => $page->field('email'),
			_debug => 0
		) if $page->field('email') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Personal/Preferred/Day',
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => $preferDay || undef,
			_debug => 0
		)if $page->field('prefer_day') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			item_name => 'Person/Name/LastFirst',
			value_type => App::Universal::ATTRTYPE_TEXT,
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

	#$self->handlePostExecute($page, $command, $flags);

	#return '';

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

	if($gender == $male && $member eq 'Patient')
	{
		$namePrefix = 'Mr.';
	}
	elsif($gender == $female && ($maritalStatus == $married || $maritalStatus == $separated || $maritalStatus == $widowed) && $member eq 'Patient')
	{
		$namePrefix = 'Mrs.';
	}
	elsif($gender == $female && ($maritalStatus == $single || $maritalStatus == $divorced || $maritalStatus == $maritalUnknown || $maritalStatus == $notApplicable) && $member eq 'Patient')
	{
		$namePrefix = 'Ms.';
	}
	elsif($member eq 'Physician')
	{
		$namePrefix = 'Dr.';
	}

	my @ethnicity = $page->field('ethnicity');
	my @languages = $page->field('language');

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
			language => join(', ', @languages) || undef,
			_debug => 0
		);

	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');


	if($command eq 'add')
	{
		$page->schemaAction(
				'Person_Org_Category', $command,
				person_id => $personId || undef,
				org_internal_id => $orgIntId || undef,
				category => $member || undef,
				_debug => 0
			);

		$page->schemaAction(
				'Person_Attribute', $command,
				parent_id => $personId,
				item_name => $member,
				value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
				value_int => $orgIntId,
				parent_org_id => $orgIntId,
				_debug => 0
			) if $member ne 'Patient';

		$page->schemaAction(
				'Person_Attribute', $command,
				parent_id => $personId || undef,
				item_name => 'BloodType' || undef,
				value_type => App::Universal::ATTRTYPE_TEXT,
				value_text => $page->field('blood_type') || undef,
				_debug => 0
		);
	}

	handleAttrs($self, $page, $command, $flags, $member, $personId);

	$member = lc($member);
	if($page->field('delete_record'))
	{
		$page->redirect("/person/$personId/dlg-remove-$member/$personId");
	}
	elsif ($command eq 'update')
	{
		$page->redirect("/person/$personId/profile");
	}
	else
	{
		$self->handlePostExecute($page, $command, $flags);
	}
}

sub handleAttrs
{
	my ($self, $page, $command, $flags, $member, $personId) = @_;
	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');
	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $personId || undef,
			parent_org_id => $orgIntId ||undef,
			item_name => 'Misc Notes' ,
			value_type => 0,
			value_text => $page->field('misc_notes') || undef,
			value_date => $page->getDate() || undef,
			value_textB => $page->session('user_id') || undef,
			_debug => 0
			) if $page->field('misc_notes') ne '';

	my $commandJobCode = $command eq 'update' &&  $page->field('job_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Person_Attribute', $commandJobCode,
			parent_id => $personId || undef,
			parent_org_id => $orgIntId ||undef,
			item_id => $page->field('job_item_id') || undef,
			item_name => 'Job Code' ,
			value_text => $page->field('job_title') || undef,
			value_textB => $page->field('job_code') || undef,
			_debug => 0
		) if $member ne 'Patient';

	my $relType = $page->field('rel_type');
	my $otherRelType = $page->field('other_rel_type');
	$otherRelType = "\u$otherRelType";
	my $relationship = $relType eq 'Other' ? "Other/$otherRelType" : $relType;
	my $partyName =  $page->field('party_name') ne '' ? $page->field('party_name') : $personId;

	my $commandResponsible = $command eq 'update' &&  $page->field('resp_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Person_Attribute', $commandResponsible,
			parent_id => $personId || undef,
			item_id => $page->field('resp_item_id') || undef,
			item_name => 'Guarantor' || undef,
			value_type => App::Universal::ATTRTYPE_EMERGENCY || undef,
			value_text => $partyName || undef,
			value_textB => $relationship || undef,
			_debug => 0
			);

	my $commandTitle = $command eq 'update' &&  $page->field('nurse_title_item_id') eq '' ? 'add' : $command;
	my @titles = $page->field('nurse_title');
	$page->schemaAction(
			'Person_Attribute', $commandTitle,
			parent_id => $personId || undef,
			item_id => $page->field('nurse_title_item_id') || undef,
			parent_org_id => $orgIntId ||undef,
			item_name => 'Nurse/Title',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => join(',', @titles) || undef,
			_debug => 0
		) if $member eq 'Nurse';

	my $commandPhyType = $command eq 'update' &&  $page->field('phy_type_item_id') eq '' ? 'add' : $command;
	my @physicianType = $page->field('physician_type');
	$page->schemaAction(
			'Person_Attribute', $commandPhyType,
			parent_id => $personId || undef,
			item_id => $page->field('phy_type_item_id') || undef,
			parent_org_id => $orgIntId ||undef,
			item_name => 'Physician/Type',
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => join(',', @physicianType) || undef,
			_debug => 0
		) if $member eq 'Physician';

	my $commandDriverLicense = $command eq 'update' &&  $page->field('driver_license_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
				'Person_Attribute', $commandDriverLicense,
				parent_id => $personId || undef,
				item_id => $page->field('driver_license_item_id') || undef,
				item_name => 'Driver/License',
				value_type => App::Universal::ATTRTYPE_LICENSE,
				value_text => $page->field('license_number') || undef,
				value_textB => $page->field('license_state') || undef,
				_debug => 0
	) if $member eq 'Patient';

	my $commandNurseEMp = $command eq 'update' &&  $page->field('nurse_emp_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
				'Person_Attribute', $commandNurseEMp,
				parent_id => $page->field('person_id')  || undef,
				item_name => 'Employee',
				item_id   =>  $page->field('nurse_emp_item_id') || undef,
				value_type => App::Universal::ATTRTYPE_LICENSE,
				value_text => $page->field('emp_id')  || undef,
				value_dateA=> $page->field('emp_exp_date') || undef,
				_debug => 0
	) if ($page->field('emp_id') ne '' && $member eq 'Nurse');

	my $commandAcct = $command eq 'update' &&  $page->field('acct_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
			'Person_Attribute', $commandAcct,
			parent_id => $personId || undef,
			item_id => $page->field('acct_item_id') || undef,
			parent_org_id => $page->session('org_internal_id') ||undef,
			item_name => 'Patient/Account Number',
			value_type => 0,
			value_text => $page->field('acct_number') || undef,
			_debug => 0
	) if $page->field('acct_number') ne '';

	my $commandChart = $command eq 'update' &&  $page->field('chart_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
		'Person_Attribute', $commandChart,
		parent_id => $personId || undef,
		item_id => $page->field('chart_item_id') || undef,
		parent_org_id => $page->session('org_internal_id') ||undef,
		item_name => 'Patient/Chart Number',
		value_type => 0,
		value_text => $page->field('chart_number') || undef,
		_debug => 0
	) if $page->field('chart_number') ne '';

	my $commandBillProvider = $command eq 'update' &&  $page->field('bill_provider_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
		'Person_Attribute', $commandBillProvider,
		parent_id => $personId || undef,
		item_id => $page->field('bill_provider_item_id') || undef,
		parent_org_id => $page->session('org_internal_id') ||undef,
		item_name => 'Bill Provider',
		value_type => 0,
		value_text => $page->field('bill_provider') || undef,
		value_textB => $page->field('physician_type') || undef,
		_debug => 0
	);

	my $commandPatientInactive = $command eq 'update' &&  $page->field('inactive_patient_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
		'Person_Attribute', $commandPatientInactive,
		parent_id => $personId || undef,
		item_id => $page->field('inactive_patient_item_id') || undef,
		parent_org_id => $page->session('org_internal_id') ||undef,
		item_name => 'Inactive Patient',
		value_type => 0,
		value_int => $page->field('inactivate_record') || undef,
		value_date => $page->field('inactivate_date') || undef,
		_debug => 0
	) if $member eq 'Patient';

	my $commandEthnicity = $command eq 'update' &&  $page->field('ethnicity_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
		'Person_Attribute', $commandEthnicity,
		parent_id => $page->field('person_id')  || undef,
		item_name => 'Other Ethnicity',
		item_id   =>  $page->field('ethnicity_item_id') || undef,
		value_type => App::Universal::ATTRTYPE_TEXT,
		value_text => $page->field('other_ethnicity')  || undef,
		_debug => 0
	);

	my $commandLanguage = $command eq 'update' &&  $page->field('language_item_id') eq '' ? 'add' : $command;
	$page->schemaAction(
		'Person_Attribute', $commandLanguage,
		parent_id => $page->field('person_id')  || undef,
		item_name => 'Other Language',
		item_id   =>  $page->field('language_item_id') || undef,
		value_type => App::Universal::ATTRTYPE_TEXT,
		value_text => $page->field('other_language')  || undef,
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
		my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
		my $orgIntId = $page->session('org_internal_id');
		$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');


		my $ssNum = $self->getField('ssndatemf')->{fields}->[0];
		my $firstName = $self->getField('person_id')->{fields}->[0];
		my $lastName = $self->getField('person_id')->{fields}->[2];
		my $personId = $page->field('person_id');

		my $personssn = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selssn', $orgIntId);
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
	my $orgId = $page->param('org_id') ? $page->param('org_id') : $page->session('org_id');
	my $orgIntId = $page->session('org_internal_id');

	# Disabled remove
	#$self->handlePostExecute($page, $command, $flags);
	#return '';

	$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $orgIntId, $orgId) if $page->param('org_id');

	$page->schemaAction(
			'Person', $command,
			person_id => $personId || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Person_Org_Category', $command,
			person_id => $personId || undef,
			category => $member || undef,
			org_internal_id => $orgIntId || undef,
			_debug => 0
		);

	$self->handlePostExecute($page, $command, $flags);

	return '';
}

1;
