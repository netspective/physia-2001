##############################################################################
package App::Statements::Report::Prescription;
##############################################################################

use strict;

use DBI::StatementManager;
use Data::Publish;
use vars qw(@EXPORT $STMTMGR_REPORT_PRESCRIPTION);
use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_PRESCRIPTION);


$STMTMGR_REPORT_PRESCRIPTION = new App::Statements::Report::Prescription (

	'selPrescriptionByID' => {
		sqlStmt => qq
		{
			select *
			from person_medication
			where permed_id = :1
			and cr_org_internal_id = :2
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

	'physicianDEA' => {
		sqlStmt => qq
		{
			select value_text dea
			from person_attribute
			where parent_id = :1
			and item_name = 'DEA'
			and value_type = 500
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
			select value_text phone
			from org_attribute
			where parent_id = :1
			and item_name = 'Primary'
			and value_type = 10
		}
	},

);

1;
