##############################################################################
package App::Statements::BillingStatement;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_STATEMENTS);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_STATEMENTS);

$STMTMGR_STATEMENTS = new App::Statements::BillingStatement(

	'sel_outstandingClaims' => qq{
		SELECT Invoice.invoice_id, bill_to_id, billing_facility_id, service_facility_id,
			provider_id, care_provider_id, client_id, total_cost, total_adjust, balance,
			to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, bill_party_type,
			(select nvl(sum(net_adjust), 0)
				from Invoice_Item_Adjust
				where parent_id in (select item_id from Invoice_Item where parent_id = Invoice.invoice_id)
					and adjustment_type = 0
					and payer_type != 0
			) as insurance_receipts,
			(select nvl(sum(net_adjust), 0)
				from Invoice_Item_Adjust
				where parent_id in (select item_id from Invoice_Item where parent_id = Invoice.invoice_id)
					and adjustment_type = 0
					and payer_type = 0
			) as patient_receipts,
			(select complete_name from Person where person_id = Invoice.client_id) as patient_name
		FROM Transaction, Invoice_Billing, Invoice
		WHERE Invoice.invoice_status > 3 
			AND Invoice.invoice_status != 15 
			AND Invoice.invoice_status != 16
			AND Invoice.invoice_date <= trunc(sysdate) - :1
			AND Invoice.balance > 0
			AND Invoice.invoice_subtype in (0, 7)
			AND Invoice_Billing.bill_id = Invoice.billing_id
			AND Invoice_Billing.bill_party_type != 3
			AND Invoice_Billing.bill_to_id IS NOT NULL
			AND Transaction.trans_id = Invoice.main_transaction
		ORDER BY Invoice.invoice_id
	},
	
	'sel_aging' => qq{
		SELECT nvl(sum(balance), 0)
		FROM Invoice_Billing, Invoice
		WHERE client_id = :1
			and invoice_date > trunc(sysdate) - :2
			and invoice_date <= trunc(sysdate) - :3
			and invoice_status > 3 
			and invoice_status != 15 
			and invoice_status != 16
			and invoice_subtype in (0, 7)
			and bill_id = billing_id
			and bill_to_id = :4
	},
	
	'sel_orgAddress' => qq{
		SELECT name_primary, line1, line2, city, state, replace(zip, '-', null) as zip
		FROM Org_Address, Org
		WHERE org_internal_id = :1
			and Org_Address.parent_id = Org.org_internal_id
	},
	
	'sel_personAddress' => qq{
		SELECT complete_name, line1, line2, city, State, replace(zip, '-', null) as zip
		FROM Person_Address, Person
		WHERE person_id = ?
			and Person_Address.parent_id = Person.person_id
	},
	
	'sel_submittedClaims_perOrg' => qq{
		select invoice_id
		from Invoice
		where invoice_status = @{[ App::Universal::INVOICESTATUS_SUBMITTED]}
			and cr_org_internal_id = ?
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
		order by invoice_id
	},
		
);
	
1;
