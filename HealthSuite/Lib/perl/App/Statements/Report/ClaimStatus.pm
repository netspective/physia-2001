##############################################################################
package App::Statements::Report::ClaimStatus;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_RPT_CLAIM_STATUS);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_RPT_CLAIM_STATUS);

$STMTMGR_RPT_CLAIM_STATUS = new App::Statements::Report::ClaimStatus(

	'sel_invoices' => {
		sqlStmt => qq{
			select caption as invoice, count(caption) as cnt
			from Insurance, Invoice_Billing, Invoice_Status, Invoice
			where Invoice.cr_org_id = ?
				and Invoice.invoice_date between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and Invoice_Status.id = Invoice.invoice_status
				and Invoice_Billing.invoice_id = Invoice.invoice_id
				and Insurance.ins_internal_id = Invoice_Billing.bill_ins_id
			group by caption
		},
		publishDefn => {
			columnDefn =>
			[
				{head => 'Claims', url => 'javascript:doActionPopup("#hrefSelfPopup#&detail=payer&payer=#&{?}#")', hint => 'View Details' },
				{head => 'Count', dAlign => 'right'},
			],
		},
	},

	'sel_claim_status' => qq{
		select  'All Claims' as caption,-1 as id , 2 as sort_field from Dual
		UNION
		select  caption, id,1 as sort_field from Invoice_Status
		order by 3,2 asc
	},
	
	'sel_payer_type' => qq{
		select 'All' as col0, -1 as col1 from Dual
		UNION
		select replace(caption, 'Client', 'Self-Pay') as col0, id as col1 from Invoice_Bill_Party_Type
		order by col1
	},

	'sel_distinct_ins_org_id' => {
		sqlStmt => qq{
			select ' ' as col0, '0' as col1 from Dual
			UNION
			select distinct ins_org_id as col0, ins_org_id as col1 from Insurance
			where record_type = 3
				and ins_org_id is not null
		},
	},
	
	'sel_claim_detail' =>q
	{
		select 
		i.invoice_id, ii.code,
		iia.payer_id,iia.pay_date,
		iia.pay_ref,decode(iia.adjustment_amount,NULL,0,iia.adjustment_amount)+decode(iia.plan_paid,NULL,0,iia.plan_paid),
		nvl((select caption from payment_type pt where  pt.id = iia.pay_type ),
		(select 'Insurance' from DUAL where iia.payer_type = 1))
		
		from invoice_item ii,invoice i ,Invoice_Item_Adjust iia
		where ii.parent_id = i.invoice_id and ii.item_id = iia.parent_id (+) and i.invoice_id= ? 		
	},
);

1;

