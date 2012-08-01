##############################################################################
package App::Page::BrowseFS::NSF;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(%RESOURCE_MAP);
use base qw(App::Page::BrowseFS);

%RESOURCE_MAP = (
	'nsf' => {},
);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	
	my $orgId = $self->session('org_internal_id');

	$self->setBrowseInfo(
		heading => 'Per-Se NSF Files',
		rootFS => "@{[$CONFDATA_SERVER->path_PerSeEDIDataOutgoing()]}/archive/$orgId", 
		rootURL => '/nsf',
		rootURLCaption => 'NSF',
		rootHeading => 'NSF Files',
		flags => App::Component::Navigate::FileSys::NAVGPATHFLAG_REVERSESORT,
	);
}

1;
