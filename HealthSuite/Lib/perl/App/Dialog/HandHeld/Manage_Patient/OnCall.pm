##############################################################################
package App::Dialog::HandHeld::Manage_Patient::OnCall;
##############################################################################

use strict;
use SDE::CVS ('$Id: OnCall.pm,v 1.2 2001-01-31 19:03:28 thai_nguyen Exp $', '$Name:  $');
use App::Dialog::Transaction::OnCall;

use vars qw($INSTANCE);

$INSTANCE = new App::Dialog::Transaction::OnCall();
$INSTANCE->heading("On Call Notes");

sub App::Dialog::Transaction::OnCall::showActivePatient
{
	return 1;
}

1;
