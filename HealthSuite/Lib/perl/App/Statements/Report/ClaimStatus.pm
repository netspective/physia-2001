##############################################################################
package App::Statements::Report::ClaimStatus;
##############################################################################

use strict;
#use base 'Exporter';
#use base 'DBI::StatementManager';

use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_RPT_CLAIM_STATUS);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_RPT_CLAIM_STATUS);

$STMTMGR_RPT_CLAIM_STATUS = new App::Statements::Report::ClaimStatus(

	'sel_payers' => {
		sqlStmt => qq{
			select Claim_Type.caption as payer, count(Claim_Type.id) as count
			from Transaction, Claim_Type, Invoice
			where Invoice.cr_org_id = ?
				and Invoice.invoice_date between to_date(? || ' 12:00 AM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
					and to_date(? || ' 11:59 PM', '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and Transaction.trans_id = Invoice.main_transaction
				and Claim_Type.id = Transaction.bill_type
			group by Claim_Type.caption
		},
		publishDefn => 	{
			columnDefn =>
				[
					{head => 'Payer', url => 'javascript:doActionPopup("#hrefSelfPopup#&detail=payer&payer=#&{?}#")', hint => 'View Details' },
					{head => 'Count', dAlign => 'right'},
				],
		},
	},



);

1;
