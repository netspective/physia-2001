##############################################################################
package App::Page::Search::ApptSlot;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);
use App::Schedule::Analyze;
use App::Schedule::Utilities;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Org;
use Set::IntSpan;

use CGI::Dialog;
use App::Dialog::Field::RovingResource;


use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/apptslot' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	#$self->params('_advanced', 1) if $pathItems->[0] eq 'apptslota';
	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';

	unless ($self->param('searchAgain')) {
		if ($pathItems->[1]) {
			my ($resource_ids, $facility_ids, $start_date, $appt_duration, $patient_type,
				$appt_type) =
				split(/,/, $pathItems->[1]);

			$start_date =~ s/\-/\//g;
			$self->param('resource_ids', $resource_ids) if defined $resource_ids;
			$self->param('facility_ids', $facility_ids) if defined $facility_ids;
			$self->param('start_date',  $start_date) if defined $start_date;
			$self->param('appt_duration', $appt_duration || 10);
			$self->param('_f_patient_type', $patient_type) if defined $patient_type;
			$self->param('_f_appt_type', $appt_type) if defined $appt_type;
			$self->param('searchAgain', 1);
		}
	}

	$self->param('execute', 'Go') if $pathItems->[2];  # Auto-execute
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my $parallelSearchChecked = "checked" if $self->param('parallel_search');

	my $dialog = new CGI::Dialog(schema => $self->SUPER::getSchema());
	my $rovingPhysField = new App::Dialog::Field::RovingResource(
		physician_field => 'resource_ids',
		name => 'roving_physician',
		caption => 'Roving Physician',
		type => 'foreignKey',
		fKeyDisplayCol => 0,
		fKeyValueCol => 0,
		fKeyStmtMgr => $STMTMGR_SCHEDULING,
		fKeyStmt => 'selRovingPhysicianTypes',
		appendMode => 1,
	);

	my $rovingPhysFieldHtml = $rovingPhysField->getHtml($self, $dialog);

	my $patientTypeField = new CGI::Dialog::Field(caption => 'Patient Type',
		name => 'patient_type',
		type => 'select',
		fKeyStmtMgr => $STMTMGR_SCHEDULING,
		fKeyStmt => 'selPatientTypesDropDown',
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
	);

	my $apptTypeField =	new CGI::Dialog::Field(caption => 'Appointment Type',
		name => 'appt_type',
		type => 'select',
		fKeyStmtMgr => $STMTMGR_SCHEDULING,
		fKeyStmt => 'sel_ApptTypesDropDown',
		fKeyStmtBindSession => ['org_internal_id'],
		fKeyDisplayCol => 1,
		fKeyValueCol => 0,
	);

	my $patientTypeFieldHtml = $patientTypeField->select_as_html($self, $dialog);
	my $apptTypeFieldHtml = $apptTypeField->select_as_html($self, $dialog);

	my $chooseDateOptsHtml = qq{
		<option value="">Choose Day</option>
		<option value="@{[ UnixDate('today', '%m/%d/%Y') ]}">Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 1 week'), '%m/%d/%Y') ]}">1 week from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 2 weeks'), '%m/%d/%Y') ]}">2 weeks from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 3 weeks'), '%m/%d/%Y') ]}">3 weeks from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 6 weeks'), '%m/%d/%Y') ]}">6 weeks from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 3 months'), '%m/%d/%Y') ]}">3 months from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 6 months'), '%m/%d/%Y') ]}">6 months from Today</option>
		<option value="@{[ UnixDate(DateCalc('today', '+ 1 year'), '%m/%d/%Y') ]}">1 year from Today</option>
	};
	
	return ('Find next available slot', qq{
	<CENTER>
		<nobr>
		<font face='arial,helvetica' size='2' color=black>
		<label for="parallel_search">Parallel Search</label>
		<input name='parallel_search' id="parallel_search" type=checkbox $parallelSearchChecked>

		<font face='arial,helvetica' size='2' color=black>
		&nbsp; Resource(s)
		<input name='resource_ids' id='resource_ids' size=30 maxlength=255 value="@{[$self->param('resource_ids')]}" title='Resource IDs'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.resource_ids, '/lookup/physician/id', ',', false, null);">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		<font face='arial,helvetica' size='2' color=black>
		&nbsp; Facility(s)
		<input name='facility_ids' id='facility_ids' size=20 maxlength=32 value="@{[$self->param('facility_ids')]}" title='Facility IDs'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.facility_ids, '/lookup/org/id', ',', false);">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>
		</nobr>
		<br>
		<table>
			$rovingPhysFieldHtml
		</table>

		<nobr>
		<font face='arial,helvetica' size='2' color=black>
		Starting

		<SELECT onChange="document.search_form.start_date.value = this.value">
			$chooseDateOptsHtml
		</SELECT>
		
		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>
		<input name='start_date' id='start_date' size=10 maxlength=10 title='Start Date'
			value="@{[$self->param('start_date') || UnixDate ('today', '%m/%d/%Y')]}"
			onblur="validateChange_Date(event)">
		<A HREF="javascript: showCalendar(document.search_form.start_date);">
			<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></A>

		<font face='arial,helvetica' size='2' color=black>
		&nbsp; Duration (minutes)
		<input name='appt_duration' size=3 value="@{[$self->param('appt_duration') || 10]}">
		
		<font face='arial,helvetica' size='2' color=black>
		&nbsp; Search Duration
		<select name="search_duration" style="color: navy">
			<option value="7" >1 week</option>
			<option value="14">2 weeks</option>
			<option value="21">3 weeks</option>
			<option value="30">1 month</option>
		</select>

		<table>
			<tr>
				<td>
					<table cellpadding=1 cellspacing=0>
						$patientTypeFieldHtml					
					</table>
				</td>
				
				<td>
					<table cellpadding=1 cellspacing=0>
						$apptTypeFieldHtml			
					</table>
				</td>
				<td>
					<input type=submit name="execute" value="Go">				
				</td>
			</tr>
		</table>

		<script>
			setSelectedValue(document.search_form.search_duration, '@{[ $self->param('search_duration') || 7 ]}');
			
			setSelectedValue(document.search_form._f_patient_type, '@{[ $self->param('_f_patient_type') ]}');
			setSelectedValue(document.search_form._f_appt_type, '@{[ $self->param('_f_appt_type') ]}');
		</script>

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">

	</CENTER>
	});
}

