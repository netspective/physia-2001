##############################################################################
package App::Component::WorkList::Verify;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use Date::Calc qw(:all);
use Date::Manip;
use DBI::StatementManager;
use App::Statements::Component::Scheduling;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Statements::Org;
use App::Schedule::Utilities;
use Data::Publish;
use Exporter;
use CGI::ImageManager;

use enum qw(BITMASK:VERIFYFLAG_ APPOINTMENT_COMPLETE APPOINTMENT_PARTIAL
	INSURANCE_COMPLETE INSURANCE_PARTIAL MEDICAL PERSONAL);

use vars qw(%RESOURCE_MAP @EXPORT
	@ITEM_TYPES
	%PATIENT_URLS
	%PHYSICIAN_URLS
	%ORG_URLS
	%APPT_URLS
	$patientDefault
	$physicianDefault
	$orgDefault
	$apptDefault
);

use base qw(CGI::Component Exporter);

my $arlPrefix = '/worklist/insverify';

@ITEM_TYPES = ('patient', 'physician', 'org', 'appt');

%PATIENT_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Patient Profile'},
	'View Chart' => {arl => '/person/itemValue/chart', title => 'View Patient Chart'},
	'View Account' => {arl => '/person/itemValue/account', title => 'View Patient Account'},
	'Make Appointment' => {arl => "$arlPrefix/dlg-add-appointment/itemValue", title => 'Make Appointment'},
);

%PHYSICIAN_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Physician Profile'},
	'View Schedule' => {arl => '/schedule/apptcol/itemValue', title => 'View Physician Schedule'},
	'Add Template' => {arl => "$arlPrefix/dlg-add-template/itemValue", title => 'Add Schedule Template'},
);

%ORG_URLS = (
	'View Profile' => {arl => '/org/itemValue/profile', title => 'View Org Profile'},
	'View Fee Schedules' => {arl => '/org/itemValue/catalog', title => 'View Org Fee Schedules'},
);

%APPT_URLS = (
	'Reschedule' => {arl => "$arlPrefix/dlg-reschedule-appointment/itemValue", title => 'Reschedule Appointment'},
	'Cancel' => {arl => "$arlPrefix/dlg-cancel-appointment/itemValue", title => 'Cancel Appointment'},
	'No-Show' => {arl => "$arlPrefix/dlg-noshow-appointment/itemValue", title => 'No-Show Appointment'},
	'Update' => {arl => "$arlPrefix/dlg-update-appointment/itemValue", title => 'Update Appointment'},
);

$patientDefault = 'View Profile';
$physicianDefault = 'View Profile';
$orgDefault = 'View Profile';
$apptDefault = 'Update';

@EXPORT = qw(%PATIENT_URLS %PHYSICIAN_URLS %ORG_URLS %APPT_URLS @ITEM_TYPES);

%RESOURCE_MAP = (
	'worklist-verify' => {
		_class => new App::Component::WorkList::Verify(),
	},
);

my $PUBLISH_DEFN =
{
	columnDefn =>
	[
		{colIdx => 0, head => '', dAlign => 'center'},
		{colIdx => 1, head => 'Patient / Physician (Facility)'},
		{colIdx => 2, head => 'Appointment', dAlign => 'center'},
		{colIdx => 3, head => 'Verify', dAlign => 'center'},
	],
};

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};

	$layoutDefn->{frame}->{heading} = " ";
	$layoutDefn->{style} = 'panel.transparent';

	for my $itemType (@ITEM_TYPES)
	{
		my $name = $itemType . 'OnSelect';
		unless ($page->session($name))
		{
			my $itemName = 'Worklist/' . "\u$itemType" . '/OnSelect';
			my $preference = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
				'selSchedulePreferences', $page->session('user_id'), $itemName);

			my $defaultVar = $itemType. 'Default';
			$page->session($name, $preference->{resource_id} || eval "\$$defaultVar");
			#$page->addDebugStmt("Read Preference for $name", $page->session($name));
		}
	}
}

sub getHtml
{
	my ($self, $page) = @_;

	$self->initialize($page);
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, $self->getComponentHtml($page));
}

