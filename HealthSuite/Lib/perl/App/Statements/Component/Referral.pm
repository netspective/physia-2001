##############################################################################
package App::Statements::Component::Referral;
##############################################################################

use strict;
use Exporter;

use Date::Manip;
use DBI::StatementManager;
use App::Universal;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_REFERRAL $STMTRPTDEFN_WORKLIST
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
		{colIdx => 0, head => ' ', dAlign => 'left', url => "#9#"},
		{colIdx => 1, head => 'ID', dAlign => 'left', url => "#8#"},
		{colIdx => 2, head => 'Status', dAlign => 'left'},
		{colIdx => 3, head => 'Patient', dAlign => 'left'},
		{colIdx => 4, head => 'Referred To', dAlign => 'left'},
		{colIdx => 5, head => 'Service Type', dAlign => 'left'},
		{colIdx => 6, head => 'Requested Service', dAlign => 'left'},
		{colIdx => 7, head => 'Date of Request', dAlign => 'left'},
		#{colIdx => 8, hint => 'View Account Balance', head => 'Balance', url => '/person/#10#/account', dAlign => 'right', dformat => 'currency', summarize => 'sum'},
	],
};

$STMTMGR_COMPONENT_REFERRAL = new App::Statements::Component::Referral(
	'sel_personinfo' => qq {
		select short_name, complete_name 
		from person where person_id = ?
	},
	'sel_referrals_open' => qq{		
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
		t.trans_type = $REFERRAL_STATUS_OPEN 
		order by trans_id
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
		order by trans_id
	},
);

1;
