##############################################################################
package App::Page::BrowseFS::EDI;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::BrowseFS);
%RESOURCE_MAP = (
	'edi' => {},
	);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->setBrowseInfo(
		heading => 'Per-Se EDI Reports',
		rootFS => $CONFDATA_SERVER->path_PerSeEDIErrors(), 
		rootURL => '/edi',
		rootURLCaption => 'EDI',
		rootHeading => 'EDI Data',
		flags => App::Component::Navigate::FileSys::NAVGPATHFLAG_REVERSESORT,
	);
}

1;
