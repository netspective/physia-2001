##############################################################################
package App::Dialog::Report::Org::General::Scheduling::PatientActivity;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Report::Scheduling;
use App::Statements::Search::Appointment;


use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'patientActivity', heading => 'Patient Activity');

	$self->addContent(

		new CGI::Dialog::Field::Duration(name => 'report',
			caption => 'Report Dates',
			options => FLDFLAG_REQUIRED
		),
		#new App::Dialog::Field::Organization::ID(name => 'facility_id',
		#	caption => 'Facility ID',
		#	#types => ['Facility'],
		#	options => FLDFLAG_REQUIRED
		#),
		new App::Dialog::Field::OrgType(
			caption => 'Facility',
			name => 'facility_id',
			options => FLDFLAG_PREPENDBLANK,
			types => qq{'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'},
		),		
		new App::Dialog::Field::Person::ID(caption =>'Physican ID', 
						   name => 'person_id',types => ['Physician'] ),
		
							
	);

	$self->addFooter(new CGI::Dialog::Buttons);
	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
	$page->field('resource_id', $page->session('user_id'));
	$page->field('facility_id', $page->session('org_id'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $resource_id = $page->field('resource_id');
	my $facility_id = $page->field('facility_id');
	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');
	my $person_id     = $page->field('person_id');
	my $orgInternalId =$page->session('org_internal_id');
	my $internalFacilityId =$page->field('facility_id');
	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');
	my $html = qq{
	<table cellpadding=10>
		<tr align=center valign=top>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Appointments</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_appointments_byStatus',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Patients Seen By Physician</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsSeen',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Patients Seen By Patient Type</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsSeen_byPatientType',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Appointments By Procedure Code</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsCPT',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Appointments By Product Type</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsProduct',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>		
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Missing Encounters</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_missingEncounter',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset ]) ]}
		</td>				
		</tr>									
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Date Appointments Entered</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_dateEntered',
				[$internalFacilityId, $startDate, $endDate,$orgInternalId,$gmtDayOffset]) ]}
		</td>				
		
	</table>
	};

	return $html;
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_physician
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $physician   = $page->param('physician');
	my $person_id     = $page->field('person_id');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	
	$page->addContent("<b>Patients Seen by $physician</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailPatientsSeenByPhysician', [$physician, $internalFacilityId, $startDate, $endDate,$orgInternalId])
	);
}

sub prepare_detail_CPT
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $cpt   = $page->param('CPT');
	my $person_id     = $page->field('person_id');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');

	$page->addContent("<b>$cpt Procedures</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailPatientsCPT', [$cpt, $internalFacilityId, $startDate, $endDate,$orgInternalId])
	);

}

sub prepare_detail_product
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $product   = $page->param('product');
	my $person_id     = $page->field('person_id');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	
	$page->addContent("<b>$product</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailPatientsProduct', [$product, $internalFacilityId, $startDate, $endDate,$orgInternalId])
	);

}

sub prepare_detail_missing_encounter
{
	my ($self, $page) = @_;
	my $encounterDate = $page->param('encounter');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	$page->addContent("<b>Missing Encounter ($encounterDate)</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailMissingEncounter', [$internalFacilityId, $encounterDate,$orgInternalId])
	);
}


sub prepare_detail_date_entered
{
	my ($self, $page) = @_;
	my $enteredDate = $page->param('entered');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');	
	$page->addContent("<b>Data Appointment Entered ($enteredDate)</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailDateEntered', [$internalFacilityId, $enteredDate,$orgInternalId,$gmtDayOffset])
	);
}

sub prepare_detail_appointments
{
	my ($self, $page) = @_;
	my $facility_id  = $page->param('_f_facility_id');
	my $startDate    = $page->param('_f_report_begin_date');
	my $endDate      = $page->param('_f_report_end_date') ;
	my $event_status = $page->param('event_status');
	my $caption      = $page->param('caption');
	my $person_id     = $page->field('person_id');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	$page->addContent("<b>'$caption' Appointments</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_DetailAppointmentStatus',
			[$event_status,$internalFacilityId, $startDate, $endDate,$orgInternalId],
		),
	);
}

sub prepare_detail_patient_type
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $patient_type_id  = $page->param('patient_type_id');
	my $patient_type_caption = $page->param('patient_type_caption');
	my $person_id     = $page->field('person_id');
	my $internalFacilityId = $page->param('_f_facility_id');
	my $orgInternalId = $page->session('org_internal_id');
	$page->addContent("<b>'$patient_type_caption' Appointments</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detailPatientsSeenByPatientType',
			[$patient_type_id,$internalFacilityId, $startDate, $endDate,$orgInternalId])
	);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
