##############################################################################
package App::Schedule::Object;
##############################################################################

use strict;
use Set::IntSpan;

sub new
{
	my $type = shift;
	my %params = @_;

	$params{resource_id} = $params{resource_id} || undef;
	$params{facility_id} = $params{facility_id} || undef;
	$params{minute_set}  = $params{minute_set} || undef;

	return bless \%params, $type;
}

##############################################################################
package App::Schedule::Analyze;
##############################################################################

use strict;
use Set::IntSpan;
use Date::Calc qw(:all);
use App::Schedule::Template;
use App::Schedule::Slot;
use App::Schedule::Utilities;
use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Org;
use App::Statements::Component::Scheduling;

use enum qw(BITMASK:MULTIRESOURCESEARCH_ SERIAL PARALLEL);
use enum qw(BITMASK:ANALYZEFETCHEVENTS_ BYTIME BYEVENTID);

use constant DEFAULT_SEARCH => MULTIRESOURCESEARCH_SERIAL;
use constant ANALYZE_ALLTEMPLATES => -99;
use constant APPT_DEFAULTDURATION => 10;

use vars qw($ANALYZE_INFINITY_DAYS);
$ANALYZE_INFINITY_DAYS = 10000;

my $WORKLIST_ITEMNAME = 'WorkList';

sub new
{
	my $type = shift;
	my %params = @_;
	my @today = Today();

	$params{resource_ids} = [] unless exists $params{resource_ids};
	$params{facility_ids} = [] unless exists $params{facility_ids};

	$params{search_start_date} = \@today unless exists $params{search_start_date};
	$params{search_duration}   = 7 unless exists $params{search_duration};

	$params{patient_type} = -1 unless exists $params{patient_type};
	$params{appt_type}   = -1 unless $params{appt_type};

	return bless \%params, $type;
}

sub findAvailSlots
{
	my ($self, $page, $flag, $eventId) = @_;

	$flag = DEFAULT_SEARCH unless $flag;
	my @scheduleObjects = $self->findScheduleObjects($page, 0, $eventId);

	my @available_slots = ();

	for my $facility_id (@{$self->{facility_ids}})
	{
		my $minute_set = new Set::IntSpan;
		my $initFlagForFacility = 1;

		for (@scheduleObjects)
		{
			next if $_->{facility_id} ne $facility_id;

			if ($flag & MULTIRESOURCESEARCH_PARALLEL) {
				if ($initFlagForFacility) {
					$initFlagForFacility = 0;
					$minute_set = $_->{minute_set};
				} else {
					$minute_set = $minute_set->intersect($_->{minute_set});
				}
			} else {
				push(@available_slots, $_);
			}
		}

		push(@available_slots, new App::Schedule::Object(facility_id=>$facility_id, minute_set=>$minute_set))
			if ($flag & MULTIRESOURCESEARCH_PARALLEL);
	}

	if ($page->param('debug')){
		for (@available_slots) {
			$page->addDebugStmt("$_->{resource_id} -- $_->{facility_id} -- @{[minuteSet_dayTime($_->{minute_set}->run_list())]} <br>");
		}
	}

	return @available_slots;
}

sub findUnAvailableAppointments
{
	my ($self, $page) = @_;
	my @unAvailSlots = ();

	my @scheduleObjects = $self->findScheduleObjects($page, 1);

	for my $resource_id (@{$self->{resource_ids}})
	{
		for my $facility_id (@{$self->{facility_ids}})
		{
			my @events = ();
			$self->findEventSlots($page, \@events, $resource_id, $facility_id);
			for my $e (@events)
			{
				my $day = $e->{day} - Date_to_Days(@{$self->{search_start_date}});
				my $dayMinutes = $day * 24 *60;
				my ($low, $high) = split(/\-/, $e->{minute_set}->run_list);
				$low  += $dayMinutes;
				$high += $dayMinutes;
				my $minute_range = "$low-$high";

				for (@scheduleObjects)
				{
					next unless ($_->{resource_id} eq $resource_id && $_->{facility_id} eq $facility_id);
					push (@unAvailSlots, $e) unless $_->{minute_set}->superset($minute_range);
					last;
				}
			}
		}
	}

	return @unAvailSlots;
}

