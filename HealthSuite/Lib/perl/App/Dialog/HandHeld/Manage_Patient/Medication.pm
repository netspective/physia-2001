##############################################################################
package App::Dialog::HandHeld::Manage_Patient::Medication;
##############################################################################

use strict;
use SDE::CVS ('$Id: Medication.pm,v 1.2 2000-12-28 23:26:00 thai_nguyen Exp $', '$Name:  $');
use App::Dialog::Medication;

use vars qw($INSTANCE);

$INSTANCE = new App::Dialog::Medication();
$INSTANCE->heading("Prescribe Medication");

sub App::Dialog::Medication::execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $patientId = $page->param('person_id');
	$page->param('_dialogreturnurl', "Manage_Patient?pid=$patientId");
	App::Dialog::Medication::execute_add($self, $page, 'prescribe', $flags);
}

1;
