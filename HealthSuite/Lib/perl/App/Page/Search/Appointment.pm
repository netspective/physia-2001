##############################################################################
package App::Page::Search::Appointment;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Search::Appointment;
use App::Statements::Scheduling;

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
	$self->param('execute', 'Go') if $pathItems->[2];  # Auto-execute

	unless ($self->param('searchAgain'))
	{
		my ($resource_id, $facility_id, $action, $fromDate, $toDate, $apptStatus, $eventId) =
			split(/,/, $pathItems->[1]);

		$self->param('resource_id', $resource_id);
		$self->param('facility_id', $facility_id);
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
		"/schedule/appointment/cancel/%itemValue%",
		"/schedule/appointment/reschedule/%itemValue%",
		"/schedule/appointment/noshow/%itemValue%",
		"/schedule/appointment/update/%itemValue%",
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
			Events Outside Available Templates
		</nobr>
		<br>

		Resource:
		<input name='resource_id' size=17 maxlength=32 value="@{[$self->param('resource_id')]}" title='Resource ID'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.resource_id, '/lookup/physician/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		Facility:
		<input name='facility_id' size=17 maxlength=32 value="@{[$self->param('facility_id')]}" title='Facility ID'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.facility_id, '/lookup/org/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>
		<input type=submit name="execute" value="Go">
		
		&nbsp; &nbsp; Order by:
		<SELECT name='order_by'>
			<option value="time">Appointment Time</option>
			<option value="name">Patient Name</option>
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

	if ($self->param('unAvailEventSearch'))
	{
		$self->param('search_from_date', UnixDate('today', '%m/%d/%Y')) unless $self->param('search_from_date');
		$self->param('search_to_date', UnixDate('nextweek', '%m/%d/%Y')) unless $self->param('search_to_date');
		$self->param('action', 5) unless $self->param('action');

		my @resource_ids = split(/,/, $self->param('resource_id'));
		my @facility_ids = split(/,/, $self->param('facility_id'));

		my @search_start_date = Decode_Date_US($self->param('search_from_date'));
		my @search_end_date = Decode_Date_US($self->param('search_to_date'));
		my $search_duration = Delta_Days(@search_start_date, @search_end_date);

		my $sa = new App::Schedule::Analyze (
			resource_ids      => \@resource_ids,
			facility_ids      => \@facility_ids,
			search_start_date => \@search_start_date,
			search_duration   => $search_duration,
			patient_type      => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES,
			visit_type        => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES,
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

		$self->addContent(
			'<CENTER>',
			$STMTMGR_APPOINTMENT_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_conflict_appointments',
				[$eventId, $self->session('org_id')],
			),
			'</CENTER>'
		);
	}

	else
	{
		my $fromDate = $self->param('search_from_date') ? $self->param('search_from_date') : '01/01/1900';
		my $toDate = $self->param('search_to_date') ? $self->param('search_to_date') : '12/31/2099';
		my $resourceId = $self->param('resource_id') || '*';
		my $facilityId = $self->param('facility_id') || '*';
		my ($apptStatusFrom, $apptStatusTo);

		my $fromStamp = $fromDate;
		my $toStamp   = $toDate;

		$fromStamp =~ s/_/ /g;
		$toStamp   =~ s/_/ /g;

		$fromStamp .= " 12:00 AM" unless $fromStamp =~ / \d\d:\d\d[ ]*[AaPp][Mm]/;
		$toStamp   .= " 11:59 PM" unless $toStamp   =~ / \d\d:\d\d[ ]*[AaPp][Mm]/;

		if ($self->param('appt_status')) {
			($apptStatusFrom, $apptStatusTo) = split(/,/, $self->param('appt_status'));
		} else {
			($apptStatusFrom, $apptStatusTo) = (0, 0);
		}

		$resourceId =~ s/\*/%/g;
		$facilityId =~ s/\*/%/g;

		my $html;
		if ($self->param('order_by') eq 'name')
		{
			$html = $STMTMGR_APPOINTMENT_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_appointment_orderbyName',
				[$facilityId, "$fromStamp", "$toStamp", $resourceId, $apptStatusFrom, $apptStatusTo, $self->session('org_id')]
			),
		}
		else
		{
			$html = $STMTMGR_APPOINTMENT_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_appointment',
				[$facilityId, "$fromStamp", "$toStamp", $resourceId, $apptStatusFrom, $apptStatusTo, $self->session('org_id')]
			),
		}
		
		$self->addContent('<CENTER>', $html, '</CENTER>');
	}

	return 1;
}

1;
