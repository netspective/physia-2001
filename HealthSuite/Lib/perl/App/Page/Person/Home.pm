##############################################################################
package App::Page::Person::Home;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use CGI::ImageManager;
use Date::Manip;
use App::Configuration;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/home' => {},
	);


sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
	}

	if (my $date = $pathItems->[2])
	{
		$date =~ s/\-/\//g;
		$self->param('_date', $date);
	}

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

sub prepare_view
{
	my ($self) = @_;
	my $categories = $self->session('categories');

	$self->param('_date', UnixDate('today', '%m/%d/%Y')) unless $self->param('_date');

	my $pageHome;

	if (grep {$_ eq 'Physician'} @$categories)
	{
		$pageHome = qq {
			<SCRIPT SRC='/lib/calendar.js'></SCRIPT>
			<SCRIPT>
				function updatePage(selectedDate)
				{
					var dashDate = selectedDate.replace(/\\//g, "-");
					parent.location = '/person/' + document.all.person_id.value + '/home/' + dashDate;
				}
			</SCRIPT>
			<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					#component.stp-person.scheduleAppts#</BR>
					#component.stp-person.inPatient#<BR>
					#component.stp-person.bookmarks#<BR>
					#component.news-health#<BR>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.messageCounts#<BR>
					#component.lookup-records#<BR>
					#component.news-top#<BR>
				</TD>
			</TR>
			</TABLE>
		};
	}
	else
	{
		$pageHome = qq {
		<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
				<TR VALIGN=TOP>
				<TD>
					#component.stp-person.messageCounts#<BR>
					#component.lookup-records#<BR>
					#component.navigate-reports-root#<BR>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.sessionPhysicians#<BR>
					#component.stp-person.myAssociatedResourceAppointments#<BR>
					#component.stp-person.myAssociatedResourceInPatients#<BR>
					#component.stp-person.mySessionActivity#
			</TD>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.create-records#<BR>
					#component.news-top#<BR>
					#component.news-health#<BR>
					#component.stp-person.bookmarks#<BR>
				</TD>
			</TR>
		</TABLE>
		};
	}
	$self->addContent($pageHome);
}

1;
