##############################################################################
package App::Dialog::Budget;
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
	'budget' => {},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'budget', heading => 'Payment Plan');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'budget_date_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'budget_balance_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'staff_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'payment_cycle_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'payment_due_date_id'),

		new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'budget_date'),
		new CGI::Dialog::Field(type => 'currency', caption => 'Balance to Budget', name => 'budget_balance'), #defaultValue => ''),
#		new CGI::Dialog::Field(caption => 'Staff ID', name => 'staff_id', defaultValue => ''),
		new App::Dialog::Field::Person::ID(caption => 'Staff ID', name => 'staff_id', options => FLDFLAG_REQUIRED, types => ['Staff']),
		new CGI::Dialog::Field(type => 'select', selOptions => 'Monthly:monthly;Weekly:weekly;Bi-Weekly:biweekky', caption => 'Cycle of Payment', name => 'payment_cycle'),
		new CGI::Dialog::Field(type => 'date', caption => 'First Payment Due Date', name => 'payment_due_date'),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	if(my $staffId = $page->param('person_id'))
	{
		$page->field('staff_id', $staffId);
		$self->setFieldFlags('staff_id', FLDFLAG_READONLY);
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
