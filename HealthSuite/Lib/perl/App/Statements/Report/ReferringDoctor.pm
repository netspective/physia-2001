##############################################################################
package App::Statements::Report::ReferringDoctor;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_REFERRING_DOCTOR);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_REFERRING_DOCTOR );

$STMTMGR_REPORT_REFERRING_DOCTOR = new App::Statements::Report::ReferringDoctor
(
	'totalPatientCount' =>
	{
		sqlStmt => qq
		{
			select count(i.client_id) patientCount
			from person p, transaction t, invoice i
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
		}
	},

	'patientCount' =>
	{
		sqlStmt => qq
		{
			select p.simple_name name, p.person_id, count(i.client_id) patientCount
			from person p, transaction t, invoice i
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			group by p.simple_name, p.person_id
		},

		sqlStmtBindParamDescr => ['Date Range when the Doctor has referred the patient in which Plan'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Doctor',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0#',
				},
				{
					colIdx => 1,
					head => '# of Patients',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#2#',
				},
			],
		},
	},

	'patientOrgCount' =>
	{
		sqlStmt => qq
		{
			select p.simple_name name, p.person_id, o.name_primary, count(i.client_id) patientCount
			from person p, transaction t, invoice i, org o, invoice_billing ib, insurance ins
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.billing_id = ib.bill_id
			and ib.bill_ins_id = ins.ins_internal_id
			and ins.ins_org_id = o.org_internal_id
			and ib.bill_party_type = 3
			group by p.simple_name, p.person_id, o.name_primary

			union

			select p.simple_name name, p.person_id, null, count(i.client_id) patientCount
			from person p, transaction t, invoice i, invoice_billing ib
			where i.invoice_date between to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') and to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and t.trans_id = i.main_transaction
			and p.person_id = t.data_text_a
			and i.billing_id = ib.bill_id
			and ib.bill_party_type <> 3
			group by p.simple_name, p.person_id
		},

		sqlStmtBindParamDescr => ['Date Range when the Doctor has referred the patient in which Plan'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Doctor',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0#',
				},
				{
					colIdx => 1,
					head => 'Insurance Org',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#2#',
				},
				{
					colIdx => 2,
					head => '# of Patients',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#3#',
				},
			],
		},
	},
);


1;

