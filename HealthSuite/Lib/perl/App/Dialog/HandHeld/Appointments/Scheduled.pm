##############################################################################
package App::Dialog::HandHeld::Appointments::Scheduled;
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
	my $self = App::Dialog::HandHeld::Appointments::All::new(@_, id => 'scheduledappts', heading => 'Scheduled');
	$self->{sqlStmtId} = 'sel_scheduledAppts';
	return $self;
}

$INSTANCE = new __PACKAGE__;

1;