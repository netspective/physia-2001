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
	 	ea.value_textB as physician,
		org.org_id as org_name,
		aas.caption as status,
		TO_CHAR(e.start_time, 'MM/DD/YYYY HH12:MI AM') AS start_time,
		e.subject,  
		e.scheduled_by_id as scheduled_by,
		e.checkin_by_id as checkin_by, 
		e.checkout_by_id as checkout_by	,				
		aat.caption as patient_type,
		ea.value_textB as provider,
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
		transaction t,
		invoice i,
		invoice_billing ib,
		Appt_Attendee_Type aat, 
		Appt_Status aas,
		org
		%fromTable%
	WHERE	%whereCond%
		AND	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
		AND	e.facility_id = :2
		AND	org.org_internal_id = :2
		AND	p.person_id = ea.value_text
		AND	trunc(e.start_time) BETWEEN TO_DATE(:3, 'MM/DD/YYYY')
		AND	TO_DATE(:4, 'MM/DD/YYYY')
		AND	e.event_id = ea.parent_id
		AND	e.event_id = t.parent_event_id (+)
		AND	i.main_transaction (+)= t.trans_id
		AND	ib.invoice_id (+)= i.invoice_id
		AND aas.id = e.event_status
		AND aat.id = ea.value_int	
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
				WHERE	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND	e.facility_id = :1
				AND	trunc(e.start_time) BETWEEN TO_DATE(:2, 'MM/DD/YYYY')
				AND	TO_DATE(:3, 'MM/DD/YYYY')
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
				WHERE	ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND	e.facility_id = :1
				AND	trunc(e.start_time) BETWEEN TO_DATE(:2, 'MM/DD/YYYY')
				AND	TO_DATE(:3, 'MM/DD/YYYY')
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
		sqlStmt => qq{
			select value_textB as physician, count(value_textB) as count
			from Event, Event_Attribute
			where Event_Attribute.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and facility_id = :1
				and Event.event_id = Event_Attribute.parent_id
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
			group by value_textB
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
				and facility_id = :1
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and event_status in (1, 2)
				and Appt_Attendee_Type.id = ea.value_int
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
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,	
		whereCond=>q{aat.id = :1 and event_status in (1,2) },
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,

	},

	# -----------------------------------------------------------------------------------------
	'sel_appointments_byStatus' => {
		sqlStmt => qq{
			select caption as appointments, count(caption) as count, event_status
			from Appt_Status, Event, Event_Attribute
			where value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and Event.event_id = Event_Attribute.parent_id
				and facility_id = :1
				and Event.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
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
	'sel_DetailAppointmentStatus'=>{
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,		
		whereCond =>q{ aas.id = :1},			
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,				 
			
	},	

);

1;
