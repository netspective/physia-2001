##############################################################################
package App::Statements::Component::Referral;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_REFERRAL $STMTRPTDEFN_WORKLIST
	);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_COMPONENT_REFERRAL);

my $REFERRAL_STATUS_OPEN = App::Universal::TRANSTYPEPROC_REFERRAL;
my $REFERRAL_STATUS_AUTHORIZE = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;

#----------------------------------------------------------------------------------------------------------------------
my $timeFormat = 'HH:MIam';
$STMTRPTDEFN_WORKLIST =
{
	columnDefn =>
	[
		{colIdx => 0, head => 'ID', dAlign => 'left', url => "/person/#7#/dlg-add-trans-$REFERRAL_STATUS_AUTHORIZE/#0#"},
		{colIdx => 1, head => 'Status', dAlign => 'left'},
		{colIdx => 2, head => 'Patient', dAlign => 'left'},
		{colIdx => 3, head => 'Service Provider', dAlign => 'left'},
		{colIdx => 4, head => 'Service Type', dAlign => 'left'},
		{colIdx => 5, head => 'Requested Service', dAlign => 'left'},
		{colIdx => 6, head => 'Date of Request', dAlign => 'left'},
		#{colIdx => 8, hint => 'View Account Balance', head => 'Balance', url => '/person/#10#/account', dAlign => 'right', dformat => 'currency', summarize => 'sum'},
	],
};

$STMTMGR_COMPONENT_REFERRAL = new App::Statements::Component::Referral(
	'sel_referrals_open' => qq{
		select 
			trans_id as referral_id,
			(select p.complete_name || ' (' || p.person_id || ')' from person p where p.person_id = t.trans_owner_id) as patient,
			(select p.complete_name || ' (' || p.person_id || ')' from person p where p.person_id = t.provider_id) as referrer,
			(select p.complete_name || ' (' || p.person_id || ')' from person p where p.person_id = t.care_provider_id) as service_provider,
			t.trans_owner_id as patient_id,
			t.provider_id as referrer_id,
			t.care_provider_id as service_provider_id,
			t.data_text_a as service_provider_type, 
			t.trans_substatus_reason as requested_service,
			t.trans_end_stamp as request_date, 
			t.trans_status as status
		from transaction t
		where 
		t.trans_type = $REFERRAL_STATUS_OPEN
	},
);

1;
