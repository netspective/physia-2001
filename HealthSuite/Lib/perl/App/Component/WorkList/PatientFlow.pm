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

@ITEM_TYPES = ('patient', 'physician', 'org', 'appt');

my $arlPrefix = '/worklist/patientflow';

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
	'worklist-patientflow' => {
		_class => new App::Component::WorkList::PatientFlow(),
		},
	);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};

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
		$time1 = $page->session('time1') || '12:00 AM';
		$time2 = $page->session('time2') || '11:59 PM';
	}
	else
	{
		$time1 = $page->session('time1') || 30;
		$time1 = 30 if ($time1 < 0);
		$time2 = $page->session('time2') || 120;
		$time2 = 120 if $time2 < 0;
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
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today', $gmtDayOffset,	$time1, $time2, $user_id, $orgInternalId);
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
		my ($apptMinutes, $checkinMinutes, $checkoutMinutes, $waitMinutes, $visitMinutes);
		$apptMinutes = stamp2minutes($_->{appointment_time});

		next if $oldEventId == $_->{event_id};
		next if $_->{parent_id};

		my $alertExists = $STMTMGR_COMPONENT_SCHEDULING->recordExists($page, STMTMGRFLAG_NONE,
			'sel_alerts', $_->{patient_id});

		my $alertHtml;
		if ($alertExists) {
			$alertHtml = qq{<a href="javascript:doActionPopup('/popup/alerts/$_->{patient_id}')"
				class=today title="View $_->{patient_id} Alert(s)"><b>Alert<b></a>
			};
		}

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

		my $accountBalance = $STMTMGR_COMPONENT_SCHEDULING->getSingleValue($page,
			STMTMGRFLAG_NONE, 'sel_accountBalance', $_->{patient_id});

		my $patientBalance = $STMTMGR_COMPONENT_SCHEDULING->getSingleValue($page,
			STMTMGRFLAG_NONE, 'sel_patientBalance', $_->{patient_id});

		my $copay;
		$copay = $STMTMGR_COMPONENT_SCHEDULING->getSingleValue($page,
			STMTMGRFLAG_NONE, 'sel_copay', $_->{invoice_id}) if $_->{invoice_id};

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

		my $flags = $_->{flags};
		my $apptVerifyIcon = $flags & VERIFYFLAG_APPOINTMENT_COMPLETE ?
			$IMAGETAGS{'icons/green_a'}	: $flags & VERIFYFLAG_APPOINTMENT_PARTIAL ?
			$IMAGETAGS{'icons/black_a'} : $IMAGETAGS{'icons/red_a'};
		my $insVerifyIcon = $flags & VERIFYFLAG_INSURANCE_COMPLETE ?
			$IMAGETAGS{'icons/green_i'} : $flags & VERIFYFLAG_INSURANCE_PARTIAL ?
			$IMAGETAGS{'icons/black_i'} : $IMAGETAGS{'icons/red_i'};

		my $medVerifyIcon = $flags & VERIFYFLAG_MEDICAL ? $IMAGETAGS{'icons/green_m'}
			: $IMAGETAGS{'icons/red_m'};
		my $perVerifyIcon = $flags & VERIFYFLAG_PERSONAL ? $IMAGETAGS{'icons/green_p'}
			: $IMAGETAGS{'icons/red_p'};

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
				<A HREF='/person/$_->{patient_id}/dlg-confirm-appointment/$_->{event_id}?_dialogreturnurl=$arlPrefix'
				TITLE='Confirm Appointment'>$apptVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-insurance-records/$_->{event_id}/$_->{patient_id}?_dialogreturnurl=$arlPrefix'
				TITLE='Verify Insurance Records'>$insVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-medical/$_->{event_id}/$_->{patient_id}?_dialogreturnurl=$arlPrefix'
				TITLE='Verify Medical Records'>$medVerifyIcon</A>

				<A HREF='/person/$_->{patient_id}/dlg-verify-personal-records/$_->{event_id}/$_->{patient_id}?_dialogreturnurl=$arlPrefix'
				TITLE='Verify Personal Records'>$perVerifyIcon</A>

				<A HREF="javascript:doActionPopup('/person/$_->{patient_id}/facesheet')"
				TITLE='Print Face Sheet'>$IMAGETAGS{'icons/black_f'}</A>

				</nobr>

			},

			($_->{checkin_time} || $_->{checkout_time}) ? qq{<strong>$_->{checkin_time}</strong><br>
				<strong title="Wait time in minutes" style="color:#999999">($waitMinutes)</strong>}:
				qq{<a href='$arlPrefix/dlg-add-checkin/$_->{event_id}' TITLE='CheckIn $_->{patient_id}' class=today>CheckIn</a>},

			$_->{checkin_time} || $_->{checkout_time} ?
				($_->{checkout_time} ? qq{<strong>$_->{checkout_time}</strong><br>
				<strong title="Visit time in minutes" style="color:#999999">($visitMinutes)</strong>} :
					qq{<a href='$arlPrefix/dlg-add-checkout/$_->{event_id}' TITLE='CheckOut $_->{patient_id}' class=today>CheckOut</a>}
				)
				: undef ,

			$_->{invoice_id} ? qq{
				<a href='/invoice/$_->{invoice_id}' TITLE='View Claim $_->{invoice_id} Summary' class=today><b>$_->{invoice_id}</b></a> <br>
				<strong style="color:#999999">($_->{invoice_status})</strong>
			}
				: undef,

			$_->{invoice_id} ? $copay : undef,

			$accountBalance,
			$_->{parent_invoice_id} || $_->{invoice_id},
			$_->{patient_id},

			$_->{invoice_id} && $_->{inv_status} > 3 ? qq{
				<a href='javascript:doActionPopup("/patientbill/$_->{invoice_id}")' class=today title="Print Patient Bill $_->{invoice_id}">
					Print</a>
			}
				: undef,

			$patientBalance,
		);

		push(@data, \@rowData);
		$oldEventId = $_->{event_id};
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