sub getComponentHtml
{
	my ($self, $page) = @_;

	my $selectedDate = $page->param('_seldate') || 'today';
	$selectedDate = 'today' unless ParseDate($selectedDate);
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	my $facility_id = $page->session('org_internal_id');
	my $user_id = $page->session('user_id');

	my ($time1, $time2);

	if ($page->session('showTimeSelect'))
	{
		$time1 = $page->session('time1') || '12:00 AM';
		$time2 = $page->session('time2') || '11:59 PM';
	}
	else
	{
		$time1 = $page->session('time1') || 30;
		$time2 = $page->session('time2') || 120;
	}

	my @start_Date = Decode_Date_US($fmtDate);
	my @end_Date   = Add_Delta_Days (@start_Date, 1);
	my $startDate = sprintf("%02d/%02d/%04d", $start_Date[1],$start_Date[2],$start_Date[0]);
	my $endDate   = sprintf("%02d/%02d/%04d", $end_Date[1],$end_Date[2],$end_Date[0]);

	my $startTime = $startDate . " $time1";
	my $endTime   = $startDate . " $time2";
	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');

	my $orgInternalId = $page->session('org_internal_id');
	my $appts;
	if ($page->param('Today'))
	{
		if ($page->session('showTimeSelect') == 0)
		{
			my $standardTimeOffset = 0;
			$standardTimeOffset = 1/24 if $page->session('TZ') ne $page->session('DAYLIGHT_TZ');
			
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today', $gmtDayOffset,	$time1, $time2, $user_id, $orgInternalId,
				$standardTimeOffset);
		} else
		{
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today_byTime', $gmtDayOffset, $startTime, $endTime, 
				$user_id, $orgInternalId);
		}
	}
	else
	{
		$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_events_worklist_not_today', $gmtDayOffset, $startTime, $endTime, $user_id, 
			$orgInternalId);
	}

	my @data = ();
	my $html = qq{
		<style>
			a.today {text-decoration:none; font-family:Verdana; font-size:8pt}
			strong {font-family:Tahoma; font-size:8pt; font-weight:normal}
		</style>
	};

	my $oldEventId = 0;
	foreach (@$appts)
	{
		my $flags = $_->{flags};
		next if $flags & VERIFYFLAG_INSURANCE_COMPLETE;
		
		my ($apptMinutes, $checkinMinutes, $checkoutMinutes, $waitMinutes, $visitMinutes);
		$apptMinutes = stamp2minutes($_->{appointment_time});

		next if $oldEventId == $_->{event_id};

		my $alertExists = $STMTMGR_COMPONENT_SCHEDULING->recordExists($page, STMTMGRFLAG_NONE,
			'sel_alerts', $_->{patient_id});

		my $alertHtml;
		if ($alertExists) {
			$alertHtml = qq{<a href="javascript:doActionPopup('/popup/alerts/$_->{patient_id}')"
				class=today title="View $_->{patient_id} Alert(s)"><b>Alert<b></a>
			};
		}

		my $patientHref = $PATIENT_URLS{$page->session('patientOnSelect')}->{arl};
		$patientHref =~ s/itemValue/$_->{patient_id}/;
		my $physicianHref = $PHYSICIAN_URLS{$page->session('physicianOnSelect')}->{arl};
		$physicianHref =~ s/itemValue/$_->{physician}/;
		my $orgHref = $ORG_URLS{$page->session('orgOnSelect')}->{arl};
		$orgHref =~ s/itemValue/$_->{facility_name}/;
		my $apptHref = $APPT_URLS{$page->session('apptOnSelect')}->{arl};
		$apptHref =~ s/itemValue/$_->{event_id}/;

		my $patientTitle = $PATIENT_URLS{$page->session('patientOnSelect')}->{title};
		$patientTitle =~ s/Patient/$_->{patient_id}/;
		my $physicianTitle = $PHYSICIAN_URLS{$page->session('physicianOnSelect')}->{title};
		$physicianTitle =~ s/Physician/$_->{physician}/;
		my $orgTitle = $ORG_URLS{$page->session('orgOnSelect')}->{title};
		$orgTitle =~ s/Org/$_->{facility_name}/;
		my $apptTitle = $APPT_URLS{$page->session('apptOnSelect')}->{title};

		my $insVerifyIcon = $flags & VERIFYFLAG_INSURANCE_COMPLETE ?
			$IMAGETAGS{'icons/green_i'} : $flags & VERIFYFLAG_INSURANCE_PARTIAL ?
			$IMAGETAGS{'icons/black_i'} : $IMAGETAGS{'icons/red_i'};

		my @rowData = (
			qq{<nobr>
				<A HREF='$arlPrefix/dlg-reschedule-appointment/$_->{event_id}' TITLE='Reschedule Appointment'>$IMAGETAGS{'icons/square-lgray-hat-sm'}</A>
				<A HREF='$arlPrefix/dlg-cancel-appointment/$_->{event_id}' TITLE='Cancel Appointment'>$IMAGETAGS{'icons/action-edit-remove-x'}</A>
				<A HREF='$arlPrefix/dlg-noshow-appointment/$_->{event_id}' TITLE='No-Show Appointment'>$IMAGETAGS{'icons/schedule-noshow'}</A>
				</nobr><br>
				$alertHtml
			},

			qq{
				<nobr>
				<A HREF='$patientHref' TITLE='$patientTitle' class=today>
				<b>$_->{patient}</b> ($_->{patient_type})</A>
				</nobr>
				<br>

				<A HREF='$physicianHref' TITLE='$physicianTitle' class=today>
				$_->{physician}</A>
				(<A HREF='$orgHref' TITLE='$orgTitle' class=today>$_->{facility_name}</A>)
			},

			qq{
				<A HREF='$apptHref' TITLE='$apptTitle' class=today>
				@{[ formatStamp($_->{appointment_time}) ]}</A> <br>
				<nobr><strong style="color:#999999">($_->{appt_type})</strong></nobr>
			},

			qq{<nobr>
				<A HREF='/person/$_->{patient_id}/dlg-verify-insurance-records/$_->{event_id}/$_->{patient_id}?_dialogreturnurl=$arlPrefix'
				TITLE='Verify Insurance Records'>$insVerifyIcon</A>

				<A HREF="javascript:doActionPopup('/person/$_->{patient_id}/facesheet')"
				TITLE='Print Face Sheet'>$IMAGETAGS{'icons/black_f'}</A>

				</nobr>
			},
		);

		push(@data, \@rowData);
		$oldEventId = $_->{event_id};
	}

	$html .= createHtmlFromData($page, 0, \@data, $PUBLISH_DEFN);

	$html .= "<i style='color=red'>No appointment data found.  Please setup Resource and Facility selections.</i> <P>"
		if (scalar @{$appts} < 1);

	return $html;
}

sub formatStamp
{
	my ($stamp) = @_;

	if ($stamp =~ /\d\d\/\d\d\/\d\d\d\d/)
	{
		my ($day, $time) = split(/\s/, $stamp);
		return qq{$day $time};
	}
	else
	{
		return "<b>$stamp</b>";
	}

}

1;
