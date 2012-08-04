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

	'closeReferralById' => qq
	{
		UPDATE Person_Referral 
		SET referral_status = 3,
		referral_status_date = sysdate
		where referral_id = :1
	},

	'delReferralNotes' => qq
	{
		UPDATE Person_Referral_Note 
		SET referral_notes_status = 5
		where user_id = :1
		and person_id = :2
	},

	'copyReferral' => qq
	{
		insert into Person_Referral (
			REQUEST_DATE,
			REFERRAL_URGENCY,
			USER_ID,
			PERSON_ID,
			REQUESTER_ID,
			PRODUCT_INTERNAL_ID,
			INS_ORG_INTERNAL_ID,
			CODE,
			CODE_TYPE,
			REL_DIAGS,
			PROVIDER_ID,
			SPECIALITY ,
			REFERRAL_TYPE,
			ALLOWED_VISITS,
			AUTH_NUMBER,
			REFERRAL_BEGIN_DATE,
			REFERRAL_END_DATE,
			COMMUNICATION,
			COMPLETION_DATE,
			RECHECK_DATE,
			REFERRAL_STATUS,
			REFERRAL_STATUS_DATE,
			REFERRAL_REASON,
			COMMENTS     
			)
		select
			REQUEST_DATE,
			REFERRAL_URGENCY,
			:3,
			PERSON_ID,
			REQUESTER_ID,
			PRODUCT_INTERNAL_ID,
			INS_ORG_INTERNAL_ID,
			CODE,
			CODE_TYPE,
			REL_DIAGS,
			PROVIDER_ID,
			SPECIALITY ,
			REFERRAL_TYPE,
			ALLOWED_VISITS,
			AUTH_NUMBER,
			REFERRAL_BEGIN_DATE,
			REFERRAL_END_DATE,
			COMMUNICATION,
			COMPLETION_DATE,
			RECHECK_DATE,
			REFERRAL_STATUS,
			REFERRAL_STATUS_DATE,
			REFERRAL_REASON,
			COMMENTS     
		FROM Person_Referral
		WHERE
			referral_id = :1
			AND user_id = :2
	},

	'transferReferral' => qq
	{
		UPDATE Person_Referral
		SET referral_status = 2,
		referral_status_date = sysdate
		where referral_id = :1
	}

);

1;
