##############################################################################
package App::Dialog::Encounter::CreateClaim;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Person;
use App::Statements::Insurance;
use App::Statements::Invoice;
use App::Statements::Catalog;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Encounter;
use App::Dialog::Field::Person;
use App::Dialog::Field::Catalog;
use App::Universal;
use App::Utilities::Invoice;
use Text::Abbrev;

use vars qw(@ISA  %PROCENTRYABBREV %RESOURCE_MAP);

%RESOURCE_MAP = (
	'claim' => {
		_arl_add => ['person_id'],
		_arl_modify => ['invoice_id']
		},
	);

use Date::Manip;

use Devel::ChangeLog;

@ISA = qw(App::Dialog::Encounter);

use constant NEXTACTION_ADDPROC => "/invoice/%param.invoice_id%/dialog/procedure/add";
use constant NEXTACTION_CLAIMSUMM => "/invoice/%param.invoice_id%/summary";
use constant NEXTACTION_PATIENTACCT => "/person/%field.attendee_id%/account";
use constant NEXTACTION_POSTPAYMENT => "/invoice/%param.invoice_id%/dialog/postinvoicepayment?paidBy=personal";
use constant NEXTACTION_POSTTRANSFER => "/person/%field.attendee_id%/dlg-add-posttransfer";
use constant NEXTACTION_CREATECLAIM => "/org/#session.org_id#/dlg-add-claim";
use constant NEXTACTION_CREATEHOSPCLAIM => "/org/#session.org_id#/dlg-add-claim?isHosp=1";
use constant NEXTACTION_WORKLIST => "/worklist";

%PROCENTRYABBREV = abbrev qw(place type lab modifier cpt units emergency reference comments);

use vars qw(%ITEMTOFIELDMAP);
%ITEMTOFIELDMAP =
(
	'place' => 'data_num_a',
	'type' => 'data_num_b',
	'lab' => 'item_type',
	'cpt' => 'code',
	'modifier' => 'modifier',
	'units' => 'quantity',
	'emergency' => 'data_text_a',
	'reference' => 'data_text_c',
	'comments' => 'data_text_b'
	#abbreviation => fieldname
);

sub initialize
{
	my $self = shift;

	$self->SUPER::initialize();

	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "claim '#param.invoice_id#' to <a href='/person/#field.attendee_id#/account'>#field.attendee_id#</a>"
	};

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('checkin_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('checkout_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('start_time', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('appt_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('subject', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('remarks', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('subject', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('confirmed_info', FLDFLAG_INVISIBLE, 1);

	#if hosp claim, show hosp orgs, otherwise show service orgs
	if(my $isHosp = $page->param('isHosp'))
	{
		$self->heading('$Command Hospital Claim');
		$self->updateFieldFlags('org_fields', FLDFLAG_INVISIBLE, 1);

		$self->addFooter(new CGI::Dialog::Buttons(
			nextActions_add => [				
				['Add Hospital Claim', NEXTACTION_CREATEHOSPCLAIM],
				['Go to Patient Account', NEXTACTION_PATIENTACCT],
				['Return to Work List', NEXTACTION_WORKLIST],
				],
			cancelUrl => $self->{cancelUrl} || undef));
	}
	else
	{
		$self->heading('$Command Claim');
		$self->updateFieldFlags('hosp_org_fields', FLDFLAG_INVISIBLE, 1);

		$self->addFooter(new CGI::Dialog::Buttons(
			nextActions_add => [
				['Add a Procedure', NEXTACTION_ADDPROC],
				['Go to Claim Summary', NEXTACTION_CLAIMSUMM, 1],
				['Go to Patient Account', NEXTACTION_PATIENTACCT],
				['Post Personal Payment to this Claim', NEXTACTION_POSTPAYMENT],
				['Post Transfer for this Patient', NEXTACTION_POSTTRANSFER],
				['Add Claim', NEXTACTION_CREATECLAIM],
				['Add Hospital Claim', NEXTACTION_CREATEHOSPCLAIM],
				['Return to Work List', NEXTACTION_WORKLIST],
				],
			cancelUrl => $self->{cancelUrl} || undef));
	}

	#turn these fields off if there is no person id
	if($command eq 'add')
	{
		my $personId = $page->param('person_id') || $page->field('attendee_id');
		$personId = uc($personId);
		if($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $personId))
		{
			if($page->field('payer') eq '' || $personId ne $page->field('attendee_id'))
			{
				my $payerField = $self->getField('payer');
				$payerField->invalidate($page, 'Please choose a primary payer for this claim.');
			}
		}
		else
		{
			$self->updateFieldFlags('payer', FLDFLAG_INVISIBLE, 1);
			#$self->updateFieldFlags('deduct_fields', FLDFLAG_INVISIBLE, 1);
			$self->updateFieldFlags('deduct_balance', FLDFLAG_INVISIBLE, 1);
			$self->updateFieldFlags('primary_ins_phone', FLDFLAG_INVISIBLE, 1);
		}
	}

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;
	my $invoiceFlags = $page->field('invoice_flags');
	my $claimType = $page->field('claim_type');
	my $invoiceStatus = $page->field('current_status');

	if($claimType != App::Universal::CLAIMTYPE_SELFPAY && ($invoiceStatus == App::Universal::INVOICESTATUS_ETRANSFERRED || 
		$invoiceStatus == App::Universal::INVOICESTATUS_MTRANSFERRED || $invoiceStatus == App::Universal::INVOICESTATUS_PAPERCLAIMPRINTED) )
	{
		$command = 'add';
		voidInvoice($page, $page->field('old_invoice_id'));
	}

	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
	addHistoryItem($page, $page->param('invoice_id'), value_text => 'Updated');
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	voidInvoice($page, $invoiceId);
	$page->redirect("/invoice/$invoiceId/summary");
}

1;
