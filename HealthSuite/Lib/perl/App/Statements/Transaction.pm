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
		select trans_id, trans_owner_type, trans_owner_id, parent_event_id, parent_trans_id, trans_type, trans_subtype, trans_status,
			caption, detail, code, billing_facility_id, service_facility_id, provider_id, care_provider_id, consult_id, initiator_id,
			receiver_type, receiver_id, processor_id, trans_seq, bill_type, related_to, data_text_a, data_text_b, data_text_c, data_num_a, data_num_b, data_num_c,
			to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT'), to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT'),
			to_char(init_onset_date, '$SQLSTMT_DEFAULTDATEFORMAT'), to_char(curr_onset_date, '$SQLSTMT_DEFAULTDATEFORMAT')
		from transaction
		where trans_id = ?
		},
        'selTransactionByData_num_a' => qq{
                select * from transaction
                        where data_num_a = ?
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
	'selMiscProcedureCodesById' => qq{
		select  t.caption as name ,t.detail as description ,t.code as proc_code,
		(select value_text from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 1) cpt_code1,
		(select value_text from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 2) cpt_code2,
		(select value_text from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 3) cpt_code3,
		(select value_text from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 4) cpt_code4,
		(select item_id from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 1) item_id1,
		(select item_id from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 2) item_id2,
		(select item_id from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 3) item_id3,
		(select item_id from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 4) item_id4,
		(select value_textB from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 1) modifier1,
		(select value_textB from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 2) modifier2,
		(select value_textB from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 3) modifier3,
		(select value_textB from Trans_Attribute ta where ta.parent_id = t.trans_id and value_int = 4) modifier4				
		from Transaction t
		where t.trans_id = :1		
		and trans_status = $ACTIVE
		},		
	#
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
);


1;
