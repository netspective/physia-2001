##############################################################################
package App::Statements::Component::Scheduling;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

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
		{colIdx => 7, head => 'Due', hHint => 'Copay due by patient for this visit', url => '/invoice/#9#/dialog/adjustment/personal,#11#', 
			hint => "Copay due for this visit.\nClick to apply payment.", 
			dAlign => 'right', dformat => 'currency', summarize => 'sum'},
		{colIdx => 8, hint => 'View Account Balance', head => 'Balance', url => '/person/#10#/account', dAlign => 'right', dformat => 'currency', summarize => 'sum'},
		{colIdx => 12, head => 'Action'},
	],
};

my $STMTFMT_SEL_EVENTS_WORKLIST = qq{
	patient.name_last || ', ' || substr(patient.name_first,1,1) as patient,
	ea.value_textB as physician,
	e.facility_id as facility,
	%simpleStamp:e.start_time% as appointment_time,
	%simpleStamp:e.checkin_stamp% as checkin_time,
	%simpleStamp:e.checkout_stamp% as checkout_time,
	Invoice.invoice_id,
	patient.person_id as patient_id,
	e.event_id,
	Appt_Type.caption as appt_type,
	replace(Appt_Attendee_Type.caption, ' Patient', '') as patient_type,
	Invoice_Status.caption as invoice_status
	from Invoice_Status, Appt_Attendee_Type, Appt_Type, Invoice, Transaction,
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
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = ?
		)
	and e.facility_id in (
		select value_int from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
			and item_name = '$WORKLIST_ITEMNAME'
			and parent_org_id = ?
		)
	and Transaction.parent_event_id(+) = e.event_id
	and Invoice.main_transaction(+) = Transaction.trans_id
	and Appt_Type.appt_type_id = e.appt_type
	and Appt_Attendee_Type.id = ea.value_int
	and Invoice_Status.id(+) = Invoice.invoice_status
};

my $STMTFMT_SEL_EVENTS_WORKLIST_ORDERBY = qq{
	e.start_time, ea.value_text
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
			e.start_time between sysdate - (?/24/60) and sysdate + (?/24/60)			
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
			e.start_time between to_date(?, '$STAMPFORMAT')
				and to_date(?, '$STAMPFORMAT')
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
			e.start_time between to_date(?, '$STAMPFORMAT')
				and to_date(?, '$STAMPFORMAT')
		},
		
		publishDefn => $STMTRPTDEFN_WORKLIST,
	},

# ---------------------------------------------------------------------------------
	'sel_deadBeatBalance' => qq{
			select sum(balance)
			from invoice
			where client_id = ?
				and balance > 0
	},

	'sel_copayInfo' => qq{
			select extended_cost as amount, balance, item_id
			from Invoice_Item
			where parent_id = ?
			and item_type = 3
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
	
);
	
1;
