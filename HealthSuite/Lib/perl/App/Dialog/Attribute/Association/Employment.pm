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
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'assoc-employment' => {
		heading => '$Command Employment',
		_arl => ['person_id'] ,
		_arl_modify => ['item_id'],
		_idSynonym => [
			'attr-' .App::Universal::ATTRTYPE_EMPLOYEDFULL(),
			'attr-' .App::Universal::ATTRTYPE_EMPLOYEDPART(),
			'attr-' .App::Universal::ATTRTYPE_SELFEMPLOYED(),
			'attr-' .App::Universal::ATTRTYPE_RETIRED(),
			'attr-' .App::Universal::ATTRTYPE_STUDENTFULL(),
			'attr-' .App::Universal::ATTRTYPE_STUDENTPART(),
			'attr-' .App::Universal::ATTRTYPE_EMPLOYUNKNOWN(),
			'attr-' .App::Universal::ATTRTYPE_UNEMPLOYED(),
			],
		},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'Employment');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Organization::ID(
			caption =>'Employer ID',
			addType => 'employer',
			name => 'rel_id'
		),
		new CGI::Dialog::Field(
			caption => 'Employment Status',
			name => 'value_type',
			fKeyStmtMgr => $STMTMGR_PERSON,
			fKeyStmt => 'selEmpStatus',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0
		),
		new CGI::Dialog::Field(
			caption => 'Occupation',
			name => 'rel_type'
		),
		new CGI::Dialog::Field(
			type => 'phone',
			caption => 'Phone Number',
			name => 'phone_number'
		),
		new CGI::Dialog::MultiField(
			name => 'dates',
			fields => [
				new CGI::Dialog::Field(
					type => 'date',
					caption => 'Begin',
					name => 'begin_date',
					defaultValue => ''
				),
				new CGI::Dialog::Field(
					type => 'date',
					caption => 'End Date',
					name => 'end_date',
					defaultValue => ''
				),
			],
		),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "\u$self->{id} to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};
	$self->addFooter(
		new CGI::Dialog::Buttons(
			cancelUrl => $self->{cancelUrl} || undef
		),
	);

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
	$page->field('end_date', $employment->{'value_dateend'});
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->param('person_id');
	my $occupation = $page->field('rel_type') eq '' ? 'Unknown' : $page->field('rel_type');
	$occupation = "\u$occupation";

	my $relId = $page->field('rel_id');
	my $relIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $relId);

	$page->schemaAction(
		'Person_Attribute',	$command,
		item_id => $page->param('item_id') || undef,
		parent_id => $personId || undef,
		item_name => $occupation || undef,
		value_type => $page->field('value_type') || undef,
		value_int => $relIntId || undef,
		value_text => $relId || undef,
		value_textB => $page->field('phone_number') || undef,
		value_date => $page->field('begin_date') || undef,
		value_dateEnd => $page->field('end_date') || undef,
		_debug => 0,
	);

#	if($command eq 'add' && $relId ne '')
#	{
#		my $wrkCompValueType = App::Universal::ATTRTYPE_INSGRPWORKCOMP;
#		if(my $orgHasWorkCompPlans = $STMTMGR_ORG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAttributeByValueType', $relIntId, $wrkCompValueType))
#		{
#			foreach my $workCompPlan (@{$orgHasWorkCompPlans})
#			{
#				my $insType = App::Universal::CLAIMTYPE_WORKERSCOMP;
#				my $insId = $workCompPlan->{value_text};
#				my $insIntId = $workCompPlan->{value_int};
#				my $patientHasPlan = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_CACHE, 'selPatientHasPlan', $insId, $personId, $insType);
#				next if $patientHasPlan ne '';
#
#				my $workCompPlanInfo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceData', $insIntId);
#
#				my $remitType = $workCompPlanInfo->{remit_type};
#				$page->schemaAction(
#						'Insurance', 'add',
#						ins_id => $insId || undef,
#						parent_ins_id => $workCompPlan->{value_int} || undef,
#						owner_id => $personId || undef,
#						owner_org_id => $page->session('org_internal_id'),
#						ins_org_id => $workCompPlanInfo->{ins_org_id} || undef,
#						ins_type => defined $insType ? $insType : undef,
#						remit_type => defined $remitType ? $remitType : undef,
#						remit_payer_id => $workCompPlanInfo->{remit_payer_id} || undef,
#						remit_payer_name => $workCompPlanInfo->{remit_payer_name} || undef,
#						record_type => App::Universal::RECORDTYPE_PERSONALCOVERAGE || undef,
#						_debug => 0
#				);
#			}
#		}
#	}

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


1;
