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
		),
		new App::Dialog::Field::Organization::ID(caption => 'Organization ID',
			name => 'org_id',
			options => FLDFLAG_REQUIRED,
		),
		
		new CGI::Dialog::Field(caption => 'Old Password',
			name => 'old_password',
			type => 'password',
			options => FLDFLAG_REQUIRED,
			invisibleWhen => (CGI::Dialog::DLGFLAG_REMOVE | CGI::Dialog::DLGFLAG_ADD),
		),
		new CGI::Dialog::Field(caption => 'Password',
			name => 'password',		
			type => 'password',
			options => FLDFLAG_REQUIRED,
			onBlurJS => qq{confirmPassword(this.form)},
		),
		new CGI::Dialog::Field(caption => 'Confirm Password',
			name => 'confirm_password',		
			type => 'password',
			options => FLDFLAG_REQUIRED,
			onBlurJS => qq{confirmPassword(this.form)},
		),							

		new CGI::Dialog::Field(caption => 'Max Sessions',
			type => 'integer',
			options => FLDFLAG_REQUIRED,
			defaultValue => '1',
			hints => 'The max. number of simultaneous logins',
			readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE,
			name => 'quantity'
		),

		new CGI::Dialog::Field(type => 'hidden', name => 'have_password'),	
		new CGI::Dialog::Field(type => 'hidden', name => 'verify_old_password'),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	
	my $personId = $page->param('person_id');
	my $orgId    = $page->param('org_id');
	
	my $existing = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selLoginOrg', $personId, $orgId);
	if ($existing->{person_id})
	{
		$self->updateFieldFlags('person_id', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('org_id', FLDFLAG_READONLY, 1);
		
		$page->property('have_password', 1);
		$page->property('verify_old_password', $existing->{password});
		$page->property('quantity', $existing->{quantity});
	}
	else
	{
		$self->updateFieldFlags('old_password', FLDFLAG_INVISIBLE, 1);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	my $orgId = $page->param('org_id');

	#my $data = $STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selLoginOrg', $personId, $orgId);
	
	$page->field('person_id', $page->param('person_id')) unless $page->field('person_id');
	$page->field('org_id', $page->param('org_id')) unless $page->field('org_id');
	$page->field('quantity', $page->property('quantity'));
	
	$page->field('have_password', $page->property('have_password') || 0);
	$page->field('verify_old_password', $page->property('verify_old_password'));
}

sub customValidate
{
	my ($self, $page) = @_;
	
	unless ($page->field('verify_old_password') eq $page->field('old_password'))
	{
		my $oldPwField = $self->getField('old_password');
		$oldPwField->invalidate($page, qq{Old Password is incorrect.  Please re-enter.});
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $orgId    = $page->field('org_id');
	my $password = $page->field('password');
	my $quantity = $page->field('quantity');
	
	if ($page->field('have_password'))
	{
		$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updPersonLogin', 
			$password, $quantity, $personId, $orgId);
	}
	else
	{
		$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'insPersonLogin', 
			$page->session('_session_id'), $page->session('user_id'), $page->session('org_id'), $personId, $orgId, $password, $quantity);
	}

	$page->param('_dialogreturnurl', "/org/@{[$page->param('org_id')]}/personnel");
	$self->handlePostExecute($page, $command, $flags);
	#return "\u$command completed.";
}

1;
