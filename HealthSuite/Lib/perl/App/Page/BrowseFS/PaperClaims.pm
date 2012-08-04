##############################################################################
package App::Page::BrowseFS::PaperClaims;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::BrowseFS);
%RESOURCE_MAP = (
	'paperclaims' => {},
);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->setBrowseInfo(
		heading => 'Paper Claims',
		rootFS => $CONFDATA_SERVER->path_PaperClaims(), 
		rootURL => '/paperclaims',
		rootURLCaption => 'Paper Claims',
		rootHeading => 'Paper Claims',
		flags => App::Component::Navigate::FileSys::NAVGPATHFLAG_REVERSESORT,
	);
}

1;
