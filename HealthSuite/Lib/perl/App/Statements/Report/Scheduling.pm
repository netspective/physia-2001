##############################################################################
package App::Statements::Report::Scheduling;
##############################################################################

use strict;

use DBI::StatementManager;
use Data::Publish;
use vars qw(@EXPORT $STMTMGR_REPORT_SCHEDULING $STMTFMT_DETAIL_APPT_SCHEDULE $STMTRPTDEFN_DETAIL_APPT_SCHEDULE
);
use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_SCHEDULING);

my $TIME_FORMAT = 'HH:MI AM';

$STMTRPTDEFN_DETAIL_APPT_SCHEDULE = {
	columnDefn =>
	[
		{ head => 'Patient', colIdx=>0, hint => 'View #17# #11# Profile',
			url=>q{javascript:chooseItemForParent('/person/#11#/profile')},
			options => PUBLCOLFLAG_DONTWRAP,
		},
		{ head => 'Chart', colIdx => 2,},
		{ head => 'Account', colIdx => 1,},
		{ head => 'Physician', colIdx => 3, options => PUBLCOLFLAG_DONTWRAP,},
		{ head => 'Facility', colIdx => 4},
		{ head => 'Appt Status', colIdx => 5, options => PUBLCOLFLAG_DONTWRAP,},
		{ head => 'Appointment Time', colIdx => 6, hint => 'Event ID #16#'},
		{ head => 'Reason for Visit', colIdx => 7},
		{ head => 'Scheduled By', colIdx => 8, hint => '#13#'},
		{ head => 'Checkin By', colIdx => 9, hint => '#14#'},
		{ head => 'Checkout By', colIdx => 10, hint => '#15#'},
	],
};

my $discardAppt_defn = {
	columnDefn =>
	[
		{ head => 'Patient', colIdx=>0, hint => 'View #17# #11# Profile',
			url=>q{javascript:chooseItemForParent('/person/#11#/profile')},
			options => PUBLCOLFLAG_DONTWRAP,
		},
		{ head => 'Chart', colIdx => 2,},
		{ head => 'Account', colIdx => 1,},
		{ head => 'Physician', colIdx => 3, options => PUBLCOLFLAG_DONTWRAP,},
		{ head => 'Facility', colIdx => 4},
		{ head => 'Appt Status', colIdx => 5, options => PUBLCOLFLAG_DONTWRAP,},
		{ head => 'Remarks', colIdx => 18,},
		{ head => 'Appointment Time', colIdx => 6, hint => 'Event ID #16#'},
		{ head => 'Reason for Visit', colIdx => 7},
		{ head => 'Scheduled By', colIdx => 8, hint => '#13#'},
	],
};