sub findScheduleObjects
{
	my ($self, $page, $skipEvents, $eventId) = @_;

	my @scheduleObjects = ();

	$self->findResourceIds($page, \@{$self->{resource_ids}});
	
	unless (@{$self->{facility_ids}}) {
		@{$self->{facility_ids}} = ();
		$self->findFacilityIds($page, \@{$self->{facility_ids}});
	}

	for my $resource_id (@{$self->{resource_ids}})
	{
		for my $facility_id (@{$self->{facility_ids}})
		{
			my $object = new App::Schedule::Object(
				resource_id => $resource_id,
				facility_id => $facility_id,
				minute_set  => $self->buildMinuteSet($page, $resource_id, $facility_id, $skipEvents, $eventId)
			);
			push (@scheduleObjects, $object);
		}
	}

	return @scheduleObjects;
}

sub buildMinuteSet
{
	my ($self, $page, $resource_id, $facility_id, $skipEvents, $eventId) = @_;

	my $posMinuteSet = new Set::IntSpan;
	my $negMinuteSet = new Set::IntSpan;

	my $daysOffset = Date_to_Days(@{$self->{search_start_date}});

	my @templates = $self->getTemplates($page, $resource_id, $facility_id);
	for my $t (@templates)
	{
		my $template_days_set = $t->findTemplateDays($self->{search_duration}, @{$self->{search_start_date}});
		for ($template_days_set->first; $template_days_set->current; $template_days_set->next)
		{
			my $day = $template_days_set->current - $daysOffset;
			my $dayMinutes = $day * 24 *60;
			my $low  = hhmm2minutes($t->{start_time}) + $dayMinutes;
			my $high = hhmm2minutes($t->{end_time}) + $dayMinutes;

			if ($t->{available}) {
				my $minute_range = $low . "-" . $high;
				$posMinuteSet = $posMinuteSet->union($minute_range);
			} else {
				my $minute_range = ($low+1) . "-" . ($high-1);
				$negMinuteSet = $negMinuteSet->union($minute_range);
			}
		}
	}

	unless ($skipEvents)
	{
		my $eventsMinuteSet = $self->handleEventSlots($page, $resource_id, $facility_id, $eventId);
		$posMinuteSet = $posMinuteSet->diff($eventsMinuteSet);
	}

	return $posMinuteSet->diff($negMinuteSet);
}

sub handleEventSlots
{
	my ($self, $page, $resource_id, $facility_id, $eventId) = @_;

	my $eventsMinuteSet = new Set::IntSpan();
	my $daysOffset = Date_to_Days(@{$self->{search_start_date}});
	
	my %apptTypeTracker = ();
	
	my $flags |= ANALYZEFETCHEVENTS_BYEVENTID;
	my $events = $self->fetchEvents($page, $resource_id, $facility_id, $flags);

	for my $event (@{$events})
	{
		next if $event->{event_id} == $eventId;
		
		my @start_day = split (/,/, $event->{start_day});
		my $day = Date_to_Days(@start_day) - $daysOffset;
		my $dayMinutes = $day * 24 *60;
		
		if ($event->{appt_type_id} && $event->{appt_type_id} != -1)
		{
			my $effectiveMinuteSet = $self->handleApptType($page, \%apptTypeTracker, $event, $day);
			$eventsMinuteSet = $eventsMinuteSet->union($effectiveMinuteSet);
		}
		else
		{
			my $apptDuration = findApptDuration($page, $event->{appt_type_id});
			my $startMinute  = hhmm2minutes($event->{start_minute}) + $dayMinutes +1;
			my $endMinute    = $startMinute + $apptDuration -2;
			$eventsMinuteSet = $eventsMinuteSet->union("$startMinute-$endMinute");
		}
	}
	
	#for my $key (sort keys %apptTypeTracker)
	#{
	#	for my $subkey (sort keys %{$apptTypeTracker{$key}} )
	#	{
	#		$page->addDebugStmt( "$key:$subkey ==> $apptTypeTracker{$key}->{$subkey}" );
	#	}
	#}
	
	return $eventsMinuteSet;
}

sub handleApptType
{
	my ($self, $page, $apptTypeRef, $event, $day) = @_;
	
	$self->populateApptTypeTracker($page, $apptTypeRef, $event, $day);

	my $apptType = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE, 'selApptTypeById', 
		$event->{appt_type_id});

	$page->property('apptType', $apptType);		
	
	my $effectiveMinuteSet = new Set::IntSpan();
	if ($self->{appt_type} && $self->{appt_type} != -1)
	{
		$effectiveMinuteSet = $self->processApptTypeRules($page, $apptTypeRef, $event, $day);
	}
	else
	{
		my $dayMinutes = $day * 24 *60;
		my $apptDuration = findApptDuration($page, $event->{appt_type_id});
		my $startMinute  = hhmm2minutes($event->{start_minute}) + $dayMinutes +1;
		my $endMinute    = $startMinute + $apptDuration -2;

		$startMinute -= $apptType->{lead_time} if $apptType->{lead_time};
		$endMinute += $apptType->{lag_time} if $apptType->{lag_time};

		$effectiveMinuteSet = $effectiveMinuteSet->copy("$startMinute-$endMinute");
	}
	
	return $effectiveMinuteSet;
}

