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
use constant NEXTACTION_ONHOLD => "/invoice/%param.invoice_id%/dialog/hold";
use constant NEXTACTION_CLAIMSUMM => "/invoice/%param.invoice_id%/summary";
use constant NEXTACTION_PATIENTACCT => "/person/%field.attendee_id%/account";
use constant NEXTACTION_POSTPAYMENT => "/person/%field.attendee_id%/dlg-add-postpersonalpayment";
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

	#$self->heading('$Command Claim');

	$self->SUPER::initialize();

	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "claim '#param.invoice_id#' to <a href='/person/#field.attendee_id#/account'>#field.attendee_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['Add a Procedure', NEXTACTION_ADDPROC],
							['Place this claim on hold', NEXTACTION_ONHOLD],
							['Go to Claim Summary', NEXTACTION_CLAIMSUMM, 1],
							['Go to Patient Account', NEXTACTION_PATIENTACCT],
							['Post Payment for this Patient', NEXTACTION_POSTPAYMENT],
							['Post Transfer for this Patient', NEXTACTION_POSTTRANSFER],
							['Add Claim', NEXTACTION_CREATECLAIM],
							['Add Hospital Claim', NEXTACTION_CREATEHOSPCLAIM],
							['Return to Work List', NEXTACTION_WORKLIST],
							],
						cancelUrl => $self->{cancelUrl} || undef));

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
		$self->heading('Add Hospital Claim');
		$self->updateFieldFlags('org_fields', FLDFLAG_INVISIBLE, 1);
	}
	else
	{
		$self->heading('Add Claim');
		$self->updateFieldFlags('hosp_org_fields', FLDFLAG_INVISIBLE, 1);
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

	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $todaysDate = $page->getDate();
	my $invoiceId = $page->param('invoice_id');
	if($command eq 'update')
	{
	#	$page->schemaAction(
	#		'Invoice_Attribute', 'add',
	#		item_id => $page->field('batch_item_id') || undef,
	#		parent_id => $invoiceId || undef,
	#		item_name => 'Invoice/Edit/Batch ID',
	#		value_type => defined $textValueType ? $textValueType : undef,
	#		value_text => $batchId || undef,
	#		value_date => $page->field('batch_date') || undef,
	#		_debug => 0
	#	);

		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => 'Updated',
			#value_textB => "Edit Batch ID: $batchId",
			value_date => $todaysDate,
			_debug => 0
		);
	}

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
		my $itemId = $item->{item_id};
		my $voidItemType = App::Universal::INVOICEITEMTYPE_VOID;

		next if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;
		next if $itemType == $voidItemType;
		next if $item->{data_text_b} eq 'void';

		my $extCost = 0 - $item->{extended_cost};
		my $itemBalance = $extCost;
		my $emg = $item->{emergency};
		$page->schemaAction(
			'Invoice_Item', 'add',
			parent_item_id => $itemId || undef,
			parent_id => $invoiceId || undef,
			item_type => defined $voidItemType ? $voidItemType : undef,
			service_begin_date => $item->{service_begin_date} || undef,
			service_end_date => $item->{service_end_date} || undef,
			hcfa_service_place => $item->{hcfa_service_place} || undef,
			hcfa_service_type => $item->{hcfa_service_type} || undef,
			modifier => $item->{modifier} || undef,
			quantity => $item->{quantity} || undef,
			emergency => defined $emg ? $emg : undef,
			code => $item->{code} || undef,
			caption => $item->{caption} || undef,
			#comments =>  $item->{} || undef,
			unit_cost => $item->{unit_cost} || undef,
			rel_diags => $item->{rel_diags} || undef,
			data_text_a => $item->{data_text_a} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			#balance => defined $itemBalance ? $itemBalance : undef,
			_debug => 0
		);

		$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId || undef,
			data_text_b => 'void',
			_debug => 0
		);

		$self->handlePostExecute($page, $command, $flags);

	}

	#VOID CLAIM
	#my $totalCost = 0;
	#my $updatedLineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	#foreach my $item (@{$updatedLineItems})
	#{
	#	$totalCost += $item->{extended_cost};
	#}

	#my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	#my $balance = $totalCost + $invoiceInfo->{total_adjust};

	my $invoiceStatus = App::Universal::INVOICESTATUS_VOID;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		#total_cost => defined $totalCost ? $totalCost : undef,
		#balance => defined $balance ? $balance : undef,
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


	#ADD HISTORY ATTRIBUTE
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	$page->schemaAction(
		'Invoice_Attribute', 'add',
		parent_id => $invoiceId,
		item_name => 'Invoice/History/Item',
		value_type => defined $historyValueType ? $historyValueType : undef,
		value_text => 'Voided claim',
		value_date => $todaysDate,
		_debug => 0
	);

	#$page->endUnitWork();
	$page->redirect("/invoice/$invoiceId/summary");
}

1;
