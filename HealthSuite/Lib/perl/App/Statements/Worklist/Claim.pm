##############################################################################
package App::Statements::Worklist::Claim;
##############################################################################

use strict;

use DBI::StatementManager;
use App::Universal;

use vars qw(@EXPORT $STMTMGR_WORKLIST_CLAIM);

use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_CLAIM);

# -------------------------------------------------------------------------------------------
$STMTMGR_WORKLIST_CLAIM = new App::Statements::Worklist::Claim (
	'sel_invoice_worklist_item' => qq{
		select to_char(data_date_a, '$SQLSTMT_DEFAULTDATEFORMAT') as close_date, Invoice_Worklist.*
		from Invoice_Worklist
		where invoice_id = :1
			and worklist_type = :2
			and worklist_status = :3
	},

	'sel_invoice_worklist_item_by_person' => qq{
		select to_char(reck_date, '$SQLSTMT_DEFAULTDATEFORMAT') as formatted_reck_date,
		invoice_worklist.*
		from Invoice_Worklist
		where invoice_id = :1
			and worklist_type = :2
			and responsible_id = :3
			and worklist_status = :4
	},
);

1;
