##############################################################################
package App::Dialog::WorklistSetup::Collection;
##############################################################################

use strict;
use Carp;

use vars qw(%RESOURCE_MAP);
use base qw(App::Dialog::CollectionSetup);

%RESOURCE_MAP = (
	'wl-collection-setup' => {},
);

sub initialize
{
	my $self = shift;

	$self->heading('Collection Worklist Setup');
	$self->SUPER::initialize();

	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	$page->param('itemNamePrefix', 'WorkList-Collection-Setup');
	$page->param('wl_LNameRange', 'WorkListCollectionLNameRange');
	
	$self->SUPER::populateData($page, $command, $activeExecMode, $flags);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	$self->SUPER::execute($page, $command, $flags);
	$self->handlePostExecute($page, $command, $flags, '/worklist/collection');
}

1;
