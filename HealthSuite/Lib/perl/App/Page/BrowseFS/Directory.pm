##############################################################################
package App::Page::BrowseFS::Directory;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use App::Configuration;
use App::Page::BrowseFS;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::BrowseFS);
%RESOURCE_MAP = (
	'directory' => {},
	);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->setBrowseInfo(
		rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgDirectory(), 'General'), 
		rootURL => '/directory',
		rootURLCaption => 'Directory',
		rootHeading => 'Directories',
		);
}

1;
