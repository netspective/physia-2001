##############################################################################
package App::Statements::Insurance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_INSURANCE);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INSURANCE);

$STMTMGR_INSURANCE = new App::Statements::Insurance(

	'selGroupInsurance' => qq{
		select 	o.INS_INTERNAL_ID, o.product_name, o.INS_ORG_ID, o.INS_TYPE, o.plan_name, o.GROUP_NUMBER, o.GROUP_NAME, o.POLICY_NUMBER,
			o.INDIV_DEDUCTIBLE_AMT, o.FAMILY_DEDUCTIBLE_AMT, o.PERCENTAGE_PAY, o.THRESHOLD, o.COPAY_AMT,
			ct.caption as ins_type_caption
		from insurance o, claim_type ct
		where o.ins_type = ct.id
			and o.product_name = ?
		},
	'selInsuranceGroup' => qq{
		select 	i.INS_ORG_ID, i.INS_TYPE, i.plan_name, i.GROUP_NUMBER, i.GROUP_NAME, i.POLICY_NUMBER,
			i.INDIV_DEDUCTIBLE_AMT, i.FAMILY_DEDUCTIBLE_AMT, i.PERCENTAGE_PAY, i.THRESHOLD, i.COPAY_AMT,
			ct.caption as ins_type_caption
		from 	insurance i, claim_type ct
		where 	i.ins_type = ct.id
		and 	i.ins_internal_id = ?
		},
	'selInsuranceAttr' => q{
		select *
		from insurance_attribute
		where parent_id = ?
			and item_name = ?
		},
	'selInsuranceAttr_Org' => q{
		select *
		from insurance_attribute
		where parent_id = ?
			and item_name = ?
			and cr_org_id = ?
		},
	'selInsOrgData' => qq{
		select *
			from org
			where org_id = ?
		},
	'selInsurancePlansForOrg' => qq{
		select INS_INTERNAL_ID, product_name, INS_ORG_ID, INS_TYPE, plan_name, GROUP_NUMBER, o.GROUP_NAME, POLICY_NUMBER,
			INDIV_DEDUCTIBLE_AMT, FAMILY_DEDUCTIBLE_AMT, PERCENTAGE_PAY, THRESHOLD, COPAY_AMT,
			ct.caption as ins_type_caption
		from insurance o, claim_type ct
		where
			ct.id = o.ins_type and
			ins_org_id = ? and
			record_type in (2, 3) and
			NOT ins_type = 6
		},
	'selInsuranceByInsOrgAndMemberNumberForElig' => qq{
		select ins_internal_id, parent_ins_id, ins_org_id, owner_person_id, plan_name, product_name,
			to_char(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as coverage_begin_date_html,
			to_char(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as coverage_end_date_html,
			to_char(coverage_begin_date, 'YYYY,MM,DD') as coverage_begin_date,
			to_char(coverage_end_date, 'YYYY,MM,DD') as coverage_end_date,
			ct.caption as ins_type
		from insurance, claim_type ct
		where ins_org_id = ?
			and member_number = ?
			and ins_type = ct.id
		},
	'selInsuranceByOwnerAndProductNameForElig' => qq{
		select ins_internal_id, parent_ins_id, ins_org_id, owner_person_id, plan_name, product_name,
			to_char(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') as coverage_begin_date_html,
			to_char(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') as coverage_end_date_html,
			to_char(coverage_begin_date, 'YYYY,MM,DD') as coverage_begin_date,
			to_char(coverage_end_date, 'YYYY,MM,DD') as coverage_end_date,
			ct.caption as ins_type
		from insurance, claim_type ct
		where ins_org_id = ?
			and owner_person_id = ?
			and ins_type = ct.id
		},
	'selWorkersCompPlansForOrg' => qq{
		select ins_internal_id, product_name, ins_org_id, remit_type, remit_payer_id, remit_payer_name, ins_type
		from insurance
		where ins_org_id = ?
			and ins_type = ?
			and record_type in (?, ?, ?, ?)
		},
	'selWorkersCompPlanInfo' => qq{
		select ins_internal_id, product_name, ins_org_id, remit_type, remit_payer_id, remit_payer_name, ins_type
		from insurance
		where product_name = ?
			and ins_type = 6
		},
	'selInsurancePayerPhone' => qq{
		select item_id, value_text as phone
		from insurance_attribute
		where parent_id = ?
			and item_name = 'Contact Method/Telephone/Primary'
		},
	'selInsurancePayerFax' => qq{
		select item_id, value_text as fax
		from insurance_attribute
		where parent_id = ?
			and item_name = 'Contact Method/Fax/Primary'
		},
	'delInsurancePlanAttrs' => qq{
		delete
		from insurance_attribute
		where parent_id = ?
		},
	'selInsPlanAttributesForOrg' => qq{
		select item_id, value_text as product_name, value_textB as plan_name, value_int as ins_internal_id
		from org_attribute
		where parent_id = ? and item_name like ?
		},
	'selSpecificWrkCmpAttr' => qq{
		select *
		from org_attribute
		where parent_id = ? and value_int = ? and value_type = ?
		},
	'selAllWrkCmpAttr' => qq{
		select *
		from org_attribute
		where value_int = ? and value_type = ?
		},
	'selInsurance' => qq{
		select *
		from insurance
		where owner_person_id = ?
		order by coverage_end_date desc, bill_sequence
		},
	'selInsuranceByPlanNameAndPersonAndInsType' => qq{
		select *
		from insurance
		where plan_name = ?
			and owner_person_id = ?
			and ins_type = ?
		},
	'selInsuranceByInsType' => qq{
		select *
		from insurance
		where owner_person_id = ?
			and ins_type = ?
		},
	'selInsuranceByPersonOwnerAndGuarantorAndInsType' => qq{
		select *
		from insurance
		where owner_person_id = ?
			and guarantor_id = ?
			and ins_type = ?
		},
	'selInsuranceGroupData' => qq{
		select INS_ORG_ID, INS_TYPE, plan_name, GROUP_NUMBER, GROUP_NAME, POLICY_NUMBER, RECORD_TYPE,
			INDIV_DEDUCTIBLE_AMT, FAMILY_DEDUCTIBLE_AMT, PERCENTAGE_PAY, THRESHOLD, COPAY_AMT,
			ct.caption as ins_type_caption
			from insurance i, claim_type ct
			where i.ins_type = ct.id AND i.product_name = ?
		},
	'selEmployerWorkersCompPlans' => qq{
		select oa.value_text as ins_id, oa.value_textB as group_name
			from org_attribute oa, person_attribute pa, insurance ins
			where
				(pa.value_type in (220, 221)) and
				(pa.value_text = oa.parent_id) and
				(pa.parent_id = ?) and
				(oa.value_type = 361)
		union
			select ins.product_name, group_name
			from org, insurance ins, person_attribute pa
			where
				org.org_id = ins.ins_org_id and
				ins.ins_type = 6 and
				(((pa.value_type in (220, 221)) and
				(pa.value_text = org.org_id) and
				(pa.parent_id=?)))
		},
	'selPatientHasPlan' => qq{
		select ins_internal_id
			from insurance
			where product_name = ?
			and owner_person_id = ?
			and ins_type = ?
		},

	'selInsuranceGroupName' => qq{
		select group_name
			from insurance
			where product_name = ?
		},
	'selPlanByInsIdAndRecordType' => qq{
		select *
			from insurance ins
			where product_name = ?
			and record_type = ?
		},
	'selInsuranceData' => qq{
		select *
			from Insurance
			where ins_internal_id = ?
		},
	'selInsuranceForInvoiceSubmit' => qq{
		select ins.ins_internal_id, ins.parent_ins_id, ins.ins_org_id, ins.ins_type, ins.owner_person_id, ins.group_name, ins.group_number, ins.insured_id, ins.member_number,
				to_char(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') , to_char(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') ,
				ins.rel_to_insured, ins.record_type, ins.extra, ct.caption as claim_type
				from insurance ins, claim_type ct
			where ins.ins_internal_id = ?
				and ct.id = ins_type
		},
	'selChildrenPlans' => qq{
		select *
			from Insurance
			where parent_ins_id = ?
		},
	'selInsuranceAddr' => qq{
		select line1 as addr_line1, line2 as addr_line2, city as addr_city,	state as addr_state,
			zip as addr_zip, country as addr_country, item_id
		from insurance_address
		where parent_id = ? and address_name = 'Billing'
		},
	'selInsuranceAddrWithOutColNameChanges' => qq{
		select line1, line2, city, state, zip, country
		from insurance_address
		where parent_id = ?
			and address_name = 'Billing'
		},
	'selPayerChoicesByOwnerPersonId' => qq{
		select i.plan_name, 'Insurance' as group_name, bs.caption as bill_seq, i.bill_sequence as bill_seq_id, guarantor_type
		   	from insurance i, claim_type ct, bill_sequence bs
			where i.owner_person_id = ?
				and ct.id = i.ins_type
				and bs.id = i.bill_sequence
				and i.bill_sequence in (1,2,3,4)
				and ct.group_name = 'insurance'
		UNION
		(select wk.plan_name, 'Workers Compensation' as group_name, '' as bill_seq, wk.bill_sequence as bill_seq_id, guarantor_type
			from insurance wk
			where wk.owner_person_id = ?
				and wk.ins_type = 6)
		UNION
		(select guarantor_id as plan_name, 'Third-Party' as group_name, '' as bill_seq, bill_sequence as bill_seq_id, guarantor_type
			from insurance
			where owner_person_id = ?
				and ins_type = 7)
		order by bill_seq_id
		},

		#UNION
		#select 'Third-Party Other' as plan_name, 'Third-Party Other' as group_name, '' as bill_seq, '3' as myorder
		#	from dual
		#UNION
		#select 'Self-Pay' as plan_name, 'Self-Pay' as group_name, '' as bill_seq, '4' as myorder
		#	from dual
		#order by myorder

	'selAllWorkCompByOwnerId' => qq{
		select plan_name, product_name
			from insurance
			where owner_person_id = ?
				and ins_type = 6
		},
	'selInsuranceByOwnerAndProductName' => qq{
		select *
			from insurance
			where product_name = ?
			and owner_person_id = ?
		},
	'selInsuranceByPersonAndInsOrg' => qq{
		select *
			from insurance
			where owner_person_id = ?
				and ins_org_id = ?
		},
	'selInsuranceByInsOrgAndMemberNumber' => qq{
		select *
			from insurance
			where ins_org_id = ?
				and member_number = ?
		},
	'selInsuranceByBillSequence' => qq{
		select *
			from insurance
			where bill_sequence = ?
				and owner_person_id = ?
		},
	'selInsuranceBillCaption' => qq{
		select caption
			from bill_sequence
			where id = ?
		},
	'selInsurancePlanData' => qq{
		select *
			from insurance
			where product_name = ?
			and record_type in (?, ?, ?, ?)
		},
	'selInsuranceGroupName' => qq{
		select group_name
			from insurance
			where product_name = ?
		},
	'selPersonPlanExists' => qq{
		select plan_name
			from insurance
			where product_name = ?
			and plan_name = ?
			and record_type = ?
			and owner_person_id = ?
			and ins_org_id = ?
		},

	'selInsuredRelationship' => qq{
		select caption
		from insured_relationship
		where id = ?
		},
	'selNewProductExists' => qq{
		select product_name
			from insurance
			where product_name = ?
			and ins_org_id = ?
		},
	'selNewPlanExists' => qq{
		select plan_name
			from insurance
			where product_name = ?
			and plan_name = ?
			and ins_org_id = ?
			and record_type = 2
		},

	'selDoesProductExists' => qq{
		select ins_internal_id
			from insurance
			where product_name = ?
			and ins_org_id = ?
			and record_type = 1
		},
	'selDoesPlanExistsForPerson' => qq{
		select ins_internal_id
			from insurance
			where product_name = ?
			and owner_person_id = ?
		},
	'selIsPlanUnique' => qq{
		select ins_internal_id
			from insurance
			where product_name = ?
			and record_type = ?
		},
	'selIsPlanWorkComp' => qq{
		select ins_internal_id
			from insurance
			where product_name = ?
			and ins_type = ?
		},
	#'selInsuranceEncounterDialog' => qq{
		#select ins_internal_id, product_name, ins_type, copay_amt, bill_sequence,
			#ins_org_id, group_name
			#from insurance
			#where bill_sequence = ?
			#and owner_person_id = ?
		#},

	'selExistsPlanForPerson' => qq{
		select ins_internal_id
				from insurance
				where ins_type = ?
				and owner_person_id = ?
		},
	'selPersonInsurance' => qq{
		select ins.ins_internal_id, ins.parent_ins_id, ins.ins_org_id, ins.ins_type, ins.owner_person_id, ins.group_name, ins.group_number, ins.insured_id, ins.member_number,
				to_char(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') , to_char(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') ,
				ins.rel_to_insured, ins.record_type, ins.extra, ct.caption as claim_type
				from insurance ins, claim_type ct
			where ins.owner_person_id = ?
				and ins.bill_sequence = ?
				and ct.id = ins_type
		},

	'selPersonInsuranceId' => qq{
			select *
				from insurance
				where ins_org_id = ?
				and product_name = ?
				 and ins_type = ?
		},

	'selPatientWorkersCompPlan' => qq{
			select *
			from insurance
			where product_name = ?
			and ins_type = 6
		},
	'selEmpExistPlan' => qq{
			select  distinct ins.product_name
				from person_attribute patt, insurance ins
				where patt.parent_id = ?
				and patt.value_type between 220 and 226
				and patt.value_text = ins.ins_org_id
				and ins.record_type = 6
		},
	'selInsuredRelation' => qq{
			select  id, caption
				from Insured_Relationship
		},
	'selPpoHmoIndicator' => qq{
			select  caption, abbrev
				from PPO_HMO_Indicator
		},
	'selInsTypeCode' => qq{
		select  caption, abbrev
			from insurance_type_code
			where group_name = 'UI'
		},
	'selInsPlan' => qq{
		select  *
			from insurance
			where product_name = ?
			and plan_name = ?
			and ins_org_id = ?
			and record_type = 2
		},
	'selInsSequence' => qq{
			select bill_sequence
			from insurance
			where owner_person_id = ?
		},
	'selDoesInsSequenceExists' => qq{
			select bill_sequence
			from insurance
			where owner_person_id = ?
			and bill_sequence = ?
		},
	'selUpdateInsSequence' => qq{
			update insurance
			set bill_sequence = 99
			where owner_person_id = ?
			and bill_sequence > ?
			and bill_sequence < 5
		},
	'selUpdateAndAddInsSeq' => qq{
					update insurance
					set bill_sequence = 99
					where ins_internal_id = ?
					and bill_sequence = ?
		},

	'selDeleteFeeSchedule' => qq{
		delete
		from insurance_attribute
		where parent_id = ?
			and item_name = 'Fee Schedule'
			and cr_org_id = ?
	},
	'selUpdatePlanAndCoverage' => qq{
		 update insurance
		 set ins_type = ?,
		 product_name = ?,
		 ins_org_id = ?
		 where product_name = ?
		 and ins_org_id = ?
		 and record_type in (2, 3)
	},
	'selUpdateCoverage' => qq{
		 update insurance
		 set ins_org_id = ?,
		 product_name = ?,
		 plan_name = ?
		 where parent_ins_id = ?
	},
	#--------------------------------------------------------------------------------------------------------------------------------------
	'sel_Person_Insurance' => {
		sqlStmt => qq{
				select 	decode(bill_sequence,0,'Primary',1,'Secondary',2,'Tertiary',3,'Inactive','','W. Comp'),
					plan_name, ins_org_id
				from 	insurance
				where 	owner_person_id = ?
				order by coverage_end_date desc, bill_sequence
				},
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'billingSequence', dataFmt => '#&{?}#: #1# (#2#)' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Health Coverage' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Health Coverage' },
			banner => {
				actionRows =>
				[
					{ caption => 'Hello #session.user_id#', url => 'test' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	}
);

1;
