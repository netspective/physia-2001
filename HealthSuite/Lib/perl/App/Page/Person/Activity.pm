##############################################################################
package App::Page::Person::Activity;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/activity' => {},
	);


sub prepare_view
{
	my ($self, $flags, $colors, $fonts, $viewParamValue) = @_;

	$self->addLocatorLinks(['Activity', 'activity']);
	$self->addContent(" ", $self->param('errorcode'), " -- NOT YET IMPLEMENTED.");

	my $personId = $self->param('person_id');

	#$self->addHeaderPane(new App::Pane::Person::Encounters(style => App::Pane::PANESTYLE_PAGE, mode => App::Pane::PANEMODE_VIEW, dataStyle => $App::Pane::DATASTYLE_SUMMARY, personId => $personId));

	return 1;
}
