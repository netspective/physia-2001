##############################################################################
package App::Statements::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

my $EVENTATTRTYPE_APPOINTMENT = App::Universal::EVENTATTRTYPE_APPOINTMENT;
my $ASSOC_VALUE_TYPE = App::Universal::ATTRTYPE_RESOURCEPERSON;

use vars qw(@ISA @EXPORT $STMTMGR_SCHEDULING $STMTRPTDEFN_TEMPLATEINFO $STMTFMT_SEL_TEMPLATEINFO
	$STMTFMT_SEL_EVENTS
);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_SCHEDULING);

my $timeFormat = 'HH:MI AM';

$STMTFMT_SEL_TEMPLATEINFO = qq{
	select template_id,
		r_ids as resources,
		caption,
		org_id,
		to_char(start_time - ?, '$timeFormat') as start_time,
		to_char(end_time - ?, '$timeFormat') as end_time,
		to_char(effective_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as begin_date,
		to_char(effective_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as end_date,
		decode(available,0,'Not Available',1,'Available') as available,
		patient_types,
		appt_types,
		days_of_month,
		months,
		days_of_week
	from Org, Sch_Template
	where Sch_Template.owner_org_id = ?
		and facility_id = org_internal_id
		and upper(r_ids) like upper(?)
		and upper(org_id) like upper(?)
		and (available = ? or available = ?)
		%effectiveWhereClause%
	order by available, r_ids, template_id
};

$STMTFMT_SEL_EVENTS = qq{
	select to_char(e.start_time - :1, 'hh24mi') as start_minute,
		to_char(e.start_time - :1, 'yyyy,mm,dd') as start_day,
		e.duration,
		e.event_id,
		ea.value_text as patient_id,
		ea.value_textB as resource_id,
		patient.name_last || ', ' || substr(patient.name_first,1,1) as short_patient_name,
		patient.complete_name as patient_complete_name,
		e.subject,
		aat.caption as patient_type,
		e.remarks,
		e.event_status,
		e.facility_id,
		to_char(e.checkin_stamp - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkin_stamp,
		to_char(e.checkout_stamp - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkout_stamp,
		stat.caption as appt_status,
		e.parent_id,
		e.scheduled_by_id,
		to_char(e.scheduled_stamp - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as scheduled_stamp,
		at.caption as appt_type,
		e.appt_type as appt_type_id
	from Appt_Type at, Appt_Status stat, Appt_Attendee_type aat, Person patient,
		Event_Attribute ea, Event e
	where e.start_time >= to_date(:2, 'yyyy,mm,dd') + :1
		and e.start_time < to_date(:3, 'yyyy,mm,dd') + :1
		and e.discard_type is null
		and e.event_status in (0,1,2)
		%facilityClause%
		and ea.parent_id = e.event_id
		and ea.value_text = patient.person_id
		and upper(ea.value_textB) = upper(:5)
		and ea.value_type = $EVENTATTRTYPE_APPOINTMENT
		and aat.id = ea.value_int
		and stat.id = e.event_status
		and at.appt_type_id (+) = e.appt_type
		%orderByClause%
};

$STMTRPTDEFN_TEMPLATEINFO =
{
	columnDefn =>
		[
			{ head => 'ID', url => q{javascript:location.href='/schedule/dlg-update-template/#&{?}#?_dialogreturnurl=/search/template'}, hint => 'Edit Template #&{?}#'},
			{ head => 'Resource(s)', url => q{javascript:location.href='/search/template/1/#&{?}#'}, hint => 'View #&{?}# Templates'},
			{ head => 'Caption'},
			{ head => 'Facility', url => q{javascript:location.href='/search/template/1//#&{?}#'}, hint => 'View #&{?}# Templates'},
			{ head => 'Effective', dataFmt => '#6#-<br>#7#', },
			{ head => 'Time', dataFmt => '#4#-<br>#5#',},
			{ head => 'Available', colIdx => 8,},
			{ head => 'Days', colIdx => 11,},
			{ head => 'Months', colIdx => 12,},
			{ head => 'Weekdays', colIdx => 13,},
			{ head => 'Patient/ Visit', dataFmt => '#9#<br>#10#',},
		],
};

# -------------------------------------------------------------------------------------------
$STMTMGR_SCHEDULING = new App::Statements::Scheduling(

	'sel_events_at_facility' =>
	{
		sqlStmt => $STMTFMT_SEL_EVENTS,
		facilityClause => 'and e.facility_id = :4',
		orderByClause => 'order by e.start_time, nvl(e.parent_id, 0), e.event_id',
	},

	'sel_analyze_events' =>
	{
		sqlStmt => $STMTFMT_SEL_EVENTS,
		facilityClause => 'and e.facility_id = :4',
		orderByClause => 'order by nvl(e.parent_id, 0), e.event_id',
	},

	'sel_events_any_facility' =>
	{
		sqlStmt => $STMTFMT_SEL_EVENTS,
		facilityClause => 'and e.facility_id > :4',
		orderByClause => 'order by e.start_time, nvl(e.parent_id, 0), e.event_id',
	},

	'updSchedulingPref' => qq{
		update Person_Attribute set value_int = value_int-1
		where parent_id = ?
			and value_int > ?
			and item_name like 'Preference/Schedule/DayView/Column%'
			and parent_org_id = ?
	},

	'selCompleteName' => qq{
		select complete_name from Person where person_id = ?
	},

	'selFacilityName' => qq{
		select name_primary from Org
		where org_internal_id = ?
	},
	'selApptDuration' => qq{
		select id, caption
		from appt_duration
	},
	'selFacilityList' => qq{
		select distinct o.ORG_ID, o.NAME_PRIMARY
		from org o, org_category oc
		where o.ORG_ID = oc.PARENT_ID
			and UPPER(oc.MEMBER_NAME) in ('FACILITY','CLINIC')
	},
	'sel_eventInfo' => {
		_stmtFmt => qq{
			select event_status, checkin_by_id, checkout_by_id, 
				to_char(checkin_stamp - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkin_stamp,
				to_char(checkout_stamp - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkout_stamp
			from Event
			where event_id = :2
		}
	},

	# --------------------------------------------------------------------------------------------
	'selPatientInfo' => qq{
		select complete_name, pa1.value_text as hphone, pa2.value_text as wphone, complete_addr_html,
		pa3.value_text as email
		from Person_Address, Person_Attribute pa3, Person_Attribute pa2, Person_Attribute pa1, Person
		where person_id = ?
		and pa1.parent_id (+) =  Person.person_id
		and pa1.item_name (+) = 'Contact Method/Telephone/Home'
		and pa2.parent_id (+) = Person.person_id
		and pa2.item_name (+) = 'Contact Method/Telephone/Work'
		and pa3.parent_id (+) = Person.person_id
		and pa3.item_name (+) = 'Contact Method/EMail/Primary'
		and Person_Address.parent_id = Person.person_id
	},

	'selEncountersCheckIn/Out' => qq{
		select e.event_id, e.parent_id, e.facility_id as service_facility_id, e.event_status, e.event_type, e.subject,
			to_char(e.start_time - :1, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time,
			e.duration, e.remarks, e.owner_id,
			e.scheduled_by_id, e.scheduled_stamp, e.checkin_by_id, at.caption as appt_type,
			ea.value_text as attendee_id, ea.value_int as attendee_type,
			ea.value_textB as care_provider_id, '2' as bill_type
		from Appt_Type at, Event_Attribute ea, Event e
		where e.event_id = :2
			and ea.parent_id = e.event_id
			and ea.value_type = $EVENTATTRTYPE_APPOINTMENT
			and at.appt_type_id(+) = e.appt_type
	},

	'selEventAttribute' => qq{
		select *
		from event_attribute
		where parent_id = ?
			and value_type = ?
	},

	'selColumnPreference' => qq{
		select item_id, value_text as resource_id, org_id as facility_id,
			nvl(value_intb, 0) as date_offset
		from Org, Person_Attribute
		where parent_id = ?
			and item_name = 'Preference/Schedule/DayView/Column'
			and value_int = ?
			and org_internal_id (+) = to_number(value_textb)
			and Person_Attribute.parent_org_id = ?
	},

	'selApptSheetTimes' => qq{
		select value_int as start_time, value_intB as end_time
		from Person_Attribute
		where parent_id = ?
			and item_name = 'ApptSheet Times'
	},

	'insApptSheetTimesPref' => qq{
		insert into Person_Attribute
		(parent_id, item_name        , value_int, value_intB)
		values
		(?        , 'ApptSheet Times', ?        , ?         )
	},

	'updApptSheetTimesPref' => qq{
		update Person_Attribute set
			value_int  = ?,
			value_intB = ?
		where parent_id = ?
			and item_name = 'ApptSheet Times'
	},

	'selNumPreferences' => qq{
		select count(*) from Person_Attribute
		where parent_id = ?
			and item_name = 'Preference/Schedule/DayView/Column'
			and parent_org_id = ?
	},

	'selPopulateTemplateDialog' => qq{
		select template_id, caption, r_ids, facility_id, available, status, remarks,
			preferences, days_of_month, months, days_of_week, patient_types, appt_types,
			to_char(effective_begin_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_begin_date,
			to_char(effective_end_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_end_date,
			to_char(start_time - :1, '$timeFormat') as duration_begin_time,
			to_char(end_time - :1,'$timeFormat') as duration_end_time
		from Sch_Template_R_Ids, Sch_Template
		where template_id = :2
			and parent_id = template_id
			and rownum = 1
	},

	'selPopulateApptTypeDialog' => qq{
		select appt_type_id, r_ids, caption, duration, lead_time, lag_time, back_to_back,
			multiple, num_sim, rr_ids, am_limit, pm_limit, day_limit
		from Appt_Type
		where appt_type_id = :1
	},

	'selPopulateAppointmentDialog' => qq{
		select e.event_id, e.facility_id, e.event_status, e.event_type, e.subject,
			to_char(e.start_time - :1, '$SQLSTMT_DEFAULTDATEFORMAT') as appt_date_0,
			to_char(e.start_time - :1, '$timeFormat') as appt_time_0,
			e.duration, e.remarks, e.owner_id,
			e.scheduled_by_id, e.scheduled_stamp, e.checkin_by_id,
			ea.value_text as attendee_id,
			ea.value_int as patient_type,
			ea.value_textB as resource_id,
			e.appt_type, e.parent_id
		from Event_Attribute ea, event e
		where event_id = :2
			and ea.parent_id = e.event_id
			and ea.value_type = $EVENTATTRTYPE_APPOINTMENT
	},

	'selApptTypeById' => qq{
		select * from Appt_Type where appt_type_id = :1
	},

	'selSchedulePreferences' => qq{
		select item_id, value_text as resource_id, value_textb as facility_id,
			value_int as column_no, value_intb as offset
		from Person_Attribute
		where parent_id = ?
			and item_name = ?
		order by column_no
	},

	'selSchedulePreferencesByOrg' => qq{
		select item_id, value_text as resource_id, value_textb as facility_id,
			value_int as column_no, value_intb as offset
		from Person_Attribute
		where parent_id = ?
			and item_name = ?
			and parent_org_id = ?
		order by column_no
	},

	'selActionOption' => qq{
		select item_id, value_int from Person_Attribute
		where parent_id = ?
			and item_name = ?
	},

	'selExistingApptInfo' => qq{
		select event_type, subject, duration, remarks, facility_id, value_int as attendee_type
		from Event_Attribute, Event
		where event_id = ?
		and Event_Attribute.parent_id = Event.event_id
		and Event_Attribute.value_type = $EVENTATTRTYPE_APPOINTMENT
	},

	'selEffectiveTemplate' =>
	{
		sqlStmt => $STMTFMT_SEL_TEMPLATEINFO,
		#simpleReport => $STMTRPTDEFN_TEMPLATEINFO,
		publishDefn => $STMTRPTDEFN_TEMPLATEINFO,
		effectiveWhereClause => qq{
			and status = ?
			and nvl(effective_end_date, sysdate+1) > sysdate},
	},

	'selInEffectiveTemplate' =>
	{
		sqlStmt => $STMTFMT_SEL_TEMPLATEINFO,
		#simpleReport => $STMTRPTDEFN_TEMPLATEINFO,
		publishDefn => $STMTRPTDEFN_TEMPLATEINFO,
		effectiveWhereClause => qq{
			and (status = ? or
				(	effective_end_date is NOT NULL
					and trunc(effective_end_date) < trunc(sysdate)
				)
			)
		},
	},

	'selApptTypeSearch' =>
	{
		sqlStmt => qq{
			select distinct
				appt_type_id, r_ids, caption, duration, lead_time, lag_time,
				decode(back_to_back, 0, 'No', 1, 'Yes', 'No'),
				decode(multiple, 0, 'No', 1, 'Yes', 'No'),
				num_sim, am_limit, pm_limit, rr_ids, day_limit
			from Appt_Type_R_Ids, Appt_Type
			where owner_org_id = :1
				and (upper(member_name) = upper(:2) or upper(r_ids) like upper(:3))
				and upper(caption) like upper(:4)
				and Appt_Type_R_Ids.parent_id = appt_type_id
			order by caption, r_ids, appt_type_id
		},

		publishDefn =>
		{
			columnDefn =>
			[
				{ head => 'ID',
					url => q{javascript:chooseItem('/org/#session.org_id#/dlg-update-appttype/#&{?}#', '#2#', false, '#0#')},
				},
				{ head => 'Caption/ Resource',
					dataFmt => qq{
						Caption: <b>#2# </b><br>
						<a href="javascript:location.href='/search/appttype/1/#1#'"
							title='View #1# Appointment Types' style="text-decoration:none" >#1#</a> <br>
					},
				},
				{ head => 'Details',
					dataFmt => qq{
						<nobr>Duration: <b>#3# minutes</b></nobr><br>
						<nobr>Lead / Lag Time: #4# / #5# minutes</nobr><br>
						Add'l Resources: <i>#11#</i>
					},
				},
				{ head => 'Addl Details',
					dataFmt => qq{
						<nobr>Back-to-Back: #6# </nobr><br>
						<nobr>Multiple / Limits: #7# / #8#</nobr><br>
						<nobr>Limits Day/AM/PM: #12# / #9# / #10# / </nobr><br>
					},
				},

			],
		}
	},

	'sel_AllApptTypes' => qq{
		select appt_type_id, caption || ' (' || appt_type_id || ')' as caption
		from Appt_Type
		where owner_org_id = :1
		order by caption
	},

	'sel_ApptTypesDropDown' => qq{
		select appt_type_id, caption || ' (' || appt_type_id || ')' as caption
		from Appt_Type
		where owner_org_id = :1
		UNION
		select 0 as appt_type_id, ' ' as caption from Dual
		order by caption
	},

	'selResourcesAtFacility' => qq{
		select distinct attendee_id
		from Template
		where facility_id = ?
	},

	'selAssociatedResources' => qq{
		select value_text as resource_id, value_textb as facility_id
		from Person_Attribute
		where parent_id = ?
			and value_type = $ASSOC_VALUE_TYPE
			and item_name = 'Physician'
			and parent_org_id = ?
	},

	'selRovingPhysicianTypes' => qq{
		select translate(caption, '/ ', '__') as caption
		from Medical_Specialty
		where group_name = 'Physician Specialty'
		UNION
		select ' ' as caption from Dual
		order by caption
	},

	'updAssignResource' => qq{
		update Event_Attribute set value_textB = ?
		where upper(value_textB) = upper(?)
		and parent_id in
			(select event_id from Event
				where start_time between to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT') + ?
					and to_date (?, '$SQLSTMT_DEFAULTDATEFORMAT')  + ? +1
					and facility_id = ?
			)
	},

	'updAssignResource_noFacility' => qq{
		update Event_Attribute set value_textB = ?
		where upper(value_textB) = upper(?)
		and parent_id in
			(select event_id from Event
				where start_time between to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT') + ?
					and to_date (?, '$SQLSTMT_DEFAULTDATEFORMAT')  + ? +1
					and owner_id = ?
			)
	},

	'selPatientTypes' => qq{
		select id, caption from Appt_Attendee_Type
	},

	#'selVisitTypes' => qq{
	#	select id, caption from Transaction_Type where id>=2040 and id<3000
	#},

	'selPatientTypesDropDown' => qq{
		select id, caption from Appt_Attendee_Type
		UNION
		select -1 as id, ' ' as caption from dual
		order by caption
	},

	'selRovingResources' => qq{
		select distinct member_name from Sch_Template_R_Ids where upper(member_name) like ?
	},

	'sel_resources_with_templates' => qq{
		select distinct member_name as resource_id
		from Sch_Template_R_Ids
		where parent_id in (select template_id from Sch_Template where owner_org_id = ?)
	},

	'sel_facilities_from_templates' => qq{
		select distinct facility_id
		from Sch_Template
		where owner_org_id = ?
	},

	'sel_resources_like' => qq{
		select distinct member_name as person_id
		from Sch_Template_R_Ids
		where upper(member_name) like upper(?)
			and parent_id in (select template_id from Sch_Template where owner_org_id = ?)
	},

	'sel_facilities_like' => qq{
		select distinct org_internal_id, org_id
		from Org, Sch_Template
		where upper(org_id) like upper(?)
			and Org.org_internal_id = Sch_Template.facility_id
			and Sch_Template.owner_org_id = ?
	},

# -- WAITING LIST -----------------------------------------------------------------------------

	'selAppointmentConflictCheck' => qq{
		select to_char(start_time - ?, 'hh24mi') as start_minute,
			to_char(start_time - ?, 'yyyy,mm,dd') as start_day, duration,
			event_id,	ea.value_text as patient_id, ea.value_textB as resource_id,
			Event.parent_id, Event.appt_type
		from 	Event_Attribute ea, Event
		where start_time between to_date(?, 'yyyy,mm,dd') + ?
			and to_date(?, 'yyyy,mm,dd') + ?
			and discard_type is null
			and event_status in (0,1,2)
			and facility_id = ?
			and ea.parent_id = event_id
			and ea.value_textB = ?
			and ea.value_type = $EVENTATTRTYPE_APPOINTMENT
		order by nvl(Event.parent_id, 0), event_id
	},

	'selCountWaiting' => qq{
		select count(*) +1 from Event where parent_id = ? and event_status < 3
	},

	'selNextInLineEventID' => qq{
		select min(event_id) from Event where parent_id = ? and event_status < 3
	},

	'updShiftWaitingList_ParentCancel' => qq{
		update Event_Attribute set value_intB = value_intB -1
		where parent_id in (select event_id from Event where Event.parent_id = ? and event_status < 3)
	},

	'updShiftWaitingList_BrotherCancel' => qq{
		update Event_Attribute set value_intB = value_intB -1
		where parent_id in (select event_id from Event where Event.parent_id = ?)
		and value_intB > ?
	},

	'updCleanUpWaitingList0' => qq{
		update Event_Attribute set value_intB = NULL
		where value_type = $EVENTATTRTYPE_APPOINTMENT
			and value_intB <= 0
	},

	'updParentEventToNULL' => qq{
		update Event set parent_id = NULL where event_id = ?
	},

	'updSetNewParentEvent' => qq{
		update Event set parent_id = ? where parent_id = ?
	},

	'selParentEventID' => qq{
		select parent_id from Event where event_id = ?
	},

	'selOrderInLine' => qq{
		select value_intB from Event_Attribute where parent_id = ? and value_intB is NOT NULL
	},

	'selWaitingPatients' => qq{
		select value_text, event_id
		from Event_Attribute, Event
		where Event.parent_id = ?
			and Event_Attribute.parent_id = Event.event_id
			and Event_Attribute.value_type = $EVENTATTRTYPE_APPOINTMENT
		union
		select 'None' as value_text, 9999999999999999 as event_id from Dual
		order by event_id
	},

	'sel_futureAppointments' => {
		sqlStmt => qq{
			select to_char(e.start_time - ?, '$SQLSTMT_DEFAULTSTAMPFORMAT') appt_time,
				ea.value_textB as physician, e.subject
			from Event_Attribute ea, Event e
			where e.start_time > sysdate
				and ea.parent_id = e.event_id
				and upper(ea.value_text) = upper(?)
				and e.owner_id = ?
			order by e.start_time
		},
	},
);

1;
