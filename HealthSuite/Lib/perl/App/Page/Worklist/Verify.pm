##############################################################################
package App::Page::Worklist::Verify;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use App::ImageManager;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Page;
use App::Statements::Search::Appointment;

use App::Dialog::WorklistSetup;

use base qw{App::Page::WorkList};

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'worklist/insverify' => {
		_views => [
			{caption => '#session.decodedDate#', name => 'date',},
			{caption => 'Recent Activity', name => 'recentActivity',},
			{caption => 'Setup', name => 'setup',},
			],
		_title => 'Insurance Verification Work List',
		_iconSmall => 'images/page-icons/worklist-verification',
		_iconMedium => 'images/page-icons/worklist-verification',
		_iconLarge => 'images/page-icons/worklist-verification',
		},
	);

my $baseArl = '/worklist/insverify';

sub prepare_view_date
{
	my ($self) = @_;

	$self->param('person_id', $self->session('user_id'));

	$self->addContent(qq{<center>
		<TABLE BORDER=0 CELLSPACING=1 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD colspan=5>
					#component.worklist-verify#
				</TD>
			</TR>
		</TABLE>
		</center>
	});

	return 1;
}

sub prepare_view_recentActivity
{
	my ($self) = @_;

	$self->addContent(qq{<br>
		<TABLE BORDER=0 CELLSPACING=1 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					#component.stp-person.mySessionViewCount#<BR>
					#component.stp-person.recentlyVisitedPatients#<BR>
				</TD>
				<TD>
					&nbsp;
				</TD>
				<TD colspan=3>
					#component.stp-person.mySessionActivity# <br>
				</TD>
			</TR>
		</TABLE>
	});

	return 1;
}

sub prepare_view_setup
{
	my ($self) = @_;

	my $dialog = new App::Dialog::WorklistSetup(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	return 1 if $self->param('_pm_view') eq 'setup';
	return 1 if $self->param('_stdAction') eq 'dialog';

	#push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'apptslot'));
	$self->SUPER::prepare_page_content_footer(@_);

	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;

	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	$self->SUPER::prepare_page_content_header(@_);

	return 1 if $self->param('_stdAction') eq 'dialog';
	push(@{$self->{page_content_header}}, $self->getControlBarHtml()) unless ($self->param('noControlBar'));
	return 1;
}


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		['Insurance Verifications', $baseArl],
	);

	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		#unless($self->hasPermission("page/worklist/patientflow/$activeView"))
		unless($self->hasPermission("page$baseArl"))
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information.
						Permission page$baseArl is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	#return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('person_id', $self->session('person_id')) unless $self->param('person_id');

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'date');
		$self->param('noControlBar', 1);

		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->param('_dialogreturnurl', $baseArl);
	$self->printContents();
	return 0;
}

sub handleARL_date
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	if (defined $pathItems->[2])
	{
		$pathItems->[2] =~ s/\-/\//g;
		$self->param('_seldate', $pathItems->[2]);
	}

	$self->param('noControlBar', 0);
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=date$');
}

sub getJavascripts
{
	my ($self) = @_;

	return qq{

		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>

		<SCRIPT>
			function updatePage(selectedDate)
			{
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = '$baseArl/date/' + dashDate;
			}
		</SCRIPT>
	};
}

1;
