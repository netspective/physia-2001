##############################################################################
package App::Page::Person::Documents::LabOrder;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::Documents);
use Date::Manip;
use Date::Calc qw(:all);
use CGI::Dialog::DataNavigator;
use SQL::GenerateQuery;
use App::Configuration;
use CGI::ImageManager;

use Data::Publish;

use vars qw(%RESOURCE_MAP $QDL %PUB_OBS %PUB_OBS_RESULTS %PUB_OBS_RESULTS_HIST);
%RESOURCE_MAP = (
	'person/documents/lab-orders' => {
		#_idSynonym => ['_default'],
		_tabCaption => 'Lab Orders',
		},
	);


$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'LabOrder.qdl');


########################################################
# Drill Level 0 - Observations
########################################################


%PUB_OBS = (
	name => 'obs',
	columnDefn => [
		{head => '#', dataFmt => '#{auto_row_number}#',},
		{head => 'Lab Company', colIdx => '#{lab_name}#' },		
		{head => 'Lab Order ID', colIdx => '#{lab_order_id}#',,url=>"/person/#{person_id}#/dlg-update-lab-order/#{lab_order_id}#"},
		{head => 'Lab Order Status', colIdx => '#{status}#',},		
		{head => 'Lab Order Date/Time', colIdx => '#{date_order}#', dformat => 'stamp',},		
		{head => 'Patient ID', dataFmt => '<a href="/person/#{person_id}#/chart">#{person_id}#</a>',},
		{head => 'Patient Name', colIdx => '#{patient_name}#',},
		{head => 'Provider', dataFmt => '<a href="/person/#{provider_id}#/profile" onClick="window.event.cancelBubble = true">#{provider_id}#</a>',},
		{head => 'Action', 
			dataFmt => qq{
				<a title="Print" href="javascript:alert('Print Not Implemented')">$IMAGETAGS{'icons/print'}</a>
				<a title="Fax" href="javascript:alert('Fax Not Implemented')">$IMAGETAGS{'widgets/mail/fax'}</a>
				<a title="E-Mail" href="javascript:alert('E-Mail Not Implemented')">$IMAGETAGS{'widgets/mail/forward'}</a>
			},},		
	],
	dnQuery => \&obsQuery,
	dnDrillDown => \%PUB_OBS_RESULTS,
	dnARLParams => ['lab_order_id'],
	dnAncestorFmt => 'All Lab Orders',
);


sub obsQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);
	my $date=  UnixDate('tomorrow','%d-%b-%y');
	my $date1= UnixDate('yesterday','%d-%b-%y');	
	my $cond1 = $sqlGen->WHERE('org_internal_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('date_order', 'between',$date1,$date);		
	my $cond2C = $sqlGen->WHERE('status', 'is','Pending');			
	my $cond3;
	if($self->param('person_id') eq $self->session('person_id'))
	{
		my $temp = $sqlGen->OR($cond2C,$cond2);
		$cond3 = $sqlGen->AND($cond1, $temp);
		
	}
	else
	{
		my $cond2 = $sqlGen->WHERE('person_id', 'is',$self->param('person_id'));				
		$cond3 = $sqlGen->AND($cond1,$cond2);
	}
	$cond3->outColumns(
		'person_id',
		'patient_name',
		'provider_id',
		'lab_name',
		'lab_order_id',
		'date_order',
		'status',
	);		
	#$sqlGen->orderBy('person_id');
	$cond3->orderBy({id => 'lab_order_id', order => 'Descending'});
	return $cond3;
}


########################################################
# Drill Level 1 - Observation Results
########################################################


%PUB_OBS_RESULTS = (
	name => 'obs_results',
	columnDefn => [
		{head => 'Lab Test ID.', colIdx => '#{lab_test_id}#',},
		{head => 'Test Name', colIdx => '#{lab_test_name}#',},
		{head => 'Test Type', colIdx => '#{test_type}#',},
		{head => 'Test Selection', colIdx =>  '#{selection}#',},
	],
	dnQuery => \&obsResultsQuery,
	dnAncestorFmt => "Tests In Lab Order : #param.dn.obs.lab_order_id#" ,
	dnARLParams => ['lab_test_entry_id','lab_test_name'],
	dnDrillDown => \%PUB_OBS_RESULTS_HIST,
);


sub obsResultsQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('org_internal_id', 'is', $self->session('org_internal_id'));
	my $cond2 = $sqlGen->WHERE('lab_order_id', 'is', $self->param('dn.obs.lab_order_id'));
	my $cond4 = $sqlGen->WHERE('lab_parent_id', 'isnotdefined');
	my $cond3 = $sqlGen->AND($cond1, $cond2,$cond4);
	$cond3->outColumns('lab_test_id',
			   'lab_test_name',
			   'test_entry_id',
			   'test_type',
			   'selection',		
			   'lab_test_entry_id',
			   #'lab_panel_name',

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
		{head => 'Lab Test ID', dataFmt => '#{lab_panel_name}#',},
		{head => 'Lab Test Name', dataFmt => '#{lab_panel_name}#',},
		{head => 'Price', colIdx =>'#{lab_panel_price}#', dformat=>'currency'},
	],
	dnQuery => \&obsResultsHistQuery,
	dnAncestorFmt => "Tests In Panel : #param.dn.obs_results.lab_test_name#" ,

);


sub obsResultsHistQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	#my $cond1 = $sqlGen->WHERE('org_internal_id', 'is', $self->session('org_internal_id'));
	my $cond3 = $sqlGen->WHERE('lab_panel_parent_id', 'is', $self->param('dn.obs_results.lab_test_entry_id'));
	my $cond4 = $sqlGen->AND($cond3);
	$cond4->outColumns(
		'lab_panel_id',
		'lab_panel_name',
		#'test_entry_id',
		'lab_panel_price'
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