sub processApptTypeRules
{
	my ($self, $page, $apptTypeRef, $event, $day) = @_;
	
	my $dayMinutes = $day * 24 *60;
	my $apptTypeId = $event->{appt_type_id};
	my $key = $day . '_' . $apptTypeId;
	my $apptTime = $event->{start_minute};
	
	my $apptType = $page->property('apptType');
	my ($low, $high);
	
	my $minuteSet = new Set::IntSpan();
	my $effectiveMinuteSet = new Set::IntSpan();

	if ($apptType->{day_limit} && $apptTypeRef->{$key}->{count} >= $apptType->{day_limit}
		&& $self->{appt_type} == $apptType->{appt_type_id}
	)
	{
		$low = $dayMinutes+1;
		$high = $dayMinutes+1439;
		return new Set::IntSpan("$low-$high");
	}

	if ( $self->{appt_type} == $apptType->{appt_type_id} && 
			(
				$apptTypeRef->{$key}->{amCount} >= $apptType->{am_limit} || 
				$apptTypeRef->{$key}->{pmCount} >= $apptType->{pm_limit}
			)
	)
	{
		if ($apptType->{am_limit} && $apptTypeRef->{$key}->{amCount} >= $apptType->{am_limit})
		{
			$low = $dayMinutes+1;
			$high = $dayMinutes+719;
			$minuteSet = $minuteSet->copy("$low-$high");
			$effectiveMinuteSet = $effectiveMinuteSet->union($minuteSet)
		}

		if ($apptType->{pm_limit} && $apptTypeRef->{$key}->{pmCount} >= $apptType->{pm_limit})
		{
			$low = $dayMinutes+721;
			$high = $dayMinutes+1439;
			$minuteSet = $minuteSet->copy("$low-$high");
			$effectiveMinuteSet = $effectiveMinuteSet->union($minuteSet)
		}
	
		return $effectiveMinuteSet;
	}

	if ( ($event->{appt_type_id} != $self->{appt_type}) || (! $apptType->{multiple} && ! $apptType->{num_sim}) ||
		($apptType->{multiple} && $apptTypeRef->{$key}->{$apptTime} >= $apptType->{num_sim})
	)
	{
		my $dayMinutes = $day * 24 *60;
		my $apptDuration = findApptDuration($page, $event->{appt_type_id});
		my $startMinute  = hhmm2minutes($event->{start_minute}) + $dayMinutes +1;
		my $endMinute    = $startMinute + $apptDuration -2;

		#$startMinute -= $apptType->{lead_time} if $apptType->{lead_time};
		#$endMinute += $apptType->{lag_time} if $apptType->{lag_time};

		$effectiveMinuteSet = $effectiveMinuteSet->copy("$startMinute-$endMinute");
	} 
	else
	{
		$effectiveMinuteSet = $effectiveMinuteSet->copy("");
	}
	
	if ($event->{appt_type_id} == $self->{appt_type})
	{
		my $dayMinutes = $day * 24 *60;
		my $apptDuration = findApptDuration($page, $event->{appt_type_id});

		my $startMinute  = hhmm2minutes($event->{start_minute}) + $dayMinutes +1;
		my $endMinute    = $startMinute + $apptDuration -2;

		$startMinute -= $apptType->{lead_time} if $apptType->{lead_time};
		$endMinute += $apptType->{lag_time} if $apptType->{lag_time};
		
		if (! $apptType->{back_to_back})
		{
			my $effectiveDuration = $endMinute - $startMinute;
			my $back2backStartMinute = $startMinute - $effectiveDuration;
			my $back2backEndMinute = $endMinute + $effectiveDuration;
		
			$effectiveMinuteSet = $effectiveMinuteSet->union("$back2backStartMinute-$back2backEndMinute");
		}
		else
		{
			$effectiveMinuteSet = $effectiveMinuteSet->union("$startMinute-$endMinute");
		}

		if ($apptTypeRef->{$key}->{$apptTime} < $apptType->{num_sim})
		{
			my $rawStartTime = hhmm2minutes($event->{start_minute}) + $dayMinutes;
			my $rawEndTime = $rawStartTime + $apptDuration;
			$effectiveMinuteSet = $effectiveMinuteSet->diff("$rawStartTime-$rawEndTime");
		}
	}
	
	return $effectiveMinuteSet;
}

