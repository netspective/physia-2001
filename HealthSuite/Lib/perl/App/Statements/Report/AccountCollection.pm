##############################################################################
package App::Statements::Report::AccountCollection;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_ACCOUNT_COLLECTION $PUBLISH_DEFN);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_ACCOUNT_COLLECTION $PUBLISH_DEFN);

my $ACTIVE = App::Universal::TRANSSTATUS_ACTIVE;
my $OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;


$PUBLISH_DEFN =
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
			colIdx => 5,
			head => 'Notes',
			hAlign => 'center',
			dAlign => 'right',
			dataFmt => '#6#',
			url => q{javascript:doActionPopup('#hrefSelfPopup#&detail=notes&person_id=#1#')}
		},
	],
};


$STMTMGR_REPORT_ACCOUNT_COLLECTION = new App::Statements::Report::AccountCollection
(
	'selCollectors' =>
	{
		sqlStmt => qq
		{
			select distinct
				p1.simple_name patient_name,
				iw.person_id patient_id,
				i.balance,
				trunc(sysdate - i.invoice_date) age,
				iw.invoice_id
			from	person p1,
				Invoice_Worklist iw,
				person_org_category poc,
				invoice i
			where i.invoice_date between to_date(:1, 'MM/DD/YYYY') and to_date(:2, 'MM/DD/YYYY')
			and i.balance > 0
			and i.invoice_status <> 16
			and i.invoice_id = iw.invoice_id
			and iw.person_id = p1.person_id
			and p1.person_id = poc.person_id
			and poc.org_internal_id = :3
			and iw.worklist_type='Collection'
			AND iw.worklist_status = 'Account In Collection'
			order by trunc(sysdate - i.invoice_date) desc
		},

		sqlStmtBindParamDescr => ['Date Range and Org Internal Id'],

	},


	'selCollectorsOwners' =>
	{
		sqlStmt => qq
		{
			select distinct
				p2.simple_name provider_name,
				iw.owner_id provider_id
			from
				person p2,
				Invoice_Worklist iw
			where iw.person_id = :1
			and iw.owner_id = p2.person_id
			and iw.worklist_type='Collection'
			AND iw.worklist_status = 'Account In Collection'
			and iw.responsible_id = iw.owner_id
			order by 2
		},
	},


	'selCollectorsNotesCount' =>
	{
		sqlStmt => qq
		{
			select count(*)
			from transaction
			where trans_type = $NOTES
			and trans_owner_id = :1
		},

	},

	'selCollectorsNotes' =>
	{
		sqlStmt => qq
		{
			select detail
			from transaction
			where trans_type = $NOTES
			and trans_owner_id = :1
		},

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Notes',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#0#',
				},
			],
		},
	},
);

1;
