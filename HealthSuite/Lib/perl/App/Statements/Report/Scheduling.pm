##############################################################################
package App::Statements::Report::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_SCHEDULING
);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_SCHEDULING);

$STMTMGR_REPORT_SCHEDULING = new App::Statements::Report::Scheduling(

	# -----------------------------------------------------------------------------------------
	'sel_patientsSeen' => {
		_stmtFmt => qq{
			select value_text as physician, count(value_text) as count
			from Event, Event_Attribute
			where Event_Attribute.item_name = 'Appointment/Attendee/Physician'
				and facility_id = ?
				and Event.event_id = Event_Attribute.parent_id
				and Event.start_time between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
			group by value_text
		},
		publishDefn => 	{
			columnDefn =>
				[
					{	head => 'Physician', 
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=physician&physician=#&{?}#')}, hint => 'View Details' 
					},
					{	head => 'Count', dAlign => 'right'},
				],
		},
	},

	'sel_detailPatientsSeenByPhysician' => {
		_stmtFmt => qq{
			select ea2.value_text as patient, Appt_Attendee_Type.caption as patient_type,
				Appt_Status.caption as status, to_char(start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				as Appointment_Time, Event.subject, Event.remarks, scheduled_by_id as scheduled_by,
				checkin_by_id as checkin_by, checkout_by_id as checkout_by
			from Appt_Attendee_Type, Appt_Status, Event, Event_Attribute ea1, Event_Attribute ea2
			where ea1.item_name = 'Appointment/Attendee/Physician'
				and ea1.value_text = ?
				and ea2.item_name = 'Appointment/Attendee/Patient'
				and ea2.parent_id = ea1.parent_id
				and facility_id = ?
				and Event.event_id = ea1.parent_id
				and Event.start_time between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				and Appt_Status.id = Event.event_status
				and Appt_Attendee_Type.id = ea2.value_int
			order by Event.start_time, Event.event_status
		},
	},

	# -----------------------------------------------------------------------------------------
	'sel_patientsSeen_byPatientType' => {
		_stmtFmt => qq{
			select caption as patient_type, count(caption) as count, Appt_Attendee_Type.id
			from Appt_Attendee_Type, Event, Event_Attribute ea2, Event_Attribute ea1
			where ea1.item_name = 'Appointment/Attendee/Physician'
				and ea2.item_name = 'Appointment/Attendee/Patient'
				and ea2.parent_id = ea1.parent_id
				and Event.event_id = ea1.parent_id
				and facility_id = ?
				and Event.start_time between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				and Appt_Attendee_Type.id = ea2.value_int
			group by caption, Appt_Attendee_Type.id
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Patient type',
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=patient_type&patient_type_id=#2#&patient_type_caption=#0#')}, hint => 'View Details' },
					{head => 'Count', dAlign => 'right'},
				],
		},
	},

	'sel_detailPatientsSeenByPatientType' => {
		_stmtFmt => qq{
			select Event_Attribute.value_text as patient, Appt_Attendee_Type.caption as patient_type,
				Appt_Status.caption as status, to_char(start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				as Appointment_Time, Event.subject, Event.remarks, scheduled_by_id as scheduled_by,
				checkin_by_id as checkin_by, checkout_by_id as checkout_by
			from Appt_Attendee_Type, Appt_Status, Event, Event_Attribute
			where Event_Attribute.item_name = 'Appointment/Attendee/Patient'
				and Event.event_id = Event_Attribute.parent_id
				and facility_id = ?
				and Event.start_time between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				and Appt_Status.id = Event.event_status
				and Appt_Attendee_Type.id = ?
				and Appt_Attendee_Type.id = Event_Attribute.value_int
			order by Event.start_time, Event.event_status
		},
	},

	# -----------------------------------------------------------------------------------------
	'sel_appointments_byStatus' => {
		_stmtFmt => qq{
			select caption as appointments, count(caption) as count,
				event_status
			from Appt_Status, Event, Event_Attribute
			where item_name = 'Appointment/Attendee/Physician'
				and Event.event_id = Event_Attribute.parent_id
				and facility_id = ?
				and Event.start_time between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and Appt_Status.id = Event.event_status
			group by caption, event_status
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Appointments', 
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=appointments&event_status=#2#&caption=#0#')}, hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right'},
				],
		},
	},

);

1;