sub findResourceIds
{
	my ($self, $resourcesString) = @_;

	my $orgInternalId = $self->session('org_internal_id');
	my @resource_ids = ();
	
	if ($resourcesString =~ /(\*|\%)/)
	{
		for my $r (split(/\s*,\s*/, cleanup($resourcesString)))
		{
			$r =~ s/\*/\%/g;
			my $resources = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE,
			'sel_resources_like', $r, $orgInternalId);
			
			for (@{$resources}) {
				push(@resource_ids, $_->{person_id});
			}
		}
	}
	else
	{
		@resource_ids = split(/\s*,\s*/, cleanup($resourcesString));
	}

	return @resource_ids;
}

sub findFacilityIds
{
	my ($self, $facilityString) = @_;
	
	my $orgInternalId = $self->session('org_internal_id');
	my @facilities = split(/\s*,\s*/, cleanup($facilityString));
	
	my @facility_ids = ();
	my @internalOrgIds = ();
	
	# ------- Special case:  single number org_internal_id passed in from Appointment Dialog
	if (scalar @facilities == 1 && $facilities[0] =~ /^\d*$/)
	{
		my $orgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selId', $facilities[0]);
		
		$self->param('facility_ids', $orgId) if ($orgId);
		return @facilities;
	}
	# ------------------- End Special Case
	
	for my $f (@facilities)
	{
		if ($f =~ /(\%|\*)/)
		{
			my $f1 = $f;
			$f1 =~ s/\*/\%/g;
			my $fac = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE, 
				'sel_facilities_like', $f1, $orgInternalId);
			
			for (@{$fac}) {
				push(@internalOrgIds, $_->{org_internal_id});
			}
		}
		elsif ($f =~ /^\d+$/)
		{
			push(@internalOrgIds, $f);
		}
		else
		{
			push(@facility_ids, $f);
		}
	}
	
	for (@facility_ids)
	{
		my $internalOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE,
			'selOrgId', $self->session('org_internal_id'), uc($_));
		push(@internalOrgIds, $internalOrgId) if defined $internalOrgId;
	}

	unless (scalar @internalOrgIds >= 1)
	{
		for (@facilities)
		{
			chomp;
			if ($_ =~ /.*\D.*/)
			{
				$self->addError("Facility '$_' is NOT a valid Facility in this Org.  Please verify and try again.");
				return (-1);
			}
		}
	}
	
	my $set = new Set::IntSpan(\@internalOrgIds);
	
	return $set->elements();
}

