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
			#readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE
		),
		new App::Dialog::Field::Organization::ID(caption => 'Organization ID',
			name => 'org_id',
			options => FLDFLAG_REQUIRED,
			#readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE
		),
		
		#new CGI::Dialog::Field(caption => 'Old Password',
		#	name => 'old_password',
		#	type => 'password',
		#	options => FLDFLAG_REQUIRED,
		#	invisibleWhen => (CGI::Dialog::DLGFLAG_REMOVE | CGI::Dialog::DLGFLAG_ADD),
		#),
		new CGI::Dialog::Field(caption => 'Password',
			name => 'password',		
			type => 'password',
			options => FLDFLAG_REQUIRED,
			invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE,
		),
		#new CGI::Dialog::Field(caption => 'Confirm Password',
		#	name => 'confirm_password',		
		#	type => 'password',
		#	options => FLDFLAG_REQUIRED,
		#	invisibleWhen => CGI::Dialog::DLGFLAG_REMOVE,
		#),							

		new CGI::Dialog::Field(caption => 'Max Sessions',
			type => 'integer',
			options => FLDFLAG_REQUIRED,
			defaultValue => '1',
			hints => 'The max. number of simultaneous logins',
			readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
			name => 'quantity'
		),
		
		#new CGI::Dialog::Field(caption => 'Delete record?',
		#	type => 'bool',
		#	name => 'delete_record',
		#	style => 'check',
		#	invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
		#	readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE
		#),
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

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	my $orgId = $page->param('org_id');

	my $data = $STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selLoginOrg', $personId, $orgId);
	
	$page->field('person_id', $page->param('person_id')) unless $page->field('person_id');
	$page->field('org_id', $page->param('org_id')) unless $page->field('org_id');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $orgId    = $page->field('org_id');
	my $password = $page->field('password');
	my $quantity = $page->field('quantity');
	
	
	if ($STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selLoginOrg', 
		$personId, $orgId))
	{
		$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updPersonLogin', 
			$password, $quantity, $personId, $orgId);
	}
	else
	{
		$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'insPersonLogin', 
			$page->session('_session_id'), $page->session('user_id'), $personId, $orgId, $password, $quantity);
	}

	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}

1;
