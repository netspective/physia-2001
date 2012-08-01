##############################################################################
package Org::ACS::Page::Person;
##############################################################################

use strict;
use App::Page::Person;

use App::Configuration;
use vars qw(@ISA);

@ISA = qw(App::Page::Person);

sub prepare_page_content_header
{
	my $self = shift;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	# we don't want to have "normal" PPMS headers
	$self->{page_heading} = $self->property('person_simple_name');
	$self->{page_menu_sibling} = [];

	App::Page::prepare_page_content_header($self, @_);
	return 1;
}

sub prepare_view_profile
{
	my ($self) = @_;

	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.patientInfo#<BR>
					#component.stpt-person.employmentAssociations#<BR>
					#component.stpt-person.miscNotes#<BR>
					<!--
					#component.stpt-person.officeLocation#
					#component.stpt-person.phoneMessage#<BR>
					#component.stpt-person.insurance#<BR>
					#component.stpt-person.careProviders#<BR>
					#component.stpt-person.emergencyAssociations#<BR>
					#component.stpt-person.familyAssociations#<BR>
					#component.stpt-person.additionalData#
					#component.stpt-person.diagnosisSummary#<BR>
					#component.stpt-person.feeschedules#<BR>
					-->
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.referralAndIntake#<BR>
					#component.stpt-person.referralAndIntakeCount#<BR>
					<!--
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
						<TR VALIGN=TOP>
							<TD>#component.stp-person.alerts#</TD>
							<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
							<TD>#component.stp-person.activeMedications#</TD>
						</TR>
					</TABLE><BR>
					#component.stp-person.refillRequest#<BR>
					#component.stp-person.hospitalizationSurgeriesTherapies#<BR>
					#component.stp-person.activeProblems#<BR>
					#component.stp-person.authorization#<BR>
						<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
							<TR VALIGN=TOP>
								<TD>#component.stp-person.attendance#</TD>
								<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
								<TD>#component.stp-person.certification#</TD>
							</TR>
						</TABLE><BR>
					#component.stp-person.affiliations#<BR>
					#component.stp-person.associatedSessionPhysicians#<BR>
					#component.stp-person.benefits#</BR>
					</font>
					-->
				</TD>
				<!--
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<font size=1 face=arial>
					#component.st-person.diagnosisSummary#<BR>
					</font>
				</TD>
				<TD WIDTH=25%>
					<font size=1 face=arial>
					#component.stpt-person.allergies#<BR>
					#component.stpt-person.preventiveCare#<BR>
					#component.stpt-person.advancedDirectives#<BR>
					</font>
				</TD>
				-->
			</TR>
		</TABLE>
	});
}

1;
