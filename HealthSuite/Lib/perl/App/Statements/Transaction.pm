##############################################################################
package App::Statements::Transaction;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_TRANSACTION);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_TRANSACTION);

my $ACTIVE  = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;


$STMTMGR_TRANSACTION = new App::Statements::Transaction(
	'selTransaction' => qq{
			select provider_id, rel.caption as related_to,
					data_text_a as ref_id, billing_facility_id, service_facility_id
				from transaction, trans_related_to  rel
				where trans_id = ?
				and transaction.related_to = rel.id
	},
	'selTransactionById' => qq{
		select trans_id, trans_owner_type, trans_owner_id, parent_event_id, parent_trans_id,
			trans_type, trans_subtype, trans_status, caption, detail, code, billing_facility_id,
			service_facility_id, provider_id, care_provider_id, consult_id, initiator_id,
			receiver_type, receiver_id, processor_id, trans_seq, bill_type, related_to,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c,
			to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS trans_begin_stamp,
			to_char(trans_end_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS trans_end_stamp,
			to_char(init_onset_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS init_onset_date,
			to_char(curr_onset_date, '$SQLSTMT_DEFAULTDATEFORMAT') AS curr_onset_date,
			trans_status_reason, related_data, caption, trans_substatus_reason
		from Transaction
		where trans_id = ?
	},
	'selTransactionByData_num_a' => qq{
		select * from transaction
		where data_num_a = ?
	},
	'selTransactionByUserAndData_num_a' => qq{
			SELECT *
			FROM transaction
			WHERE data_num_a = ?
			AND trans_owner_id = ?
	},
	'selTransAndICDNameByTransId' => qq{
		select code, curr_onset_date, trans_id, trans_type, r.name as icdname
			from transaction, ref_icd r
			where trans_id = ?
				and r.icd = code
	},
	'selVisitType' => qq{
		select id, caption
			from transaction_type
			where id>=2040 and id<3000
	},
	#'selPersonActiveProblems' => qq{
	#	    select t.trans_type, t.trans_id, t.caption, t.code, t.curr_onset_date, t.provider_id,
	#					ref.descr as code_caption, parent_trans_id, service_facility_id
	#			from transaction t, ref_icd ref
	#			where trans_type = 3020
	#			    and trans_owner_type = 0 and trans_owner_id = ?
	#				and t.code = ref.icd (+)
	#				and trans_status = ?
	#	    	order by curr_onset_date DESC
	#	},
	#'selActiveProblemsNotes' => qq{
	#	    select trans_id, trans_type, data_text_a, trans_begin_stamp, provider_id
	#			from transaction
	#			where trans_type = 3100
	#			    and trans_owner_id = ?
	#				and trans_status = ?
	#	    	order by trans_begin_stamp DESC
	#	},
	#'selPersonActiveProblemsDiagnosis' => qq{
	#	    select trans_type, trans_id, data_text_a as code_caption, curr_onset_date, provider_id
	#			from transaction
	#			where trans_type between 3000 and 3010
	#			     and trans_owner_id = ?
	#			    and trans_status = ?
	#	    	order by curr_onset_date DESC
	#	},
	#'selPersonIncompleteInvoices' => qq{
	#       select invoice_id
	#	   		from invoice
	#	   		where invoice_type = 0
	#	  			and invoice_status < ?
	#	  			and client_id = ?
    #    },
    #'selPersonActiveMedications' => qq{
    #        select trans_id, tr.caption, trans_begin_stamp, code, detail as instructions, provider_id,
	#					data_text_a as dosage, tr.trans_type, tt.caption as type_name
	#			   from transaction tr, transaction_type tt
	#			   where trans_type between 7000 and 7999
	#					and tr.trans_type = tt.id
	#					and trans_owner_type = 0 and trans_owner_id = ?
	#					and trans_status = ?
	#				order by trans_begin_stamp DESC
	#    },

	'selPersonHospitalization' => qq{
		select trans_id,trans_type,trans_begin_stamp, related_data, caption, trans_status_reason, provider_id, data_text_a, data_text_b, data_text_c,
			consult_id, detail
			from transaction
			where trans_type between 11000 and 11999
				and trans_owner_id = ? and trans_status = ?
	},

	'selPersonMeasurements' => qq{
			select trans_id,trans_type,cr_stamp,trans_begin_stamp,data_text_a,data_text_b
				from transaction t
				where trans_begin_stamp =
					(select max(trans_begin_stamp)
						from transaction tt
					  	where t.data_text_b = tt.data_text_b and tt.trans_type between 12000 and 12999 and tt.trans_owner_id = ?
					  	group by tt.data_text_b)
	},

	'selMeasurementCount' => qq{
		select count(*) from transaction
			where trans_type between 12000 and 12999 and trans_owner_id = ? and data_text_b = ?
	},

		#
		# both the selPersonEncounters and selPersonEncounterChildren need to be updated
		# to properly account for ICD/CPT codes that might conflict in the catalog_item
		# tables. for instance, if an organization has redefined an ICD/CPT, what will happen?
		#
	'selPersonEncounters' => qq{
		select trans_id, trans_type, transaction.caption, transaction.code, transaction.modifier, trans_owner_id,transaction.data_text_a,transaction.data_text_b,
				pkg_entity.GetEntityDisplay(INITIATOR_TYPE, INITIATOR_ID) as initiator,
				pkg_entity.GetEntityDisplay(RECEIVER_TYPE, RECEIVER_ID) as receiver,
				pkg_entity.GetEntityDisplay(0, PROVIDER_ID) as provider,
				pkg_entity.GetEntityDisplay(0, CARE_PROVIDER_ID) as care_provider,
				pkg_entity.GetEntityDisplay(1, SERVICE_FACILITY_ID) as service_facility,
				TRANS_BEGIN_STAMP, to_char(TRANS_BEGIN_STAMP, 'MM/DD/YYYY') as TRANS_BEGIN_STAMP_FORMAT,
				TRANS_END_STAMP, tt.caption as type_name, GROUP_NAME, ICON_IMG_SUMM, invoice_id,
				ref_cpt.name as cpt_caption, ref_icd.description as icd_caption
			from transaction, transaction_type tt, invoice,
				offering_catalog_entry ref_cpt, offering_catalog_entry ref_icd
			where PARENT_TRANS_ID is null
					and	TRANS_TYPE = ID
					and TRANS_OWNER_TYPE = 0 and TRANS_OWNER_ID = ?
					and trans_id = invoice.main_transaction (+)
					and transaction.code = ref_cpt.code (+)
				and transaction.code = ref_icd.code (+)
			order by TRANS_BEGIN_STAMP DESC, GROUP_NAME, tt.CAPTION
	},
	'selPersonEncounterChildren' => qq{
		select trans_id, trans_type, transaction.caption, transaction.code, transaction.modifier, trans_owner_id,
				pkg_entity.GetEntityDisplay(INITIATOR_TYPE, INITIATOR_ID) as initiator,
				pkg_entity.GetEntityDisplay(RECEIVER_TYPE, RECEIVER_ID) as receiver,
				pkg_entity.GetEntityDisplay(0, PROVIDER_ID) as provider,
				pkg_entity.GetEntityDisplay(0, CARE_PROVIDER_ID) as care_provider,
				pkg_entity.GetEntityDisplay(1, SERVICE_FACILITY_ID) as service_facility,
				TRANS_BEGIN_STAMP, to_char(TRANS_BEGIN_STAMP, 'MM/DD/YYYY') as TRANS_BEGIN_STAMP_FORMAT,
				TRANS_END_STAMP, tt.caption as type_name, GROUP_NAME, ICON_IMG_SUMM, invoice_id,
				ref_cpt.name as cpt_caption, ref_icd.description as icd_caption
			from transaction, transaction_type tt, invoice,
				offering_catalog_entry ref_cpt, offering_catalog_entry ref_icd
			where PARENT_TRANS_ID = ?
					and	TRANS_TYPE = ID
					and TRANS_OWNER_TYPE = 0 and TRANS_OWNER_ID = ?
					and trans_id = invoice.main_transaction (+)
					and transaction.code = ref_cpt.code (+)
				and transaction.code = ref_icd.code (+)
			order by TRANS_BEGIN_STAMP DESC, GROUP_NAME, tt.CAPTION
 	},
	'selTestsEncounter' => qq{
		select trans_id, trans_type, data_text_a, data_text_b, trans_begin_stamp
		from transaction
		where trans_type between 12000 and 12999 and trans_owner_id = ?
	},
	'selCondition' => qq{
		select caption
		from trans_related_to
		where id = ?
	},
	'selTransCreateClaim' => qq{
		select trans_id, trans_type, caption as subject, provider_id, care_provider_id, parent_event_id,
				service_facility_id, billing_facility_id, bill_type, data_text_a as ref_id, data_text_b as comments
		from transaction
		where trans_id = ?
	},
	'selTransId' => qq{
		select trans_id
		from transaction
		where parent_event_id = ?
	},
	'selByTransId' => qq{
		select *
		from transaction
		where trans_id = ?
	},

	'selByParentTransId' => qq{
		select *
		from transaction
		where parent_trans_id = ?
	},
	'selUpdateTransStatus' => qq{
		update transaction
		set trans_status = 3
		where parent_trans_id = ?
	},


	####################################################################
	#SQL STATEMENTS FOR MISC PROCEDURE CODES
	####################################################################
	'sel4MiscProcedureById' =>qq{
		select t.caption as name ,t.detail as description ,t.code as proc_code,ta.value_text as cpt_code ,
		ta.item_id as item_id , ta.value_textB as modifier
		FROM transaction t, trans_attribute ta
		WHERE t.trans_id = :1
		and trans_status=$ACTIVE
		and ta.parent_id (+) = t.trans_id
		and rownum <5
		order by ta.item_id asc
	},
	'selMiscProcedureById' => qq{
		select  t.caption as name ,t.detail as description ,t.code as proc_code,
		ta.value_text as cpt_code1,ta.item_id as item_id1, ta.value_textB modifier1,
		ta.value_int as nextId, t.trans_id as trans_id
		from Transaction t, trans_attribute ta
		where trans_status = $ACTIVE
		and ta.parent_id = t.trans_id
		and ta.item_id = :1
	},
	'selMiscProcedureNameById' => qq{
		select  t.caption as name ,t.detail as description ,t.code as proc_code
		from transaction t
		where trans_status = $ACTIVE
		and t.trans_id = :1
	},

	'selNextProcedureSeq' => qq{
		select max(value_int)+1
		FROM trans_attribute ta where ta.parent_id = ?
		and trans_stauts = $ACTIVE
	},
	'selMiscProcedureByCode' =>qq{
		select distinct code
		FROM transaction
		WHERE code = :1
		and trans_type = @{[App::Universal::TRANSTYPEPROC_REGULAR]}
		and trans_subtype = '@{[App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT]}'
		and trans_status = $ACTIVE
	},
	'selMiscProcedureByTransId' =>qq{
		select  code
		FROM transaction t
		WHERE  trans_id = :1
	},
	####################################################################
	#END SQL STATEMENTS FOR MISC PROCEDURE CODES
	####################################################################


	# expects bind parameters:
	#   1: user_id
	#   2: user_id (same as 1)
	#   3: session org_id
	#
	'selMyAndAssociatedInPatients' => qq{
		select trans_owner_id, trans_id,trans_type,trans_begin_stamp, related_data, caption, trans_status_reason, provider_id, data_text_a, data_text_b, data_text_c,
			consult_id, detail, complete_name
			from transaction, person
			where trans_type between 11000 and 11999
				and
				(	provider_id = ? or
					provider_id in (select value_text from person_attribute where parent_id = ? and parent_org_id = ? and item_name = 'Association/Resource/Physician')
				)
				and trans_status = 2
				and person_id = trans_owner_id
	},
#############################################################################
	# SQL STATEMENT TO GET THE DECEASED PATIENT INFO
#############################################################################

	'selDataByTransTypeAndCaption' => qq
		{
			SELECT  trans_id
			FROM 	transaction
			WHERE 	trans_owner_id = ?
			AND 	trans_type = @{[App::Universal::TRANSTYPE_ALERTPATIENT]}
			AND	caption = 'Deceased Patient'
		},

#####################################################################
	#SQL STAEMENTS FOR REFERRAL AUTHORIZATION INFO
#####################################################################

	'selClaimNumByParentId' => qq
		{
			SELECT  value_int
			FROM trans_attribute
			WHERE  parent_id = ?
		},
	'selUpdateTransByParentId' => qq
		{
			UPDATE transaction
			SET auth_ref = ?,
			    consult_id = ?
			WHERE parent_trans_id = ?
		},
	'selUpdateReferralStatus' => qq
		{
			UPDATE transaction
			SET trans_substatus_reason = 'Assigned'
			WHERE trans_id = ?
			AND trans_substatus_reason = 'Unassigned'
		},
	'selRemoveChildReferrals' => qq
		{
			DELETE
			FROM transaction
			WHERE parent_trans_id = ?
			AND trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION]}
		},
	'selRemoveChildReferralAttr' => qq
		{
			DELETE
			FROM trans_attribute
			WHERE parent_id = ?
		},
	'selByParentIdItemName' => qq
		{
			SELECT *
			FROM trans_attribute
			WHERE parent_id = ?
			AND item_name = ?
		},
	'selReferralSourceType' => qq
		{
			SELECT
				id,
				caption
			FROM 	referral_source_type
			ORDER BY caption
		},
	'selIntakeService' => qq
		{
			SELECT
				id,
				caption
			FROM 	intake_service
			ORDER BY caption
		},
	'selIntakeDetail' => qq
		{
			SELECT
				id,
				caption
			FROM 	intake_detail
			ORDER BY caption
		},
	'selReferralUnitType' => qq
		{
			SELECT
				id,
				caption
			FROM 	referral_unit_type
			ORDER BY caption
		},
	'selReferralFollowStatus' => qq
		{
			SELECT
				id,
				caption
			FROM 	referral_followup_status
			ORDER BY caption
		},
	'selReferralResult' => qq
		{
			SELECT
				id,
				caption
			FROM 	referral_result
			ORDER BY caption
		},
	'selIntakeClient' => qq
		{
			SELECT
				id,
				caption
			FROM    intake_client
			ORDER BY caption
		},
	'selReferralServiceDesc' => qq
		{
			SELECT
				id,
				caption
			FROM 	referral_service_descr
			ORDER BY caption
		},
	'selTransAddressByName' => qq
		{
			SELECT *
			FROM trans_address
			WHERE parent_id = ?
			AND address_name = ?
		},
	'selServiceRequestData' => qq
		{
			SELECT *
			FROM transaction t
			WHERE trans_id = (
						SELECT MAX(trans_id)
						FROM transaction tt
						WHERE tt.trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL]}
						AND tt.consult_id = ?

					)
		},
	'selServiceProcedureData' =>qq
		{
			SELECT 	trans_id, trans_owner_type, trans_owner_id, parent_event_id, parent_trans_id,
			trans_type, trans_subtype, trans_status, caption, detail, code, billing_facility_id,
			service_facility_id, provider_id, care_provider_id, consult_id, initiator_id,
			receiver_type, receiver_id, processor_id, trans_seq, bill_type, related_to,
			data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c,
			to_char(data_date_a, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS data_date_a,
			to_char(data_date_b, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS data_date_b,
			trans_status_reason, related_data, caption, trans_substatus_reason,
			modifier,unit_cost,quantity
			
			FROM 	transaction t
			WHERE	t.parent_trans_id = :1		
			AND	t.trans_type = @{[App::Universal::TRANSTYPEPROC_SERVICE_REQUEST_PROCEDURE]}
			ORDER BY trans_id asc
		},
);


1;
