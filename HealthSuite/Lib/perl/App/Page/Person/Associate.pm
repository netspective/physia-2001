##############################################################################
package App::Page::Person::Associate;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/associate' => {},
	);


sub prepare_view
{
	my ($self, $flags, $colors, $fonts, $viewParamValue) = @_;
	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
				<font size=1 face=arial>
				#component.stp-person.attendance#<BR>
				#component.stp-person.billinginfo#<BR>
				#component.stp-person.certification#<BR>
				#component.stp-person.affiliations#<BR>
				#component.stp-person.benefits#<BR>
				</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
				<font size=1 face=arial>
				#component.stpt-person.feeschedules#<BR>
				#component.stpt-person.associatedSessionPhysicians#<BR>
				</font>
				</TD>
			</TR>
		</TABLE>
	});
}
