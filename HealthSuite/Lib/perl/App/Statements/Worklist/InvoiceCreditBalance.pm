##############################################################################
package App::Statements::Worklist::InvoiceCreditBalance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_WORKLIST_CREDIT);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_CREDIT);

# -------------------------------------------------------------------------------
$STMTMGR_WORKLIST_CREDIT = new App::Statements::Worklist::InvoiceCreditBalance (
# -------------------------------------------------------------------------------

	'del_worklist_credit_dates' => qq{
		delete from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 150
			and item_name = :3
	},

	'del_worklist_credit_physician' => qq{
		delete from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 250
			and item_name = :3
	},

	'del_worklist_credit_org' => qq{
		delete from Person_Attribute
		where
			parent_id = :1
			and parent_org_id = :2
			and value_type = 252
			and item_name = :3
	},

	'del_worklist_credit_products' => qq{
		delete from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 110
			and item_name = :3
	},

	'del_worklist_credit_sorting' => qq{
		delete from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 110
			and item_name = :3
	},

	'sel_worklist_credit_dates' => qq{
		select
			to_char(value_date, 'DD-MON-YYYY') value_date,
			to_char(value_dateend, 'DD-MON-YYYY') value_dateend
		from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 150
			and item_name = :3
	},

	'sel_worklist_credit_available_products' => qq{
		select i.ins_internal_id as product_id, product_name || ' (' || ct.caption || ')'
		from claim_type ct, insurance i, org
		where i.record_type = 1
			AND	org.org_internal_id = i.owner_org_id
			AND	org.owner_org_id = :1
			AND ct.id = i.ins_type
		order by product_name
	},

	'sel_worklist_credit_physician' => qq{
		select value_text from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 250
			and item_name = :3
	},

	'sel_worklist_credit_org' => qq{
		select value_text from Person_Attribute
		where
			parent_id = :1
			and parent_org_id = :2
			and value_type = 252
			and item_name = :3
	},

	'sel_worklist_credit_all_products' =>qq{
		select 	pa.value_int
		FROM 	Person_Attribute pa
		WHERE	pa.value_type = 110
		AND	parent_id = :1
		AND	parent_org_id = :2
		AND	item_name = :3
		AND	value_int = -1
	},
	'sel_worklist_credit_products' => qq{
		select pa.value_int as product_id, i.product_name
		from Person_Attribute pa, Insurance i
		where
			parent_id = :1
			and parent_org_id = :2
			and i.ins_internal_id = pa.value_int
			and pa.value_type = 110
			and item_name = :3
		order by i.product_name
	},

	'sel_worklist_credit_sorting' => qq{
		select value_int from Person_Attribute
		where parent_id = :1
			and parent_org_id = :2
			and value_type = 110
			and item_name = :3
	},

	'sel_worklist_credit' => qq{
		select client_id, simple_name, invoice_id, balance, trunc(sysdate) - trunc(invoice.invoice_date) as age
		from invoice, person
		where client_id = :1
			and balance < 0
			and person.person_id = invoice.client_id
			and invoice_date between to_date(:2,'mm/dd/yyyy') and to_date(:3,'mm/dd/yyyy')
			AND	ROWNUM<=:4
	},

	'sel_worklist_credit_count' => qq{
		select count(*)
		from invoice, person
		where client_id = :1
			and balance < 0
			and person.person_id = invoice.client_id
	},


);

1;
