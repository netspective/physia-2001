##############################################################################
package App::Statements::Report::SuperBill;
##############################################################################

use strict;

use DBI::StatementManager;
use Data::Publish;
use vars qw(@EXPORT $STMTMGR_REPORT_SUPERBILL);
use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_SUPERBILL);


$STMTMGR_REPORT_SUPERBILL = new App::Statements::Report::SuperBill (

	'selSBbyStartEndDate' => {
		sqlStmt => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :3, 'HH24:MI') as start_time
			from event e, event_attribute ea
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :3, 'HH24:MI') as start_time
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

	'selSBbyStartEndDatePhysician' => {
		sqlStmt => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :3, 'HH24:MI') as start_time
			from event e, event_attribute ea
			where e.event_id = ea.parent_id
			and owner_id = :4
			and e.superbill_id is not null
			and e.start_time >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') + :3
			and e.start_time < to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + 1 + :3
			and ea.value_textb = :5
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :3, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :3, 'HH24:MI') as start_time
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

	'selSBbyEvents' => {
		sqlStmt => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :2, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :2, 'HH24:MI') as start_time
			from event e, event_attribute ea
			where e.event_id = :1
			and e.event_id = ea.parent_id
			and owner_id = :3
			and e.superbill_id is not null
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id,
				to_char(e.start_time - :2, '$SQLSTMT_DEFAULTDATEFORMAT') as start_date,
				to_char(e.start_time - :2, 'HH24:MI') as start_time
			from event e, event_attribute ea, appt_type apt
			where e.event_id = :1
			and e.event_id = ea.parent_id
			and owner_id = :3
			and e.superbill_id is null
			and e.appt_type = apt.appt_type_id
			and apt.superbill_id is not null
		}
	},

	'catalogEntryHeader' => {
		sqlStmt => qq
		{
			select entry_id, name
			from offering_catalog_entry
			where catalog_id = :1
			and parent_entry_id is null
			and entry_type = 0
			and status = 1
			and not name = 'main'
			order by entry_id
		}
	},

	'catalogEntryCount' => {
		sqlStmt => qq
		{
			select count(*) entry_count
			from offering_catalog_entry
			where catalog_id = :1
			and parent_entry_id = :2
			and entry_type = 100
			and status = 1
		}
	},

	'catalogEntries' => {
		sqlStmt => qq
		{
			select entry_id, code, name
			from offering_catalog_entry
			where catalog_id = :1
			and parent_entry_id = :2
			and entry_type = 100
			and status = 1
			order by entry_id
		}
	},

	'personInfo' => {
		sqlStmt => qq
		{
			select
				name_last,
				name_middle,
				name_first,
				person_id,
				to_char(date_of_birth, 'DD-MON-YYYY') dob,
				gender,
				marital_status,
				ssn,
				simple_name
			from person
			where person_id = :1
		}
	},

	'personAddressInfo' => {
		sqlStmt => qq
		{
			select line1, line2, city, state, zip, country
			from person_address
			where parent_id = :1
			and address_name = 'Home'
		}
	},

	'personContactInfo' => {
		sqlStmt => qq
		{
			select value_text phone
			from person_attribute
			where parent_id = :1
			and item_name = 'Home'
			and value_type = 10
		}
	},

	'orgInfo' => {
		sqlStmt => qq
		{
			select org_id, name_primary, tax_id
			from org
			where org_internal_id = :1
		}
	},

	'orgAddressInfo' => {
		sqlStmt => qq
		{
			select line1, line2, city, state, zip, country
			from org_address
			where parent_id = :1
			and address_name = 'Mailing'
		}
	},

	'orgContactInfo' => {
		sqlStmt => qq
		{
			select value_text
			from org_attribute
			where parent_id = :1
			and item_name = 'Primary'
			and value_type = 10
		}
	},

);

1;
