##############################################################################
package App::Page::Person::Appointment;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/appointment' => {},
	);


sub prepare_view
{
	my $self = shift;
	my $personId = $self->param('person_id');

	my $dialogCmd = 'add';
	my $cancelUrl = "/person/$personId/profile";
	my $dialog = new App::Dialog::Appointment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);
}
