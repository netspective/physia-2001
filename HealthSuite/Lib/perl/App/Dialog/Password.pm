##############################################################################
package App::Dialog::Password;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;

use App::Universal;
use vars qw(@ISA);
@ISA = qw(CGI::Dialog);


sub initialize
{
	my $self = shift;

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Person ID',
							name => 'person_id',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new App::Dialog::Field::Organization::ID(caption => 'Organization ID',
							name => 'org_id',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
		new CGI::Dialog::Field(caption => 'Password',
							type => 'password',
							options => FLDFLAG_REQUIRED,
							invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE,
							name => 'password'),
		new CGI::Dialog::Field(caption => 'Max Sessions',
							type => 'integer',
							options => FLDFLAG_REQUIRED,
							defaultValue => '1',
							hints => 'The max. number of simultaneous logins',
							readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
							name => 'quantity'),
		new CGI::Dialog::Field(caption => 'Delete record?',
							type => 'bool',
							name => 'delete_record',
							style => 'check',
							invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
							readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	if($command eq 'remove')
	{
		$page->field('delete_record', 1);
	}

}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	$page->schemaAction(
			'Person_Login', $command,
			person_id => $page->field('person_id') || undef,
			org_id => $page->field('org_id') || undef,
			password => $page->field('password') || undef,
			quantity => $page->field('quantity') || undef,
			_debug => 1
	);

	$self->handlePostExecute($page, $command, $flags);
	return '';
}

1;