sub execute
{
	my ($self) = @_;

	my @resource_ids = $self->findResourceIds($self->param('resource_ids'));
	my @internalOrgIds = $self->findFacilityIds($self->param('facility_ids'));
	
	return if grep(/\-1/, @internalOrgIds);
	
	my $rIds;
	if ($self->field('appt_type') > 0)
	{
		my $apptType = $STMTMGR_SCHEDULING->getRowAsHash($self, STMTMGRFLAG_NONE,
			'selApptTypeById', $self->field('appt_type'));
			
		$rIds = $apptType->{rr_ids};
		push(@resource_ids, split(/\s*,\s*/, $rIds)) if $rIds;
		#$self->param('resource_ids', join(',', @resource_ids));
		$self->param('parallel_search', 1) if defined $rIds;
		$self->param('appt_duration', $apptType->{duration});
	}
	
	$self->param('appt_duration', 10) if $self->param('appt_duration') <= 0;

	$self->param('start_date', UnixDate('today', '%m/%d/%Y')) 
		unless validateDate($self->param('start_date'));
	
	my @search_start_date = Decode_Date_US($self->param('start_date'));
	eval {check_date(@search_start_date);};
	@search_start_date = Today() if $@;

	my $patient_type = $self->field('patient_type') if defined $self->field('patient_type');
	my $appt_type = $self->field('appt_type') if defined $self->field('appt_type');

	my $sa = new App::Schedule::Analyze (
		resource_ids      => \@resource_ids,
		facility_ids      => \@internalOrgIds,
		search_start_date => \@search_start_date,
		search_duration   => $self->param('search_duration') || 7,
		patient_type      => defined $patient_type ? $patient_type : -1,
		appt_type         => defined $appt_type ? $appt_type : -1
	);

	my $flag = defined $self->param('parallel_search') || defined $rIds ?
		App::Schedule::Analyze::MULTIRESOURCESEARCH_PARALLEL : App::Schedule::Analyze::MULTIRESOURCESEARCH_SERIAL;

	my @available_slots = $sa->findAvailSlots($self, $flag);
	my $slotsHtml = $self->getSlotsHtml($sa, @available_slots);
	$self->addContent($slotsHtml);
}

sub getSlotsHtml
{
	my ($self, $sa, @slots) = @_;

	my $html = qq{
		<style>
				a { text-decoration: none; }
				a { color:blue; }
				td { font-size: 9pt; font-family: Verdana }
				th { font-size: 9pt; font-family: Verdana }
				a:hover { color: red; }
		</style>
	};

	$html .= "<br>" if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	$html .= "<center> <table border=0 cellspacing=0 cellpadding=3>\n";

	if (@slots) {
		$html .= "<tr bgcolor=#eeeedd><th>Resource</th><th>Facility</th><th colspan=2>Day</th><th>Time Slot</th></tr>\n";
	} else {
		$html .= "<tr><td>No available slot found in this search period.</td></tr>\n";
	}

	my $patient_type = $self->param('_f_patient_type');
	$patient_type = 1 if $patient_type == -1;
	my $appt_type = $self->param('_f_appt_type');
	my $duration = $self->param('appt_duration');

	my $found = 0;
	my $today = Date_to_Days(Today());
	my $dayPrinted = 0;

	my $startDay = Date_to_Days(@{$sa->{search_start_date}});

	if (scalar @{$sa->{resource_ids}} == 1)
	{
		for (@slots)
		{
			my $resource_id = $_->{resource_id};
			my $facility_id = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selId', $_->{facility_id});
			my @minute_ranges = split(/,/, $_->{minute_set}->run_list);

			my $facilityInternalId = $_->{facility_id};

			for (@minute_ranges)
			{
				my ($outerLow, $outerHigh) = split(/-/, $_);
			
				for (my $loopIndex=$outerLow; $loopIndex<$outerHigh; $loopIndex += $duration) 
				{
					my $low = $loopIndex;
					my $high = $low + $duration;
					last if ($high > $outerHigh);

					my $dayOffset = int($low/24/60);
					$low  -= $dayOffset*24*60;
					$high -= $dayOffset*24*60;

					my $day  = $dayOffset + $startDay;

					last if ($high - $low) < $duration;
					last if ($day < $today);

					$found = 1;
					$html .= $self->getRowHtml($sa, $day, $low, $high, $resource_id, $facility_id, $duration,
						$patient_type, $appt_type, $facilityInternalId, \$dayPrinted);
				}
			}
		}
	}
	else
	{
		for (@slots)
		{
			my $resource_id = $_->{resource_id};
			my $facility_id = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selId',
				$_->{facility_id});
			my @minute_ranges = split(/,/, $_->{minute_set}->run_list);

			my $facilityInternalId = $_->{facility_id};

			for (@minute_ranges)
			{
				my ($low, $high) = split(/-/, $_);

				my $dayOffset = int($low/24/60);
				$low  -= $dayOffset*24*60;
				$high -= $dayOffset*24*60;

				my $day  = $dayOffset + $startDay;

				next if ($high - $low) < $duration;
				next if ($day < $today);

				$found = 1;
				$html .= $self->getRowHtml($sa, $day, $low, $high, $resource_id, $facility_id, $duration,
					$patient_type, $appt_type, $facilityInternalId, \$dayPrinted);
			}
		}
	}

	if (! $found && @slots) {
		$html .= "<tr><td>No available slot found meeting this appointment duration.</td></tr>";
	}

	$html .= "</table></center>";

	return $html;
}


