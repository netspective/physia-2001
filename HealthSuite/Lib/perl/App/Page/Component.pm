##############################################################################
package App::Page::Component;
##############################################################################

use strict;
use App::Page;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# see if the ARL points to showing a dialog, panel, or some other standard action
	$self->arlHasStdAction($rsrc, $pathItems, 0);
	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;