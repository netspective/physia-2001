##############################################################################
package App::Component::WorkList::PatientFlow;
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

use enum qw(BITMASK:VERIFYFLAG_ APPOINTMENT INSURANCE MEDICAL PERSONAL);

use vars qw(@ISA %RESOURCE_MAP @EXPORT
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
@ISA   = qw(CGI::Component Exporter);
@ITEM_TYPES = ('patient', 'physician', 'org', 'appt');

%PATIENT_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Chart' => {arl => '/person/itemValue/chart', title => 'View Chart'},
	'View Account' => {arl => '/person/itemValue/account', title => 'View Account'},
	'Make Appointment' => {arl => '/worklist/patientflow/dlg-add-appointment/itemValue', title => 'Make Appointment'},
);

%PHYSICIAN_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Schedule' => {arl => '/schedule/apptcol/itemValue', title => 'View Schedule'},
	'Add Template' => {arl => '/worklist/patientflow/dlg-add-template/itemValue', title => 'Add Schedule Template'},
);

%ORG_URLS = (
	'View Profile' => {arl => '/org/itemValue/profile', title => 'View Profile'},
	'View Fee Schedules' => {arl => '/org/itemValue/catalog', title => 'View Fee Schedules'},
);

%APPT_URLS = (
	'Reschedule' => {arl => '/worklist/patientflow/dlg-reschedule-appointment/itemValue', title => 'Reschedule Appointment'},
	'Cancel' => {arl => '/worklist/patientflow/dlg-cancel-appointment/itemValue', title => 'Cancel Appointment'},
	'No-Show' => {arl => '/worklist/patientflow/dlg-noshow-appointment/itemValue', title => 'No-Show Appointment'},
	'Update' => {arl => '/worklist/patientflow/dlg-update-appointment/itemValue', title => 'Update Appointment'},
);

$patientDefault = 'View Profile';
$physicianDefault = 'View Profile';
$orgDefault = 'View Profile';
$apptDefault = 'Update';

@EXPORT = qw(%PATIENT_URLS %PHYSICIAN_URLS %ORG_URLS %APPT_URLS @ITEM_TYPES);

%RESOURCE_MAP = (
	'worklist-patientflow' => {
		_class => new App::Component::WorkList::PatientFlow(),
		},
	);


sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist/patientflow';

	$layoutDefn->{frame}->{heading} = " ";
	$layoutDefn->{style} = 'panel.transparent';


	$layoutDefn->{banner}->{actionRows} =
	[
		{
			caption => qq{
				<a href='$arlPrefix/dlg-add-appointment'>Add Walk-In</a> |
				<a href='$arlPrefix/dlg-add-appointment'>Add Appointment</a> |
				<a href='$arlPrefix/dlg-add-patient/'>Add Patient</a> |

				&nbsp
				<SELECT onChange='location.href=this.options[selectedIndex].value'>
					<option value='#'>Select Action</option>
					<option value='$arlPrefix/dlg-add-ins-product/'>Add Insurance Product</option>
					<option value='$arlPrefix/dlg-add-ins-plan/'>Add Insurance Plan</option>
					<option value='$arlPrefix/dlg-add-assign/'>Reassign Physician</option>
					<option value='#'>Print Encounter Form</option>
					<option value='#'>Print Face Sheet</option>
				</SELECT>
			}
		},
	];

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
		$time1 = $page->session('time1') || '12:00am';
		$time2 = $page->session('time2') || '11:59pm';
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

	my $orgInternalId = $page->session('org_internal_id');
	my $appts;
	if ($page->param('Today'))
	{
		if ($page->session('showTimeSelect') == 0)
		{
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today', $time1, $time2, $user_id, $orgInternalId, $user_id, $orgInternalId);
		} else
		{
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today_byTime', $startTime, $endTime, $user_id, $orgInternalId, $user_id, $orgInternalId);
		}
	}
	else
	{
		$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_events_worklist_not_today', $startTime, $endTime, $user_id, $orgInternalId, $user_id, $orgInternalId);
	}

	my @data = ();
	my $html = qq{
		<style>
			a.today {text-decoration:none; font-family:Verdana; font-size:8pt}
			strong {font-family:Tahoma; font-size:8pt; font-weight:normal}
		</style>
	};

	foreach (@$appts)
	{
		my ($apptMinutes, $checkinMinutes, $checkoutMinutes, $waitMinutes, $visitMinutes);
		$apptMinutes = stamp2minutes($_->{appointment_time});

		$_->{facility_name} = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', 
			$_->{facility});
		
		if ($_->{checkin_time} || $_->{checkout_time})
		{
			$checkinMinutes  = stamp2minutes($_->{checkin_time});
			$waitMinutes = $checkinMinutes - $apptMinutes;
			$waitMinutes = 'early' if $waitMinutes < 0;
		}

		if ($_->{checkout_time})
		{
			$checkoutMinutes = stamp2minutes($_->{checkout_time});
			$visitMinutes = $checkoutMinutes - $checkinMinutes;
			$visitMinutes = 'early' if $visitMinutes < 0;
		}

		my $deadBeatBalance = $STMTMGR_COMPONENT_SCHEDULING->getSingleValue($page,
			STMTMGRFLAG_NONE, 'sel_deadBeatBalance', $_->{patient_id});

		my $copay;
		$copay = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page,
			STMTMGRFLAG_NONE, 'sel_copayInfo', $_->{invoice_id}) if $_->{invoice_id};

		my $patientHref = $PATIENT_URLS{$page->session('patientOnSelect')}->{arl};
		$patientHref =~ s/itemValue/$_->{patient_id}/;
		my $physicianHref = $PHYSICIAN_URLS{$page->session('physicianOnSelect')}->{arl};
		$physicianHref =~ s/itemValue/$_->{physician}/;
		my $orgHref = $ORG_URLS{$page->session('orgOnSelect')}->{arl};
		$orgHref =~ s/itemValue/$_->{facility_name}/;
		my $apptHref = $APPT_URLS{$page->session('apptOnSelect')}->{arl};
		$apptHref =~ s/itemValue/$_->{event_id}/;

		my $patientTitle = $PATIENT_URLS{$page->session('patientOnSelect')}->{title};
		my $physicianTitle = $PHYSICIAN_URLS{$page->session('physicianOnSelect')}->{title};
		my $orgTitle = $ORG_URLS{$page->session('orgOnSelect')}->{title};
		my $apptTitle = $APPT_URLS{$page->session('apptOnSelect')}->{title};

		my $flags = $_->{flags};
		my $insVerifyIcon = $flags & VERIFYFLAG_INSURANCE ? $IMAGETAGS{'icons/verify-insurance-complete'}
			: $IMAGETAGS{'icons/verify-insurance-incomplete'};
		my $apptVerifyIcon = $flags & VERIFYFLAG_APPOINTMENT ? $IMAGETAGS{'icons/verify-appointment-complete'}
			: $IMAGETAGS{'icons/verify-appointment-incomplete'};
		my $medVerifyIcon = $flags & VERIFYFLAG_MEDICAL ? $IMAGETAGS{'icons/verify-medical-complete'}
			: $IMAGETAGS{'icons/verify-medical-incomplete'};
		my $perVerifyIcon = $flags & VERIFYFLAG_PERSONAL ? $IMAGETAGS{'icons/verify-personal-complete'}
			: $IMAGETAGS{'icons/verify-personal-incomplete'};
			
		
		my @rowData = (
			qq{
				<A HREF='/worklist/patientflow/dlg-reschedule-appointment/$_->{event_id}' TITLE='Reschedule Appointment'><IMG SRC='/resources/icons/square-lgray-hat-sm.gif' BORDER=0></A>
				<br><nobr>
				<A HREF='/worklist/patientflow/dlg-cancel-appointment/$_->{event_id}' TITLE='Cancel Appointment'><IMG SRC='/resources/icons/action-edit-remove-x.gif' BORDER=0></A>
				<A HREF='/worklist/patientflow/dlg-noshow-appointment/$_->{event_id}' TITLE='No-Show Appointment'><IMG SRC='/resources/icons/schedule-noshow.gif' BORDER=0></A>
				</nobr>
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
				<A HREF='/person/$_->{patient_id}/dlg-confirm-appointment/$_->{event_id}'
				TITLE='Confirm Appointment'>$apptVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-insurance-records/$_->{event_id}/$_->{patient_id}'
				TITLE='Verify Insurance Records'>$insVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-medical/$_->{event_id}/$_->{patient_id}'
				TITLE='Verify Medical Records'>$medVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-personal-records/$_->{event_id}/$_->{patient_id}'
				TITLE='Verify Personal Records'>$perVerifyIcon</A>
				</nobr>
			},

			($_->{checkin_time} || $_->{checkout_time}) ? qq{<strong>$_->{checkin_time}</strong><br>
				<strong title="Wait time in minutes" style="color:#999999">($waitMinutes)</strong>}:
				qq{<a href='/worklist/patientflow/dlg-add-checkin/$_->{event_id}' TITLE='CheckIn $_->{patient_id}' class=today>CheckIn</a>},

			$_->{checkin_time} || $_->{checkout_time} ?
				($_->{checkout_time} ? qq{<strong>$_->{checkout_time}</strong><br>
				<strong title="Visit time in minutes" style="color:#999999">($visitMinutes)</strong>} :
					qq{<a href='/worklist/patientflow/dlg-add-checkout/$_->{event_id}' TITLE='CheckOut $_->{patient_id}' class=today>CheckOut</a>}
				)
				: undef ,

			$_->{invoice_id} ? qq{
				<a href='/invoice/$_->{invoice_id}' TITLE='View Claim $_->{invoice_id} Summary' class=today><b>$_->{invoice_id}</b></a> <br>
				<strong style="color:#999999">($_->{invoice_status})</strong>
			}
				#: qq{<a href='/create/invoice_id/$_->{patient_id}' class=today>Add</a>},
				: undef,

			$_->{invoice_id} ? $copay->{balance} : undef,

			$deadBeatBalance,
			$_->{invoice_id},
			$_->{patient_id},
			$copay->{item_id},

			$_->{invoice_id} ? qq{
				<a href='javascript:doActionPopup("/patientbill/$_->{invoice_id}")' class=today title="Print Patient Bill $_->{invoice_id}">
					Print</a>
			}
				: undef,

		);

		push(@data, \@rowData);
	}

	$html .= createHtmlFromData($page, 0, \@data,
		$App::Statements::Component::Scheduling::STMTRPTDEFN_WORKLIST);

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
