##############################################################################
package App::Dialog::HandHeld::Appointments::Completed;
##############################################################################

use strict;
use Carp;

use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::HandHeld;
use App::Dialog::HandHeld::Appointments::All;
use App::Statements::HandHeld;
use App::Universal;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::HandHeld::Appointments::All);

sub new
{
	my $self = App::Dialog::HandHeld::Appointments::All::new(@_, id => 'completedappts', heading => 'Completed');
	$self->{sqlStmtId} = 'sel_completedAppts';
	return $self;
}

$INSTANCE = new __PACKAGE__;

1;