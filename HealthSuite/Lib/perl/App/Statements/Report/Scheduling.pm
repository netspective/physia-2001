##############################################################################
package App::Statements::Report::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Data::Publish;
use vars qw(@ISA @EXPORT $STMTMGR_REPORT_SCHEDULING $STMTFMT_DETAIL_APPT_SCHEDULE $STMTRPTDEFN_DETAIL_APPT_SCHEDULE
);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_SCHEDULING);


$STMTRPTDEFN_DETAIL_APPT_SCHEDULE ={
		
		columnDefn => 
		[
		{ head => 'Patient',colIdx=>0, hint=>'#11#',url=>q{javascript:chooseItemForParent('/person/#0#/profile')}},			
		{ head => 'Chart', 	colIdx => 13, },
		{ head => 'Account',	colIdx => 14,},					
		{ head => 'Physician',colIdx=>1,	},					
		{ head => 'Facility',hint=>'#12#',colIdx=>2	},					
		{ head => 'Appt Status',	colIdx=>3},
		{ head => 'Appt Start Time',colIdx=>4	},
		{ head => 'Reason for Visit',colIdx=>5	},
		{ head => 'Scheduled By',	colIdx=>6},
		{ head => 'Checkin By',	colIdx=>7},
		{ head => 'Checkout By',colIdx=>8	},
		],
				
};
$STMTFMT_DETAIL_APPT_SCHEDULE = qq{
	SELECT distinct p.person_id as patient,
	 	ea.value_text as physician,
		org.org_id as org_name,
		aas.caption as status,
		TO_CHAR(e.start_time, 'MM/DD/YYYY HH12:MI AM') AS start_time,
		e.subject,  
		e.scheduled_by_id as scheduled_by,
		e.checkin_by_id as checkin_by, 
		e.checkout_by_id as checkout_by	,				
		aat.caption as patient_type,
		ea.value_text as provider,
		p.simple_name,
		org.name_primary,
		(SELECT	value_text
		FROM	Person_Attribute  pa
		WHERE	pa.parent_id = p.person_id
		AND	pa.item_name = 'Patient/Account Number'
		) as account_number,
		(SELECT	value_text
		FROM	Person_Attribute  pa
		WHERE	pa.parent_id = p.person_id
		AND	pa.item_name = 'Patient/Chart Number'
		) as chart_number	
	FROM	
		Event e, 
		person p,
		Event_Attribute ea,
		Event_Attribute ea2,					
		transaction t,
		invoice i,
		invoice_billing ib,
		Appt_Attendee_Type aat, 
		Appt_Status aas,
		org
		%fromTable%
	WHERE	%whereCond%
	AND	ea.item_name = 'Appointment/Attendee/Physician'
	AND	ea2.item_name = 'Appointment/Attendee/Patient'
	AND	e.facility_id = :2
	AND	org.org_internal_id = :2
	AND	p.person_id = ea2.value_text
	AND	trunc(e.start_time) BETWEEN TO_DATE(:3, 'MM/DD/YYYY')
	AND	TO_DATE(:4, 'MM/DD/YYYY')
	AND 	(ea.value_text = :5 OR :5 IS NULL)
	AND	e.event_id = ea.parent_id
	AND	e.event_id = ea2.parent_id
	AND	e.event_id = t.parent_event_id (+)
	AND	i.main_transaction (+)= t.trans_id
	AND	ib.invoice_id (+)= i.invoice_id
	AND 	aas.id = e.event_status
	AND 	aat.id = ea2.value_int	
	ORDER BY 5	
};

