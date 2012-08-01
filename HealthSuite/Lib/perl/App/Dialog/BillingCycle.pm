##############################################################################
package App::Dialog::BillingCycle;
##############################################################################

use strict;
use DBI::StatementManager;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Statements::Person;
use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'billingcycle' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'billingcycle', heading => '$Command Billing Cycle');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		#new CGI::Dialog::Field(type => 'hidden', name => 'budget_date_id'),
		#new CGI::Dialog::Field(type => 'hidden', name => 'budget_balance_id'),

		new CGI::Dialog::Field(type => 'select', selOptions => 'A-F;G-L;M-S;T-Z', caption => 'Patients', name => 'name_range', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'select', selOptions => 'First Week;Second Week;Third Week;Fourth Week', caption => 'Statement Cycle', name => 'period', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'select', selOptions => ';Hold Statement:1;No Statement:2', caption => 'Statement Status', name => 'statement_status', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'Reason', name => 'reason', type => 'memo', cols => 25, rows => 4, options => FLDFLAG_REQUIRED),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	if($page->param('person_id'))
	{
		$self->updateFieldFlags('name_range', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('period', FLDFLAG_INVISIBLE, 1);
		$self->heading('Modify Patient Billing Cycle');
	}
	else
	{
		$self->updateFieldFlags('statement_status', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('reason', FLDFLAG_INVISIBLE, 1);
		$self->heading('Add Billing Cycle');
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

#	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $userId = $page->session('user_id');
	$page->field('staff_id', $userId);

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->param('person_id');

	$page->redirect("/person/$personId/profile");
}

1;
