##############################################################################
package App::Page::Search::Appointment;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Appointment;
use App::Statements::Scheduling;
use App::Statements::Org;

use Date::Manip;
use Date::Calc qw(:all);
use App::Schedule::Analyze;
use App::Schedule::Utilities;
use Data::Publish;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/appointment' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('_pm_view', $pathItems->[0]);
	$self->param('execute', 'Go') if $pathItems->[1];  # Auto-execute

	unless ($self->param('searchAgain'))
	{
		my ($resource_ids, $facility_ids, $action, $fromDate, $toDate, $apptStatus, $eventId) =
			@{$pathItems}[1..7];

		$self->param('resource_ids', $resource_ids);
		$self->param('facility_ids', $facility_ids);
		$self->param('action', $action);
		$self->param('appt_status', "$apptStatus,$apptStatus") if $apptStatus;
		$self->param('event_id', $eventId);

		$fromDate =~ s/\-/\//g;
		$self->param('search_from_date', $fromDate);
		$toDate =~ s/\-/\//g;
		$self->param('search_to_date', $toDate);
		$self->param('searchAgain', 1);
	}

	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my @actionValues = (
		"/schedule/apptsheet/encounterCheckin/%itemValue%",
		"/schedule/apptsheet/encounterCheckout/%itemValue%",
		"/schedule/dlg-cancel-appointment/%itemValue%",
		"/schedule/dlg-reschedule-appointment/%itemValue%",
		"/schedule/dlg-noshow-appointment/%itemValue%",
		"/schedule/dlg-update-appointment/%itemValue%",
	);

	$self->param('item_action_arl_select', $actionValues[$self->param('action')])
		if defined $self->param('action');

	my ($createFns, $itemFns) = ('', '');
	if($self->param('execute') && ! ($flags & (SEARCHFLAG_LOOKUPWINDOW | SEARCHFLAG_SEARCHBAR)))
	{
		$itemFns = qq{
			<BR>
			<FONT size=5 face='arial'>&nbsp;</FONT>
			On Select:
			<SELECT name="item_action_arl_select">
				<option value="$actionValues[0]">Check In</option>
				<option value="$actionValues[1]">Check Out</option>
				<option value="$actionValues[2]">Cancel</option>
				<option value="$actionValues[3]">Reschedule</option>
				<option value="$actionValues[4]">No Show</option>
				<option value="$actionValues[5]">Edit Appointment</option>
			</SELECT>

			<SELECT name="item_action_arl_dest_select">
				<option>In this window</option>
				<option>In new window</option>
			</SELECT>

			<script>
				setSelectedValue(document.search_form.item_action_arl_select, '@{[$self->param('item_action_arl_select')]}');
			</script>
		};
	}
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<a href="/org/#session.org_id#/dlg-add-appointment">Schedule Appointment</a>
		};
	}

	my $unAvailEventSearchChecked = "checked" if $self->param('unAvailEventSearch');

	my $html = qq{
		<CENTER>
		<nobr>
		Type:
			<SELECT name='appt_status'>
				<option value="0,0">Scheduled</option>
				<option value="1,1">In Progress</option>
				<option value="2,2">Complete</option>
				<option value="3,3">Cancelled</option>
				<option value="0,3">All appointments</option>
			</SELECT>
		<script>
			setSelectedValue(document.search_form.appt_status, '@{[ $self->param('appt_status')]}');
		</script>

		&nbsp Date Range:
		<input name='search_from_date' size=10 maxlength=10 value="@{[$self->param('search_from_date')]}" title='From Date'>
		<input name='search_to_date' size=10 maxlength=10 value="@{[$self->param('search_to_date')]}" title='To Date'>
		<nobr>
			&nbsp <input name='unAvailEventSearch' type=checkbox $unAvailEventSearchChecked>
			Appointments Outside Available Templates
		</nobr>
		<br>

		Resource(s):
		<input name='resource_ids' size=17 maxlength=64 value="@{[$self->param('resource_ids')]}" title='Resource ID'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.resource_ids, '/lookup/physician/id', ',', false);">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		Facility(s):
		<input name='facility_ids' size=17 maxlength=64 value="@{[$self->param('facility_ids')]}" title='Facility ID'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.facility_ids, '/lookup/org/id', ',', false);">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>
		<input type=submit name="execute" value="Go">

		&nbsp; &nbsp; Order by:
		<SELECT name='order_by'>
			<option value="time">Appointment Time</option>
			<option value="name">Patient Name</option>
			<option value="account">Account Number</option>
			<option value="chart">Chart Number</option>
		</SELECT>
		<script>
			setSelectedValue(document.search_form.order_by, '@{[ $self->param('order_by')]}');
		</script>

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">

		$itemFns
		</CENTER>
	};

	return ('Appointments Manager', $html);
}

