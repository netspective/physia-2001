##############################################################################
package App::Statements::BillingStatement;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@EXPORT $STMTMGR_STATEMENTS);

use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_STATEMENTS);

my $SELECT_OUTSTANDING_CLAIMS = qq{
	SELECT i.invoice_id, ib.bill_to_id, t.billing_facility_id, t.provider_id, t.care_provider_id,
		i.client_id, i.total_cost, i.total_adjust, i.balance,
		to_char(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, ib.bill_party_type,
		(select nvl(sum(net_adjust), 0)
			from Invoice_Item_Adjust
			where parent_id in (select item_id from Invoice_Item where parent_id = i.invoice_id)
				and adjustment_type = 0
				and payer_type != 0
		) as insurance_receipts,
		(select nvl(sum(net_adjust), 0)
			from Invoice_Item_Adjust
			where parent_id in (select item_id from Invoice_Item where parent_id = i.invoice_id)
				and adjustment_type = 0
				and payer_type = 0
		) as patient_receipts,
		p.complete_name AS patient_name,
		p.name_last AS patient_name_last,
		'claim' as statement_type
	FROM Transaction t, Invoice_Billing ib, Invoice i, Person p
	WHERE
		p.person_id = i.client_id
		AND i.owner_id = :1
		AND i.invoice_status > 3
		AND i.invoice_status != 15
		AND i.invoice_status != 16
		AND i.balance > 0
		AND i.invoice_subtype in (0, 7)
		AND ib.bill_id = i.billing_id
		AND ib.bill_party_type != 3
		AND ib.bill_to_id IS NOT NULL
		AND t.trans_id = i.main_transaction
		%ProviderClause%
		%ExcludeAlreadySentClause%
		AND not exists(select 'x' from Payment_Plan_Inv_Ids ppii
			where ppii.member_name = i.invoice_id
		)
	UNION
	SELECT plan_id * (-1) as invoice_id, pp.person_id as bill_to_id, pp.billing_org_id as
		billing_facility_id, 'Payment Plan' as provider_id, NULL as care_provider_id,
		pp.person_id as client_id, pp.payment_min as total_cost, 0 as total_adjust, pp.balance,
		to_char(pp.first_due, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, 0 as bill_party_type,
		0 as insurance_receipts,
		(select nvl(sum(value_float), 0) from Payment_History where parent_id = pp.plan_id)
		as patient_receipts,
		p.complete_name as patient_name, p.name_last as patient_name_last,
		'payplan' as statement_type
	FROM Person p, Payment_Plan pp
	WHERE pp.next_due > sysdate
		and pp.owner_org_id = :1
		and pp.balance > 0
		and p.person_id = pp.person_id
		and (pp.laststmt_date is NULL or
			(pp.laststmt_date is NOT NULL and pp.laststmt_date < trunc(sysdate) -14)
		)
};

$STMTMGR_STATEMENTS = new App::Statements::BillingStatement(

	'sel_statementClaims_perOrg' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND not exists (select 'x' from person_attribute pa
			where pa.parent_id = t.provider_id
				and pa.value_type = 960
				and pa.value_intb = 1
			)
		},
		ExcludeAlreadySentClause => qq{AND not exists(select 'x' from Statement s
			where s.transmission_stamp > trunc(sysdate) -14
				and s.payto_id = t.billing_facility_id
				and s.billto_id = ib.bill_to_id
				and s.patient_id = i.client_id
			)
		},
	},

	'sel_statementClaims_perOrg_perProvider' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND t.provider_id = :2},
		ExcludeAlreadySentClause => qq{AND not exists(select 'x' from Statement s
			where s.transmission_stamp > trunc(sysdate) -14
				and s.payto_id = t.billing_facility_id
				and s.billto_id = ib.bill_to_id
				and s.patient_id = i.client_id
			)
		},
	},

	'sel_BillingIds' => qq{
		select org.org_internal_id, org.org_id, org_attribute.value_text as billing_id,
			org_attribute.value_int as nsf_type, null as provider_id
		from org_attribute, org
		where org.parent_org_id is null
			and org.org_internal_id != 1
			and org_attribute.parent_id = org.org_internal_id
			and org_attribute.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
			and org_attribute.item_name = 'Organization Default Clearing House ID'
			and org_attribute.value_intb = 1
		UNION
		select person_org_category.org_internal_id, org.org_id, person_attribute.value_text
			as billing_id, person_attribute.value_int as nsf_type, person_id as provider_id
		from org, person_org_category, person_attribute
		where person_attribute.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
			and person_attribute.item_name = 'Physician Clearing House ID'
			and person_attribute.value_intb = 1
			and person_org_category.person_id = person_attribute.parent_id
			and person_org_category.category = 'Physician'
			and org.org_internal_id = person_org_category.org_internal_id
	},

	'sel_internalStatementId' => qq{
		select int_statement_id from statement where statement_id = :1
	},

	'sel_daysBillingEvents' => qq{
		SELECT item_id, parent_id, value_int AS day, value_text AS name_begin, value_textb AS name_end,
			value_intb AS balance_condition, value_float AS balance_criteria
		FROM org_attribute
		WHERE parent_id = :1
			AND value_int = :2
			AND value_type = @{[ App::Universal::ATTRTYPE_BILLINGEVENT ]}
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
		SELECT name_primary, line1, line2, city, state, replace(zip, '-', null) as zip
		FROM org_address, org
		WHERE org_internal_id = :1
			AND org_address.parent_id = org.org_internal_id
			AND org_address.address_name = :2
	},

	'sel_personAddress' => qq{
		SELECT complete_name, line1, line2, city, State, replace(zip, '-', null) as zip,
			simple_name
		FROM Person_Address, Person
		WHERE person_id = ?
			and Person_Address.parent_id = Person.person_id
	},

	'sel_submittedClaims_perOrg' => qq{
		select invoice_id
		from Transaction, Invoice
		where invoice_status in (
				@{[ App::Universal::INVOICESTATUS_SUBMITTED]},
				@{[ App::Universal::INVOICESTATUS_APPEALED]}
			)
			and owner_id = ?
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
			and Transaction.trans_id = Invoice.main_transaction
			and not exists (select 'x' from person_attribute pa
				where pa.parent_id = Transaction.provider_id
					and pa.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
					and pa.item_name = 'Physician Clearing House ID'
					and pa.value_intb = 1)
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
	},

	'sel_outstandingInvoices' => qq{
		select Invoice.invoice_id, Invoice.invoice_id || ' - ' || to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT')
			|| ' - \$' || to_char(Invoice.balance, '99999.99') as caption
		from Invoice_Billing, Invoice
		where Invoice.owner_id = :2
			and Invoice.balance > 0
			and Invoice.invoice_status > 3
			and Invoice.invoice_status != 15
			and Invoice.invoice_status != 16
			and Invoice.invoice_subtype in (0, 7)
			and Invoice_Billing.bill_id = Invoice.billing_id
			and Invoice_Billing.bill_party_type < 2
			and Invoice_Billing.bill_to_id = :1
		order by invoice_id desc
	},

	'sel_paymentPlan' => {
		sqlStmt => qq{
			SELECT payment_cycle, payment_min, to_char(first_due, '$SQLSTMT_DEFAULTDATEFORMAT')
				as first_due, to_char(next_due, '$SQLSTMT_DEFAULTDATEFORMAT') as next_due,
				to_char(lastpay_date, '$SQLSTMT_DEFAULTDATEFORMAT' ) as lastpay_date, lastpay_amount,
				balance, billing_org_id, inv_ids, plan_id, person_id
			FROM Payment_Plan
			WHERE person_id = :1
				and owner_org_id = :2
		},
		publishDefn => {
			columnDefn => [
				{ head => 'Payment Cycle',
					dataFmt => {
						7 => 'Weekly',
						14 => 'Bi-Weekly',
						30 => 'Monthly',
					},
				},
				{	head => 'Amount', dformat => 'currency',},
				{	head => 'First Due', },
				{	head => 'Next Due', },
				{	head => 'Last Payment Date',},
				{	head => 'Last Payment Amount', dformat => 'currency',},
				{	head => 'Balance', dformat => 'currency',},
			],
		},
	},

	'sel_paymentHistory' => {
		sqlStmt => qq{SELECT * FROM (
				select to_char(value_stamp - :3, '$SQLSTMT_DEFAULTDATEFORMAT'),
					value_float, value_text
				from payment_history h, payment_plan p
				where p.person_id = :1
					and p.owner_org_id = :2
					and h.parent_id = p.plan_id
				order by value_stamp desc
			) WHERE ROWNUM < 11
		},

		publishDefn => {
			columnDefn => [
				{ head => 'Payment Date', },
				{	head => 'Amount', dformat => 'currency', summarize => 'sum'},
				{ head => 'Note', },
			],
		},

	},

	'sel_last4Statements' => {
		sqlStmt => qq{
			select * from
			(
				select patient_id, to_char(transmission_stamp, '$SQLSTMT_DEFAULTDATEFORMAT')
					as transmission_date, transmission_status.caption as status, to_char(ack_stamp,
					'$SQLSTMT_DEFAULTDATEFORMAT') as ack_date, int_statement_id, ext_statement_id,
					amount_due, inv_ids as claim_ids
				from transmission_status, statement
				where billto_id = :1
					and payto_id = :2
					and patient_id = :3
					and transmission_status.id (+) = statement.transmission_status
				order by statement_id desc
			)
			where rownum < 5
		},
	},

	'sel_testStatements_Org' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND not exists (select 'x' from person_attribute pa
			where pa.parent_id = t.provider_id
				and pa.value_type = 960
				and pa.value_intb = 1
			)
		},
		ExcludeAlreadySentClause => undef,
	},

	'sel_testStatements_Provider' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND t.provider_id = :2},
		ExcludeAlreadySentClause => undef,
	},

);

1;
