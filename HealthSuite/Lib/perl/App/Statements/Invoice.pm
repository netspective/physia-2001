##############################################################################
package App::Statements::Invoice;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_INVOICE $STMTFMT_SEL_INVOICETYPE $STMTRPTDEFN_DEFAULT_ORG
	$STMTRPTDEFN_DEFAULT_PERSON $PATIENT_BILL_PUBLISH_DEFN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INVOICE);

$STMTFMT_SEL_INVOICETYPE = qq{
	SELECT
		i.invoice_id,
		i.total_items,
		TO_CHAR(MIN(iit.service_begin_date), '$SQLSTMT_DEFAULTDATEFORMAT') AS service_begin_date,
		ist.caption as invoice_status,
		ib.bill_to_id,
		i.total_cost,
		i.total_adjust,
		i.balance,
		i.client_id,
		ib.bill_to_id,
		o.org_id,
		ib.bill_party_type,
		i.invoice_status as status_id,
		i.parent_invoice_id,
		to_char(i.invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date
	FROM invoice i, invoice_status ist, invoice_billing ib, invoice_item iit, org o
	WHERE
	%whereCond%
	AND iit.parent_id (+) = i.invoice_id
	AND ib.bill_id (+) = i.billing_id
	AND ist.id = i.invoice_status
	AND to_char(o.org_internal_id (+)) = ib.bill_to_id
	AND NOT (i.invoice_status = 15 AND i.parent_invoice_id is not NULL)
	GROUP BY
		i.invoice_id,
		i.total_items,
		ist.caption,
		i.total_cost,
		i.total_adjust,
		i.balance,
		i.client_id,
		ib.bill_to_id,
		o.org_id,
		ib.bill_party_type,
		i.invoice_status,
		i.parent_invoice_id,
		i.invoice_date
	ORDER BY i.invoice_id desc
};



$STMTRPTDEFN_DEFAULT_ORG =
{
	columnDefn =>
			[
				{ head => 'ID', url => '/invoice/#&{?}#/summary', hint => 'Created on: #14#', dAlign => 'RIGHT'},
				{ head => 'IC' , hint => 'Claim Identifier', dAlign => 'CENTER'},
				{ head => 'Svc Date'},
				{ head => 'Status', colIdx => 12, dataFmt => {
										'0' => '#3#',
										'1' => '#3#',
										'2' => '#3#',
										'3' => '#3#',
										'4' => '#3#',
										'5' => '#3#',
										'6' => '#3#',
										'7' => '#3#',
										'8' => '#3#',
										'9' => '#3#',
										'10' => '#3#',
										'11' => '#3#',
										'12' => '#3#',
										'13' => '#3#',
										'14' => '#3#',
										'15' => '#3#',
										'16' => 'Void #13#'
									},
				},
				{ head => 'Client', colIdx => 8},
				{ head => 'Charges', summarize => 'sum', dformat => 'currency'},
				{ head => 'Adjust', summarize => 'sum', dformat => 'currency'},
				{ head => 'Balance', summarize => 'sum', dformat => 'currency'},

			],
};

$STMTRPTDEFN_DEFAULT_PERSON =
{
	columnDefn =>
			[
				{ head => 'ID', url => '/invoice/#&{?}#/summary', hint => "Created on: #14#",dAlign => 'RIGHT'},
				{ head => 'IC', hint => 'Number Of Items In Claim',dAlign => 'CENTER'},
				{ head => 'Svc Date'},
				{ head => 'Status', colIdx => 12, dataFmt => {
										'0' => '#3#',
										'1' => '#3#',
										'2' => '#3#',
										'3' => '#3#',
										'4' => '#3#',
										'5' => '#3#',
										'6' => '#3#',
										'7' => '#3#',
										'8' => '#3#',
										'9' => '#3#',
										'10' => '#3#',
										'11' => '#3#',
										'12' => '#3#',
										'13' => '#3#',
										'14' => '#3#',
										'15' => '#3#',
										'16' => 'Void #13#'
									},
				},
				{ head => 'Payer', colIdx => 11, dataFmt => {
										'0'  => '#4#',
										'1'  => '#4#',
										'2' => '#10#',
										'3' => '#10#',
									},
				},
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
	'selInvoiceMainTransById' => q{
		select main_transaction 
		from invoice
		where invoice_id = ?
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
	'selServiceOrgByInvoiceId'=>q{
		SELECT	t.service_facility_id
		FROM	transaction t, invoice i
		WHERE	i.invoice_id = :1
		AND	i.main_transaction = t.trans_id
		},
	'selInvoiceAddr' => q{
		select *
		from invoice_address
		where parent_id = ?
		and address_name = ?
		},
	'selAllOutstandingInvoicesByClient' => q{
		select *
		from invoice
		where balance > 0
			and client_id = ?
			and owner_id = ?
			and invoice_status != 15
			and invoice_status != 16
		},
	'selSelfPayOutstandingInvoicesByClient' => q{
		select *
		from invoice
		where balance > 0
			and client_id = ?
			and owner_id = ?
			and invoice_status != 15
			and invoice_status != 16
			and invoice_subtype = 0
		},
	'selAllNonZeroBalanceInvoicesByClient' => q{
		select * from invoice
		where client_id = ?
			and owner_id = ?
			and invoice_status != 16
			and invoice_status != 15
		},
	'selAllNonVoidedInvoicesByClient' => q{
		select * from invoice
		where client_id = ?
			and owner_id = ?
			and invoice_status != 16
		},
	'selTotalPatientBalance' => qq{
		select sum(balance)
		from invoice
		where client_id = ?
			and owner_id = ?
			and invoice_status != 16
			and invoice_status != 15
		},
	'selCreditInvoicesByClient' => q{
		select * from invoice
		where client_id = ?
			and owner_id = ?
			and balance < 0
		},
	'selInvoicesByType' => q{
		select * from invoice
		where invoice_type = ?
		},
	'selInvoiceByIdAndClient' => q{
		select *
		from invoice
		where invoice_id = ?
			and client_id = ?
		},
	'selInvoiceAndClaimType' => q{
		select i.invoice_id, i.invoice_status, iis.caption as invoice_status_caption, i.invoice_type,
			i.invoice_subtype, ct.caption as claim_type_caption, i.client_id,
			i.claim_diags, i.total_items, i.total_cost, i.total_adjust, i.balance, i.client_id
		from invoice i, claim_type ct, invoice_status iis
		where i.invoice_id = ?
		and i.invoice_subtype = ct.id (+)
		and i.invoice_status = iis.id (+)
		},
	'selInvoiceItem' => qq{
		select parent_id, item_id, item_type, hcfa_service_place, hcfa_service_type, emergency, comments, caption, code, code_type, modifier, flags,
			unit_cost, quantity, rel_diags, to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
			to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date, balance, total_adjust, extended_cost,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c
		from invoice_item
		where item_id = ?
		},
	'selInvoiceItems' => qq{
		select parent_id, item_id, item_type, hcfa_service_place, hcfa_service_type, emergency, comments, caption, code, code_type, modifier, flags,
			unit_cost, quantity, rel_diags, to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
			to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date, balance, total_adjust, extended_cost,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c
		from invoice_item
		where parent_id = ?
		},
	'selInvoiceProcedureItems' => qq{
		select parent_id, item_id, item_type, hcfa_service_place, hcfa_service_type, emergency, comments, caption, code, code_type, modifier, flags,
			unit_cost, quantity, rel_diags, to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
			to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date, balance, total_adjust, extended_cost,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c
		from invoice_item
		where parent_id = ?
			and item_type in (?,?)
			and data_text_b is NULL
		},
	'selInvoiceItemsByType' => qq{
		select parent_id, item_id, item_type, hcfa_service_place, hcfa_service_type, emergency, comments, caption, code, code_type, modifier, flags,
			unit_cost, quantity, rel_diags, to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
			to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date, balance, total_adjust, extended_cost,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c
		from invoice_item
		where parent_id = ?
			and item_type = ?
			and data_text_b is NULL
		},
	'selServiceDateRangeForAllItems' => qq{
		select  to_char(least(service_begin_date), '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
				to_char(greatest(service_end_date), '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date
		from invoice_item
		where parent_id = ?
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
	'selInvoiceBillingCurrent' => qq{
		select *
		from invoice_billing
		where bill_id = ?
		},
	'selInvoiceBillingPrimary' => qq{
		select *
		from invoice_billing
		where invoice_id = ?
		and bill_sequence = 1
		and invoice_item_id is NULL
		},
	'selInvoiceBillingRecs' => qq{
		select bill_id, invoice_id, invoice_item_id, assoc_bill_id, bill_sequence, bill_party_type, bill_to_id, bill_ins_id, bill_amount,
			bill_pct, to_char(bill_date, '$SQLSTMT_DEFAULTDATEFORMAT') as bill_date, bill_status, bill_result
		from invoice_billing
		where invoice_id = ?
		order by bill_sequence
		},
	'selAllAttributesExclHistory' => qq{
		select item_id, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB, value_block,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateEnd,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateB			
		from invoice_attribute
		where parent_id = ?
			and NOT item_name = 'Invoice/History/Item'
		},
	'selPostSubmitAttributes' => qq{
		select item_id, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT'), to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT'),
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT'), to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT'),
			value_block
		from invoice_attribute
		where parent_id = ?
			and value_intB = 1
			and item_name not like 'Invoice/TWCC%'
		},
	'delPostSubmitAttributes' => q{
		delete
		from invoice_attribute
		where parent_id = ?
			and value_intB = 1
			and item_name not like 'Invoice/TWCC%'
		},
	'delPostSubmitAddresses' => q{
		delete
		from invoice_address
		where parent_id = ?
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
	'delAutoWriteoffAdjustmentsForItem' => q{
		delete
		from invoice_item_adjust
		where parent_id = ?
			and adjustment_type = 3
		},
	'selAutoWriteoffAdjustmentsForItem' => q{
		select *
		from invoice_item_adjust
		where parent_id = ?
			and adjustment_type = 3
		},
	'selItemAdjustments' => qq{
		select 	iia.adjustment_id, iia.adjustment_amount,	iia.payer_id, iia.payer_type, iia.plan_allow, iia.plan_paid, iia.deductible, iia.copay,
			iia.submit_date, iia.pay_date, comments, pay_ref, pay_method as pay_method_id, writeoff_amount,
			adjust_codes, net_adjust, data_text_a,
			pat.caption as pay_type, adm.caption as adjustment_type,
			pam.caption as pay_method, wt.caption as writeoff_code
		from invoice_item_adjust iia, adjust_method adm, payment_type pat, payment_method pam, writeoff_type wt
		where iia.parent_id = ?
		and iia.writeoff_code = wt.id (+)
		and iia.pay_method = pam.id (+)
		and iia.adjustment_type = adm.id (+)
		and iia.pay_type = pat.id (+)
		},
	'selItemAdjustmentsByInvoiceId' => qq{
		select iia.adjustment_id, iia.adjustment_amount, iia.payer_type, iia.payer_id, iia.refund_to_type, iia.refund_to_id, iia.parent_id,
				iia.plan_allow, iia.plan_paid, iia.deductible, iia.copay, to_char(iia.pay_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
				iia.pay_type, iia.pay_method, iia.pay_ref, iia.writeoff_code, iia.writeoff_amount, iia.adjust_codes, iia.net_adjust,
				iia.comments, iia.data_text_a, iia.data_text_b, iia.data_text_c, iia.data_num_a, iia.data_num_b, iia.data_num_c
		from invoice_item_adjust iia, invoice_item ii, invoice i
		where i.invoice_id = ?
			and i.invoice_id = ii.parent_id
			and ii.item_id = iia.parent_id
		},
	'selItemAdjustmentsByItemParent' => q{
		select *
		from invoice_item_adjust
		where parent_id = ?
		},
	'selAllInvoiceTypeForClient' =>
		{
				_stmtFmt => $STMTFMT_SEL_INVOICETYPE,
				whereCond => 'upper(client_id) = ? and (owner_type = 1 and owner_id = ?)',
				publishDefn => $STMTRPTDEFN_DEFAULT_PERSON,
		},
	'selNonVoidInvoiceTypeForClient' =>
		{
				_stmtFmt => $STMTFMT_SEL_INVOICETYPE,
				whereCond => 'upper(client_id) = ? and invoice_status != 16 and (owner_type = 1 and owner_id = ?)',
				publishDefn => $STMTRPTDEFN_DEFAULT_PERSON,
		},
	'selInvoiceTypeForOrg' =>
		{
			_stmtFmt => $STMTFMT_SEL_INVOICETYPE,
			whereCond => ' ib.bill_to_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT_ORG,
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
	'selAdjTypeCaption' => q{
		select caption
		from adjust_method
			where id = ?
		},
	'selClaimTypeCaption' => q{
		select caption
		from claim_type
			where id = ?
		},
	'selItemTypeCaption' => q{
		select caption
		from inv_item_type
			where id = ?
		},
	'selWriteoffTypes' => q{
		select caption, id, 2 as myorder
		from writeoff_type
		UNION
		(select '' as caption, -99999 as id, 1 as myorder
			from dual)
		order by myorder
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
	'selAccidentDropDown' => q{
		select caption, id, 2 as myorder
			from trans_related_to
		UNION
		(select 'None' as caption, -99999 as id, 1 as myorder
			from dual)
		order by myorder
		},
	'selProcedure' => qq{
		select item_type, code as procedure, code_type, modifier as procmodifier, unit_cost as proccharge,
				quantity as procunits, emergency as emg, comments, flags,
				data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c,
				rel_diags as procdiags, hcfa_service_place as servplace, hcfa_service_type as servtype,
				to_char(service_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_begin_date,
				to_char(service_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as service_end_date
			from invoice_item
			where item_id = ?
		},

	'sel_previousBalance' => qq{
		select upper(client_id) as client_id, sum(balance) as balance
		from Invoice
		where upper(client_id) = (select client_id from Invoice where invoice_id = ?)
			and invoice_id != ?
			and balance > 0
		group by upper(client_id)
	},

	'sel_defaultInvoiceItemDate' => qq{
		select to_char(cr_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') from Invoice_Item
		where item_id = ?
	},

	'checkOfficeVisitCPT' => qq{
		select cpt
		from ref_cpt
		where cpt = ?
			and cpt in ('99201','99202','99203','99204','99205','99211','99212','99213','99214','99215')
	},

	'selFSHierarchy' => qq{
		select per.value_int as fs, 1 as fs_order
		from person_attribute per, org_attribute org, insurance_attribute insplan, insurance_attribute insprod
		where per.parent_id = :1
			and org.parent_id = :2
			and insplan.parent_id = :3
			and insprod.parent_id (+)= :4
			and per.item_name = 'Fee Schedule'
			and org.item_name = 'Fee Schedule'
			and insplan.item_name = 'Fee Schedule'
			and insprod.item_name (+)= 'Fee Schedule'
			and per.value_int = org.value_int
			and org.value_int = insplan.value_text
			and insplan.value_text = insprod.value_text (+)
		UNION
		select per.value_int as fs, 2 as fs_order
		from person_attribute per, insurance_attribute insplan, insurance_attribute insprod
		where per.parent_id = :1
			and insplan.parent_id = :3
			and insprod.parent_id (+)= :4
			and per.item_name = 'Fee Schedule'
			and insplan.item_name = 'Fee Schedule'
			and insprod.item_name (+)= 'Fee Schedule'
			and per.value_int = insplan.value_text
			and insplan.value_text = insprod.value_text (+)
		UNION
		select org.value_int as fs, 3 as fs_order
		from org_attribute org, insurance_attribute insplan, insurance_attribute insprod
		where org.parent_id = :2
			and insplan.parent_id = :3
			and insprod.parent_id (+)= :4
			and org.item_name = 'Fee Schedule'
			and insplan.item_name = 'Fee Schedule'
			and insprod.item_name (+)= 'Fee Schedule'
			and org.value_int = insplan.value_text
			and insplan.value_text = insprod.value_text (+)
		UNION
		select to_number(insplan.value_text) as fs, 4 as fs_order
		from insurance_attribute insplan, insurance_attribute insprod
		where insplan.parent_id = :3
			and insprod.parent_id (+)= :4
			and insplan.item_name = 'Fee Schedule'
			and insprod.item_name (+)= 'Fee Schedule'
			and insplan.value_text = insprod.value_text (+)
		UNION
		select to_number(insprod.value_text) as fs, 5 as fsOrder
		from insurance_attribute insprod
		where insprod.parent_id = :4
			and insprod.item_name = 'Fee Schedule'
		ORDER BY 2 asc
	},
	'selPaymentMethod' => qq{
		select caption
		from Payment_Method
		UNION
		select 'Payment'
		from dual
	},
	
	'selPaperClaims' => qq{
		SELECT invoice_id
		FROM Invoice
		WHERE owner_id = :1
			and invoice_status = @{[ App::Universal::INVOICESTATUS_SUBMITTED ]}
			and invoice_subtype in (@{[ App::Universal::CLAIMTYPE_SELFPAY ]}, 
				@{[ App::Universal::CLAIMTYPE_CLIENT ]})
	UNION
		SELECT Invoice.invoice_id
		FROM Insurance, Invoice_Billing, Invoice
		WHERE owner_id = :1
			and invoice_status = @{[ App::Universal::INVOICESTATUS_SUBMITTED ]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY ]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT ]}
			and Invoice_Billing.bill_id = Invoice.billing_id
			and Insurance.ins_internal_id = Invoice_Billing.bill_ins_id
			and Insurance.remit_type = 0
		ORDER BY 1
	},
	
);


$PATIENT_BILL_PUBLISH_DEFN =
{
	columnDefn =>
	[
		{head => 'Date', colIdx => 0},
		{head => 'Description', colIdx => 1},
		{head => 'Amount', colIdx => 2, summarize => 'sum', dAlign => 'right', dformat => 'currency',},
		{head => 'Paid', colIdx => 3, summarize => 'sum', dAlign => 'right', dformat => 'currency',},
	],
};



1;
