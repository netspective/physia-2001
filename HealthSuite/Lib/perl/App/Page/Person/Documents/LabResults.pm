##############################################################################
package App::Page::Person::Documents::LabResults;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::Documents);

use CGI::Dialog::DataNavigator;
use SQL::GenerateQuery;
use App::Configuration;
use Data::Publish;

use vars qw(%RESOURCE_MAP $QDL %PUB_OBS %PUB_OBS_RESULTS %PUB_OBS_RESULTS_HIST);
%RESOURCE_MAP = (
	'person/documents/labs' => {
		_idSynonym => ['_default'],
		_tabCaption => 'Lab Results',
		},
	);


$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'Observation.qdl');


########################################################
# Drill Level 0 - Observations
########################################################


%PUB_OBS = (
	name => 'obs',
	columnDefn => [
		{head => '#', dataFmt => '#{auto_row_number}#',},
		{head => 'Status', dataFmt => '#{obs_status_caption}#',},
		{head => 'Patient ID', dataFmt => '<a href="/person/#{observee_id}#/chart">#{observee_id}#</a>',},
		{head => 'Patient Name', dataFmt => '#{observee_simple_name}#',},
		{head => 'Physician', dataFmt => '<a href="/person/#{observer_id}#/profile" onClick="window.event.cancelBubble = true">#{observer_id}#</a>',},
		{head => 'Test Name', dataFmt => '#{battery_text}#',},
		{head => 'Collected On', colIdx => '#{specimen_collection_stamp}#', dformat => 'stamp',},
		{head => 'Reported On', colIdx => '#{obs_report_stamp}#', dformat => 'stamp',},
	],
	dnQuery => \&obsQuery,
	dnDrillDown => \%PUB_OBS_RESULTS,
	dnARLParams => ['observation_id'],
	dnAncestorFmt => 'All Lab Results',
);


sub obsQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('observer_org_int_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('observee_id', 'is', $self->param('person_id'));
	my $cond3 = $sqlGen->AND($cond1, $cond2);
	$cond3->outColumns(
		'observation_id',
		'obs_status_caption',
		'observee_id',
		'observee_simple_name',
		'observer_id',
		'battery_text',
		'specimen_collection_stamp',
		'obs_report_stamp',
	);
	return $cond3;
}


########################################################
# Drill Level 1 - Observation Results
########################################################


%PUB_OBS_RESULTS = (
	name => 'obs_results',
	columnDefn => [
		{head => 'Seq.', dataFmt => '#{result_sequence}#',},
		{head => 'Name', dataFmt => '#{result_obs_text}#',},
		{head => 'Result', dataFmt => '#{result_value_text}# #{result_units_text}#',},
		{head => 'Normal Range', dataFmt => '#{result_normal_range}#',},
		{head => 'Flags', dataFmt => '#{result_abnormal_flags}#',},
		{head => 'Status', dataFmt => '#{result_order_status}#',},
		{head => 'Notes', dataFmt => '#{result_notes}#',},
	],
	dnQuery => \&obsResultsQuery,
	dnAncestorFmt => \&obsResultsAncestorFmt,
	dnARLParams => ['result_obs_text'],
	dnDrillDown => \%PUB_OBS_RESULTS_HIST,
);


sub obsResultsQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('observer_org_int_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('observation_id', 'is', $self->param('dn.obs.observation_id'));
	my $cond3 = $sqlGen->AND($cond1, $cond2);
	$cond3->outColumns(
		'result_sequence',
		'result_obs_text',
		'result_value_text',
		'result_units_text',
		'result_normal_range',
		'result_abnormal_flags',
		'result_order_status',
		'result_notes',
	);
	return $cond3;
}


sub obsResultsAncestorFmt
{
	my $self = shift;
	my ($dialog) = @_;

	my $date = $self->param('dn.obs.specimen_collection_stamp');
	$date = Data::Publish::fmt_stamp($self, $date);
	return "#param.dn.obs.observee_simple_name# on $date";
}


########################################################
# Drill Level 2 - Observation Results History
########################################################


%PUB_OBS_RESULTS_HIST = (
	name => 'obs_results_hist',
	columnDefn => [
		{head => 'Collected On', colIdx => '#{specimen_collection_stamp}#', dformat => 'stamp',},
		{head => 'Physician', dataFmt => '#{observer_id}#',},
		{head => 'Result', dataFmt => '#{result_value_text}# #{result_units_text}#',},
		{head => 'Normal Range', dataFmt => '#{result_normal_range}#',},
		{head => 'Flags', dataFmt => '#{result_abnormal_flags}#',},
		{head => 'Status', dataFmt => '#{result_order_status}#',},
		{head => 'Notes', dataFmt => '#{result_notes}#',},
	],
	dnQuery => \&obsResultsHistQuery,
	dnAncestorFmt => '"#param.dn.obs_results.result_obs_text#" Test History',
);


sub obsResultsHistQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('observer_org_int_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('observee_id', 'is', $self->param('dn.obs.observee_id'));
	my $cond3 = $sqlGen->WHERE('result_obs_text', 'is', $self->param('dn.obs_results.result_obs_text'));
	my $cond4 = $sqlGen->AND($cond1, $cond2, $cond3);
	$cond4->outColumns(
		'specimen_collection_stamp',
		'observer_id',
		'result_value_text',
		'result_abnormal_flags',
		'result_order_status',
		'result_normal_range',
		'result_units_text',
		'result_notes',
	);
	return $cond4;
}



########################################################
# Handle the page display
########################################################

sub prepare_view
{
	my $self = shift;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_OBS, topHtml => $tabsHtml, page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent($dlgHtml);
}


1;
