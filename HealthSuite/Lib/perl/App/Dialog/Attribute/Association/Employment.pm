##############################################################################
package App::Dialog::Attribute::Association::Employment;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Association;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use Date::Manip;
use vars qw(@ISA);
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'Employment');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Organization::ID(caption =>'Employer ID', name => 'rel_id'),
		new CGI::Dialog::Field(caption => 'Employment Status',
									name => 'value_type',
									fKeyStmtMgr => $STMTMGR_PERSON,
									fKeyStmt => 'selEmpStatus',
									fKeyDisplayCol => 1,
									fKeyValueCol => 0),
		new CGI::Dialog::Field(caption => 'Occupation', name => 'rel_type'),
		new CGI::Dialog::Field(type => 'phone', caption => 'Phone Number', name => 'phone_number', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'date', caption => 'Begin Date', name => 'begin_date', defaultValue => ''),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "\u$self->{id} to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $itemId = $page->param('item_id');
	my $employment = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	$page->field('rel_type', $employment->{item_name});
	$page->field('value_type', $employment->{'value_type'});
	$page->field('phone_number', $employment->{'value_textb'});
	$page->field('rel_id', $employment->{'value_text'});
	$page->field('begin_date', $employment->{'value_date'});

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->param('person_id');
	my $occupation = $page->field('rel_type') eq '' ? 'Unknown' : $page->field('rel_type');
	$occupation = "\u$occupation";

	my $relId = $page->field('rel_id');

	$page->schemaAction(
			'Person_Attribute',	$command,
			item_id => $page->param('item_id') || undef,
			parent_id => $personId || undef,
			item_name => $occupation || undef,
			value_type => $page->field('value_type') || undef,
			value_text => $relId || undef,
			value_textB => $page->field('phone_number') || undef,
			value_date => $page->field('begin_date') || undef,
			_debug => 0
	);

	if($command eq 'add' && $relId ne '')
	{
		my $wrkCompValueType = App::Universal::ATTRTYPE_INSGRPWORKCOMP;
		if(my $orgHasWorkCompPlans = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAttributeByValueType', $relId, $wrkCompValueType))
		{
			foreach my $workCompPlan (@{$orgHasWorkCompPlans})
			{
				my $insType = App::Universal::CLAIMTYPE_WORKERSCOMP;
				my $insId = $workCompPlan->{value_text};
				my $insIntId = $workCompPlan->{value_int};
				my $patientHasPlan = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selPatientHasPlan', $insId, $personId, $insType);
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

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

use constant PANEDIALOG_EMPLOYMENT => 'Dialog/Employment';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/02/2000', 'RK',
		PANEDIALOG_EMPLOYMENT,
		'Added a new dialog for Employment Pane.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/07/2000', 'RK',
		PANEDIALOG_EMPLOYMENT,
		'Renamed the Package name from App::Dialog::Association::Employment to App::Dialog::Attribute::Association::Employment.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/28/2000', 'RK',
		PANEDIALOG_EMPLOYMENT,
		'Replaced fkeyxxx select in the dialogs with Sql statement from Statement Manager'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_EMPLOYMENT,
		'Removed Item Path from Item Name'],

);
1;