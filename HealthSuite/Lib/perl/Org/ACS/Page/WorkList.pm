##############################################################################
package Org::ACS::Page::WorkList;
##############################################################################

use strict;
use Date::Manip;

use App::Page::WorkList;
use CGI::ImageManager;

use vars qw(@ISA);
@ISA = qw(App::Page::WorkList);

sub prepare_view_default
{
	my $self = shift;
	$self->addContent(qq{
		<p>&nbsp;<p>&nbsp;
		<center>
		<table cellspacing=5 cellpadding=5>
			<tr>
				<td>$IMAGETAGS{'images/page-icons/worklist-patient-flow'}</td>
				<td><font size=4 face=arial><b><a href="/worklist/referral">Service Request Worklist</a></b></font></td>
			</tr>
			<tr>
				<td>$IMAGETAGS{'images/page-icons/worklist-referral'}</td>
				<td><font size=4 face=arial><b><a href="/worklist/referral?user=physician">Referral Followup Worklist</a></b></font></td>
			</tr>
		<table>
		</center>
	});
	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
	}

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
