##############################################################################
package App::Statements::Component::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_SCHEDULING $STMTRPTDEFN_WORKLIST
	);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_COMPONENT_SCHEDULING);

my $WORKLIST_ITEMNAME = 'WorkList';

#----------------------------------------------------------------------------------------------------------------------
my $timeFormat = 'HH:MIam';
$STMTRPTDEFN_WORKLIST =
{
	columnDefn =>
	[
		{colIdx => 0, head => '', dAlign => 'center'},
		{colIdx => 1, head => 'Patient'},
		{colIdx => 2, head => 'Appointment', dAlign => 'center'},
		{colIdx => 3, head => 'Confirm', dAlign => 'center'},
		{colIdx => 4, head => 'Checkin', dAlign => 'center'},
		{colIdx => 5, head => 'Checkout', dAlign => 'center'},
		{colIdx => 6, head => 'Claim', dAlign => 'center'},
		{colIdx => 7, head => 'OV Copay',
			hHint => 'Copay due by patient for this visit',
			dAlign => 'right', dformat => 'currency', summarize => 'sum'
		},
		{colIdx => 8, head => 'Account Balance', hint => 'View Account Balance',
			url => '/person/#10#/account',
			dAlign => 'right', dformat => 'currency', summarize => 'sum'
		},
		{colIdx => 12, head => 'Patient Balance', hint => 'View Account Balance',
			url => '/person/#10#/account',
			dAlign => 'right', dformat => 'currency', summarize => 'sum'
		},
		{colIdx => 11, head => 'Action'},
	],
};

my $STMTFMT_SEL_EVENTS_WORKLIST = qq{
	patient.name_last || ', ' || substr(patient.name_first,1,1) as patient,
	ea.value_textB as physician,
	e.facility_id as facility,
	%simpleStamp:e.start_time - :1% as appointment_time,
	%simpleStamp:e.checkin_stamp - :1% as checkin_time,
	%simpleStamp:e.checkout_stamp - :1% as checkout_time,
	Invoice.invoice_id,
	patient.person_id as patient_id,
	e.event_id,
	Appt_Type.caption as appt_type,
	replace(Appt_Attendee_Type.caption, ' Patient', '') as patient_type,
	Invoice_Status.caption as invoice_status,
	ea.value_intB as flags, o.org_id as facility_name, Invoice.invoice_status as inv_status,
	parent_invoice_id, e.parent_id
	from Org o, Invoice_Status, Appt_Attendee_Type, Appt_Type, Invoice, Transaction,
		Person patient, Event_Attribute ea, Event e
};

my $STMTFMT_SEL_EVENTS_WORKLIST_WHERECLAUSE = qq{
	%timeSelectClause%
	and e.discard_type is null
	and e.event_status in (0,1,2)
	and ea.parent_id = e.event_id
	and ea.value_text = patient.person_id
	and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
	and ea.value_textB in (
		select value_text from Person_Attribute
		where parent_id = :4
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = :5
		)
	and e.facility_id in (
		select value_int from Person_Attribute
		where parent_id = :4
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = :5
		)
	and Transaction.parent_event_id(+) = e.event_id
	and Invoice.main_transaction(+) = Transaction.trans_id
	and Appt_Type.appt_type_id (+) = e.appt_type
	and Appt_Attendee_Type.id = ea.value_int
	and Invoice_Status.id(+) = Invoice.invoice_status
	and o.org_internal_id = e.facility_id
};

my $STMTFMT_SEL_EVENTS_WORKLIST_ORDERBY = qq{
	e.start_time, e.facility_id, ea.value_text
};

my $STAMPFORMAT = 'mm/dd/yyyy hh12:miam';