sub getRowHtml
{
	my ($self, $sa, $day, $low, $high, $resource_id, $facility_id, $duration, $patient_type, 
		$appt_type, $facilityInternalId, $dayPrinted) = @_;

	my $html;
	
	my $timeString = minute_set_2_string("$low-$high", TIME_H12);
	my @date = Days_to_Date($day);

	my $dateString = sprintf ("%02d-%02d-%04d", $date[1],$date[2],$date[0]);
	my $fmtDate  = sprintf ("%02d/%02d/%04d", $date[1],$date[2],$date[0]);
	my $dow = sprintf ("%.3s", Day_of_Week_to_Text(Day_of_Week(@date)));

	my $resourceHref;
	my $facilityHref;

	if ($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
		$resourceHref = $resource_id;
		$resourceHref = join(',', @{$sa->{resource_ids}}) if $self->param('parallel_search');
		$facilityHref = $facility_id;
	} else {
		$resourceHref = qq{<a style="font-weight:bold" href="javascript:chooseItem('/search/apptslot/%itemValue%/1', '$resource_id,,$dateString,$duration,$patient_type,$appt_type', false);" >$resource_id </a>};
		$facilityHref = qq{<a href="javascript:chooseItem('/search/apptslot/%itemValue%/1', ',$facility_id,$dateString,$duration,$patient_type,$appt_type', false);" >$facility_id </a>};
		$resourceHref = join(',', @{$sa->{resource_ids}}) if $self->param('parallel_search');
	}

	if ($$dayPrinted == $day) {
		$html .= "<tr><td>$resourceHref</td><td>$facilityHref</td><td>&nbsp</td><td>&nbsp</td>";
	} else {
		$html .= "<TR><TD COLSPAN=5><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>";
		$html .= "<tr><td>$resourceHref</td><td>$facilityHref</td><td align=right>";

		if (! $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
			$html .= "<a href='/schedule/apptsheet/$dateString'>$dow</a>";
		} else {
			$html .= "$dow";
		}

		$html .= "</td><td>$fmtDate</td>\n";
		$$dayPrinted = $day;
	}

	my $startTime = $dateString . "_" . Trim(minute_set_2_string($low, TIME_H12));
	my $startTimeHref;

	if ($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
		my $dashDateString = $dateString;
		$dashDateString =~ s/\-/\//g;
		my $beginTime = Trim(minute_set_2_string($low, TIME_H12));
		$startTimeHref = qq{<a href="javascript:chooseItem('/schedule/appointment/add/%itemValue%', '$dashDateString', false, '$beginTime');" >$timeString </a>};
	} else {
		$startTime =~ s/ /_/g;
		#$startTimeHref = qq{<a href="javascript:chooseItem('/schedule/appointment/add/%itemValue%', '$resource_id,$startTime,$facilityInternalId,$patient_type,$appt_type', false);" >$timeString </a>};
		$startTimeHref = qq{<a href="javascript:chooseItem('/schedule/dlg-add-appointment//$resource_id/$facilityInternalId/$startTime/$patient_type/$appt_type', null, false);" >$timeString </a>};
	}

	$html .= "<td>$startTimeHref</td>\n";
	$html .= "</tr>\n";
	
	return $html;
}

1;
