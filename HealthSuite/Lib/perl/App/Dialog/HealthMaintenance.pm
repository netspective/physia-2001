##############################################################################
package App::Dialog::HealthMaintenance;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Organization;
use DBI::StatementManager;
use App::Statements::Org;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'health-rule' => {
			heading => '$Command Health Maintenance Rule', 
			_arl => ['rule_id']
		},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'healthmaintenance', heading => '$Command Health Maintenance Rule');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption =>'Rule ID', name => 'rule_id', options => FLDFLAG_REQUIRED, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),		
		new CGI::Dialog::MultiField(caption =>'Start Age/End Age/Age Metric',
					fields => [
						new CGI::Dialog::Field(name => 'start_age', defaultValue => '', size => 3, maxLength => 3),
						new CGI::Dialog::Field(name => 'end_age', defaultValue => '', size => 3, maxLength => 3),
						new CGI::Dialog::Field(caption => 'Age Metric',							
							name => 'age_metric',
							fKeyStmtMgr => $STMTMGR_ORG,
							fKeyStmt => 'selTimeMetric',							
							fKeyDisplayCol => 1,
							fKeyValueCol => 0),
					]),
		new CGI::Dialog::Field(type=> 'enum', enum => 'Gender', caption => 'Gender', name => 'gender', options => FLDFLAG_REQUIRED, defaultValue => '3'),
		new CGI::Dialog::Field(caption =>'Measure', name => 'measure'),
		new CGI::Dialog::MultiField(caption =>'Periodicity/Peroidicity Metric',
					fields => [
						new CGI::Dialog::Field(caption => 'Periodicity', name => 'periodicity', defaultValue => ''),
						new CGI::Dialog::Field(caption => 'Periodicity Metric',
							name => 'periodicity_metric',
							fKeyStmtMgr => $STMTMGR_ORG,
							fKeyStmt => 'selTimeMetric',							
							fKeyDisplayCol => 1,
							fKeyValueCol => 0),
					]),		
		new App::Dialog::Field::Diagnoses(caption => 'Diagnoses', name => 'diagnoses', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'Directions', name => 'directions'),
		new CGI::Dialog::Field(caption => 'Source', name => 'source'),
		new CGI::Dialog::MultiField(caption =>'Begin/End Source Date',
					fields => [
						new CGI::Dialog::Field(name => 'src_begin_date', type => 'date', defaultValue => ''),
							new CGI::Dialog::Field(name => 'src_end_date', type => 'date', futureOnly => 0),								
					]),
	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'Hlth_Maint_Rule ',
		key => "#param.org_id#",
		data => "#field.rule_id# to <a href='/org/#param.org_id#/profile'>#param.org_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return () if $command eq 'add';
	my $ruleId = $page->param('rule_id');
	return $STMTMGR_ORG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selHealthRule',$ruleId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $orgId = $page->param('org_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);

	$page->schemaAction(
		'Hlth_Maint_Rule',	$command,
		org_internal_id => $orgIntId,
		rule_id => $page->field('rule_id') || undef,
		gender => $page->field('gender') || undef,
		start_age => $page->field('start_age') || undef,
		end_age => $page->field('end_age') || undef,
		age_metric => $page->field('age_metric') || undef,
		measure => $page->field('measure') || undef,
		periodicity => $page->field('periodicity') || undef,
		periodicity_metric => $page->field('periodicity_metric') || undef,
		diagnoses => $page->field('diagnoses') || undef,
		directions => $page->field('directions') || undef,
		source => $page->field('source') || undef,
		src_begin_date => $page->field('src_begin_date') || undef,
		src_end_date => $page->field('src_end_date') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;