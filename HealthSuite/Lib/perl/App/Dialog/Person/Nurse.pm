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

use vars qw(@ISA %RESOURCE_MAP);
%RESOURCE_MAP = (
	'nurse' => {
		heading => '$Command Nurse',
		_arl => ['person_id'],
		_arl_modify => ['person_id'],
		_idSynonym => 'Nurse',
		},
	);
@ISA = qw(App::Dialog::Person);

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";

	$self->heading('$Command Nursing Staff');
	$self->addContent(
		new App::Dialog::Field::Person::ID::New(
			caption => 'Nurse ID',
			name => 'person_id',
			readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			postHtml => $postHtml,
		),
	);
	
	# Add in the default person fields
	$self->SUPER::initialize();
	
	$self->addContent(
		new CGI::Dialog::Field(
			type => 'hidden',
			name => 'nurse_title_item_id',
		),
		new CGI::Dialog::Subhead(
			heading => 'Certification',
			name => 'cert_for_nurse',
		),
		new CGI::Dialog::MultiField(
			name=> 'nurse_license',
			hints => "'Exp Date' and 'License Required' should be entered if there is a 'Nursing License'.",
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(
					caption => 'Nursing License',
					name => 'rn_number',
				),
				new CGI::Dialog::Field(
					caption => 'Exp Date',
					type=> 'date',
					name => 'rn_number_exp_date',
					defaultValue => '',
				),
				new CGI::Dialog::Field(
					caption => 'License Required',
					type => 'bool',
					name => 'check_license',
					style => 'check',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'licens_num_date1',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(
					caption => 'License Certification',
					type => 'select',
					selOptions => ';DEA;DPS;Medicaid;Medicare;UPIN;Tax ID;IRS;Board Certification;BCBS;Railroad Medicare;Champus;WC#;National Provider Identification',
					name => 'license1',
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				),
				new CGI::Dialog::Field(
					caption => 'Number',
					name => 'license_num1',
				),
				new CGI::Dialog::Field(
					caption => 'Exp Date',
					type=> 'date',
					name => 'license1_exp_date',
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'licens_num_date2',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(
					caption => 'License Certification',
					type => 'select',
					selOptions => ';DEA;DPS;Medicaid;Medicare;UPIN;Tax ID;IRS;Board Certification;BCBS;Railroad Medicare;Champus;WC#;National Provider Identification',
					name => 'license2',
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				),
				new CGI::Dialog::Field(
					caption => 'Number',
					name => 'license_num2',
				),
				new CGI::Dialog::Field(
					type=> 'date',
					caption => 'Exp Date',
					name => 'license2_exp_date',
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'licens_num_date3',
			invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(
					caption => 'License Certification',
					type => 'select',
					selOptions => ';DEA;DPS;Medicaid;Medicare;UPIN;Tax ID;IRS;Board Certification;BCBS;Railroad Medicare;Champus;WC#;National Provider Identification',
					name => 'license3',
					readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				),
				new CGI::Dialog::Field(
					caption => 'Number',
					name => 'license_num3',
				),
				new CGI::Dialog::Field(
					caption => 'Exp Date',
					type=> 'date',
					name => 'license3_exp_date',
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'empid_date',
			fields => [
				new CGI::Dialog::Field(
					caption => 'Employee ID',
					name => 'emp_id',
				),
				new CGI::Dialog::Field(
					caption => 'Exp Date',
					type=> 'date',
					name => 'emp_exp_date',
					futureOnly => 1,
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::Field(
			caption => 'Associated Physician Name',
			name => 'value_text',
			options => FLDFLAG_PREPENDBLANK,
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selAssocNurse',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			defaultValue => '',
		),
		new CGI::Dialog::Field(
			caption => 'Delete record?',
			name => 'delete_record',
			type => 'bool',
			style => 'check',
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
			readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
		),
	);

	$self->addFooter(
		new CGI::Dialog::Buttons(
			nextActions_add => [
				['View Nurse Summary', "/person/%field.person_id%/profile", 1],
				['Add Another Nurse', '/org/#session.org_id#/dlg-add-nurse'],
				['Go to Search', "/search/person/id/%field.person_id%"],
				['Return to Home', "/person/#session.user_id#/home"],
				['Go to Work List', "person/worklist"],
			],
			cancelUrl => $self->{cancelUrl} || undef,
		),

	);

	return $self;
}


sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('acct_chart_num', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('blood_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('ethnicity', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('party_name', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('relation', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('license_num_state', FLDFLAG_INVISIBLE, 1);

	my $personId = $page->param('person_id');

	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Nurse '$personId'?");
	}

	$self->getField('value_text')->{fKeyStmtBindPageParams} = $page->session('org_internal_id');

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}


sub customValidate
{
	my ($self, $page) = @_;

	my $licenseNum = $self->getField('nurse_license')->{fields}->[0];
	my $licenseDate = $self->getField('nurse_license')->{fields}->[1];
	my $licenseCheck = $self->getField('nurse_license')->{fields}->[2];

	my $licenseValid1 = $self->getField('licens_num_date1')->{fields}->[0];
	my $licenseValid2 = $self->getField('licens_num_date2')->{fields}->[0];
	my $licenseValid3 = $self->getField('licens_num_date3')->{fields}->[0];

	my $licenseName2 = $page->field('license2');
	my $licenseName3 = $page->field('license3');
	my $licenseName1 = $page->field('license1');
	if($page->field('rn_number') ne '' && ($page->field('check_license') eq '' || $page->field('rn_number_exp_date') eq ''))
	{
		$licenseNum->invalidate($page, "'Exp Date' and 'License Required' should be entered when 'Nursing License' is entered");
	}

	elsif($page->field('check_license') ne '' && ($page->field('rn_number') eq '' || $page->field('rn_number_exp_date') eq ''))
	{
		$licenseNum->invalidate($page, "'Nursing License' and 'Exp Date' should be entered when 'Exp Date' is entered");
	}

	elsif($page->field('rn_number_exp_date') ne '' && ($page->field('rn_number') eq '' || $page->field('check_license') eq ''))
	{
		$licenseNum->invalidate($page, "'Nursing License' and 'License Required' should be entered when 'Exp Date' is entered");
	}

	if ($licenseName2 eq $licenseName1 && $licenseName2 ne '')
	{
		$licenseValid2->invalidate($page, "The license '$licenseName2' cannot be added more than once");
	}

	if (($licenseName3 eq $licenseName1 || $licenseName3 eq $licenseName2) && $licenseName3 ne '')
	{
		$licenseValid3->invalidate($page, "The license '$licenseName3' cannot be added more than once");
	}

	if ($licenseName1 ne '' && $page->field('license_num1') eq '')
	{
		$licenseValid1->invalidate($page, "The 'License Number' should be entered when a 'License Certification' is selected");
	}

	if ($licenseName2 ne '' && $page->field('license_num2') eq '')
	{
		$licenseValid2->invalidate($page, "The 'License Number' should be entered when a 'License Certification' is selected");
	}

	if ($licenseName3 ne '' && $page->field('license_num3') eq '')
	{
		$licenseValid3->invalidate($page, "The 'License Number' should be entered when a 'License Certification' is selected");
	}

}


sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => $page->field('license1') || undef,
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('license_num1')  || undef,
			value_textB => $page->field('license1')  || undef,
			value_dateEnd => $page->field('license1_exp_date') || undef,
			_debug => 0
	) if $page->field('license1') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => $page->field('license2') || undef,
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('license_num2')  || undef,
			value_textB => $page->field('license3')  || undef,
			value_dateEnd => $page->field('license2_exp_date') || undef,
			_debug => 0
	) if $page->field('license2') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => $page->field('license3') || undef,
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('license_num3')  || undef,
			value_textB => $page->field('license3')  || undef,
			value_dateEnd => $page->field('license3_exp_date') || undef,
			_debug => 0
	) if $page->field('license3') ne '';

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->field('person_id'),
		item_name => 'Physician',
		value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
		value_text => $page->field('value_text') || undef,
		parent_org_id => $page->session('org_internal_id') || undef,
		_debug => 0
	);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Nursing/License',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('rn_number')  || undef,
			value_textB => 'Nursing/License',
			value_dateEnd => $page->field('rn_number_exp_date') || undef,
			value_int => $page->field('check_license')  || undef,
			_debug => 0
		) if $page->field('rn_number') ne '';

	$self->handleContactInfo($page, $command, $flags, 'nurse');

}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Nurse';

	$self->SUPER::execute_remove($page, $command, $flags, $member);

}


1;
