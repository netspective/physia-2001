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
		{ head => 'Patient',colIdx=>0, hint=>'View Patient Profile',url=>q{javascript:chooseItemForParent('/person/#11#/profile')}},			
		{ head => 'Chart', 	colIdx => 2, },
		{ head => 'Account',	colIdx => 1,},					
		{ head => 'Physician',colIdx=>3,	},					
		{ head => 'Facility',hint=>'#12#',colIdx=>4	},					
		{ head => 'Appt Status',	colIdx=>5},
		{ head => 'Appointment Time',colIdx=>6	},
		{ head => 'Reason for Visit',colIdx=>7	},
		{ head => 'Scheduled By',	colIdx=>8},
		{ head => 'Checkin By',	colIdx=>9},
		{ head => 'Checkout By',colIdx=>10	},
		],				
};
$STMTFMT_DETAIL_APPT_SCHEDULE = qq{
		SELECT 	(SELECT simple_name 
			FROM 	person 
			WHERE 	person_id = ea.value_text) as patient_name,
			(SELECT	value_text
			FROM	Person_Attribute  pa
			WHERE	pa.parent_id = ea.value_text
			AND	pa.item_name = 'Patient/Account Number'
			) 	as account_number,
			(SELECT	value_text
			FROM	Person_Attribute  pa
			WHERE	pa.parent_id = ea.value_text
			AND	pa.item_name = 'Patient/Chart Number'
			) 	as chart_number,
			(SELECT simple_name 
			FROM 	person 
			WHERE 	person_id = ea.value_textb) as physician_name,
			(SELECT org_id 
			FROM org 
			WHERE org_internal_id = e.facility_id) as org_name,				
			(SELECT caption 
			FROM 	Appt_Status 
			WHERE	id = e.event_status) as appt_status,
			TO_CHAR(e.start_time - :6, 'MM/DD/YYYY HH12:MI AM') as start_time,
			e.subject as reason_visit,
			e.scheduled_by_id as scheduled_by,			
			e.checkin_by_id as checkin_by, 
			e.checkout_by_id as checkout_by,
			ea.value_text as patient_id,
			ea.value_textb as physician_id
		FROM	Event e, Event_Attribute ea 
			%fromTable%
		WHERE	%whereCond%
		AND	(:2 IS NULL OR facility_id = :2)
		AND EXISTS
		(
			SELECT 	'x'
			FROM 	org
			WHERE 	owner_org_id = :5
			AND 	org_internal_id = e.facility_id
		)
		AND	e.event_id = ea.parent_id
		AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
		AND	e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		ORDER BY 5, 7
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
			WHERE	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND (:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = e.facility_id
				)
				AND	e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND	e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND	e.event_id = ea.parent_id
				AND	e.event_id = t.parent_event_id
				AND	i.main_transaction = t.trans_id
				AND	ii.parent_id = i.invoice_id
				AND	ii.code is not NULL
			GROUP BY ii.code
			ORDER BY 1
		},
		publishDefn => 	{
			columnDefn =>
			[
			{head => 'Procedure Code',
				url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=CPT&CPT=#&{?}#',
					null,'location,status,width=800,height=600,scrollbars,resizable')}, 
				hint => 'View Details' },
			{head => 'Count', dAlign => 'right',summarize=>'sum'},
			],
		},				
	},

	'sel_detailPatientsCPT' =>{
		_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		fromTable =>q{,	transaction t,
			invoice i,
			invoice_item ii
		},
		whereCond =>q{ii.parent_id = i.invoice_id 
			AND ii.code = :1 
			AND i.main_transaction = t.trans_id 
			AND e.event_id = t.parent_event_id
			AND i.parent_invoice_id is NULL
		},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,		
	},
	# -----------------------------------------------------------------------------------------				
	'sel_missingEncounter' =>
	{
		sqlStmt=>qq{
			SELECT 	to_char(e.CHECKIN_STAMP, '$SQLSTMT_DEFAULTDATEFORMAT'), count (*)
			FROM 	Event e, Event_Attribute ea
			WHERE	(:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = e.facility_id
				)
				AND	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND	e.CHECKIN_STAMP >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND	e.CHECKIN_STAMP <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND	e.event_id = ea.parent_id
				AND	e.CHECKOUT_STAMP is NULL
			GROUP BY to_char(e.CHECKIN_STAMP, '$SQLSTMT_DEFAULTDATEFORMAT')
			ORDER BY 1 desc
		},
			publishDefn => 	{
					columnDefn =>
					[
					{head => 'Check In Date',url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=missing_encounter&encounter=#&{?}#',
						null,'location,status,width=800,height=600,scrollbars,resizable')}, 
						hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
					],
				},				   
	},
	
	'sel_detailMissingEncounter' =>
	{
		sqlStmt=>qq{
				SELECT (SELECT simple_name FROM person WHERE person_id = ea.value_text) as patient_name,
					ea.value_text,
					to_char(e.checkin_stamp, 'MM/DD/YYYY HH12:MI AM') as checkin_stamp,
					(SELECT simple_name FROM person WHERE person_id =ea.value_textB) as physician_name,
					(SELECT org_id FROM org where org_internal_id = e.facility_id) as org_name,
					value_text
				FROM	Event e, Event_Attribute ea 
				WHERE	(:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :3
					AND 	org_internal_id = e.facility_id
				)
				AND	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND	e.CHECKIN_STAMP >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :4
				AND e.CHECKIN_STAMP <  TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :4
				AND	e.event_id = ea.parent_id
				AND	e.CHECKOUT_STAMP is NULL
			   },
		publishDefn =>
			   {
				columnDefn => 
				[
				{ head => 'Patient Name',colIdx=>0, hint=>'View Patient Profile',
						url => q{javascript:chooseItemForParent('/person/#1#/profile',
							null,'location,status,width=800,height=600,scrollbars,resizable'),}
				},			
				{ head => 'Patient ID', 	colIdx => 1, },
				{ head => 'Appt Start Time',colIdx=>2	},
				{ head => 'Physician Name',colIdx=>3	},
				{ head => 'Location',	colIdx=>4},
				]
			   }
	},
			
	# -----------------------------------------------------------------------------------------			
			
	'sel_dateEntered' =>
	{
		sqlStmt=>qq{
			SELECT to_char(e.scheduled_stamp -:5, '$SQLSTMT_DEFAULTDATEFORMAT'), count (*)
			FROM 	Event e, Event_Attribute ea
			WHERE	(:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = e.facility_id
				)
				AND	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND	e.scheduled_stamp >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND	e.scheduled_stamp <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND	e.event_id = ea.parent_id				
			GROUP BY to_char(e.scheduled_stamp -:5, '$SQLSTMT_DEFAULTDATEFORMAT')
			ORDER BY 1 desc
		},
			publishDefn => 	{
					columnDefn =>
					[
					{head => 'Date',url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=date_entered&entered=#&{?}#',
						null,'location,status,width=800,height=600,scrollbars,resizable')},
						hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
					],
				},				   
	},
			
	'sel_detailDateEntered' =>
	{
		sqlStmt=>qq{
			SELECT  scheduled_by_id,
				ea.value_text as patient_id,
				(SELECT simple_name FROM person WHERE person_id = ea.value_text) as patient_name,
				(SELECT simple_name FROM person WHERE person_id = ea.value_textB)  as physician_name,
				TO_CHAR(e.start_time -:4, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time,					
				(SELECT org_id FROM org where org_internal_id = e.facility_id) as org_name
			FROM	Event_Attribute ea, Event e
			WHERE e.scheduled_stamp between TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :4
					and TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :4
				AND (:1 IS NULL OR facility_id = :1)
				AND	ea.parent_id = e.event_id
				AND	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND EXISTS
				(
					SELECT 	'x' 
					FROM 	org
					WHERE 	owner_org_id = :3
					AND 	org_internal_id = e.facility_id
				)
			ORDER BY 1,3
		},

		publishDefn =>
			   {
				columnDefn => 
				[
				{ head => 'Scheduled ID', colIdx=>0,},			
				{ head => 'Patient Name', colIdx => 2,
					hint=>'View Patient Profile', url=>q{javascript:chooseItemForParent('/person/#1#/profile')}},
				{ head => 'Physician Name', colIdx =>3,},
				{ head => 'Appointment Time', colIdx=>4	},
				{ head => 'Location',	colIdx=>5},
				]
			   }
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
				WHERE	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and (:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = e.facility_id
				)
				AND	e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND	e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND	e.event_id = ea.parent_id
				AND	e.event_id = t.parent_event_id
				AND	i.main_transaction = t.trans_id
				AND	ib.bill_id = i.billing_id
				AND	ib.bill_ins_id = i.ins_internal_id
				AND	ct.id = i.ins_type
				GROUP BY ct.caption
				},
				publishDefn => 	{
					columnDefn =>
					[
					{head => 'Product Name',url =>q{javascript:doActionPopup('#hrefSelfPopup#&detail=product&product=#&{?}#',
						null,'location,status,width=800,height=600,scrollbars,resizable')}, 
						hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
					],
				},		
			},

	'sel_detailPatientsProduct' =>{
				_stmtFmt => $STMTFMT_DETAIL_APPT_SCHEDULE,				
				fromTable=>q	{,invoice i,
						invoice_billing ib,
						insurance i,
						claim_type ct,
						transaction t
						},
				whereCond=>q{	ct.caption = :1 
						AND	e.event_id = t.parent_event_id
						AND	i.main_transaction = t.trans_id						
						AND	ib.bill_id = i.billing_id
						AND	ib.bill_ins_id = i.ins_internal_id
						AND	ct.id = i.ins_type
					    },
				publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,

	},
			

	# -----------------------------------------------------------------------------------------

	'sel_patientsSeen' => {
		sqlStmt => qq{
			select value_textB as physician, count(value_textB) as count
			from Event, Event_Attribute
			where Event_Attribute.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and (:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = Event.facility_id
				)
				and Event.event_id = Event_Attribute.parent_id
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and event_status in (1, 2)
			group by value_textB
		},
		publishDefn => 	{
			columnDefn =>
				[
					{	head => 'Physician', 
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=physician&physician=#&{?}#',
							null,'location,status,width=800,height=600,scrollbars,resizable')}, 
							hint => 'View Details' 
					},
					{	head => 'Count', dAlign => 'right',summarize=>'sum'},
				],
		},
	},

	'sel_detailPatientsSeenByPhysician' => {
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,		
		whereCond =>q{ event_status in (1,2) AND ea.value_textB = :1},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,	

	},

	# -----------------------------------------------------------------------------------------
	'sel_patientsSeen_byPatientType' => {
		sqlStmt => qq{
			select caption as patient_type, count(caption) as count, Appt_Attendee_Type.id
			from Appt_Attendee_Type, Event, Event_Attribute ea
			where ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and Event.event_id = ea.parent_id
				and (:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = Event.facility_id
				)
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and event_status in (1, 2)
				and Appt_Attendee_Type.id = ea.value_int
			group by caption, Appt_Attendee_Type.id
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Patient type',
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=patient_type&patient_type_id=#2#&patient_type_caption=#0#',
							null,'location,status,width=800,height=600,scrollbars,resizable')},
						hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
				],
		},
	},

	'sel_detailPatientsSeenByPatientType' => {
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		whereCond=>q{ea.value_int = :1 and event_status in (1,2) },
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,

	},

	# -----------------------------------------------------------------------------------------
	'sel_appointments_byStatus' => {
		sqlStmt => qq{
			select caption as appointments, count(caption) as count, event_status
			from Appt_Status, Event, Event_Attribute
			where value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and Event.event_id = Event_Attribute.parent_id
				and (:1 IS NULL OR facility_id = :1)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4 
					AND 	org_internal_id = Event.facility_id
				)
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and Appt_Status.id = Event.event_status
			group by caption, event_status
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Appointments', 
						url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=appointments&event_status=#2#&caption=#0#',
							null,'location,status,width=800,height=600,scrollbars,resizable')},
						hint => 'View Details' 
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
				],
		},
	},	

	'sel_DetailAppointmentStatus'=>{
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,		
		whereCond =>q{e.event_status = :1},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,				 
			
	},	

);

1;
