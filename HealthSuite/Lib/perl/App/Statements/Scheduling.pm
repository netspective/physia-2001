##############################################################################
package App::Statements::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

my $EVENTATTRTYPE_PATIENT = App::Universal::EVENTATTRTYPE_PATIENT;
my $EVENTATTRTYPE_PHYSICIAN = App::Universal::EVENTATTRTYPE_PHYSICIAN;
my $ASSOC_VALUE_TYPE = App::Universal::ATTRTYPE_RESOURCEPERSON;

use vars qw(@ISA @EXPORT $STMTMGR_SCHEDULING $STMTRPTDEFN_TEMPLATEINFO $STMTFMT_SEL_TEMPLATEINFO
	$STMTFMT_SEL_EVENTS 
);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_SCHEDULING);

$STMTFMT_SEL_TEMPLATEINFO = qq{
	select template_id, r_ids as resources, caption, facility_id,
		to_char(start_time, 'hh:miam') as start_time,
		to_char(end_time, 'hh:miam') as end_time,
		to_char(effective_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as begin_date,
		to_char(effective_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as end_date,
		decode(available,0,'NO',1,'YES') as available,
		facility_id, to_char(cr_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as cr_stamp
	from Template
	where r_ids like ?
		and facility_id like ?
		and (available = ? or available = ?)
	order by r_ids, template_id
};

$STMTFMT_SEL_EVENTS = qq{
	select to_char(e.start_time, 'hh24mi') as start_minute,
		to_char(e.start_time,'yyyy,mm,dd') as start_day, e.duration,
		e.event_id,	ep1.value_text as patient_id, ep2.value_text as resource_id,
		patient.name_last || ', ' || substr(patient.name_first,1,1) as short_patient_name,
		patient.complete_name as patient_complete_name,
		e.subject, et.caption as event_type, aat.caption as patient_type,
		e.remarks, e.event_status, e.facility_id,
		to_char(e.checkin_stamp,'$SQLSTMT_DEFAULTSTAMPFORMAT') as checkin_stamp,
		to_char(e.checkout_stamp,'$SQLSTMT_DEFAULTSTAMPFORMAT') as checkout_stamp,
		stat.caption as appt_status, e.parent_id,
		e.scheduled_by_id,
		to_char(e.scheduled_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as scheduled_stamp
	from 	Appt_Status stat, Appt_Attendee_type aat, Person patient,
		Event_Attribute ep2, Event_Attribute ep1,
		Event_Type et, Event e
	where e.start_time between to_date(?, 'yyyy,mm,dd')
			and to_date(?, 'yyyy,mm,dd')
		and e.discard_type is null
		and e.event_status in (0,1,2)
		%facility_clause%
		and et.id = e.event_type
		and ep1.parent_id = e.event_id
		and ep1.value_type = $EVENTATTRTYPE_PATIENT
			and ep1.value_text = patient.person_id
		and ep2.parent_id = ep1.parent_id
		and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
		and ep2.value_text = ?
		and aat.id = ep1.value_int
		and stat.id = e.event_status
	order by e.start_time, nvl(e.parent_id, 0), e.event_id
};

$STMTRPTDEFN_TEMPLATEINFO =
{
	columnDefn =>
		[
			#{ head => 'ID', url => 'javascript:location.href="/schedule/template/update/#&{?}#"', hint => 'Edit Template #&{?}#'},
			{ head => 'ID', url => 'javascript:location.href="/org/#session.org_id#/dlg-update-template/#&{?}#"', hint => 'Edit Template #&{?}#'},
			{ head => 'Resource(s)', url => 'javascript:location.href="/search/template/1/#&{?}#"', hint => 'View #&{?}# Templates'},
			{ head => 'Caption'},
			{ head => 'Facility', url => 'javascript:location.href="/search/template/1//#&{?}#"', hint => 'View #&{?}# Templates'},
			{ head => 'Start Time'},
			{ head => 'End Time'},
			{ head => 'Begin'},
			{ head => 'End'},
			{ head => 'Available'},
		],
};

# -------------------------------------------------------------------------------------------
$STMTMGR_SCHEDULING = new App::Statements::Scheduling(
	
	'del_SessionPhysicians' => qq{
		delete from Person_Attribute 
		where parent_id = ?
			and value_type = App::Universal::ATTRTYPE_RESOURCEPERSON
			and item_name = 'SessionPhysicians'
			and value_int = 1
	},

	'sel_events_at_facility' =>
	{
		_stmtFmt => $STMTFMT_SEL_EVENTS,
		facility_clause => 'and e.facility_id = ?',
	},

	'sel_events_any_facility' =>
	{
		_stmtFmt => $STMTFMT_SEL_EVENTS,
		facility_clause => undef,
	},

	'updSchedulingPref' => qq{
		update Person_Attribute set value_int = value_int-1
		where parent_id = ?
			and value_int > ?
			and item_name like 'Preference/Schedule/DayView/Column%'
	},

	'selCompleteName' => qq{
		select complete_name from Person where person_id = ?
	},

	'selFacilityName' => qq{
		select name_primary from Org where org_id = ?
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
			select event_status, checkin_by_id, checkout_by_id, %simpleStamp:checkin_stamp%
				as checkin_stamp, %simpleStamp:checkout_stamp% as checkout_stamp
			from Event 
			where event_id = ?
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
		select e.event_id, e.parent_id, e.facility_id, e.event_status, e.event_type, e.subject,
			to_char(e.start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time,
			e.duration, e.remarks, e.owner_id,
			e.scheduled_by_id, e.scheduled_stamp, e.checkin_by_id,
			ep1.value_text as attendee_id, ep1.value_int as attendee_type,
			ep2.value_text as provider_id, '2' as bill_type
		from event_attribute ep1, event_attribute ep2, event e
		where e.event_id = ?
			and ep1.parent_id = e.event_id
			and ep2.parent_id = ep1.parent_id
			and ep1.item_name='Appointment/Attendee/Patient'
			and ep2.item_name='Appointment/Attendee/Physician'
	},

	'selEventAttribute' => qq{
		select *
		from event_attribute
		where parent_id = ?
			and value_type = ?
	},

	'selColumnPreference' => qq{
		select item_id, value_text as resource_id, value_textb as facility_id,
			value_intb as date_offset
		from Person_Attribute
		where parent_id = ?
			and item_name = 'Preference/Schedule/DayView/Column'
			and value_int = ?
	},

	'selNumPreferences' => qq{
		select count(*) from Person_Attribute
		where parent_id = ?
			and item_name = 'Preference/Schedule/DayView/Column'
	},

	'selPopulateTemplateDialog' => qq{
		select template_id, caption, r_ids, facility_id, available, status, remarks,
			preferences, days_of_month, months, days_of_week, patient_types, visit_types,
			to_char(effective_begin_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_begin_date,
			to_char(effective_end_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_end_date,
			to_char(start_time, 'HH:MI am') as duration_begin_time,
			to_char(end_time,'HH:MI am') as duration_end_time
		from Template_R_Ids, Template
		where template_id = ?
			and parent_id = template_id
			and rownum = 1
	},

	'selPopulateApptTypeDialog' => qq{
		select appt_type_id, caption, r_ids, facility_id,
			to_char(effective_begin_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_begin_date,
			to_char(effective_end_date,'$SQLSTMT_DEFAULTDATEFORMAT') as effective_end_date,
			duration
		from Appt_Type
		where appt_type_id = ?
	},

	'selPopulateAppointmentDialog' => qq{
		select e.event_id, e.facility_id, e.event_status, e.event_type, e.subject,
			to_char(e.start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_stamp,
			e.duration, e.remarks, e.owner_id,
			e.scheduled_by_id, e.scheduled_stamp, e.checkin_by_id,
			ep1.value_text as attendee_id, ep1.value_int as attendee_type,
			ep2.value_text as resource_id
		from event_attribute ep2, event_attribute ep1, event e
		where event_id = ?
			and ep1.parent_id = e.event_id
			and ep1.value_type = $EVENTATTRTYPE_PATIENT
			and ep2.parent_id = ep1.parent_id
			and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
	},

	'selSchedulePreferences' => qq{
		select item_id, value_text as resource_id, value_textb as facility_id,
			value_int as column_no, value_intb as offset
		from Person_Attribute
		where parent_id = ?
			and item_name = ?
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
		and Event_Attribute.value_type = $EVENTATTRTYPE_PATIENT
	},

	'selTemplateInfo' =>
	{
		_stmtFmt => $STMTFMT_SEL_TEMPLATEINFO,
		simpleReport => $STMTRPTDEFN_TEMPLATEINFO,
		publishDefn => $STMTRPTDEFN_TEMPLATEINFO,
	},

	'selApptTypeInfo' =>
	{
		_stmtFmt => qq{
			select appt_type_id, r_ids, facility_id, caption, duration, effective_begin_date,
				effective_end_date
			from Appt_Type
			where r_ids like ?
				and facility_id like ?
			order by facility_id, r_ids, appt_type_id
		},

		publishDefn =>
		{
			columnDefn =>
			[
				{ head => 'ID', url => 'javascript:location.href="/org/#session.org_id#/dlg-update-appttype/#&{?}#"', hint => 'Edit Template #&{?}#'},
				{ head => 'Resource(s)', url => 'javascript:location.href="/search/appttype/1/#&{?}#"', hint => 'View #&{?}# Templates'},
				{ head => 'Facility', url => 'javascript:location.href="/search/appttype/1//#&{?}#"', hint => 'View #&{?}# Templates'},
				{ head => 'Caption'},
				{ head => 'Begin'},
				{ head => 'End'},
			],
		}
	},

	'selResourcesAtFacility' => qq{
		select distinct attendee_id
		from Template
		where facility_id = ?
	},

	'selPatientApptHistory' => qq{
		select to_char(e.start_time,'$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time, e.duration,
			ep1.value_text as patient_id, ep2.value_text as resource_id,
			e.subject, et.caption as event_type,
			Appt_Status.Caption, e.facility_id,
			to_char(e.checkin_stamp,'$SQLSTMT_DEFAULTSTAMPFORMAT') as checkin_stamp,
			to_char(e.checkout_stamp,'$SQLSTMT_DEFAULTSTAMPFORMAT') as checkout_stamp
		from Appt_Status, Person patient, Person provider,
			Event_Attribute ep2, Event_Attribute ep1,
			Event_Type et, Event e
		where e.start_time between to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
				and to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
			and et.id = e.event_type
			and ep1.parent_id = e.event_id
			and ep1.value_type = $EVENTATTRTYPE_PATIENT
				and ep1.value_text = ?
				and ep1.value_text = patient.person_id
			and ep2.parent_id = ep1.parent_id
			and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
				and ep2.value_text = provider.person_id
			and Appt_Status.id = e.event_status
		order by e.start_time DESC
	},

	#
	# expects bind parameters:
	#   1: start date/time stamp
	#   2: end date/time stamp
	#   3: facility_id
	#   4: user_id
	#   5: user_id (same as 4)
	#
	'selMyAndAssociatedResourceAppts' => qq{
		select to_char(e.start_time, 'hh:miam') as start_time,
			e.duration, e.event_id,	ep1.value_text as patient_id, ep2.value_text as resource_id,
			patient.complete_name as patient_complete_name,
			e.subject, et.caption as event_type, aat.caption as patient_type,
			e.remarks, e.event_status, Appt_Status.caption as appt_status
		from 	Appt_Status, Appt_Attendee_type aat, Person patient, Person provider,
			Event_Attribute ep2, Event_Attribute ep1,
			Event_Type et, Event e
		where e.start_time between to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and e.discard_type is null
			and e.event_status in (0,1,2)
			and e.facility_id = ?
			and et.id = e.event_type
			and ep1.parent_id = e.event_id
			and ep1.value_type = $EVENTATTRTYPE_PATIENT
				and ep1.value_text = patient.person_id
			and ep2.parent_id = ep1.parent_id
			and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
				and ep2.value_text = provider.person_id
			and
			(	ep2.value_text = ? or
				ep2.value_text in
				(select value_text from person_attribute
					where parent_id = ?
						and value_type = $ASSOC_VALUE_TYPE
						and item_name = 'Physician'
				)
			)
			and aat.id = ep1.value_int
			and Appt_Status.id = e.event_status
		order by e.start_time
	},

	'selAssociatedResources' => qq{
		select value_text as resource_id, value_textb as facility_id
		from Person_Attribute
		where parent_id = ?
			and value_type = $ASSOC_VALUE_TYPE
			and item_name = 'Physician'
	},

	'selRovingPhysicianTypes' => qq{
		select replace(caption, ' ', '_') as caption
		from Medical_Specialty
		where group_name = 'Physician Specialty'
		UNION
		select ' ' as caption from Dual
		order by caption
	},

	'updAssignResource' => qq{
		update Event_Attribute set value_text = upper(?) where upper(value_text) = upper(?)
		and parent_id in
			(select event_id from event
				where start_time between to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
					and to_date (?, '$SQLSTMT_DEFAULTDATEFORMAT') +1
					and facility_id = ?
			)
	},

	'selPatientTypes' => qq{
		select id, caption from Appt_Attendee_Type
	},

	'selVisitTypes' => qq{
		select id, caption from Transaction_Type where id>=2040 and id<3000
	},

	'selRovingResources' => qq{
		select distinct member_name from Template_R_Ids where member_name like ?
	},

# -- WAITING LIST -----------------------------------------------------------------------------

	'selAppointmentConflictCheck' => qq{
		select to_char(start_time, 'hh24mi') as start_minute,
			to_char(start_time,'yyyy,mm,dd') as start_day, duration,
			event_id,	ea1.value_text as patient_id, ea2.value_text as resource_id,
			Event.parent_id
		from 	Event_Attribute ea2, Event_Attribute ea1, Event
		where start_time between to_date(?, 'yyyy,mm,dd')
			and to_date(?, 'yyyy,mm,dd')
			and discard_type is null
			and event_status in (0,1,2)
			and facility_id = ?
			and ea1.parent_id = event_id
			and ea1.value_type = $EVENTATTRTYPE_PATIENT
			and ea2.parent_id = ea1.parent_id
			and ea2.value_type = $EVENTATTRTYPE_PHYSICIAN
			and ea2.value_text = ?
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
		where value_type = $EVENTATTRTYPE_PATIENT
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
			and Event_Attribute.value_type = $EVENTATTRTYPE_PATIENT
		union
		select 'None' as value_text, 0 as event_id from Dual
	},
	
	'sel_futureAppointments' => {
		_stmtFmt => qq{
			select 	to_char(e.start_time, 'mm/dd/yyyy HH12:MI AM') appt_time,
				eadoc.value_text as physician, e.subject
			from 	event_attribute eaper, event_attribute eadoc, event e
			where e.start_time > sysdate	
				and eaper.parent_id = e.event_id
				and	eaper.value_text = ?
				and	eaper.item_name like '%Patient'
				and	eadoc.parent_id = e.event_id
				and	eadoc.item_name like '%Physician'
			order by e.start_time
		},
	},
);

1;