sub execute
{
	my ($self) = @_;

	$self->param('search_from_date', UnixDate('today', '%m/%d/%Y'))
		unless validateDate($self->param('search_from_date'));

	$self->param('search_to_date', UnixDate('nextweek', '%m/%d/%Y'))
		unless validateDate($self->param('search_to_date'));

	my @resource_ids = split(/\s*,\s*/, cleanup($self->param('resource_ids')));
	my @facility_ids = split(/\s*,\s*/, cleanup($self->param('facility_ids')));

	if ($self->param('unAvailEventSearch'))
	{
		$self->param('action', 5) unless $self->param('action');
			my @internalOrgIds = ();
			for (@facility_ids)
			{
				my $internalOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE,
					'selOrgId', $self->session('org_internal_id'), uc($_));
				push(@internalOrgIds, $internalOrgId) if defined $internalOrgId;
			}

			unless (scalar @internalOrgIds >= 1)
			{
				my @orgIds = ();
				for (@facility_ids)
				{
					chomp;
					if ($_ =~ /.*\D.*/)
					{
						$self->addError("Facility '$_' is NOT a valid Facility in this Org.  Please verify and try again.");
						return;
					}

					my $orgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selId', $_);
					if ($orgId)
					{
						push(@orgIds, $orgId);
						push(@internalOrgIds, $_);
					}
					$self->param('facility_ids', join(',', @orgIds));
				}
			}

		my @search_start_date = Decode_Date_US($self->param('search_from_date'));
		my @search_end_date = Add_Delta_Days(Decode_Date_US($self->param('search_to_date')), 1);
		my $search_duration = Delta_Days(@search_start_date, @search_end_date);

		my $sa = new App::Schedule::Analyze (
			resource_ids      => \@resource_ids,
			facility_ids      => \@internalOrgIds,
			search_start_date => \@search_start_date,
			search_duration   => $search_duration || 1,
			patient_type      => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES,
			appt_type         => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES,
		);

		my @unAvailSlots = $sa->findUnAvailableAppointments($self);
		my @data = ();
		for (@unAvailSlots)
		{
			my @rowData = $_->defaultRowRptFormat();
			push (@data, \@rowData);
		}

		$self->addContent(
			'<CENTER>',
				createHtmlFromData($self, 0, \@data, $App::Statements::Search::Appointment::STMTRPTDEFN_DEFAULT),
			'</CENTER>'
		);
	}

	elsif ($self->param('event_id'))
	{
		my $eventId = $self->param('event_id');

		my $gmtDayOffset = $self->session('GMT_DAYOFFSET');
		$self->addContent(
			'<CENTER>',
			$STMTMGR_APPOINTMENT_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_conflict_appointments',
				[$gmtDayOffset, $gmtDayOffset, $eventId, $self->session('org_internal_id')],
			),
			'</CENTER>'
		);
	}

	else
	{
		my $fromDate = $self->param('search_from_date');
		my $toDate = $self->param('search_to_date');

		my $fromStamp = $fromDate;
		my $toStamp   = $toDate;
		$fromStamp =~ s/_/ /g;
		$toStamp   =~ s/_/ /g;
		$fromStamp .= " 12:00 AM" unless $fromStamp =~ / \d\d:\d\d[ ]*[AaPp][Mm]/;
		$toStamp   .= " 11:59 PM" unless $toStamp   =~ / \d\d:\d\d[ ]*[AaPp][Mm]/;

		my ($apptStatusFrom, $apptStatusTo);
		if ($self->param('appt_status')) {
			($apptStatusFrom, $apptStatusTo) = split(/,/, $self->param('appt_status'));
		} else {
			($apptStatusFrom, $apptStatusTo) = (0, 0);
		}

		my @data = ();

		push(@resource_ids, '*') unless @resource_ids;
		push(@facility_ids, '*') unless @facility_ids;

		my $fromTZ = App::Schedule::Utilities::BASE_TZ;
		my $toTZ = $self->session('TZ');

		my $convFromStamp = convertStamp2Stamp($fromStamp, $toTZ, $fromTZ);
		my $convToStamp = convertStamp2Stamp($toStamp, $toTZ, $fromTZ);

		my $gmtDayOffset = $self->session('GMT_DAYOFFSET');

		for my $resourceId (@resource_ids)
		{
			$resourceId =~ s/\*/%/g;

			for my $facilityId (@facility_ids)
			{
				$facilityId =~ s/\*/%/g;

				my $appts;
				if ($self->param('order_by') eq 'name')
				{
					$appts = $STMTMGR_APPOINTMENT_SEARCH->getRowsAsHashList($self, STMTMGRFLAG_NONE,
						'sel_appointment_orderbyName', $gmtDayOffset, $gmtDayOffset, $facilityId,
						"$convFromStamp", "$convToStamp", $resourceId, $apptStatusFrom, $apptStatusTo,
						$self->session('org_internal_id')
					);
				}
				elsif ($self->param('order_by') eq 'account')
				{
					$appts = $STMTMGR_APPOINTMENT_SEARCH->getRowsAsHashList($self, STMTMGRFLAG_NONE,
						'sel_appointment_orderbyAccount', $gmtDayOffset, $gmtDayOffset, $facilityId,
						"$convFromStamp", "$convToStamp", $resourceId, $apptStatusFrom, $apptStatusTo,
						$self->session('org_internal_id')
					);
				}
				elsif ($self->param('order_by') eq 'chart')
				{
					$appts = $STMTMGR_APPOINTMENT_SEARCH->getRowsAsHashList($self, STMTMGRFLAG_NONE,
						'sel_appointment_orderbyChart', $gmtDayOffset, $gmtDayOffset, $facilityId,
						"$convFromStamp", "$convToStamp", $resourceId, $apptStatusFrom, $apptStatusTo,
						$self->session('org_internal_id')
					);
				}
				else
				{
					$appts = $STMTMGR_APPOINTMENT_SEARCH->getRowsAsHashList($self, STMTMGRFLAG_NONE,
						'sel_appointment', $gmtDayOffset, $gmtDayOffset, $facilityId, "$convFromStamp",
						"$convToStamp", $resourceId, $apptStatusFrom, $apptStatusTo,
						$self->session('org_internal_id')
					);
				}

				for (@{$appts})
				{
					my @rowData = (
						$_->{simple_name},
						$_->{start_time},
						$_->{resource_id},
						$_->{patient_type},
						$_->{subject},
						$_->{home_phone},
						$_->{caption},
						$_->{org_id},
						$_->{remarks},
						$_->{event_id},
						$_->{scheduled_by_id},
						$_->{scheduled_stamp},
						$_->{patient_id},
						$_->{appt_type},
						$_->{account_number},
						$_->{chart_number},
					);

					push(@data, \@rowData);
				}
			}
		}

		my $html = createHtmlFromData($self, 0, \@data, $App::Statements::Search::Appointment::STMTRPTDEFN_DEFAULT);
		$self->addContent('<CENTER>', $html, '</CENTER>');
	}

	return 1;
}

1;
