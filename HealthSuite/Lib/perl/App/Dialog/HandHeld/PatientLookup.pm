##############################################################################
package App::Dialog::HandHeld::PatientLookup;
##############################################################################

use strict;
use SDE::CVS ('$Id: PatientLookup.pm,v 1.1 2000-12-28 22:47:31 thai_nguyen Exp $', '$Name:  $');

use App::Dialog::PatientLookup;

use vars qw($INSTANCE);

$INSTANCE = new App::Dialog::PatientLookup();
$INSTANCE->heading("Patient Lookup");

1;
