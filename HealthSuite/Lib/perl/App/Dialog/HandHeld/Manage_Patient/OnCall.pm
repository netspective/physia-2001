##############################################################################
package App::Dialog::HandHeld::Manage_Patient::OnCall;
##############################################################################

use strict;
use SDE::CVS ('$Id: OnCall.pm,v 1.1 2001-01-30 17:41:10 thai_nguyen Exp $', '$Name:  $');
use App::Dialog::Transaction::OnCall;

use vars qw($INSTANCE);

$INSTANCE = new App::Dialog::Transaction::OnCall();
$INSTANCE->heading("On Call Notes");

1;