$STMTFMT_DETAIL_APPT_SCHEDULE = qq{
		SELECT
			(SELECT InitCap(simple_name)
				FROM 	person
				WHERE 	person_id = ea.value_text
			) as patient_name,
			(SELECT	value_text
				FROM	Person_Attribute  pa
				WHERE	pa.parent_id = ea.value_text
				AND	pa.item_name = 'Patient/Account Number'
			) as account_number,
			(SELECT	value_text
				FROM	Person_Attribute  pa
				WHERE	pa.parent_id = ea.value_text
				AND	pa.item_name = 'Patient/Chart Number'
			) as chart_number,
			(SELECT initcap(simple_name)
				FROM person
				WHERE person_id = ea.value_textb
			) as physician_name,
			(SELECT org_id
				FROM org
				WHERE org_internal_id = e.facility_id
			) as org_name,
			%apptStatusSelect%,
			TO_CHAR(e.start_time - :6, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time,
			initcap(e.subject) as reason_visit,
			e.scheduled_by_id as scheduled_by,
			e.checkin_by_id as checkin_by,
			e.checkout_by_id as checkout_by,
			ea.value_text as patient_id,
			ea.value_textb as physician_id,
			to_char(e.scheduled_stamp - :6, '$SQLSTMT_DEFAULTSTAMPFORMAT') as scheduled_stamp,
			to_char(e.checkin_stamp - :6, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkin_stamp,
			to_char(e.checkout_stamp - :6, '$SQLSTMT_DEFAULTSTAMPFORMAT') as checkout_stamp,
			e.event_id,
			aat.caption
			%discardRemarks%
		FROM	Appt_Attendee_Type aat, Event e, Event_Attribute ea
			%fromTable%
		WHERE	%whereCond%
		AND	(:2 is NULL or e.facility_id = :2)
		AND (:7 is NULL or ea.value_textb = :7)
		AND EXISTS
		(
			SELECT 'x'
			FROM org
			WHERE owner_org_id = :5
			AND org_internal_id = e.facility_id
		)
		AND e.event_id = ea.parent_id
		%startTimeConstraints%
		%excludeDiscardedAppts%
		AND aat.id = ea.value_int
		ORDER BY 5, 7
};

$STMTMGR_REPORT_SCHEDULING = new App::Statements::Report::Scheduling(

# -----------------------------------------------------------------------------------------
	'sel_appointments_byStatus' => {
		sqlStmt => qq{
			select caption as appointments, count(caption) as count, event_status
			from Appt_Status, Event, Event_Attribute
			where value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and Event.event_id = Event_Attribute.parent_id
				and (:6 is NULL or Event_Attribute.value_textb = :6)
				and (:1 is NULL or Event.facility_id = :1)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = Event.facility_id
				)
				and Event.start_time >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				and Event.start_time <  to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				and Appt_Status.id = Event.event_status
			group by caption, event_status
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Appointments',
						url => q{javascript:doActionPopup(
							'#hrefSelfPopup#&detail=appointments&event_status=#2#&caption=#0#',
							null,'location,status,width=800,height=600,scrollbars,resizable')
						},
						hint => 'View Details'
					},
					{head => 'Count', dAlign => 'right',summarize=>'sum'},
				],
		},
	},

	'sel_DetailAppointmentStatus'=>{
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond =>q{e.event_status = :1},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,
	},

	'sel_DetailDiscardAppointment'=>{
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Discard_Type WHERE id = e.discard_type) as appt_status},
		discardRemarks => qq{, discard_remarks },
		whereCond =>q{e.event_status = :1},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $discardAppt_defn,
	},

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
				AND ((ii.data_text_b is NOT NULL AND ii.data_text_b != 'void')
					OR ii.data_text_b is NULL)
				AND ii.item_type != @{[ App::Universal::INVOICEITEMTYPE_VOID ]}
				AND (:1 is NULL or e.facility_id = :1)
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 	'x'
					FROM 	org
					WHERE 	owner_org_id = :4
					AND 	org_internal_id = e.facility_id
				)
				AND e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND e.event_id = ea.parent_id
				AND e.event_id = t.parent_event_id
				AND e.event_status < 3
				AND i.main_transaction = t.trans_id
				AND i.invoice_status != 16
				AND i.parent_invoice_id is NULL
				AND ii.parent_id = i.invoice_id
				AND ii.code is not NULL
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
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		fromTable =>q{,	transaction t,
			invoice i,
			invoice_item ii
		},
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond => qq{ii.parent_id = i.invoice_id
			AND ii.code = :1
			AND ((ii.data_text_b is NOT NULL AND ii.data_text_b != 'void')
				OR ii.data_text_b is NULL)
			AND ii.item_type != @{[ App::Universal::INVOICEITEMTYPE_VOID ]}
			AND i.main_transaction = t.trans_id
			AND i.invoice_status != 16
			AND i.parent_invoice_id is NULL
			AND e.event_id = t.parent_event_id
		},
		excludeDiscardedAppts => qq{AND e.event_status < 3},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	# -----------------------------------------------------------------------------------------
	'sel_missingEncounter' =>
	{
		sqlStmt => qq{
			SELECT to_char(e.CHECKIN_STAMP - :5, '$SQLSTMT_DEFAULTDATEFORMAT'), count (*)
			FROM 	Event e, Event_Attribute ea
			WHERE	(:1 is NULL or facility_id = :1)
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				AND ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND e.event_id = ea.parent_id
				AND e.checkin_stamp is NOT NULL
				AND e.checkout_stamp is NULL
			GROUP BY to_char(e.CHECKIN_STAMP - :5, '$SQLSTMT_DEFAULTDATEFORMAT')
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
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond => qq{
			e.checkin_stamp >= TO_DATE(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			and e.checkin_stamp < TO_DATE(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
			and e.checkout_stamp is NULL
		},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	# -----------------------------------------------------------------------------------------

	'sel_dateEntered' =>
	{
		sqlStmt => qq{
			SELECT to_char(e.scheduled_stamp -:5, '$SQLSTMT_DEFAULTDATEFORMAT'), count(*)
			FROM 	Event e, Event_Attribute ea
			WHERE	(:1 is NULL or facility_id = :1)
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				AND ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND e.scheduled_stamp >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND e.scheduled_stamp <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND e.event_id = ea.parent_id
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
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond => qq{
			e.scheduled_stamp >= TO_DATE(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			and e.scheduled_stamp < TO_DATE(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		startTimeConstraints => qq{
			AND e.scheduled_stamp >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.scheduled_stamp <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	# -----------------------------------------------------------------------------------------
	'sel_patientsProduct' =>{
		sqlStmt => qq{
			SELECT	ct.caption, count(distinct e.event_id) as count
			FROM claim_type ct,
				insurance ins,
				invoice_billing ib,
				invoice i,
				transaction t,
				Event_Attribute ea,
				Event e
			WHERE e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND e.event_status < 3
				AND (:1 is NULL or e.facility_id = :1)
				AND ea.parent_id = e.event_id
				AND ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				AND t.parent_event_id = e.event_id
				AND i.main_transaction = t.trans_id
				AND i.parent_invoice_id is NULL
				AND i.invoice_status != 16
				AND ib.bill_id = i.billing_id
				AND ins.ins_internal_id = ib.bill_ins_id
				AND ct.id = ins.ins_type
			GROUP BY ct.caption
		UNION
			SELECT	ct.caption, count(distinct e.event_id) as count
			FROM claim_type ct,
				insurance ins,
				invoice_billing ib,
				invoice i,
				transaction t,
				Event_Attribute ea,
				Event e
			WHERE e.start_time >= TO_DATE(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :5
				AND	e.start_time <  TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :5
				AND e.event_status < 3
				AND (:1 is NULL or e.facility_id = :1)
				AND	ea.parent_id = e.event_id
				AND ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				AND t.parent_event_id = e.event_id
				AND i.main_transaction = t.trans_id
				AND i.parent_invoice_id is NULL
				AND i.invoice_status != 16
				AND ib.bill_id = i.billing_id
				AND ib.bill_ins_id is NULL
				AND ct.id = 0
			GROUP BY ct.caption
		},

		publishDefn => {
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
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		fromTable => qq{,invoice i,
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
		excludeDiscardedAppts => qq{AND e.event_status < 3},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	'sel_detailPatientsProductSelfPay' =>{
		sqlStmt => $STMTFMT_DETAIL_APPT_SCHEDULE,
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		fromTable=>q	{,invoice i,
			invoice_billing ib,
			claim_type ct,
			transaction t
		},
		whereCond=>q{	ct.caption = :1
			AND	e.event_id = t.parent_event_id
			AND	i.main_transaction = t.trans_id
			AND	ib.bill_id = i.billing_id
			AND	ib.bill_ins_id is NULL
			AND	ct.id = 0
		},
		excludeDiscardedAppts => qq{AND e.event_status < 3},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	# -----------------------------------------------------------------------------------------

	'sel_patientsSeen' => {
		sqlStmt => qq{
			select value_textB as physician, count(value_textB) as count
			from Event e, Event_Attribute ea
			where ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				AND (:1 is NULL or e.facility_id = :1)
				AND (:6 is NULL or ea.value_textb = :6)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				and e.event_id = ea.parent_id
				and e.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and e.event_status = 2
			group by ea.value_textB
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
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond =>q{ event_status = 2 AND ea.value_textB = :1},
		#excludeDiscardedAppts => qq{AND e.event_status < 3},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE	,

	},

	# -----------------------------------------------------------------------------------------
	'sel_patientsSeen_byPatientType' => {
		sqlStmt => qq{
			select caption as patient_type, count(caption) as count, Appt_Attendee_Type.id
			from Appt_Attendee_Type, Event e, Event_Attribute ea
			where ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
				and e.event_id = ea.parent_id
				and (:6 is NULL or ea.value_textb = :6)
				and (:1 is NULL or e.facility_id = :1)
				AND EXISTS
				(
					SELECT 'x'
					FROM org
					WHERE owner_org_id = :4
					AND org_internal_id = e.facility_id
				)
				and e.start_time between to_date(:2 || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
					and to_date(:3 || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT') + :5
				and e.event_status = 2
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
		apptStatusSelect => qq{(SELECT caption FROM Appt_Status WHERE id = e.event_status) as appt_status},
		whereCond=>q{ea.value_int = :1 and event_status = 2 },
		#excludeDiscardedAppts => qq{AND e.event_status < 3},
		startTimeConstraints => qq{
			AND e.start_time >= TO_DATE(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :6
			AND e.start_time <  TO_DATE(:4, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :6
		},
		publishDefn => $STMTRPTDEFN_DETAIL_APPT_SCHEDULE,
	},

	'selSuperBills' => {
		sqlStmt => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time
			from event e, event_attribute ea
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time
			from event e, event_attribute ea, appt_type apt
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is null
			and e.appt_type = apt.appt_type_id
			and apt.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
		}
	},

	'selSuperBillsPhysician' => {
		sqlStmt => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time
			from event e, event_attribute ea
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
			and ea.value_textb = :5
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time
			from event e, event_attribute ea, appt_type apt
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is null
			and e.appt_type = apt.appt_type_id
			and apt.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
			and ea.value_textb = :5
		}
	},

);

1;