sub populateApptTypeTracker
{
	my ($self, $page, $apptTypeRef, $event, $day) = @_;
	
	my $apptTypeId = $event->{appt_type_id};
	my $key = $day . '_' . $apptTypeId;
	my $apptTime = $event->{start_minute};
	
	$apptTypeRef->{$key}->{count}++;
	$apptTypeRef->{$key}->{$apptTime}++;

	if ($event->{start_minute} < 1200)
	{
		$apptTypeRef->{$key}->{amCount}++;
	}
	else
	{
		$apptTypeRef->{$key}->{pmCount}++;
	}
}

sub findApptDuration
{
	my ($page, $apptTypeId) = @_;
	return APPT_DEFAULTDURATION if ($apptTypeId == -1 || ! $apptTypeId);

	my $apptType = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,	'selApptTypeById', 
		$apptTypeId);

	return $apptType->{duration};
}

sub findEventSlots
{
	my ($self, $page, $eventSlotsRef, $resource_id, $facility_id, $eventId) = @_;

	my $events = $self->fetchEvents($page, $resource_id, $facility_id);
	
	@{$eventSlotsRef} = ();

	for my $event (@{$events})
	{
		next if $event->{event_id} == $eventId;

		my @start_day = split (/,/, $event->{start_day});
		my $day = Date_to_Days(@start_day);
		
		my $apptDuration = findApptDuration($page, $event->{appt_type_id});
		
		my $slot = new App::Schedule::Slot (day=>$day);
		my $end_minute = hhmm2minutes($event->{start_minute}) + $apptDuration;
		my $minute_range = hhmm2minutes($event->{start_minute}) . "-" . $end_minute;
		$slot->{minute_set} = new Set::IntSpan ("$minute_range");

		for my $key (keys %{$event})
		{
			$slot->{attributes}->{$key} = Trim($event->{$key});
		}

		# Store facility name instead of org_internal_id
		$slot->{attributes}->{facility_id} = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE,
			'selId', $slot->{attributes}->{facility_id});

		if ($event->{event_status}) {
			$slot->{attributes}->{status} =	($event->{event_status} =~ /1/) ?
				"Checked IN" : "Checked OUT";
			$slot->{attributes}->{checkinout_stamp} =	($event->{event_status} =~ /1/) ?
				$event->{checkin_stamp} : $event->{checkout_stamp};
		}
	
		push (@$eventSlotsRef, $slot);
	}

	# Find conflicts

	my @slots = sort {$a->{attributes}->{event_id} <=> $b->{attributes}->{event_id}} 
		@$eventSlotsRef;
	
	for my $slot (@slots)
	{
		if ($slot->{attributes}->{parent_id})
		{
			$slot->{attributes}->{conflict} = "On Waiting List";
		}
		else
		{
			my $existingSlot = $slot->{minute_set};
			$existingSlot = $existingSlot->diff($existingSlot->max());
			$existingSlot = $existingSlot->diff($existingSlot->min());
			
			for (@$eventSlotsRef)
			{
				next if ($_->{attributes}->{event_id} == $slot->{attributes}->{event_id});
				my $intersectSet = $_->{minute_set}->intersect($existingSlot);
				
				unless ($intersectSet->empty) {
					if ($slot->{attributes}->{event_id} < $_->{attributes}->{event_id})
					{
						$_->{attributes}->{conflict} = $_->{attributes}->{parent_id} ?
							"On Waiting List" : "*** Over-Booked ***";
					}
					else
					{
						$slot->{attributes}->{conflict} = $slot->{attributes}->{parent_id} ?
							"On Waiting List" : "*** Over-Booked ***";
					}
					
					last;
				}
			}
		}
	}
	
}

