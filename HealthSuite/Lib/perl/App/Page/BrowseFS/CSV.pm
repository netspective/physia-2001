##############################################################################
package App::Page::BrowseFS::CSV;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(%RESOURCE_MAP);
use base qw(App::Page::BrowseFS);

%RESOURCE_MAP = (
	'csv' => {},
);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	
	my $orgId = $self->session('org_internal_id');

	$self->setBrowseInfo(
		heading => 'Per-Se CSV Files',
		rootFS => "@{[$CONFDATA_SERVER->path_PerSeEDIDataIncoming()]}/reports-delim/$orgId", 
		rootURL => '/csv',
		rootURLCaption => 'CSV',
		rootHeading => 'CSV Files',
		flags => App::Component::Navigate::FileSys::NAVGPATHFLAG_REVERSESORT,
	);
}

1;
