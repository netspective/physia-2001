##############################################################################
package App::Statements::ReferralPPMS;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_REFERRAL_PPMS);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REFERRAL_PPMS);

$STMTMGR_REFERRAL_PPMS = new App::Statements::ReferralPPMS(

	'selReferralById' => qq
	{
		SELECT *
		FROM person_referral
		WHERE referral_id = :1
	},

	'selReferralType' =>qq
	{
		SELECT id, caption
		FROM referral_type
	},

	'selReferralUrgency' =>qq
	{
		SELECT id, caption
		FROM referral_urgency
	},

	'selReferralCommunication' =>qq
	{
		SELECT id, caption
		FROM referral_communication
	},

	'selReferralStatus' =>qq
	{
		SELECT id, caption
		FROM referral_status
	},
);

1;
