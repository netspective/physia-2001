##############################################################################
package App::Dialog::LoginType;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use vars qw(@ISA);

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'loginType', heading => 'Change the Login Type', );

	$self->addContent(

		new CGI::Dialog::Field(caption => 'Login Type',
					name => 'login_type'
					),

	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}



sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	my $loginType = $page->field('login_type');
	$page->session('loginType', $loginType);

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

}



1;
