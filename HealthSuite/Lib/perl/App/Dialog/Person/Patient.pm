##############################################################################
package App::Dialog::Person::Patient;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Insurance;
use App::Dialog::Field::Association;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;

#use App::Pane::Item::Property;

use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(App::Dialog::Person);

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";
	#$self->heading('$Command Patient');
	$self->addContent(
			new CGI::Dialog::Field(type => 'hidden', name => 'resp_self'),
			new App::Dialog::Field::Person::ID::New(caption => 'Patient/Person ID',
							name => 'person_id',
							types => ['Person'],
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						postHtml => $postHtml),
			);
	$self->SUPER::initialize();
	$self->addContent(
		new CGI::Dialog::Field(name => 'ethnicity',
				lookup => 'ethnicity',
				style => 'multicheck',
				caption => 'Ethnicity',
				hints => 'You may choose more than one ethnicity type.',
				invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE),

				#new CGI::Dialog::Field(caption => 'Preferred Day For Appointment', name => 'prefer_day', type => 'memo', invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE),

		#new CGI::Dialog::MultiField(caption =>'Responsible Party', name => 'responsible', hints => "Please provide either an existing Person ID or Select 'Self'",
		#		fields => [
		new App::Dialog::Field::Person::ID(caption => 'Responsible Party', name => 'party_name', types => ['Guarantor'], hints => "Please provide either an existing Person ID or leave the field 'Responsible Party' as blank and select 'Self' as 'Relationship'"),
		#				]),
		new App::Dialog::Field::Association(caption => 'Relationship To Responsible Party/Other Relationship Name', options => FLDFLAG_REQUIRED),
		#OCCUPATION
		new CGI::Dialog::Subhead(heading => 'Employment', name => 'occup_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new App::Dialog::Field::Organization::ID(caption =>'Employer ID', name => 'rel_id', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(caption => 'Employment Status',
									name => 'value_type',
									fKeyStmtMgr => $STMTMGR_PERSON,
									fKeyDisplayCol => 1,
									fKeyValueCol => 0,
									fKeyStmt => 'selEmpStatus',
									defaultValue => '226',
									invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(caption => 'Occupation', name => 'rel_type', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(type => 'phone', caption => 'Phone Number', name => 'phone_number', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		#new CGI::Dialog::Field(type => 'date', caption => 'Begin Date', name => 'begin_date', defaultValue => '', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Subhead(heading => 'Insurance', name => 'insur_heading', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		#new CGI::Dialog::Field(
		#						type => 'bool',
		#						name => 'add_insurance',
		#						caption => 'Add Personal Insurance Coverage?',
		#						style => 'check',
		#						invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::MultiField(caption =>'Ins CompanyID/Product Name/Plan Name', name => 'insplan',invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
				fields => [
							new App::Dialog::Field::Organization::ID(caption => 'Ins Company ID', name => 'ins_org_id',invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
							new App::Dialog::Field::Insurance::Product(caption => 'Product Name', name => 'product_name', findPopup => '/lookup/insurance/product_name', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
							new App::Dialog::Field::Insurance::Plan(caption => 'Plan Name', name => 'plan_name', findPopup => '/lookup/insurance/plan_name', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['Add Insurance Coverage', "/person/%field.person_id%/dlg-add-ins-coverage?_f_product_name=%field.product_name%&_f_ins_org_id=%field.ins_org_id%&_f_plan_name=%field.plan_name%", 1],
							['View Patient Summary', "/person/%field.person_id%/profile"],
							['Add Another Patient', '/org/#session.org_id#/dlg-add-patient'],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Home', "/person/#session.user_id#/home"],
							['Go to Work List', "person/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef)
	);

	$self->{activityLog} =
	{
		scope =>'person',
		key => "#field.person_id#",
		data => "Person '#field.person_id#' <a href='/person/#field.person_id#/profile'>#field.name_first# #field.name_last#</a>"
	};

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('nurse_title', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('job_code', FLDFLAG_INVISIBLE, 1);
	my $personId = $page->param('person_id');

	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1) if $command eq 'remove' || $command eq 'update';

	if ($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Patient '$personId'?");
	}

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $insOrg = $self->getField('insplan')->{fields}->[0];
	my $productName = $self->getField('insplan')->{fields}->[1];
	my $PlanName = $self->getField('insplan')->{fields}->[2];
	my $relationship = $self->getField('party_name');
	#my $relationSelf = $self->getField('responsible')->{fields}->[1];

	#my $addIns = $page->field('add_insurance');
	#if($addIns ==1 &&
	#	($page->field('ins_org_id') eq '' || $page->field('product_name') eq '' || $page->field('plan_name') eq ''))
	#{
	#	$insOrg->invalidate($page, " 'Ins Org ID', 'ProductName' and 'PlanName' cannot be blank if the Insurance Coverage is checked.");
	#}

	#if($page->field('party_name') && $page->field('resp_self'))
	#{
	#	$relationship->invalidate($page, "Cannot provide both '$relationship->{caption}' and '$relationSelf->{caption}'");
	#}
	#else
	#{
	#	unless($page->field('party_name') || $page->field('resp_self'))
	#	{
	#		$relationship->invalidate($page, "Please provide either '$relationship->{caption}' or '$relationSelf->{caption}'");
	#	}
	#}

	if ($page->field('party_name') && $page->field('rel_type') eq 'Self')
	{
		$relationship->invalidate($page, "'Relationship' should be other than 'Self' when the 'Responsible Party' is not blank");
	}

	elsif($page->field('party_name') eq ''  && $page->field('rel_type') ne 'Self')
	{
		$relationship->invalidate($page, "'Responsible Party' is required when the 'Relationship' is other than 'Self'");
	}
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	#first create registry
	my $member = 'Patient';
	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	#second create employment attribute
	my $personId = $page->field('person_id');
	my $relId = $page->field('rel_id');
	if($relId ne '')
	{
		my $occupation = $page->field('rel_type') eq '' ? 'Unknown' : $page->field('rel_type');
		$occupation = "\u$occupation";

		$page->schemaAction(
				'Person_Attribute', 'add',
				parent_id => $personId || undef,
				item_name => $occupation || undef,
				value_type => $page->field('value_type') || undef,
				value_text => $relId || undef,
				value_textB => $page->field('phone_number') || undef,
				#value_date => $page->field('begin_date') || undef,
				_debug => 0
		);

		#third check if employer has any workers comp plans and if so attach to person
		my $wrkCompValueType = App::Universal::ATTRTYPE_INSGRPWORKCOMP;
		if(my $orgHasWorkCompPlans = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAttributeByValueType', $relId, $wrkCompValueType))
		{
			foreach my $workCompPlan (@{$orgHasWorkCompPlans})
			{
				#CONSTANTS
				my $insType = App::Universal::CLAIMTYPE_WORKERSCOMP;
				my $insId = $workCompPlan->{value_text};
				my $insIntId = $workCompPlan->{value_int};
				my $patientHasPlan = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selPatientHasPlan', $insId, $personId, $insType);
				next if $patientHasPlan ne '';

				my $workCompPlanInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);

				my $remitType = $workCompPlanInfo->{remit_type};

				$page->schemaAction(
					'Insurance', 'add',
					ins_id => $insId || undef,
					parent_ins_id => $workCompPlan->{value_int} || undef,
					owner_id => $personId || undef,
					ins_org_id => $workCompPlanInfo->{ins_org_id} || undef,
					ins_type => defined $insType ? $insType : undef,
					remit_type => defined $remitType ? $remitType : undef,
					remit_payer_id => $workCompPlanInfo->{remit_payer_id} || undef,
					remit_payer_name => $workCompPlanInfo->{remit_payer_name} || undef,
					record_type => App::Universal::RECORDTYPE_PERSONALCOVERAGE || undef,
					_debug => 0
				);
			}
		}
	}

	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $personId || undef,
		item_id => $page->field('acct_item_id') || undef,
		parent_org_id => $page->session('org_id') ||undef,
		item_name => 'Patient/Account Number',
		value_type => 0,
		value_text => $page->field('acct_number') || undef,
		_debug => 0
		) if $page->field('acct_number') ne '';

	$page->schemaAction(
		'Person_Attribute', $command,
		parent_id => $personId || undef,
		item_id => $page->field('chart_item_id') || undef,
		parent_org_id => $page->session('org_id') ||undef,
		item_name => 'Patient/Chart Number',
		value_type => 0,
		value_text => $page->field('chart_number') || undef,
		_debug => 0
		) if $page->field('chart_number') ne '';

	$self->handleContactInfo($page, $command, $flags, 'Patient');
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Patient';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Patient';

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

use constant PATIENT_DIALOG => 'Dialog/Patient';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'RK',
		PATIENT_DIALOG,
		'Made a validation for the field ssn not to add an existing ssn while creating a new patient record. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/16/2000', 'RK',
		PATIENT_DIALOG,
		'Replaced fkeyxxx select in the dialog with Sql statement from Statement Manager.'],
);

1;
