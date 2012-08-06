##############################################################################
package App::Page::BrowseFS::Report;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::BrowseFS);
%RESOURCE_MAP = (
	'report' => {},
	);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->setBrowseInfo(
		rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgReports(), 'General'), 
		rootURL => '/report',
		rootURLCaption => 'Report',
		rootHeading => 'View Reports',
		);
}

1;
