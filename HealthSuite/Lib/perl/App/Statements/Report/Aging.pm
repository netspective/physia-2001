##############################################################################
package App::Statements::Report::Aging;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_REPORT_AGED_INSURANCE $STMTMGR_REPORT_AGED_PATIENT $STMTRPTDEFN_AGED_INSURANCE $STMTRPTDEFN_AGED_PATIENT $STMTMGR_REPORT_AGING);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_AGED_INSURANCE $STMTMGR_REPORT_AGED_PATIENT $STMTMGR_REPORT_AGING);

$STMTRPTDEFN_AGED_INSURANCE =
{
	columnDefn =>
		[
			{ colIdx => 0, head => 'ID', dataFmt => '<A HREF = "/invoice/#0#/summary">#0#</A>' },
			{ colIdx => 1, head => 'IC', tAlign=>'center', ,dataFmt => '#1#',dAlign =>'center' },
			{ colIdx => 2, head => 'Svc Date', dataFmt => '#2#' },
			{ colIdx => 3, head => 'Status', dataFmt => '#3#'},
			{ colIdx => 4, head => 'Client', dataFmt => '#4#' },
			{ colIdx => 5, head => 'Charges',summarize=>'sum', dataFmt => '#5#', dformat => 'currency' },
			{ colIdx => 6, head => 'Adjust',summarize=>'sum', dataFmt => '#6#', dformat => 'currency' },
			{ colIdx => 7, head => 'Balance',summarize=>'sum', dataFmt => '#7#', dformat => 'currency' },
		],
},

$STMTRPTDEFN_AGED_PATIENT =
{
	columnDefn =>
			[
				{ head => 'ID', url => '/invoice/#&{?}#/summary', hint => "Created on: #14#",dAlign => 'RIGHT'},
				{ head => 'IC', hint => 'Number Of Items In Claim',dAlign => 'CENTER'},
				{ head => 'Svc Date'},
				{ head => 'Status', colIdx => 12, dataFmt => {
										'0' => '#3#',
										'1' => '#3#',
										'2' => '#3#',
										'3' => '#3#',
										'4' => '#3#',
										'5' => '#3#',
										'6' => '#3#',
										'7' => '#3#',
										'8' => '#3#',
										'9' => '#3#',
										'10' => '#3#',
										'11' => '#3#',
										'12' => '#3#',
										'13' => '#3#',
										'14' => '#3#',
										'15' => '#3#',
										'16' => 'Void #13#'
									},
				},
				{ head => 'Payer', colIdx => 11, dataFmt => {
										'0'  => '#4#',
										'1'  => '#4#',
										'2' => '#10#',
										'3' => '#10#',
									},
				},
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
};

$STMTMGR_REPORT_AGED_INSURANCE = qq
{
	SELECT
	i.invoice_id,
	i.total_items,
	TO_CHAR(MIN(iit.service_begin_date), 'MM/DD/YYYY') AS service_begin_date,
	ist.caption as invoice_status,
	ib.bill_to_id,
	i.total_cost,
	i.total_adjust,
	i.balance,
	i.client_id,
	ib.bill_to_id,
	o.org_id,
	ib.bill_party_type,
	i.invoice_status as status_id,
	i.parent_invoice_id,
	to_char(i.invoice_date, 'MM/DD/YYYY') as invoice_date
	FROM invoice i, invoice_status ist, invoice_billing ib, invoice_item iit, org o, transaction t
	WHERE
	ib.bill_to_id = :1
	AND iit.parent_id (+) = i.invoice_id
	AND ib.bill_id (+) = i.billing_id
	AND ist.id = i.invoice_status
	AND to_char(o.org_internal_id (+)) = ib.bill_to_id
	AND NOT (i.invoice_status = 15 AND i.parent_invoice_id is not NULL)
	AND i.main_transaction = t.trans_id
	%whereClause%
	GROUP BY
	i.invoice_id,
	i.total_items,
	ist.caption,
	i.total_cost,
	i.total_adjust,
	i.balance,
	i.client_id,
	ib.bill_to_id,
	o.org_id,
	ib.bill_party_type,
	i.invoice_status,
	i.parent_invoice_id,
	i.invoice_date
	ORDER BY i.invoice_id desc
};

$STMTMGR_REPORT_AGED_PATIENT = qq
{

	SELECT
	i.invoice_id,
	i.total_items,
	TO_CHAR(MIN(iit.service_begin_date), 'MM/DD/YYYY') AS service_begin_date,
	ist.caption as invoice_status,
	ib.bill_to_id,
	i.total_cost,
	i.total_adjust,
	i.balance,
	i.client_id,
	ib.bill_to_id,
	o.org_id,
	ib.bill_party_type,
	i.invoice_status as status_id,
	i.parent_invoice_id,
	to_char(i.invoice_date, 'MM/DD/YYYY') as invoice_date
	FROM invoice i, invoice_status ist, invoice_billing ib, invoice_item iit, org o, transaction t
	WHERE
	upper(client_id) = :1 and (owner_type = 1 and owner_id = :2)
	AND iit.parent_id (+) = i.invoice_id
	AND ib.bill_id (+) = i.billing_id
	AND ist.id = i.invoice_status
	AND to_char(o.org_internal_id (+)) = ib.bill_to_id
	AND NOT (i.invoice_status = 15 AND i.parent_invoice_id is not NULL)
	AND i.main_transaction = t.trans_id
	%whereClause%
	GROUP BY
	i.invoice_id,
	i.total_items,
	ist.caption,
	i.total_cost,
	i.total_adjust,
	i.balance,
	i.client_id,
	ib.bill_to_id,
	o.org_id,
	ib.bill_party_type,
	i.invoice_status,
	i.parent_invoice_id,
	i.invoice_date
	ORDER BY i.invoice_id desc
};

$STMTMGR_REPORT_AGING = new App::Statements::Report::Aging(
	'sel_detail_aged_ins' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_INSURANCE,
		whereClause => '',
		publishDefn => $STMTRPTDEFN_AGED_INSURANCE,
	},

	'sel_detail_aged_ins_prov' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_INSURANCE,
		whereClause => 'and t.care_provider_id = :2',
		publishDefn => $STMTRPTDEFN_AGED_INSURANCE,
	},

	'sel_detail_aged_ins_org' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_INSURANCE,
		whereClause => 'and t.service_facility_id = :2',
		publishDefn => $STMTRPTDEFN_AGED_INSURANCE,
	},

	'sel_detail_aged_ins_prov_org' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_INSURANCE,
		whereClause => 'and t.care_provider_id = :2 and t.service_facility_id = :3',
		publishDefn => $STMTRPTDEFN_AGED_INSURANCE,
	},

	'sel_detail_aged_patient' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_PATIENT,
		whereClause => '',
		publishDefn => $STMTRPTDEFN_AGED_PATIENT
	},

	'sel_detail_aged_patient_prov' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_PATIENT,
		whereClause => 'and t.care_provider_id = :3',
		publishDefn => $STMTRPTDEFN_AGED_PATIENT
	},

	'sel_detail_aged_patient_org' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_PATIENT,
		whereClause => 'and t.service_facility_id = :3',
		publishDefn => $STMTRPTDEFN_AGED_PATIENT
	},

	'sel_detail_aged_patient_prov_org' =>
	{
		sqlStmt => $STMTMGR_REPORT_AGED_PATIENT,
		whereClause => 'and t.care_provider_id = :3 and t.service_facility_id = :4',
		publishDefn => $STMTRPTDEFN_AGED_PATIENT
	}

);

1;