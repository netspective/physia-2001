##############################################################################
package App::Page::Person::Chart;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use App::Configuration;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person/chart' => {},
	);


sub prepare_view
{
	my ($self) = @_;

	$self->addLocatorLinks(['Chart', 'chart']);

	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stp-person.alerts#<br>
					#component.stp-person.activeMedications#<br>
					#component.stp-person.patientAppointments#</BR>
					#component.stp-person.appointmentCount#</BR>
					#component.stp-person.hospitalizationSurgeriesTherapies#<BR>
					#component.stp-person.activeProblems#<BR>
					#component.stp-person.surgicalProcedures#<BR>
					#component.stp-person.testsAndMeasurements#<BR>
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.careProviders#<BR>
					#component.stpt-person.bloodType#<BR>
					#component.stpt-person.allergies#<BR>
					#component.stpt-person.preventiveCare#<BR>
					#component.stpt-person.advancedDirectives#<BR>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.insurance#<BR>
					#component.stpt-person.diagnosisSummary#
					</font>
				</TD>
			</TR>
		</TABLE>
	});
}


sub handleARL
{
	my $self = shift;
	my ($arl, $params, $rsrc, $pathItems) = @_;

	# DEMO SPECIAL CONDITION
	if($self->param('person_id') eq 'SZSMTIH' && $CONFDATA_SERVER->name_Group() eq App::Configuration::CONFIGGROUP_DEMO)
	{
		$self->redirect('/temp/EMRsummary/index.html');
		return 0;
	}
	return $self->SUPER::handleARL(@_);
}
