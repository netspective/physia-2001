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
			Person.complete_name AS patient_name,
			Person.name_last AS patient_name_last
		FROM Transaction, Invoice_Billing, Invoice, Person
		WHERE
			Invoice.client_id = Person.person_id
			AND Invoice.invoice_status > 3
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

	'sel_daysBillingEvents' => qq{
		SELECT
			item_id,
			parent_id,
			value_int AS day,
			value_text AS name_begin,
			value_textb AS name_end,
			value_intb AS balance_condition,
			value_float AS balance_criteria
		FROM
			org_attribute
		WHERE
			value_type = @{[ App::Universal::ATTRTYPE_BILLINGEVENT ]} AND
			value_int = :1
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

	'sel_orgAddressByName' => qq{
		SELECT
			name_primary,
			line1,
			line2,
			city,
			state,
			replace(zip, '-', null) as zip
		FROM
			org_address,
			org
		WHERE
			org_address.parent_id = org.org_internal_id AND
			org_internal_id = :1 AND
			org_address.address_name = :2
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
		where invoice_status in (
				@{[ App::Universal::INVOICESTATUS_SUBMITTED]},
				@{[ App::Universal::INVOICESTATUS_APPEALED]}
			)
			and owner_id = ?
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
		order by invoice_id
	},

	'sel_submittedClaims_perOrg_perProvider' => qq{
		select invoice_id
		from Transaction, Invoice
		where invoice_status in (
				@{[ App::Universal::INVOICESTATUS_SUBMITTED]},
				@{[ App::Universal::INVOICESTATUS_APPEALED]}
			)
			and Invoice.owner_id = :1
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
			and Transaction.trans_id = Invoice.main_transaction
			and Transaction.provider_id = :2
		order by invoice_id
	},

	'sel_billingPhone' => qq{
		select value_text
		from Org_Attribute
		where parent_id = :1
			and value_type = @{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}
	}

);

1;
