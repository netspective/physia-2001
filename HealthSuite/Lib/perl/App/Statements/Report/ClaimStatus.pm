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
		select -1 as id, 'All Claims' as caption , 2 as sort_field 2 from Dual
		UNION
		select id, caption, 1 as sort_field from Invoice_Status
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
	
);

1;

