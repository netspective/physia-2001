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


sub prepare_view
{
	my ($self) = @_;
	#######################################################
	#DEMO CODE
	my $categories = $self->session('categories');
	my $selectedDate = 'today' ;
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');
	$self->param('timeDate',$fmtDate);
	#DEMO CODE
	#######################################################
	my $pageHome;
	#If user is a Physician and the user id is TSAMO then show Physicianm home page
	#Currently this is only for DEMO
	if ($CONFDATA_SERVER->name_Group() eq App::Configuration::CONFIGGROUP_DEMO && grep {$_ eq 'Physician'} @$categories  )
	{
		$pageHome = qq {
        	<SCRIPT SRC='/lib/calendar.js'></SCRIPT>
        	<SCRIPT>
			function updatePage(selectedDate)
			{
				alert('TEST');
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = './' + dashDate;
			}
			</SCRIPT>
			<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
			<TR VALIGN=TOP>
			 <TD>
					#component.stp-person.scheduleAppts#</BR>
					#component.stp-person.inPatient#<BR>
					#component.lookup-records#<BR>

			</TD>
			<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
			<TD>
				   #component.stpt-person.docSign#<BR>
				   #component.stpt-person.docPhone#<BR>
				   #component.stpt-person.docRefill#<BR>
				   #component.stpt-person.docResults#<BR>
			</TD>
			<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
			<TD>
				   #component.stp-person.linkMedicalSite#<BR>
				   #component.stp-person.linkNonMedicalSite#<BR>
				   #component.news-top#<BR>
				   #component.news-health#<BR>
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
					#component.lookup-records#<BR>
					#component.navigate-reports-root#<BR>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.associatedSessionPhysicians#<BR>
					#component.stp-person.myAssociatedResourceAppointments#<BR>
					#component.stp-person.myAssociatedResourceInPatients#<BR>
					#component.stp-person.mySessionActivity#
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.create-records#<BR>
					#component.news-top#<BR>
					#component.news-health#
				</TD>
			</TR>
		</TABLE>
		};
	}
	$self->addContent($pageHome);
}

1;