sub fetchEvents
{
	my ($self, $page, $resource_id, $facility_id, $flags) = @_;
	
	my @start_Date = @{$self->{search_start_date}};
	my @end_Date   = Add_Delta_Days (@start_Date, $self->{search_duration});

	my $startDate = sprintf("%04d,%02d,%02d", $start_Date[0],$start_Date[1],$start_Date[2]);
	my $endDate   = sprintf("%04d,%02d,%02d", $end_Date[0],$end_Date[1],$end_Date[2]);

	my $events;

	if ($flags & ANALYZEFETCHEVENTS_BYEVENTID)
	{
		$events = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_analyze_events', $startDate, $endDate, $facility_id, $resource_id);
	}
	else
	{
		if ($facility_id) {
			$events = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_at_facility', $startDate, $endDate, $facility_id, $resource_id);
		} else {
			$events = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_any_facility', $startDate, $endDate, $resource_id);
		}
	}
	
	return $events;
}

# --------------------------------------------------------------------------------
sub findTemplateSlots
{
	my ($self, $page, $posSlotsRef, $negSlotsRef, $posDaysSetRef, $negDaysSetRef, @templates) = @_;

	@{$posSlotsRef} = ();
	@{$negSlotsRef} = ();

	my @pTemplates = ();
	my @nTemplates = ();

	for my $templ (@templates)
	{
		my $template_days_set = $templ->findTemplateDays($self->{search_duration}, @{$self->{search_start_date}});

		for ($template_days_set->first; $template_days_set->current; $template_days_set->next)
		{
			my $day = $template_days_set->current;

			if ($templ->{available}) {
				my $slot = new App::Schedule::Slot(day=>$day);
				my $minute_range = hhmm2minutes($templ->{start_time}) . "-" . hhmm2minutes($templ->{end_time});
				$slot->{minute_set} = new Set::IntSpan ("$minute_range");
				$$posDaysSetRef->insert($day);
				push(@pTemplates, $templ);
				$slot->{attributes}->{templates} = \@pTemplates;

				# $slot->{attributes}->{facility_id} = $templ->{facility_id};

				$slot->{attributes}->{facility_id} = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE,
					'selId', $templ->{facility_id});

				$slot->{attributes}->{resource_id} = $templ->{resource_id};
				push (@$posSlotsRef, $slot);

			} else { # Not available Template
				my $slot = new App::Schedule::Slot(day=>$day);
				my $minute_range = hhmm2minutes($templ->{start_time}) . "-" . hhmm2minutes($templ->{end_time});
				$slot->{minute_set} = new Set::IntSpan ("$minute_range");
				$$negDaysSetRef->insert($day);
				push(@nTemplates, $templ);
				$slot->{attributes}->{templates} = \@nTemplates;

				# $slot->{attributes}->{facility_id} = $templ->{facility_id};

				$slot->{attributes}->{facility_id} = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE,
					'selId', $templ->{facility_id});

				$slot->{attributes}->{resource_id} = $templ->{resource_id};
				push (@$negSlotsRef, $slot);

			} #end if handling positive or negative template

		} # done with all days of this template

	} # done with all templates (of this resource)
}

