##############################################################################
package App::Page::WorkList;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use App::ImageManager;
use Devel::ChangeLog;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Page;
use App::Statements::Search::Appointment;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);


sub prepare_view_default
{
	my ($self) = @_;

	$self->addContent(qq{
		<P><FONT SIZE=+1>
		<A HREF='/worklist/patientflow'>Patient Flow Worksheet</A><BR>
		<A HREF='/worklist/collection'>Collection Worksheet</A><BR>
		</FONT></P>
	});

	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		['WorkList', '/worklist'],
	);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('worklist_type', $pathItems->[0]) unless $self->param('worklist_type');
	$self->param('_pm_view', $pathItems->[1]);

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		if (my $handleMethod = $self->can("handleARL_" . $self->param('worklist_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->printContents();
	return 0;
}


sub getContentHandlers
{
	return ('prepare_view_$_pm_view=default$');
}


1;
