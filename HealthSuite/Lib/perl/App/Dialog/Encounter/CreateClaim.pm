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
use App::InvoiceUtilities;
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
	#$page->beginUnitWork("Unable to add claim");

	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);

	#$page->endUnitWork();
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;
	#$page->beginUnitWork("Unable to update claim");

	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);

	my $todaysDate = $page->getDate();
	my $invoiceId = $page->param('invoice_id');

	#add history item
	addHistoryItem($page, $invoiceId,
		value_text => 'Updated',
		value_date => $todaysDate,
	);


	$self->handlePostExecute($page, $command, $flags);
	#$page->endUnitWork();
}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;
	#$page->beginUnitWork("Unable to void claim");

	my $sessUser = $page->session('user_id');
	my $invoiceId = $page->param('invoice_id');

	my $lineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $item (@{$lineItems})
	{
		my $itemType = $item->{item_type};
		next if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;
		next if $itemType == App::Universal::INVOICEITEMTYPE_VOID;
		next if $item->{data_text_b} eq 'void';

		voidInvoiceItem($page, $invoiceId, $item->{item_id});
	}


	my $invoiceStatus = App::Universal::INVOICESTATUS_VOID;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		_debug => 0
	);


	#CREATE NEW VOID TRANSACTION FOR VOIDED CLAIM
	my $transType = App::Universal::TRANSTYPEACTION_VOID;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	$page->schemaAction(
		'Transaction', 'add',
		parent_trans_id => $page->field('trans_id') || undef,
		parent_event_id => $page->field('parent_event_id') || undef,
		trans_type => defined $transType ? $transType : undef,
		trans_status => defined $transStatus ? $transStatus : undef,
		trans_status_reason => "Claim $invoiceId has been voided by $sessUser",
		_debug => 0
	);


	#ADD HISTORY ITEM
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	addHistoryItem($page, $invoiceId,
		value_text => 'Voided claim',
		value_date => $todaysDate,
	);


	#$page->endUnitWork();
	$page->redirect("/invoice/$invoiceId/summary");
}

1;
