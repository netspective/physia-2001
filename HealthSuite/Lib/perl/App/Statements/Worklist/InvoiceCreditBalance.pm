##############################################################################
package App::Statements::Worklist::InvoiceCreditBalance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_WORKLIST_CREDIT $STMTRPTDEFN_INVOICE_CREDIT_BALANCE);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_CREDIT $STMTRPTDEFN_INVOICE_CREDIT_BALANCE);

$STMTRPTDEFN_INVOICE_CREDIT_BALANCE =
{
	columnDefn =>
		[
			{ colIdx => 0, head => 'Patient ID', dataFmt => '<A HREF = "/person/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => 'Name', dataFmt => '#1#'},
			{ colIdx => 2, head => 'Invoice ID', tAlign=>'left', dataFmt => '<A HREF = "/invoice/#2#/summary">#2#</A>' ,dAlign =>'left' },
			{ colIdx => 3, head => 'Credit Balace', dataFmt => '#3#', dformat => 'currency', summarize => 'sum'},
			{ colIdx => 4, head => 'Age', dataFmt => '#4#'},
		],
};

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

	'sel_invoice_credit_balance_patient' =>
	{
		sqlStmt =>
		qq
		{
			select client_id, p.simple_name, i.invoice_id, i.balance, trunc(sysdate) - trunc(i.invoice_date) age
			from invoice i, person p , transaction t, invoice_billing ib, insurance ins
			where i.client_id = p.person_id
			and t.trans_id = i.main_transaction
			and ib.bill_id = i.billing_id
			and ins.ins_internal_id (+) = ib.bill_ins_id
			and i.balance < 0 
			and i.invoice_status != 16
			and (i.invoice_date >= to_date(:1,'mm/dd/yyyy') OR :1 is NULL)
			and (i.invoice_date <= to_date(:2,'mm/dd/yyyy') OR :2 is NULL)
			and (t.care_provider_id = :3 OR :3 is NULL)
			and (t.service_facility_id = :4 OR :4 is NULL)
			and (ins.product_name = :5 OR :5 is NULL)
			order by client_id	
		},
		publishDefn => $STMTRPTDEFN_INVOICE_CREDIT_BALANCE		
	},
	
	'sel_invoice_credit_balance_age' =>
	{
		sqlStmt =>
		qq
		{
			select client_id, p.simple_name, i.invoice_id, i.balance, trunc(sysdate) - trunc(i.invoice_date) age
			from invoice i, person p , transaction t, invoice_billing ib, insurance ins
			where i.client_id = p.person_id
			and t.trans_id = i.main_transaction
			and ib.bill_id = i.billing_id
			and ins.ins_internal_id (+) = ib.bill_ins_id
			and i.balance < 0 
			and i.invoice_status != 16
			and (i.invoice_date >= to_date(:1,'mm/dd/yyyy') OR :1 is NULL)
			and (i.invoice_date <= to_date(:2,'mm/dd/yyyy') OR :2 is NULL)
			and (t.care_provider_id = :3 OR :3 is NULL)
			and (t.service_facility_id = :4 OR :4 is NULL)
			and (ins.product_name = :5 OR :5 is NULL)
			order by age desc
		},
		publishDefn => $STMTRPTDEFN_INVOICE_CREDIT_BALANCE		
	}


);

1;
