##############################################################################
package App::Statements::Component::Referral;
##############################################################################

use strict;
use Exporter;

use Date::Manip;
use DBI::StatementManager;
use App::Universal;
use App::Statements::Component;
my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_REFERRAL $STMTRPTDEFN_WORKLIST $STMTRPTDEFN_AUTH_WORKLIST
	);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_COMPONENT_REFERRAL);

my $REFERRAL_STATUS_OPEN = App::Universal::TRANSTYPEPROC_REFERRAL;
my $REFERRAL_STATUS_AUTHORIZE = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;
my $ATTRITYPE_RESOURCE_PERSON = App::Universal::ATTRTYPE_RESOURCEPERSON;

#----------------------------------------------------------------

my $timeFormat = 'HH:MIam';
$STMTRPTDEFN_WORKLIST =
{
	columnDefn =>
	[
		{colIdx => 1, head => 'ID', dAlign => 'left'},
		{colIdx => 2, head => 'Status', dAlign => 'left'},
		{colIdx => 3, head => 'Patient',hAlign=>'left', url => "javascript:doActionPopup('/person/#3#/profile')"},
		{colIdx => 5, head => 'Date of Request', dAlign => 'center'},
		{colIdx => 6, head => 'Intake Coordinator', dAlign => 'center'},
		{colIdx => 7, head => 'SSN', dAlign => 'center'},
		#{colIdx => 8, hint => 'View Account Balance', head => 'Balance', url => '/person/#10#/account', dAlign => 'right', dformat => 'currency', summarize => 'sum'},
	],
	bullets => '#10#',
};

$STMTRPTDEFN_AUTH_WORKLIST =
{
	columnDefn =>
	[
		{colIdx => 0, head => 'Service Request ID ', dAlign => 'left'},
		{colIdx => 1, head => 'Referral ID', dAlign => 'left', url => "#9#"},
		{colIdx => 2, head => 'Follow Up Date ', dAlign => 'left'},
		{colIdx => 3, head => 'SSN', dAlign => 'left'},
		{colIdx => 4, head => 'Last Name', dAlign => 'left'},
		{colIdx => 5, head => 'First Name', dAlign => 'left'},
		{colIdx => 6, head => 'Intake Coordinator', dAlign => 'center'},
		{colIdx => 7, head => 'Service', hAlign => 'left'},
		{colIdx => 8, head => 'Follow Up', hAlign => 'left'},
	],
};


