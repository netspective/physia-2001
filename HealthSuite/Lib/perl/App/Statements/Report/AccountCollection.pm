##############################################################################
package App::Statements::Report::AccountCollection;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_ACCOUNT_COLLECTION);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_ACCOUNT_COLLECTION );

my $ACTIVE = App::Universal::TRANSSTATUS_ACTIVE;
my $OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;

$STMTMGR_REPORT_ACCOUNT_COLLECTION = new App::Statements::Report::AccountCollection
(
	'selCollectors' =>
	{
		sqlStmt => qq
		{
			select distinct
				p1.simple_name patient_name,
				t1.trans_owner_id patient_id,
				i.balance,
				trunc(sysdate - i.invoice_date) age,
				p2.simple_name provider_name,
				t1.provider_id provider_id,
				t2.detail notes
			from
				invoice i,
				person p1,
				person p2,
				transaction t1,
				person_org_category poc,
				(
					select * from	transaction
					where trans_type = $NOTES
				) t2
			where i.invoice_date between to_date(:1, 'MM/DD/YYYY') and to_date(:2, 'MM/DD/YYYY')
			and i.balance > 0
			and i.invoice_status <> 16
			and i.invoice_id = t1.trans_invoice_id
			and t1.trans_owner_id = p1.person_id
			and t1.trans_owner_id = t2.trans_owner_id (+)
			and p1.person_id = poc.person_id
			and poc.org_internal_id = :3
			and t1.provider_id = p2.person_id
			and t1.trans_status = $ACTIVE
			and t1.trans_type = $OWNER
			and t1.trans_subtype = 'Owner'
			order by trunc(sysdate - i.invoice_date) desc
		},

		sqlStmtBindParamDescr => ['Date Range and Org Internal Id'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Patient',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0# <A HREF = "/person/#1#/profile">#1#</A>',
				},
				{
					colIdx => 2,
					head => 'Balance',
					hAlign => 'center',
					dAlign => 'right',
					dformat => 'currency',
					summarize => 'sum',
					dataFmt => '#2#',
				},
				{
					colIdx => 3,
					head => 'Age',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#3#',
				},
				{
					colIdx => 4,
					head => 'Collector',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#4# <A HREF = "/person/#5#/profile">#5#</A>',
				},
				{
					colIdx => 6,
					head => 'Notes',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#6#',
				},
			],
		},
	},
);


1;

