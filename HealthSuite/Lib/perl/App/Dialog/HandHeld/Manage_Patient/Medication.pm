##############################################################################
package App::Dialog::HandHeld::Manage_Patient::Medication;
##############################################################################

use strict;
use SDE::CVS ('$Id: Medication.pm,v 1.1 2000-12-26 18:51:43 snshah Exp $', '$Name:  $');
use App::Dialog::Medication;

use vars qw($INSTANCE);

$INSTANCE = new App::Dialog::Medication();
$INSTANCE->heading("Prescribe Medication");

1;
