##############################################################################
package App::Statements::Report::InsuranceAnalysis;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_INSURANCE_ANALYSIS_MAIN $STMTMGR_REPORT_INSURANCE_ANALYSIS $STMTMGR_REPORT_INSURANCE_ANALYSIS_CPT $PUB_DEFN);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_INSURANCE_ANALYSIS );

$STMTMGR_REPORT_INSURANCE_ANALYSIS_MAIN = qq
{

	SELECT
		o.name_primary,
		ii.code, ref_cpt.name,
		sum(quantity) units,
		avg(iia.plan_allow) avg_charge,
		avg(iia.plan_paid) avg_paid,
		max(iia.plan_paid) max_paid,
		min(iia.plan_paid) min_paid,
		o.org_id
	FROM
		invoice i,
		invoice_item ii,
		invoice_item_adjust iia,
		invoice_billing ib,
		insurance ins,
		org o,
		ref_cpt
	WHERE i.invoice_id = ii.parent_id
		and ii.item_id = iia.parent_id
		and i.billing_id = ib.bill_id
		and ib.bill_ins_id = ins.ins_internal_id
		and i.invoice_subtype not in ( 0,7 )
		and o.org_internal_id = ins.ins_org_id
		and ref_cpt.cpt = ii.code
		and iia.plan_paid != 0
		and (i.invoice_date >= to_date(:1, '$SQLSTMT_DEFAULTDATEFORMAT') or :1 is null)
		and (i.invoice_date <= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') or :2 is null)
		and (ii.service_begin_date >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') or :3 is null)
		and (ii.service_end_date <= to_date(:4, '$SQLSTMT_DEFAULTDATEFORMAT') or :4 is null)
		and (ii.code >= :5 or :5 is null)
		and (ii.code <= :6 or :6 is null)
		and (o.org_id = :7 or :7 is null)
		and i.owner_id = :8
	GROUP BY o.name_primary, ii.code, ref_cpt.name, o.org_id
	%orderbyClause%
};

$PUB_DEFN =
{
	columnDefn =>
	[
		{
			colIdx => 0,
			head => 'Insurance Co.',
			hAlign => 'center',
			dAlign => 'left',
			dataFmt => '<A HREF = "/org/#8#/account">#0#</A>',
		},
		{
			colIdx => 1,
			head => 'Code',
			hAlign => 'center',
			dAlign => 'left',
			dataFmt => '#1#',
		},
		{
			colIdx => 2,
			head => 'Description',
			hAlign => 'center',
			dAlign => 'left',
			dataFmt => '#2#',
		},
		{
			colIdx => 3,
			head => 'Units',
			hAlign => 'center',
			dAlign => 'right',
			dataFmt => '#3#'
		},
		{
			colIdx => 4,
			head => 'Avg Charge',
			hAlign => 'center',
			dformat => 'currency',
			dataFmt => '#4#',
		},
		{
			colIdx => 5,
			head => 'Avg Reimbursement',
			hAlign => 'center',
			dAlign => 'right',
			dataFmt => '#5#',
			dformat => 'currency',
		},
		{
			colIdx => 6,
			head => 'High Reimbursement',
			hAlign => 'center',
			dAlign => 'right',
			dataFmt => '#6#',
			dformat => 'currency',
		},
		{
			colIdx => 7,
			head => 'Low Reimbursement',
			hAlign => 'center',
			dAlign => 'right',
			dataFmt => '#7#',
			dformat => 'currency',
		},
	],
};

$STMTMGR_REPORT_INSURANCE_ANALYSIS = new App::Statements::Report::InsuranceAnalysis
(
	'selInsuranceAnalysisByInsurance' =>
	{
		sqlStmt => $STMTMGR_REPORT_INSURANCE_ANALYSIS_MAIN,
		orderbyClause => 'order by name_primary',
		sqlStmtBindParamDescr => ['batch date range,service date range, cpt code range,insurance org id,sort order'],
		publishDefn => $PUB_DEFN,
	},

	'selInsuranceAnalysisByCpt' =>
	{
		sqlStmt => $STMTMGR_REPORT_INSURANCE_ANALYSIS_MAIN,
		orderbyClause => 'order by code',
		sqlStmtBindParamDescr => ['batch date range,service date range, cpt code range,insurance org id,sort order'],
		publishDefn => $PUB_DEFN,
	},

);


1;