$STMTMGR_COMPONENT_SCHEDULING = new App::Statements::Component::Scheduling(
	'sel_events_worklist_today' => {
		sqlStmt => qq{
			select $STMTFMT_SEL_EVENTS_WORKLIST
			where	$STMTFMT_SEL_EVENTS_WORKLIST_WHERECLAUSE
			order by $STMTFMT_SEL_EVENTS_WORKLIST_ORDERBY
		},

		timeSelectClause => qq{
			e.start_time between sysdate - :6 - (:2/24/60) and sysdate - :6 + (:3/24/60)
		},

		publishDefn => $STMTRPTDEFN_WORKLIST,
	},

	'sel_events_worklist_today_byTime' => {
		sqlStmt => qq{
			select $STMTFMT_SEL_EVENTS_WORKLIST
			where	$STMTFMT_SEL_EVENTS_WORKLIST_WHERECLAUSE
			order by $STMTFMT_SEL_EVENTS_WORKLIST_ORDERBY
		},

		timeSelectClause => qq{
			e.start_time between to_date(:2, '$STAMPFORMAT') + :1 and to_date(:3, '$STAMPFORMAT') + :1
		},

		publishDefn => $STMTRPTDEFN_WORKLIST,
	},

	'sel_events_worklist_not_today' => {
		_stmtFmt => qq{
			select $STMTFMT_SEL_EVENTS_WORKLIST
			where	$STMTFMT_SEL_EVENTS_WORKLIST_WHERECLAUSE
			order by $STMTFMT_SEL_EVENTS_WORKLIST_ORDERBY
		},

		timeSelectClause => qq{
			e.start_time between to_date(:2, '$STAMPFORMAT') + :1 and to_date(:3, '$STAMPFORMAT') + :1
		},

		publishDefn => $STMTRPTDEFN_WORKLIST,
	},

# ---------------------------------------------------------------------------------
	'sel_accountBalance' => qq{
		select nvl(sum(balance), 0)
		from invoice
		where client_id = :1
			and invoice_status > 3
			and invoice_status != 15
			and invoice_status != 16
			and balance > 0
	},

	'sel_patientBalance' => qq{
		select nvl(sum(balance), 0)
		from invoice
		where client_id = :1
			and invoice_status > 3
			and invoice_status != 15
			and invoice_status != 16
			and invoice_subtype = 0
			and balance > 0
	},

	'sel_copayInfo' => qq{
			select extended_cost as amount, balance, item_id
			from Invoice_Item
			where parent_id = ?
			and item_type = 3
	},

	'sel_copay' => qq{
		select Insurance.copay_amt
		from Insurance, Invoice_Billing, Invoice
		where Invoice.invoice_id = :1
			and Invoice_Billing.bill_id = Invoice.billing_id
			and Insurance.ins_internal_id = Invoice_billing.bill_ins_id
	},

	'del_worklist_resources' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = ?
			and parent_org_id = ?
	},

	'sel_worklist_resources' => qq{
		select value_text as resource_id
		from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = ?
			and parent_org_id = ?
	},

	'del_worklist_facilities' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = ?
	},

	'sel_worklist_facilities' => qq{
		select value_int as facility_id
		from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = ?
	},

	'sel_populateInsVerifyDialog' => qq{
		select * from Sch_Verify where event_id = ?
	},

	'sel_MostRecentVerify' => qq{
		select * from Sch_Verify where person_id = :1
		and ins_verify_date = (select max(ins_verify_date) from Sch_Verify where person_id = :1)
	},

	'sel_populateAppConfirmDialog' => qq{
		select app_verified_by, app_verify_date, verify_action
		from Sch_Verify where event_id = ?
	},

	'sel_populateMedVerifyDialog' => qq{
		select med_verified_by, med_verify_date from Sch_Verify where event_id = ?
	},

	'sel_populatePersonalVerifyDialog' => qq{
		select per_verified_by, per_verify_date from Sch_Verify where event_id = ?
	},

	'sel_EventAttribute' => qq{
		select * from Event_Attribute where parent_id = :1
			and value_type = :2
	},

	'sel_alerts' => qq{
		select * from Transaction
		where trans_owner_id = ?
			and trans_owner_type = @{[ App::Universal::TRANSSTATUS_DEFAULT ]}
			and trans_type between 8000 and 8999
			and trans_status = @{[ App::Universal::TRANSSTATUS_ACTIVE ]}
	},

# ---------------------------------------------------------------------------------------
	'sel_detail_alerts' => {
		sqlStmt => qq{
				select Transaction.caption, detail, Transaction_Type.caption as trans_type, trans_subtype,
					to_char(trans_begin_stamp - :1, '$SQLSTMT_DEFAULTDATEFORMAT'),
					to_char(trans_end_stamp - :1, '$SQLSTMT_DEFAULTDATEFORMAT'),
					data_text_a, decode (trans_subtype, 'High', 1, 'Medium', 2, 'Low', 3, 3) as subtype_sort
				from Transaction_Type, Transaction
				where trans_type between 8000 and 8999
				and trans_owner_type = 0
				and trans_owner_id = :2
				and trans_status = 2
				and Transaction_Type.id = Transaction.trans_type
				order by subtype_sort asc, trans_begin_stamp desc
			},
		publishDefn => {
			columnDefn =>
			[
				{ head => 'Alerts',
					dataFmt => qq{<b>#0#</b> <br>
						#4# - #5#: (#3#) <u>#2#</u>: #6# <br>
						#1#
					},
				},
			],
		},
	},
);

1;
