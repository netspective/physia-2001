##############################################################################
package App::Statements::Invoice;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_INVOICE $STMTFMT_SEL_INVOICETYPE $STMTRPTDEFN_DEFAULT_ORG $STMTRPTDEFN_DEFAULT_PERSON);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INVOICE);

$STMTFMT_SEL_INVOICETYPE = qq{
			select i.invoice_id, i.total_items, to_char(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date,
					ist.caption as invoice_status, ib.bill_to_id, i.total_cost,
					i.total_adjust, i.balance, i.client_id, ib.bill_to_id
			from invoice i, invoice_status ist, invoice_billing ib
			where
				%whereCond%
				and i.invoice_status = ist.id
				and ib.invoice_id = i.invoice_id
				and ib.invoice_item_id is NULL
				and ib.bill_sequence = 1
				order by i.invoice_date, i.cr_stamp desc
};

$STMTRPTDEFN_DEFAULT_ORG =
{
	columnDefn =>
			[
				{ head => 'ID', url => '/invoice/#&{?}#', hint => 'Claim Identifier',dAlign => 'RIGHT'},
				{ head => 'IC' , hint => 'Claim Identifier', dAlign => 'CENTER'},
				{ head => 'Date'},
				{ head => 'Status'},
				{ head => 'Client'},
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
};

$STMTRPTDEFN_DEFAULT_PERSON =
{
	columnDefn =>
			[
				{ head => 'ID', url => '/invoice/#&{?}#', hint => "Claim Identifier",dAlign => 'RIGHT'},
				{ head => 'IC', hint => 'Number Of Items In Claim',dAlign => 'CENTER'},
				{ head => 'Date'},
				{ head => 'Status'},
				{ head => 'Payer'},
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
};

$STMTMGR_INVOICE = new App::Statements::Invoice(
	'hasInvoiceItems' => q{
		select 1 from Invoice_Item
		where invoice_id = ?
		},
	'selInvoice' => q{
		select *
		from invoice
		where invoice_id = ?
		},
	'selInvoiceIdByEventId' => q{
		select invoice_id
		from invoice, transaction t
		where t.parent_event_id = ?
			and (t.trans_type between 2000 and 2999)
			and t.trans_id = main_transaction
		},
	'selInvoiceByTypeAndMainTrans' => q{
		select * from invoice
		where invoice_type = ?
		and main_transaction = ?
		},
	'selInvoiceDiags' => q{
		select claim_diags as diagcodes
		from invoice
		where invoice_id = ?
		},
	'selInvoiceByStatusAndDateAndType' => qq{
		select 	invoice_id, invoice_status, client_id,
			to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date,
			balance, total_adjust
		from invoice
		where invoice_type = ?
		and invoice_status >= ?
		and invoice_date ?
		order by invoice_date desc
		},
	'selInvoiceAddr' => q{
		select *
		from invoice_address
		where parent_id = ?
		and address_name = ?
		},
	'selOutstandingInvoicesByClient' => q{
		select * from invoice
		where client_id = ?
			and balance > 0
		},
	'selInvoicesByType' => q{
		select * from invoice
		where invoice_type = ?
		},
	'selInvoiceAndClaimType' => q{
		select 	i.invoice_status, iis.caption as invoice_status_caption,
			i.invoice_subtype, ct.caption as claim_type_caption, i.client_id,
			i.claim_diags, i.total_items, i.total_cost, i.total_adjust, i.balance, i.client_id
		from invoice i, claim_type ct, invoice_status iis
		where i.invoice_id = ?
		and i.invoice_subtype = ct.id
		and i.invoice_status = iis.id
		},
	'selInvoiceItem' => q{
		select * from invoice_item
		where item_id = ?
		},
	'selInvoiceItems' => q{
		select * from invoice_item
		where parent_id = ?
		},
	'selServiceDateRangeForAllItems' => q{
		select  to_char(least(service_begin_date), 'MM/DD/YYYY') as service_begin_date,
				to_char(greatest(service_end_date), 'MM/DD/YYYY') as service_end_date
		from invoice_item
		where parent_id = ?
		},
	'selInvoiceProcedureItems' => q{
		select parent_id, item_id, item_type, hcfa_service_place, hcfa_service_type, emergency, comments, caption, code, modifier,
			unit_cost, quantity, rel_diags, data_num_c,	to_char(service_begin_date, 'MM/DD/YYYY') as service_begin_date,
			to_char(service_end_date, 'MM/DD/YYYY') as service_end_date, data_text_a
		from invoice_item
		where parent_id = ?
			and item_type in (?,?)
		},
	'selInvoiceItemsByType' => q{
		select * from invoice_item
		where parent_id = ?
			and item_type = ?
		},
	'selInvoiceItemCount' => q{
		select count(*) from Invoice_Item
		where parent_id = ?
		},
	'selInvoiceItemCountByType' => q{
		select count(*) from Invoice_Item
		where parent_id = ?
			and item_type = ?
		},
	'selInvoiceProcedureItemCount' => q{
		select count(*)
		from Invoice_Item
		where parent_id = ?
			and item_type in (?,?)
		},
	'selInvPrimSecTertBillingParties' => q{
		select *
		from invoice_billing
		where invoice_id = ?
			and bill_sequence in (?,?,?)
			and invoice_item_id is NULL
		order by bill_sequence
		},
	'delInvoiceBillingParties' => q{
		delete
		from invoice_billing
		where invoice_id = ?
			and invoice_item_id is NULL
		},
	'selInvoiceAttr' => q{
		select *
		from invoice_attribute
		where parent_id = ?
		and item_name = ?
		},
	'selClaimDiags' => q{
		select claim_diags from invoice
		where invoice_id = ?
		},
	'selRelDiags' => q{
		select rel_diags from invoice_item
		where item_id = ?
		},
	'selItemAdjustments' => q{
		select 	iia.adjustment_id, adm.caption as adjustment_type, iia.adjustment_amount,
			iia.payer_id, iia.plan_allow, iia.plan_paid, iia.deductible, iia.copay,
			iia.submit_date, iia.pay_date, pat.caption as pay_type, comments,
			pam.caption as pay_method, pay_ref, pay_method as pay_method_id,
			writeoff_code, writeoff_amount, adjust_codes, net_adjust
		from invoice_item_adjust iia, adjust_method adm, payment_type pat, payment_method pam
		where iia.parent_id = ?
		and iia.adjustment_type = adm.id
		and iia.pay_type = pat.id
		and iia.pay_method = pam.id
		},
	'selInvoiceTypeForClient' =>
		{
				_stmtFmt => $STMTFMT_SEL_INVOICETYPE,
				whereCond => 'client_id = ? and ((owner_type = 0 and owner_id = client_id) or (owner_type = 1 and owner_id = ?))',
				publishDefn => $STMTRPTDEFN_DEFAULT_PERSON,
		},
	'selInvoiceTypeForOrg' =>
		{
			_stmtFmt => $STMTFMT_SEL_INVOICETYPE,
			whereCond => ' ib.bill_to_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT_PERSON,
		},
	'selInvoiceAttrServFacility' => q{
		select value_text as name_primary, value_textb as service_facility_id
		from invoice_attribute
		where parent_id = ?
		and item_name = 'Service Provider/Facility/Service'
		},
	'selInvoiceAttrProvider' => q{
		select value_text as complete_name, value_textb as provider_id
		from invoice_attribute
		where parent_id = ?
		and item_name = 'Provider/Name/Last'
		},
	'selInvoiceAttrIllnessDates' => q{
		select value_date as similar_date, value_dateEnd as current_date
		from invoice_attribute
		where parent_id = ?
			and item_name = 'Patient/Illness/Dates'
		},
	'selAllHistoryItems' => qq{
		select cr_stamp, cr_user_id, value_text as action, value_textB as comments, to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date
		from invoice_attribute
		where parent_id = ?
			and item_name = 'Invoice/History/Item'
		order by value_date desc, cr_stamp desc
		},
	'selClaimTypeCaption' => q{
		select caption
		from claim_type
			where id = ?
		},
	'selInvoiceAttrCondition' => q{
		select item_id as condition_item_id, value_text, value_textB
				from invoice_attribute
				where parent_id = ?
				and item_name = 'Condition/Related To'
		},
	'selInvoiceAttrIllness' => q{
		select item_id as illness_item_id, value_date as illness_begin_date, value_dateEnd as illness_end_date
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Patient/Illness/Dates'
		},
	'selInvoiceAttrDisability' => q{
		select item_id as disability_item_id, value_date as disability_begin_date, value_dateEnd as disability_end_date
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Patient/Disability/Dates'
		},
	'selInvoiceAttrHospitalization' => q{
		select item_id as hospital_item_id, value_date as hospitalization_begin_date, value_dateEnd as hospitalization_end_date
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Patient/Hospitalization/Dates'
		},
	'selInvoiceAttrPatientSign' => q{
		select item_id as signature_item_id, value_int as patient_signature
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Patient/Signature'
		},
	'selInvoiceAttrAssignment' => q{
		select item_id as assignment_item_id, value_int as accept_assignment
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Assignment of Benefits'
		},
	'selInvoiceAttrInfoRelease' => q{
		select item_id as info_release_item_id, value_int as info_release
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Information Release/Indicator'
		},
	'selInvoiceAuthNumber' => q{
		select item_id as prior_auth_item_id, value_text as prior_auth
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Prior Authorization Number'
		},
	'selInvoiceDeductible' => q{
		select item_id as deduct_item_id, value_text as deduct_balance
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Patient/Deductible/Balance'
		},
	'delRefProviderAttrs' => q{
		delete from invoice_attribute where parent_id = ? and item_name like 'Ref Provider/%'
		},
	'selInvoiceProviderNameFirst' => q{
		select item_id as ref_firstname_item_id, value_textB as ref_id
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Ref Provider/Name/First'
		},
	'selInvoiceProviderNameMiddle' => q{
		select item_id as ref_middlename_item_id
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Ref Provider/Name/Middle'
		},
	'selInvoiceProviderNameLast' => q{
		select item_id as ref_lastname_item_id
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Ref Provider/Name/Last'
		},
	'selInvoiceProviderIdentification' => q{
		select item_id as ref_upin_item_id
			from invoice_attribute
			where parent_id = ?
			and item_name = 'Ref Provider/Identification'
		},
	'selInvoiceConditionId' => q{
		select id
			from trans_related_to
			where caption = ?
		},
	'selProcedure' => qq{
		select item_type, code as procedure, modifier as procmodifier, unit_cost as proccharge,
				quantity as procunits, emergency as emg, comments,
				rel_diags as procdiags, hcfa_service_place as servplace, hcfa_service_type as servtype,
				to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
				to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date
			from invoice_item
			where item_id = ?
		},
);

1;