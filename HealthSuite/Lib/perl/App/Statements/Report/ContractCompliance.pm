##############################################################################
package App::Statements::Report::ContractCompliance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REPORT_CONTRACT_COMPLIANCE);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_CONTRACT_COMPLIANCE );

$STMTMGR_REPORT_CONTRACT_COMPLIANCE = new App::Statements::Report::ContractCompliance
(
	'selCompliantInvoices' =>
	{
		sqlStmt => qq
		{
			select distinct
				to_char(iia.pay_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
				ins.product_name,
				i.invoice_id,
				ii.code,
				iia.plan_allow,
				iia.plan_paid
			from
				invoice i,
				invoice_item ii,
				invoice_item_adjust iia,
				invoice_billing ib,
				insurance ins,
				invoice_attribute ia
			where i.invoice_id = ii.parent_id
			and ii.item_id = iia.parent_id
			and iia.plan_allow <> iia.plan_paid
			and i.billing_id = ib.bill_id
			and ib.bill_ins_id = ins.ins_internal_id
			and i.invoice_subtype not in ( @{[ App::Universal::CLAIMTYPE_SELFPAY ]} , @{[ App::Universal::CLAIMTYPE_CLIENT ]} )
			and i.invoice_id = ia.parent_id
			and ia.item_name = 'Invoice/Creation/Batch ID'
			and i.owner_id = :1
			and (ii.service_begin_date >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') or :2 is null)
			and (ii.service_end_date <= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') or :3 is null)
			and (ia.value_text >= :4 or :4 is null)
			and (ia.value_text <= :5 or :5 is null)
			and (ins.product_name = :6 or :6 is null)
			order by 1, 2, 3, 4
		},

		sqlStmtBindParamDescr => ['org internal id, service begin and end date, batch from and to id, product name'],

		publishDefn =>
		{
			columnDefn =>
			[
				{
					colIdx => 0,
					head => 'Payment Date',
					hAlign => 'center',
					dAlign => 'center',
					dataFmt => '#0#',
				},
				{
					colIdx => 1,
					head => 'Product ID',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#1#',
				},
				{
					colIdx => 2,
					head => 'Invoice ID',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '<A HREF = "/invoice/#2#/summary">#2#</A>'
				},
				{
					colIdx => 3,
					head => 'CPT Code',
					hAlign => 'center',
					dAlign => 'left',
					dataFmt => '#3#',
				},
				{
					colIdx => 4,
					head => 'Amount<br>Expected',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#4#',
					dformat => 'currency',
				},
				{
					colIdx => 5,
					head => 'Amount<br>Paid',
					hAlign => 'center',
					dAlign => 'right',
					dataFmt => '#5#',
					dformat => 'currency',
				},
			],
		},
	},

);


1;

