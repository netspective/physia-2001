##############################################################################
package App::Page::Person::Summary;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use DBI::StatementManager;
use App::Statements::Person;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/summary' => {
		_idSynonym => ['profile'],
		},
	);

sub prepare_view
{
	my ($self) = @_;

	$self->addLocatorLinks(['Summary', 'summary']);
	my $personId = $self->param('person_id');
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_internal_id'));
	my $category = $personCategories->[0];

	my $careProvider='';
	my $authorization='';
	my $categories = $self->property('person_categories');
	if (grep {uc($_) eq 'PATIENT'} @$categories)
	{
		$careProvider = '#component.stpt-person.careProviders#<BR>' ;
		$authorization = '#component.stp-person.authorization#<BR>';
	}
	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.officeLocation#
					#component.stpt-person.insurance#<BR>
					$careProvider
					#component.stpt-person.employmentAssociations#<BR>
					#component.stpt-person.emergencyAssociations#<BR>
					#component.stpt-person.familyAssociations#<BR>
					#component.stpt-person.personCategory#<BR>
					#component.stpt-person.additionalData#<BR>
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.miscNotes#<BR>
					#component.stp-person.alerts#<BR>
					<!-- #component.stp-person.refillRequest#<BR> -->
					#component.stp-person.phoneMessage#<BR>
					#component.stp-person.patientAppointments#</BR>
					$authorization
					</font>
				</TD>

			</TR>
		</TABLE>
	});
}

1;
