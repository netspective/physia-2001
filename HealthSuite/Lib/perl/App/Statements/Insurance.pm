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
	'selPlanRecord' => qq{
		SELECT *
		FROM insurance
		WHERE
			record_type = @{[App::Universal::RECORDTYPE_INSURANCEPLAN]} AND
			owner_org_id = ? AND
			plan_name = ?
		},
	'selPlanRecordExists' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			record_type = @{[App::Universal::RECORDTYPE_INSURANCEPLAN]} AND
			owner_org_id = ? AND
			plan_name = ?
		},
	'selProductRecord' => qq{
		SELECT *
		FROM insurance
		WHERE
			record_type = @{[App::Universal::RECORDTYPE_INSURANCEPRODUCT]} AND
			owner_org_id = ? AND
			product_name = ?
		},
	'selProductRecordExists' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			record_type = @{[App::Universal::RECORDTYPE_INSURANCEPRODUCT]} AND
			owner_org_id = ? AND
			product_name = ?
		},
	'selInsuranceSingleColumn' => qq{
		SELECT ?
		FROM insurance
		WHERE ins_internal_id = ?
		},
	'selGroupInsurance' => qq{
		SELECT
			o.ins_internal_id,
			o.product_name,
			o.ins_org_id,
			o.ins_type,
			o.plan_name,
			o.group_number,
			o.group_name,
			o.policy_number,
			o.indiv_deductible_amt,
			o.family_deductible_amt,
			o.percentage_pay,
			o.threshold,
			o.copay_amt,
			ct.caption AS ins_type_caption
		FROM
			insurance o,
			claim_type ct
		WHERE
			o.ins_type = ct.id
			AND o.product_name = ?
		},
	'selInsuranceGroup' => qq{
		SELECT
			i.ins_org_id,
			i.ins_type,
			i.plan_name,
			i.group_number,
			i.group_name,
			i.policy_number,
			i.indiv_deductible_amt,
			i.family_deductible_amt,
			i.percentage_pay,
			i.threshold,
			i.copay_amt,
			ct.caption AS ins_type_caption
		FROM
			insurance i,
			claim_type ct
		WHERE
			i.ins_type = ct.id
			AND i.ins_internal_id = ?
		},
	'selInsuranceAttr' => q{
		SELECT *
		FROM insurance_attribute
		WHERE
			parent_id = ?
			AND item_name = ?
		},
	'selInsuranceAttr_Org' => q{
		SELECT *
		FROM insurance_attribute
		WHERE parent_id = ?
		AND item_name = ?
		},
	'selInsOrgData' => qq{
		SELECT *
			FROM org
			WHERE org_internal_id = ?
		},
	'selInsurancePlansForOrg' => qq{
		SELECT
			ins_internal_id,
			product_name,
			ins_org_id,
			ins_type,
			plan_name,
			group_number,
			o.group_name,
			policy_number,
			indiv_deductible_amt,
			family_deductible_amt,
			percentage_pay,
			threshold,
			copay_amt,
			ct.caption AS ins_type_caption
		FROM
			insurance o,
			claim_type ct
		WHERE
			ct.id = o.ins_type
			AND ins_org_id = ?
			AND record_type IN (2, 3)
			AND NOT ins_type = 6
		},
	'selInsuranceByInsOrgAndMemberNumberForElig' => qq{
		SELECT
			ins_internal_id,
			parent_ins_id,
			ins_org_id,
			owner_person_id,
			plan_name,
			product_name,
			TO_CHAR(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS coverage_begin_date_html,
			TO_CHAR(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS coverage_end_date_html,
			TO_CHAR(coverage_begin_date, 'YYYY,MM,DD') AS coverage_begin_date,
			TO_CHAR(coverage_end_date, 'YYYY,MM,DD') AS coverage_end_date,
			ct.caption AS ins_type
		FROM
			insurance,
			claim_type ct
		WHERE
			ins_org_id = ?
			AND member_number = ?
			AND ins_type = ct.id
		},
	'selInsuranceByOwnerAndProductNameForElig' => qq{
		SELECT
			ins_internal_id,
			parent_ins_id,
			ins_org_id,
			owner_person_id,
			plan_name,
			product_name,
			TO_CHAR(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS coverage_begin_date_html,
			TO_CHAR(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS coverage_end_date_html,
			TO_CHAR(coverage_begin_date, 'YYYY,MM,DD') AS coverage_begin_date,
			TO_CHAR(coverage_end_date, 'YYYY,MM,DD') AS coverage_end_date,
			ct.caption AS ins_type
		FROM
			insurance,
			claim_type ct
		WHERE
			ins_org_id = ?
			AND owner_person_id = ?
			AND ins_type = ct.id
		},
	'selWorkersCompPlansForOrg' => qq{
		SELECT
			ins_internal_id,
			product_name,
			ins_org_id,
			remit_type,
			remit_payer_id,
			remit_payer_name,
			ins_type
		FROM insurance
		WHERE
			ins_org_id = ?
			AND ins_type = ?
			AND record_type in (?, ?, ?, ?)
		},
	'selWorkersCompPlanInfo' => qq{
		SELECT
			ins_internal_id,
			product_name,
			ins_org_id,
			remit_type,
			remit_payer_id,
			remit_payer_name,
			ins_type
		FROM insurance
		WHERE
			product_name = ?
			AND ins_type = 6
		},
	'selInsurancePayerPhone' => qq{
		SELECT
			item_id,
			value_text AS phone
		FROM insurance_attribute
		WHERE
			parent_id = ?
			AND item_name = 'Contact Method/Telephone/Primary'
		},
	'selInsurancePayerFax' => qq{
		SELECT
			item_id,
			value_text AS fax
		FROM insurance_attribute
		WHERE
			parent_id = ?
			AND item_name = 'Contact Method/Fax/Primary'
		},
	'delInsurancePlanAttrs' => qq{
		DELETE
		FROM insurance_attribute
		WHERE parent_id = ?
		},
	'selInsPlanAttributesForOrg' => qq{
		SELECT
			item_id,
			value_text AS product_name,
			value_textB AS plan_name,
			value_int AS ins_internal_id
		FROM org_attribute
		WHERE
			parent_id = ?
			AND item_name like ?
		},
	'selSpecificWrkCmpAttr' => qq{
		SELECT *
		FROM org_attribute
		WHERE
			parent_id = ?
			AND value_int = ?
			AND value_type = ?
		},
	'selAllWrkCmpAttr' => qq{
		SELECT *
		FROM org_attribute
		WHERE
			value_int = ?
			AND value_type = ?
		},
	'selInsurance' => qq{
		SELECT *
		FROM insurance
		WHERE owner_person_id = ?
		ORDER BY
			coverage_end_date DESC,
			bill_sequence
		},
	'selInsuranceByPlanNameAndPersonAndInsType' => qq{
		SELECT *
		FROM insurance
		WHERE
			plan_name = ?
			AND owner_person_id = ?
			AND ins_type = ?
		},
	'selInsuranceByInsType' => qq{
		SELECT *
		FROM insurance
		WHERE
			owner_person_id = ?
			AND ins_type = ?
		},
	'selInsuranceByPersonOwnerAndGuarantorAndInsType' => qq{
		SELECT *
		FROM insurance
		WHERE
			owner_person_id = ?
			AND guarantor_id = ?
			AND ins_type = ?
		},
	'selInsuranceGroupData' => qq{
		SELECT
			ins_org_id,
			ins_type,
			plan_name,
			group_number,
			group_name,
			policy_number,
			record_type,
			indiv_deductible_amt,
			family_deductible_amt,
			percentage_pay,
			threshold,
			copay_amt,
			ct.caption AS ins_type_caption
		FROM
			insurance i,
			claim_type ct
		WHERE
			i.ins_type = ct.id
			AND i.product_name = ?
		},
	'selEmployerWorkersCompPlans' => qq{
		SELECT
			oa.value_text AS ins_id,
			oa.value_textB AS group_name
		FROM
			org_attribute oa,
			person_attribute pa,
			insurance ins
		WHERE
			pa.value_type in (220, 221)
			AND pa.value_int = oa.parent_id
			AND pa.parent_id = ?
			AND oa.value_type = 361
		UNION (
			SELECT
				ins.product_name,
				group_name
			FROM
				org,
				insurance ins,
				person_attribute pa
			WHERE
				org.org_internal_id = ins.ins_org_id
				AND ins.ins_type = 6
				AND	(
					pa.value_type in (220, 221)
					AND pa.value_int = org.org_internal_id
					AND	pa.parent_id=?
					)
			)
		},
	'selPatientHasPlan' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			product_name = ?
			AND owner_person_id = ?
			AND ins_type = ?
		},

	'selInsuranceGroupName' => qq{
		SELECT group_name
		FROM insurance
		WHERE product_name = ?
		},
	'selPlanByInsIdAndRecordType' => qq{
		SELECT *
		FROM insurance ins
		WHERE
			product_name = ?
			AND record_type = ?
		},
	'selInsuranceData' => qq{
		SELECT *
			FROM Insurance
			WHERE ins_internal_id = ?
		},
	'selInsuranceForInvoiceSubmit' => qq{
		SELECT
			ins.ins_internal_id,
			ins.parent_ins_id,
			ins.ins_org_id,
			ins.ins_type,
			ins.plan_name,
			ins.product_name,
			ins.owner_person_id,
			ins.group_name,
			ins.group_number,
			ins.insured_id,
			ins.member_number,
			TO_CHAR(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
			remit_payer_id,
			TO_CHAR(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
			ins.rel_to_insured,
			ins.record_type,
			ins.extra,
			ct.caption AS claim_type
		FROM
			insurance ins,
			claim_type ct
		WHERE
			ins.ins_internal_id = ?
			AND ct.id = ins_type
		},
	'selChildrenPlans' => qq{
		SELECT *
		FROM Insurance
		WHERE parent_ins_id = ?
		},
	'selInsuranceAddr' => qq{
		SELECT
			line1 AS addr_line1,
			line2 AS addr_line2,
			city AS addr_city,
			state AS addr_state,
			zip AS addr_zip,
			country AS addr_country,
			item_id
		FROM insurance_address
		WHERE
			parent_id = ?
			AND address_name = 'Billing'
		},
	'selInsuranceAddrWithOutColNameChanges' => qq{
		SELECT
			line1,
			line2,
			city,
			state,
			zip,
			country
		FROM insurance_address
		WHERE
			parent_id = ?
			AND address_name = 'Billing'
		},
	'selPayerChoicesByOwnerPersonId' => qq{
		SELECT
			i.ins_internal_id,
			i.plan_name,
			'Insurance' AS group_name,
			bs.caption AS bill_seq,
			i.bill_sequence AS bill_seq_id,
			guarantor_type
		FROM
			insurance i,
			claim_type ct,
			bill_sequence bs
		WHERE
			i.owner_person_id = ?
			AND ct.id = i.ins_type
			AND bs.id = i.bill_sequence
			AND i.bill_sequence IN (1,2,3,4)
			AND ct.group_name = 'insurance'
		UNION (
			SELECT
				wk.ins_internal_id,
				wk.plan_name,
				'Workers Compensation' AS group_name,
				'' AS bill_seq,
				wk.bill_sequence AS bill_seq_id,
				guarantor_type
			FROM insurance wk
			WHERE
				wk.owner_person_id = ?
				AND wk.ins_type = 6
			)
		UNION (
			SELECT
				ins_internal_id,
				guarantor_id AS plan_name,
				'Third-Party' AS group_name,
				'' AS bill_seq,
				bill_sequence AS bill_seq_id,
				guarantor_type
			FROM insurance
			WHERE
				owner_person_id = ?
				AND ins_type = 7
			)
		ORDER BY bill_seq_id
		},
	'selAllWorkCompByOwnerId' => qq{
		SELECT
			plan_name,
			product_name
		FROM insurance
		WHERE
			owner_person_id = ?
			AND ins_type = 6
		},
	'selInsuranceByOwnerAndProductName' => qq{
		SELECT *
		FROM insurance
		WHERE
			product_name = ?
			AND owner_person_id = ?
		},
	'selInsuranceByPersonAndInsOrg' => qq{
		SELECT *
		FROM insurance
		WHERE
			owner_person_id = ?
			AND ins_org_id = ?
		},
	'selInsuranceByInsOrgAndMemberNumber' => qq{
		SELECT *
		FROM insurance
		WHERE
			ins_org_id = ?
			AND member_number = ?
		},
	'selInsuranceByBillSequence' => qq{
		SELECT *
		FROM insurance
		WHERE
			bill_sequence = ?
			AND owner_person_id = ?
		},
	'selInsuranceBillCaption' => qq{
		SELECT caption
		FROM bill_sequence
		WHERE id = ?
		},
	'selInsurancePlanData' => qq{
		SELECT *
		FROM insurance
		WHERE
			product_name = ?
			AND record_type in (?, ?, ?, ?)
		},
	'selInsuranceGroupName' => qq{
		SELECT group_name
		FROM insurance
		WHERE product_name = ?
		},
	'selPersonPlanExists' => qq{
		SELECT plan_name
		FROM insurance
		WHERE
			product_name = ?
			AND plan_name = ?
			AND record_type = ?
			AND owner_person_id = ?
			AND ins_org_id = ?
		},

	'selInsuredRelationship' => qq{
		SELECT caption
		FROM insured_relationship
		WHERE id = ?
		},
	'selNewProductExists' => qq{
		SELECT product_name
		FROM insurance
		WHERE
			product_name = ?
			AND record_type = 1
		},
	'selNewPlanExists' => qq{
		SELECT plan_name
		FROM insurance
		WHERE
			plan_name = ?
			AND record_type = 2
		},

	'selDoesProductExists' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			product_name = ?
			AND ins_org_id = ?
			AND record_type = 1
		},
	'selDoesPlanExistsForPerson' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			product_name = ?
			AND owner_person_id = ?
		},
	'selIsPlanUnique' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			product_name = ?
			AND record_type = ?
		},
	'selIsPlanWorkComp' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			product_name = ?
			AND ins_type = ?
		},
#	'selInsuranceEncounterDialog' => qq{
#		SELECT
#			ins_internal_id,
#			product_name,
#			ins_type,
#			copay_amt,
#			bill_sequence,
#			ins_org_id,
#			group_name
#		FROM insurance
#		WHERE
#			bill_sequence = ?
#			AND owner_person_id = ?
#		},
	'selExistsPlanForPerson' => qq{
		SELECT ins_internal_id
		FROM insurance
		WHERE
			ins_type = ?
			AND owner_person_id = ?
		},
	'selPersonInsurance' => qq{
		SELECT
			ins.ins_internal_id,
			ins.parent_ins_id,
			ins.ins_org_id,
			ins.ins_type,
			ins.owner_person_id,
			ins.group_name,
			ins.group_number,
			ins.insured_id,
			ins.member_number,
			TO_CHAR(coverage_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
			TO_CHAR(coverage_end_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
			ins.rel_to_insured,
			ins.record_type,
			ins.extra,
			ct.caption AS claim_type
		FROM
			insurance ins,
			claim_type ct
		WHERE
			ins.owner_person_id = ?
			AND ins.bill_sequence = ?
			AND ct.id = ins_type
		},

	'selPersonInsuranceId' => qq{
		SELECT *
		FROM insurance
		WHERE
			ins_org_id = ?
			AND product_name = ?
			AND ins_type = ?
		},

	'selPatientWorkersCompPlan' => qq{
		SELECT *
		FROM insurance
		WHERE
			product_name = ?
			AND ins_type = 6
		},
	'selEmpExistPlan' => qq{
		SELECT DISTINCT ins.product_name
		FROM
			person_attribute patt,
			insurance ins
		WHERE
			patt.parent_id = ?
			AND patt.value_type between 220 AND 226
			AND patt.value_int = ins.ins_org_id
			AND ins.record_type = 6
		},
	'selInsuredRelation' => qq{
		SELECT
			id,
			caption
		FROM insured_relationship
		},
	'selPpoHmoIndicator' => qq{
		SELECT
			caption,
			abbrev
		FROM ppo_hmo_Indicator
		},
	'selInsTypeCode' => qq{
		SELECT
			caption,
			abbrev
		FROM insurance_type_code
		WHERE group_name = 'UI'
		},
	'selInsPlan' => qq{
		SELECT *
		FROM insurance
		WHERE
			product_name = ?
			AND plan_name = ?
			AND ins_org_id = ?
			AND record_type = 2
		},
	'selInsSequence' => qq{
		SELECT bill_sequence
		FROM insurance
		WHERE owner_person_id = ?
		},
	'selDoesInsSequenceExists' => qq{
		SELECT bill_sequence
		FROM insurance
		WHERE
			owner_person_id = ?
			AND bill_sequence = ?
		},
	'selUpdateInsSequence' => qq{
		UPDATE insurance
		SET bill_sequence = 99
		WHERE
			owner_person_id = ?
			AND bill_sequence > ?
			AND bill_sequence < 5
		},
	'selUpdateAndAddInsSeq' => qq{
		UPDATE insurance
		SET bill_sequence = 99
		WHERE
			ins_internal_id = ?
			AND bill_sequence = ?
		},

	'selDeleteFeeSchedule' => qq{
		DELETE
		FROM insurance_attribute
		WHERE
			parent_id = ?
			AND item_name = 'Fee Schedule'
			AND cr_org_internal_id = ?
	},
	'selUpdatePlanAndCoverage' => qq{
		 UPDATE insurance
		 SET
		 	ins_type = ?,
		 	product_name = ?,
		 	ins_org_id = ?
		 WHERE
		 	product_name = ?
		 	AND ins_org_id = ?
		 	AND record_type IN (2, 3)
	},
	'selUpdateCoverage' => qq{
		 UPDATE insurance
		 SET
		 	ins_org_id = ?,
		 	product_name = ?,
		 	plan_name = ?,
		 	owner_org_id = ?
		 WHERE parent_ins_id = ?
	},
	#--------------------------------------------------------------------------------------------------------------------------------------
	'sel_Person_Insurance' => {
		sqlStmt => qq{
			SELECT
				DECODE(bill_sequence,0,'Primary',1,'Secondary',2,'Tertiary',3,'Inactive','','W. Comp'),
				plan_name,
				ins_org_id
			FROM insurance
			WHERE owner_person_id = ?
			ORDER BY
				coverage_end_date DESC,
				bill_sequence
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
