##############################################################################
package App::Dialog::Training;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;

use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use Date::Manip;

@ISA = qw(CGI::Dialog);

# new - Define fields & next actions
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'training', heading => 'Field Training');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'float', caption => 'Float', name => 'float'),
		new CGI::Dialog::Field(type => 'percentage', caption => 'Percentage', name => 'percentage'),
		new CGI::Dialog::Field(type => 'currency', caption => 'Currency', name => 'currency'),
		new CGI::Dialog::Field(type => 'integer', caption => 'Integer', name => 'integer'),
		new CGI::Dialog::Field(type => 'date', caption => 'Date', name => 'date', options => FLDFLAG_HOME),
		new CGI::Dialog::Field(type => 'time', caption => 'Time', name => 'time', options => FLDFLAG_HOME),
		new CGI::Dialog::Field(type => 'stamp', caption => 'DateTime Stamp', name => 'stamp', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'ssn', caption => 'SSN', name => 'ssn', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'phone', caption => 'Phone', name => 'phone', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'pager', caption => 'Pager', name => 'pager'),
		new CGI::Dialog::Field(type => 'zipcode', caption => 'Zipcode', name => 'zipcode', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'email', caption => 'EMail', name => 'email', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'url', caption => 'URL', name => 'URL'),
	);
	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_add => [
			['Home Page', "/person/#session.person_id#/home", 1],
			['Work List', "/person/#session.person_id#/worklist"],
			],
		cancelUrl => $self->{cancelUrl} || undef));
	return $self;
}


# execute - Post process the dialog input
sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$self->handlePostExecute($page, $command, $flags);
}


# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant TRAINING_DIALOG => 'Dialog/Training';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '04/01/2000', 'RCWJ',
		TRAINING_DIALOG,
		'Created new dialog'],
);

1;

