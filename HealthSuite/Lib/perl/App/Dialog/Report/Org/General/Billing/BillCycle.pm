##############################################################################
package App::Dialog::Report::Org::General::Billing::BillCycle;
##############################################################################

use strict;
use Carp;
use Date::Calc qw(Delta_Days);
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;
use DBI::StatementManager;

use App::Statements::Component::Invoice;
use App::Statements::Org;
use App::Statements::Report::Accounting;
use Data::Publish;
use Data::TextPublish;
use App::Configuration;
use App::Device;
use App::Statements::Device;
use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'rpt-bill-cycle', heading => 'Billing Cycle Report');

	$self->addContent(
			#new CGI::Dialog::Field(type => 'select', selOptions => ';First Week:1;Second Week:2;Third Week:3;Fourth Week:4', caption => 'Statement Cycle', name => 'period'),
			new CGI::Dialog::Field(name => 'bill_cycle', maxValue=>31,minValue=>1, size => 2, caption => 'Day of Month'),			
			new App::Dialog::Field::Person::ID(caption =>'Physican ID', name => 'person_id', 
			types => ['Physician'],),			
			new App::Dialog::Field::OrgType(
							caption => 'Service Facility',
							name => 'service_facility_id',
							options => FLDFLAG_PREPENDBLANK,
							types => "'PRACTICE', 'CLINIC','FACILITY/SITE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'HOSPITAL', 'THERAPEUTIC SERVICES'"),
			);
	$self->addFooter(new CGI::Dialog::Buttons);

	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}


sub prepare_detail_cycle
{
	my ($self, $page) = @_;
	my $billCycle = $page->field('bill_cycle');
	my $facility = $page->field('service_facility_id');
	my $doc = $page->field('person_id');
	my $cycleDate=$page->param('cycle_date');
	my $cycleDay=$page->param('cycle_day');	
	my $html;
	my $pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
		[

			{ colIdx => 0, head => 'Patient ID', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 1, head => 'Patient Name' ,hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 3, head => 'Statement Status',},									
			{ colIdx => 2,dformat=>'currency',summarize=>'sum', head => 'Statement Amount',},			
		],
	};	
	
	my $cycleData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selBillCycleData',
				 $cycleDate,$facility,$doc,$page->session('org_internal_id'));
	my @data = ();	
	foreach (@$cycleData)
	{
		my @rowData = (
		$_->{patient_id},
		$_->{simple_name},
		$_->{amount_due},
		$_->{status}||'UNK');
		push(@data, \@rowData);	
	};
	
	my $html = '<b style="font-family:Helvetica; font-size:12pt">(Cycle Date '. $cycleDate . ' ) </b><br><br>' . createHtmlFromData($page, 0, \@data,$pub);	
	$page->addContent($html);	
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $billCycle = $page->field('bill_cycle');
	my $facility = $page->field('service_facility_id');
	my $doc = $page->field('person_id');
	my $html;
	my $pub =
	{
		reportTitle => $self->heading(),
		columnDefn =>
		[

			{ colIdx => 0, summarize=>'count',head => 'Bill Cycle', hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 1, summarize=>'sum',head => 'Number Patients',hAlign=>'left', tAlign=>'left',dAlign => 'left',},
			{ colIdx => 2, summarize=>'sum',head => '# Bills', hAlign=>'left', tAlign=>'left',dAlign => 'left',},			
			{ colIdx => 3, summarize=>'sum',head => 'Bill Amount',dformat=>'currency'},						
			{ colIdx => 4,
			url => qq{javascript:doActionPopup('#hrefSelfPopup#&detail=cycle&cycle_date=#4#&cycle_day=#0#',null,'width=900,height=600,scrollbars,resizable')}
			,head => 'Bill Date',hAlign=>'left', tAlign=>'left',dAlign => 'left',},						
		],
	};

	my $patientCount = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selPatientInBillCycle',
			$billCycle,$page->session('org_internal_id'));
	my @data = ();			
	foreach (@$patientCount)
	{
		#my $checkCycle = length($_->{cycle})==1 ? "0$_->{cycle}" : $_->{cycle};
		my $checkCycle=$_->{cycle};
		#pull statement sent for this billing cycle
		my $cycleData = $STMTMGR_REPORT_ACCOUNTING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selFourBillCycleData',
				 $checkCycle,$facility,$doc,$page->session('org_internal_id'));
				 
		#If cycle Data is empty then place one element in array so we get the bill cycle data			
		push (@{$cycleData},{empty=>1}) unless @$cycleData;
		my $size = scalar(@$cycleData);
	 	for my $cycle (@$cycleData)
		{
			my @rowData = (
			$_->{cycle},
			$_->{tlt_patient},
			$cycle->{stmt_count}||0,
			$cycle->{amount}||0,
			$cycle->{cycle_date}||'N/A');
			push(@data, \@rowData);
		}
	};
	return createHtmlFromData($page, 0, \@data, $pub);
}



# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;