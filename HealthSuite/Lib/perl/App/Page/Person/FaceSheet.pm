##############################################################################
package App::Page::Person::FaceSheet;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use DBI::StatementManager;
use App::Statements::Worklist::WorklistCollection;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/facesheet' => {},
	);

sub prepare_view
{
	my ($self) = @_;

	my $personId = $self->param('person_id');
	my $accountInfo = $STMTMGR_WORKLIST_COLLECTION->recordExists($self, STMTMGRFLAG_NONE, 'selInColl', $personId) ? '<font color=red>(Account in Collection)</font>' : '';
	my $content = qq{
		<center><h2>Patient Profile Summary</h2></center>

		<p align=right>
			@{[ UnixDate('today', '%g') ]}<br>
			#session.user_id#
		</p>
		<table width=100%>
			<tr valign=top>
				<td>
					<b>#property.person_simple_name#</b> $accountInfo<br>
					Responsible Party: @{[ $self->property('person_responsible') || 'Self' ]}
				</td>
				<td>
					ID: <b>$personId</b><br>
					SSN: #property.person_ssn#
				</td>
				<td align=right>
					DOB: #property.person_date_of_birth#<br>
					Gender: #property.person_gender_caption#
				</td>
			</tr>
		</table>
		<p>
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.officeLocation#
					<p>
					#component.stpt-person.contactMethodsAndAddresses#
					<p>
					#component.stpt-person.insurance#
					<p>
					#component.stpt-person.careProviders#
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stpt-person.employmentAssociations#
					<p>
					#component.stpt-person.emergencyAssociations#
					<p>
					#component.stpt-person.familyAssociations#
					<p>
					#component.stpt-person.accountPanel#
				</TD>
			</TR>
		</TABLE>
	};

	$self->replaceVars(\$content);

	# strip all of the images because we don't want them linked
	#
	$content =~ s!<A.*?><IMG.*action-(add|edit).*?></A>!!g;
	$self->addContent($content);
}
