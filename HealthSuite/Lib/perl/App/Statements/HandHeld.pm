##############################################################################
package App::Statements::HandHeld;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@EXPORT $STMTMGR_HANDHELD);

use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_HANDHELD);

my $timeFormat = 'HH24:MI';

my $BASE_APPT_SQL = qq{
	SELECT to_char(e.start_time - :1, 'hh24:mi') as time,
		patient.person_id as patient_id,
		patient.short_sortable_name as patient,
		initcap(e.subject) as reason,
		at.caption as appt_type,
		astat.caption as status,
		patient.person_id
	FROM  Appt_Status astat, Person patient, Person provider,
		Event_Attribute ea, Appt_Type at, Event e
	WHERE e.start_time >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :1
		AND e.start_time <  to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') + :1 + 1
		AND e.discard_type is null
		%apptStatusClause%
		AND at.appt_type_id (+) = e.appt_type
		AND ea.parent_id = e.event_id
		AND ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
		AND ea.value_text = patient.person_id
		AND ea.value_textB = provider.person_id
		AND
		(	ea.value_textB = :3 or ea.value_textB in
			(select value_text
				from person_attribute
				where parent_id = :3
					and item_name = 'WorkList'
					and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
					and parent_org_id = :4
			)
		)
		and astat.id = e.event_status
};

# -------------------------------------------------------------------------------------------
$STMTMGR_HANDHELD = new App::Statements::HandHeld(

	'sel_scheduledAppts' => {
		sqlStmt => $BASE_APPT_SQL,
		apptStatusClause => qq{AND e.event_status = @{[ App::Universal::EVENTSTATUS_SCHEDULED ]}},
	},

	'sel_inProgressAppts' => {
		sqlStmt => $BASE_APPT_SQL,
		apptStatusClause => qq{AND e.event_status = @{[ App::Universal::EVENTSTATUS_INPROGRESS ]}},
	},

	'sel_completedAppts' => {
		sqlStmt => $BASE_APPT_SQL,
		apptStatusClause => qq{AND e.event_status = @{[ App::Universal::EVENTSTATUS_COMPLETE ]}},
	},

	'sel_inPatients' => qq{
		select related_data as hospital_name,
			caption as room,
			initcap(simple_name) as patient_name,
			provider_id,
			trans_owner_id as patient_id,
			trans_status_reason as complaint
		from Person, Transaction
		where trans_type between 11000 and 11999
			and trans_status = @{[ App::Universal::TRANSSTATUS_ACTIVE ]}
			and trans_begin_stamp >= sysdate - data_num_a
			and (provider_id = :1 OR provider_id in
				(	select value_text from person_attribute
					where parent_id = :1
						and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
						and item_name = 'WorkList'
						and parent_org_id = :2
				)
			)
			and person.person_id = transaction.trans_owner_id
	},

	'sel_patientDemographics' => qq{
		select complete_sortable_name as name,
			complete_addr_html as address,
			home.value_text as home_phone,
			work.value_text as work_phone,
			to_char(date_of_birth, 'mm/dd/yyyy') as dob,
			decode(gender, 1, 'M', 2, 'F', 'U') as gender,
			trunc((sysdate - date_of_birth)/365) as age
		from person_attribute home, person_attribute work, person_address, person
		where person_id = upper(:1)
			and person_address.parent_id = person.person_id
			and work.parent_id (+) = person.person_id
			and work.item_name (+) = 'Work'
			and home.parent_id (+) = person.person_id
			and home.item_name (+) = 'Home'
	},

	'sel_patientInsurance' => qq{
		SELECT
			ins_internal_id,
			parent_ins_id,
			product_name,
			plan_name,
			DECODE(bill_sequence,1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive', 'Active'),
			owner_person_id,
			ins_org_id,
			indiv_deductible_amt,
			family_deductible_amt,
			percentage_pay,
			copay_amt,
			guarantor_name,
			decode(ins_type, 7, 'thirdparty', 'coverage') AS ins_type,
			guarantor_id,
			guarantor_type,
			(
				SELECT 	b.org_id
				FROM org b
				WHERE b.org_internal_id = i.ins_org_id
			) AS org_id,
			(
				SELECT 	g.org_id
				FROM org g
				WHERE guarantor_type = 1
				AND  g.org_internal_id = i.guarantor_id
			),
			i.coverage_begin_date,
			i.coverage_end_date
		FROM insurance i
		WHERE record_type = @{[ App::Universal::RECORDTYPE_PERSONALCOVERAGE ]}
		AND owner_person_id = upper(:1)
		ORDER BY bill_sequence
	},

	'sel_patientActiveMeds' => qq{
		SELECT
			tr.trans_type,
			tr.trans_id,
			tr.caption as medicine,
			to_char(tr.trans_begin_stamp, '$SQLSTMT_DEFAULTDATEFORMAT'),
			tt.caption as type,
			tr.provider_id,
			tr.data_text_a
		FROM
			transaction_type tt,
			transaction tr
		WHERE
			tr.trans_owner_id = upper(:1)
			AND tr.trans_type BETWEEN 7000 AND 7999
			AND tr.trans_owner_type = 0
			AND tr.trans_status = @{[ App::Universal::TRANSSTATUS_ACTIVE ]}
			AND tt.id = tr.trans_type
		ORDER BY tr.trans_begin_stamp DESC
	},

	'sel_patientActiveProblems' => qq{
		select to_char(t.curr_onset_date, '$SQLSTMT_DEFAULTDATEFORMAT') as curr_onset_date,
			to_char(t.trans_begin_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as trans_date,
			ref.name, t.provider_id, '(ICD ' || t.code || ')' as code
		from ref_icd ref, transaction t
		where t.trans_owner_id = upper(:1)
			and t.trans_owner_type = 0
			and t.trans_type = @{[ App::Universal::TRANSTYPEDIAG_ICD ]}
			and t.trans_status = @{[ App::Universal::TRANSSTATUS_ACTIVE ]}
			and ref.icd (+) = t.code
		order by trans_date desc, trans_id desc
	},

	'sel_patientBloodType' => qq{
		SELECT b.caption
		FROM Blood_Type b, Person_Attribute pa
		WHERE pa.parent_id = upper(:1)
			AND pa.item_name = 'BloodType'
			AND b.id = pa.value_text
	},

	'sel_patientAllergies' => qq{
		select value_type,
			item_id,
			item_name,
			value_text
		from person_attribute
		where parent_id = upper(:1)
			and value_type in (410, 411, 412)
	}
);

1;