# ---------------------------------------------------------------------------
sub getTemplates
{
	my ($self, $page, $resource_id, $facility_id) = @_;
	my @templates = ();

	# Query database for all templates of this resource at this facility

	my $patientTypeTable = "";
	my $apptTypeTable = "";

	my $patientTypeWhereClause = "";
	my $apptTypeWhereClause = "";

	my $patientTypeTableJoinClause = "";
	my $apptTypeTableJoinClause = "";

	my @bindParams = ($resource_id);

	my $facilityWhereClause = "";
	if ($facility_id)
	{
		$facilityWhereClause = "and facility_id = ?" ;
		push(@bindParams, $facility_id);
	}

	if ($self->{patient_type} >= 0)
	{
		$patientTypeTable = ', Sch_Template_Patient_types';
		$patientTypeWhereClause = "or Sch_Template_patient_types.member_name = ?";
		$patientTypeTableJoinClause = "and Sch_Template_Patient_Types.parent_id (+) = Sch_Template.template_id";
		push(@bindParams, $self->{patient_type});
	}

	if ($self->{appt_type} >= 0)
	{
		$apptTypeTable = ', Sch_Template_Appt_Types';
		$apptTypeWhereClause = "or Sch_Template_Appt_Types.member_name = ?";
		$apptTypeTableJoinClause = "and Sch_Template_Appt_Types.parent_id (+) = Sch_Template.template_id";
		push(@bindParams, $self->{appt_type});
	}

	my $query1 = qq{
		select to_char(nvl(effective_begin_date,SYSDATE - $ANALYZE_INFINITY_DAYS), 'yyyy,mm,dd') as effective_begin_date,
			to_char(nvl(effective_end_date, SYSDATE + $ANALYZE_INFINITY_DAYS), 'yyyy,mm,dd') as effective_end_date,
			months, days_of_week, days_of_month,
			to_char(nvl(start_time,trunc(sysdate)), 'hh24mi') as start_time,
			to_char(nvl(end_time,trunc(sysdate)-1/24/3600), 'hh24mi') as end_time,
			available, facility_id, template_id, caption, patient_types, appt_types,
			Sch_Template_R_Ids.member_name as attendee_id
		from Sch_Template, Sch_Template_R_IDs $patientTypeTable $apptTypeTable
		where upper(Sch_Template_R_Ids.member_name) = upper(?)
			$facilityWhereClause
			and status = 1
			and nvl(effective_end_date, sysdate+1) > sysdate
			and Sch_Template.template_id = Sch_Template_R_Ids.parent_id
			and (Sch_Template.patient_types is NULL
				or not exists (select ID from Appt_Attendee_Type minus
					(select to_number(member_name) from Sch_Template_Patient_Types where parent_id = template_id)
				)
				$patientTypeWhereClause
			)
			$patientTypeTableJoinClause
			and (Sch_Template.appt_types is NULL
				or not exists (select appt_type_id from appt_type minus
					(select to_number(member_name) from Sch_Template_Appt_Types where parent_id = template_id)
				)
				$apptTypeWhereClause
			)
			$apptTypeTableJoinClause
	};

	my $query2 = qq{
		select to_char(nvl(effective_begin_date,SYSDATE - $ANALYZE_INFINITY_DAYS), 'yyyy,mm,dd') as effective_begin_date,
			to_char(nvl(effective_end_date, SYSDATE + $ANALYZE_INFINITY_DAYS), 'yyyy,mm,dd') as effective_end_date,
			months, days_of_week, days_of_month,
			to_char(nvl(start_time,trunc(sysdate)), 'hh24mi') as start_time,
			to_char(nvl(end_time,trunc(sysdate)-1/24/3600), 'hh24mi') as end_time,
			available, facility_id, template_id, caption, patient_types, appt_types,
			Sch_Template_R_Ids.member_name as attendee_id
		from Sch_Template, Sch_Template_R_Ids
		where upper(Sch_Template_R_Ids.member_name) = upper(?)
			$facilityWhereClause
			and status = 1
			and nvl(effective_end_date, sysdate+1) > sysdate
			and Sch_Template.template_id = Sch_Template_R_Ids.parent_id
	};

	my $query =  (($self->{patient_type} == ANALYZE_ALLTEMPLATES)
		|| ($self->{appt_type}  == ANALYZE_ALLTEMPLATES)) ? $query2 : $query1;

	my $schedTemplates = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_DYNAMICSQL, $query, @bindParams);
	for my $t (@{$schedTemplates})
	{
		my @sdate = split(/,/, $t->{effective_begin_date});
		my @edate = split(/,/, $t->{effective_end_date});

		my $templ = new App::Schedule::Template (
			effective_begin_date => \@sdate,
			effective_end_date => \@edate,
			months => $t->{months},
			days_of_week => $t->{days_of_week},
			days_of_month => $t->{days_of_month},
			start_time => $t->{start_time},
			end_time => $t->{end_time},
			available => $t->{available},
			facility_id => $t->{facility_id},
			template_id => $t->{template_id},
			caption => $t->{caption},
			patient_types => $t->{patient_types},
			appt_types => $t->{appt_types},
			resource_id => $t->{attendee_id},
		);

		push (@templates, $templ);
	}

	return @templates;  # List of Template objects
}

sub findResourceIds
{
	my ($self, $page, $arrayRef) = @_;

	unless (@{$arrayRef})
	{
		#my $assocResources = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		#	'sel_worklist_resources', $page->session('user_id'), $WORKLIST_ITEMNAME,
		#	$page->session('org_internal_id'));

		my $assocResources = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_resources_with_templates', $page->session('org_internal_id'));

		for (@$assocResources) {
			push(@$arrayRef, $_->{resource_id});
		}
	}
}

sub findFacilityIds
{
	my ($self, $page, $arrayRef) = @_;

	#my $assocFacilities = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
	#	'sel_worklist_facilities', $page->session('user_id'), $page->session('org_internal_id'));

	my $assocFacilities = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'sel_facilities_from_templates', $page->session('org_internal_id'));

	for (@$assocFacilities) {
		push(@$arrayRef, $_->{facility_id});
	}
}

1;
