##############################################################################
package App::Dialog::PaymentPlan;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::BillingStatement;
use App::Dialog::Field::Organization;

use Date::Manip;

use vars qw(%RESOURCE_MAP);
use base qw(CGI::Dialog);

%RESOURCE_MAP = (
	'payment_plan' => {
		_arl => ['person_id'],
		_modes => ['add', 'update', 'remove', 'setup'],
	},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'payment_plan', heading => '$Command Payment Plan');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new App::Dialog::Field::Person::ID(caption => 'Patient ID',
			name => 'person_id',
			addType => 'patient',
			size => 20,
			useShortForm => 1,
			incSimpleName=>1,
			options => FLDFLAG_REQUIRED,
		),

		new App::Dialog::Field::Scheduling::Date(caption => 'First Payment Due Date',
			name => 'first_due',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::MultiField (
			fields => [
				new CGI::Dialog::Field(caption => 'Balance to Budget',
					name => 'balance',
					type => 'currency',
					hints => 'Leave blank for auto-calculation of balance',
				),
				new CGI::Dialog::Field(caption => 'Auto-Calc Balance',
					name => 'auto_calc',
					type => 'bool', style => 'check',
				),
			],
		),
		new CGI::Dialog::MultiField (
			fields => [
				new CGI::Dialog::Field(caption => 'Payment Amount',
					name => 'payment_min',
					type => 'currency',
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(caption => 'Billing Cycle',
					name => 'payment_cycle',
					type => 'select',
					selOptions => 'Monthly:30; Weekly:7; Bi-Weekly:14',
				),
			],
		),

		new App::Dialog::Field::OrgType(caption => 'Billing Org',
			name => 'billing_org_id',
			types => qq{'PRACTICE'},
			options => FLDFLAG_REQUIRED,
			hints => 'Payments will be sent to Billing Org',
			options => FLDFLAG_PERSIST,
		),

		new CGI::Dialog::Field(caption => 'Invoices',
			name => 'inv_ids',
			style => 'multidual',
			type => 'select',

			multiDualCaptionLeft => 'Invoice ID - Date - Balance',
			multiDualCaptionRight => 'Selected Invoices to Budget',
			size => '10',
			fKeyStmtMgr => $STMTMGR_STATEMENTS,
			fKeyStmt => 'sel_outstandingInvoices',
			fKeyStmtBindFields => ['person_id'],
			fKeyStmtBindSession => ['org_internal_id'],
		),

		new CGI::Dialog::MultiField(name => 'lastpay',
			fields => [
				new CGI::Dialog::Field(caption => 'Last Payment Amount',
					name => 'lastpay_amount',
					type => 'currency',
				),
				new CGI::Dialog::Field(caption => 'Date',
					name => 'lastpay_date',
					type => 'date',
					defaultValue => '',
				),
			],
		),

		new CGI::Dialog::Field(type => 'hidden', name => 'plan_id'),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	$self->{activityLog} =
	{
		scope =>'payment_plan',
		key => "#field.person_id#",
		data => "Payment Plan '#field.plan_id#' for <a href='/person/#field.person_id#/account'>#field.person_id#</a>"
	};

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	$page->param('paymentPlan_exists', $STMTMGR_STATEMENTS->createFieldsFromSingleRow($page, STMTMGRFLAG_CACHE,
		'sel_paymentPlan', $page->param('person_id'), $page->session('org_internal_id'))
	);

	$self->updateFieldFlags('lastpay', FLDFLAG_READONLY, $page->param('paymentPlan_exists'));
	$self->updateFieldFlags('lastpay', FLDFLAG_INVISIBLE, !$page->param('paymentPlan_exists'));
	$self->updateFieldFlags('person_id', FLDFLAG_READONLY, $page->param('paymentPlan_exists'));

	$page->field('person_id', $page->param('person_id'));
	$page->field('inv_ids', split(/\s*,\s*/, $page->field('inv_ids')));
	$page->field('auto_calc', 1) unless $page->param('paymentPlan_exists');
}

sub nextDue
{
	my ($dueDate, $billingCycle) = @_;

	my $nextDue = $billingCycle == 30 ? DateCalc($dueDate, "+ 1 month") :
		DateCalc($dueDate, "+ $billingCycle days");

	return UnixDate($nextDue, '%m/%d/%Y');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	$command = $page->param('paymentPlan_exists') ? 'update' : 'add';

	my $personId = $page->field('person_id');
	my $orgInternalId = $page->session('org_internal_id');
	my $invoiceList = join(',', $page->field('inv_ids'));

	my $balance;
	if ($page->field('auto_calc') && $invoiceList)
	{
		$balance = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			qq{select sum(balance) from Invoice where invoice_id in ($invoiceList) });
	}

	my $planId = $page->schemaAction('Payment_Plan', $command,
		plan_id => $command eq 'update' ? $page->field('plan_id') : undef,
		person_id => $personId,
		owner_org_id => $orgInternalId,
		billing_org_id => $page->field('billing_org_id'),
		payment_cycle => $page->field('payment_cycle'),
		balance => $page->field('balance') || $balance || 0,
		first_due => $page->field('first_due'),
		next_due => nextDue($page->field('first_due'), $page->field('payment_cycle')),
		payment_min => $page->field('payment_min'),
		inv_ids => $invoiceList || undef,
		_debug => 1,
	);

	$page->field('plan_id', $planId) unless $page->field('plan_id');
	$self->handlePostExecute($page, $command, $flags);
}

1;