$STMTMGR_REPORT_SCHEDULING = new App::Statements::Report::Scheduling(

	# -----------------------------------------------------------------------------------------
	'sel_patientsCPT' =>{
				sqlStmt => qq{
				SELECT	ii.code,count(distinct(e.event_id)) as count
				FROM	Event e, 
					Event_Attribute ea,
					transaction t,
					invoice i,
					invoice_item ii															
				WHERE	ea.item_name = 'Appointment/Attendee/Physician'
				AND	e.facility_id = :1
				AND	trunc(e.start_time) BETWEEN TO_DATE(:2, 'MM/DD/YYYY')
				AND	TO_DATE(:3, 'MM/DD/YYYY')
				AND 	(ea.value_text = :4 OR :4 IS NULL)
				AND	e.event_id = ea.parent_id
				AND	e.event_id = t.parent_event_id
				AND	i.main_transaction = t.trans_id
				AND	ii.parent_id = i.invoice_id
				AND	ii.code is not NULL
				GROUP BY ii.code
				},
				publishDefn => 	{
					columnDefn =>
					[
					{head => 'Procedure Code',url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=CPT&CPT=#&{?}#')}, hint => 'View Details' },
					{head => 'Count', dAlign => 'right'},
					],
				},				
			},

	'sel_detailPatientsCPT' =>{
				_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
				fromTable =>q{,invoice_item ii},
				whereCond =>q{ii.parent_id = i.invoice_id AND ii.code=:1},			
				publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,		
			},
			
	# -----------------------------------------------------------------------------------------			
	'sel_patientsProduct' =>{
				sqlStmt => qq{
				SELECT	ct.caption,count(distinct e.event_id) as count
				FROM	Event e, 
					Event_Attribute ea,
					transaction t,
					invoice i,
					invoice_billing ib,
					insurance i,
					claim_type ct
				WHERE	ea.item_name = 'Appointment/Attendee/Physician'
				AND	e.facility_id = :1
				AND	trunc(e.start_time) BETWEEN TO_DATE(:2, 'MM/DD/YYYY')
				AND	TO_DATE(:3, 'MM/DD/YYYY')
				AND 	(ea.value_text = :4 OR :4 IS NULL)
				AND	e.event_id = ea.parent_id
				AND	e.event_id = t.parent_event_id
				AND	i.main_transaction = t.trans_id
				AND	ib.invoice_id = i.invoice_id
				AND	ib.bill_ins_id = i.ins_internal_id
				AND	ct.id = i.ins_type
				GROUP BY ct.caption
				},
				publishDefn => 	{
					columnDefn =>
					[
					{head => 'Product Name',url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=product&product=#&{?}#')} , hint => 'View Details' },
					{head => 'Count', dAlign => 'right'},
					],
				},		
			},
	'sel_detailPatientsProduct' =>{
				_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,				
				fromTable=>q{,claim_type ct, insurance ins},
				whereCond=>q{ct.caption = :1 AND ib.bill_ins_id = ins.ins_internal_id  AND ct.id = ins.ins_type },
				publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,

	},
			

	# -----------------------------------------------------------------------------------------

	'sel_patientsSeen' => {
		_stmtFmt => qq{
			select value_text as physician, count(value_text) as count
			from Event, Event_Attribute
			where Event_Attribute.item_name = 'Appointment/Attendee/Physician'
				and facility_id = :1
				and Event.event_id = Event_Attribute.parent_id
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				AND (Event_Attribute.value_text = :4 OR :4 IS NULL)
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
		_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,		
		whereCond =>q{ event_status in (1,2) AND ea.value_text = :1},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,	

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
				and facility_id = :1
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				and Appt_Attendee_Type.id = ea2.value_int
				AND (ea1.value_text = :4 OR :4 IS NULL)
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
		_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,	
		whereCond=>q{aat.id = :1 and event_status in (1,2) },
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,

	},

	# -----------------------------------------------------------------------------------------
	'sel_appointments_byStatus' => {
		_stmtFmt => qq{
			select 	caption as appointments, count(caption) as count,
				event_status
			from 	Appt_Status, Event, Event_Attribute
			where 	item_name = 'Appointment/Attendee/Physician'
			and 	Event.event_id = Event_Attribute.parent_id
			and 	facility_id = :1
			and 	Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and 	to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and 	Appt_Status.id = Event.event_status
			and    (value_text = :4 OR :4 IS NULL)
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
	'sel_DetailAppointmentStatus'=>{
		_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,		
		whereCond =>q{ aas.id = :1},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,				 
			
	},	

);

1;