$STMTMGR_COMPONENT_REFERRAL = new App::Statements::Component::Referral(
	'sel_personinfo' => qq {
		select short_name, complete_name
		from person where person_id = ?
	},
	'sel_referrals_open' => qq{
		select *
		from (
			select
				t.trans_id as referral_id,
				t.initiator_id as org_id,
				t.consult_id as patient,
				aa.value_int as claim_number,
				t.trans_substatus_reason as requested_service,
				--%simpleDate:trans_end_stamp%,
				decode(to_char(t.trans_end_stamp, 'YYYY'),
				to_char(sysdate, 'YYYY'),
				to_char(t.trans_end_stamp, 'Mon DD'),
				to_char(t.trans_end_stamp, 'MM/DD/YY')) as trans_end_stamp,
				NVL((select tt.trans_id from transaction tt where tt.trans_type = 6010 and tt.parent_trans_id = t.trans_id
					and rownum < 2 and t.trans_status = 2), t.trans_id) as trans_id_mod,
				t.trans_subtype as intake_coordinator,
				t.trans_substatus_reason as ref_status,
				p.ssn as ssn
			from transaction t, trans_attribute aa, person p, person_org_category po
			where
			t.trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL]}
			and t.trans_substatus_reason in ('Assigned', 'Unassigned')
			and aa.parent_id = t.trans_id
			and aa.item_name = 'Referral Insurance'
			and t.consult_id = p.person_id
			and po.person_id = p.person_id

			and po.org_internal_id = ?
			and exists
					(
						select tn.trans_id
						from transaction tn, transaction tp
						where tp.parent_trans_id = t.trans_id
						and   tn.parent_trans_id = tp.trans_id
						and   (tn.trans_status_reason NOT IN ('7', '13', '14', '15', '16', '17', '18', '19') or tn.trans_status_reason IS NULL)
					)
			order by t.trans_id DESC
			)
			where rownum <= $LIMIT
	},

	'sel_referrals_user' => qq{
		select *
		from (
			select
				t.trans_id as referral_id,
				t.initiator_id as org_id,
				t.consult_id as patient,
				aa.value_int as claim_number,
				t.trans_substatus_reason as requested_service,
				--%simpleDate:trans_end_stamp%,
				decode(to_char(t.trans_end_stamp, 'YYYY'),
				to_char(sysdate, 'YYYY'),
				to_char(t.trans_end_stamp, 'Mon DD'),
				to_char(t.trans_end_stamp, 'MM/DD/YY')) as trans_end_stamp,
				NVL((select tt.trans_id from transaction tt where tt.trans_type = 6010 and tt.parent_trans_id = t.trans_id
					and rownum < 2 and t.trans_status = 2), t.trans_id) as trans_id_mod,
				t.trans_subtype as intake_coordinator,
				t.trans_substatus_reason as ref_status,
				p.ssn as ssn
			from transaction t, trans_attribute aa, person p, person_org_category po, person pp
			where
			t.trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL]}
			and t.trans_substatus_reason in ('Assigned', 'Unassigned')
			and aa.parent_id = t.trans_id
			and aa.item_name = 'Referral Insurance'
			and t.consult_id = p.person_id
			and po.person_id = p.person_id
			and t.trans_subtype = pp.person_id
			and t.trans_subtype = ?
			and po.org_internal_id = ?
			and exists
					(
						select tn.trans_id
						from transaction tn, transaction tp
						where tp.parent_trans_id = t.trans_id
						and   tn.parent_trans_id = tp.trans_id
						and   (tn.trans_status_reason NOT IN ('7', '13', '14', '15', '16', '17', '18', '19') or tn.trans_status_reason IS NULL)
					)
			order by t.trans_id DESC
			)
			where rownum <= $LIMIT
	},


	'sel_referrals_physician' => qq{
		select
			trans_id as referral_id,
			(select p.complete_name from person p where p.person_id = t.trans_owner_id) as patient,
			(select p.complete_name from person p where p.person_id = t.provider_id) as referrer,
			(select p.complete_name from person p where p.person_id = t.care_provider_id) as service_provider,
			t.trans_owner_id as patient_id,
			t.provider_id as referrer_id,
			t.care_provider_id as service_provider_id,
			t.data_text_a as service_provider_type,
			t.trans_substatus_reason as requested_service,
			--%simpleDate:trans_end_stamp%,
			decode(to_char(trans_end_stamp, 'YYYY'), to_char(sysdate, 'YYYY'), to_char(trans_end_stamp, 'Mon DD'), to_char(trans_end_stamp, 'MM/DD/YY')) as trans_end_stamp,
			NVL((select tt.trans_status_reason || '<BR>(' || tt.auth_ref || ')' from transaction tt where tt.trans_type = 6010 and tt.parent_trans_id = t.trans_id
				and rownum < 2 and trans_status = 2), 'Pending') as trans_status_reason,
			NVL((select tt.trans_id from transaction tt where tt.trans_type = 6010 and tt.parent_trans_id = t.trans_id
				and rownum < 2 and trans_status = 2), t.trans_id) as trans_id_mod
		from transaction t
		where
		t.trans_type = $REFERRAL_STATUS_OPEN and
		(t.provider_id = ? or t.care_provider_id = ?
			or (
				(t.provider_id in (select value_text from person_attribute
				where parent_id = ? and value_type = $ATTRITYPE_RESOURCE_PERSON and item_name = 'WorkList'))
				or
				(t.care_provider_id in (select value_text from person_attribute
				where parent_id = ? and value_type = $ATTRITYPE_RESOURCE_PERSON and item_name = 'WorkList'))
			)
		)
		and rownum <= $LIMIT
		order by trans_id DESC
	},

	'sel_referral_authorization' => qq{
		SELECT *
		FROM (
			SELECT
				(SELECT parent_trans_id FROM transaction WHERE trans_id = t.parent_trans_id) as referral_id,
				trans_id as intake_id,
				 data_date_b as review_date,
				 consult_id as patient,
				 (
					SELECT r.caption
					FROM referral_followup_status r
					WHERE r.id=t.trans_status_reason
					) AS follow_up,
						initiator_id as org_id,
						p.ssn as ssn,
						p.name_last as last_name,
						p.name_first as first_name,
						t.care_provider_id AS intake_coordinator,
						(
							SELECT caption
							FROM   referral_service_descr rs
							WHERE rs.id = t.caption
						) AS service
			FROM     transaction t, person p, person_org_category po
			WHERE    t.trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION]}
			AND      t.consult_id = p.person_id
			AND      po.person_id = p.person_id
			AND      po.org_internal_id = ?
			AND 		(t.trans_status_reason NOT IN ('7', '13', '14', '15', '16', '17', '18', '19') or t.trans_status_reason IS NULL)
			ORDER BY t.care_provider_id, data_date_b DESC, trans_id DESC
		)
		WHERE rownum <= $LIMIT
		},

		'sel_referral_authorization_user' => qq{
			SELECT *
			FROM (
				SELECT
					parent_trans_id as referral_id,
					trans_id as intake_id,
					data_date_b as review_date,
					consult_id as patient,
					 (
						SELECT r.caption
						FROM referral_followup_status r
						WHERE r.id=t.trans_status_reason) AS follow_up,
						  initiator_id as org_id,
						  p.ssn as ssn,
						  p.name_last as last_name,
						  p.name_first as first_name,
						  t.care_provider_id AS intake_coordinator,
						  (
								SELECT caption
								FROM   referral_service_descr rs
							WHERE rs.id = t.caption
							) AS service
				FROM    transaction t, person p, person_org_category po
				WHERE   t.trans_type = @{[App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION]}
				AND 	care_provider_id  = ?
				AND     t.consult_id = p.person_id
				AND 	po.person_id = p.person_id
				AND     po.org_internal_id = ?
				AND 		t.trans_status_reason NOT IN ('7', '13', '14', '15', '16', '17', '18', '19')
				ORDER BY t.care_provider_id, data_date_b DESC, trans_id DESC
				)
				WHERE rownum <= $LIMIT
			},

);

1;
