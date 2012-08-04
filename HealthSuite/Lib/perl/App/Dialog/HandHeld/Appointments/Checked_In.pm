##############################################################################
package App::Dialog::HandHeld::Appointments::Checked_In;
#package App::Dialog::HandHeld::Appointments::Checked-In;
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
	my $self = App::Dialog::HandHeld::Appointments::All::new(@_, id => 'checkedinappts', heading => 'Checked-In');
	$self->{sqlStmtId} = 'sel_inProgressAppts';
	return $self;
}

$INSTANCE = new __PACKAGE__;

1;
