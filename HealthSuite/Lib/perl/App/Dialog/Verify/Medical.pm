##############################################################################
package App::Dialog::Verify::Medical;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;
use App::Statements::Component::Scheduling;

use base 'CGI::Dialog';

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'medical' => { 
			_arl => ['event_id', 'person_id'], 
		},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'template', heading => 'Verify Medical Records');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'event_id'),
		
		new App::Dialog::Field::Person::ID(caption => 'Patient ID',
			name => 'person_id',
			size => 25,
			options => FLDFLAG_READONLY,
		),
		new App::Dialog::Field::Person::ID(caption => 'Verified By',
			name => 'med_verified_by',
			types => ['Staff', 'Physician'],
			size => 20,
			useShortForm => 1,
			options => FLDFLAG_REQUIRED,
		),
		new App::Dialog::Field::Scheduling::Date(caption => 'Verify Date',
			name => 'med_verify_date',
			type => 'date',
			futureOnly => 0,
			options => FLDFLAG_REQUIRED,
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons());
	
	$self->{activityLog} =
	{
		scope =>'event',
		key => "#field.person_id#",
		data => "medical records 'Event #field.event_id#' <a href='/person/#field.person_id#/profile'>#field.person_id#</a>"
	};
	
	return $self;
}

###############################
# getSupplementaryHtml
###############################

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	if(my $personId = $page->field('person_id'))
	{
		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_TOP,
			qq{
				<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
					<TR VALIGN=TOP>
						<TD>
							#component.stpt-person.contactMethodsAndAddresses#<BR>						
							<font size=1 face=arial>
							<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
								<TR VALIGN=TOP>
									<TD>#component.stpt-person.alerts#</TD>
									<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
									<TD>#component.stpt-person.activeMedications#</TD>
								</TR>
							</TABLE><BR>
							<font size=1 face=arial>

							#component.stpt-person.diagnosisSummary#<BR>
							#component.stpt-person.hospitalizationSurgeriesTherapies#<BR>
							#component.stpt-person.surgicalProcedures#<BR>
							#component.stpt-person.testsAndMeasurements#
							</font>
						</TD>
						<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD>
							<font size=1 face=arial>
							#component.stpt-person.activeProblems#<BR>
							#component.stpt-person.careProviders#<BR>
							#component.stpt-person.allergies#<BR>
							#component.stpt-person.preventiveCare#<BR>
							#component.stpt-person.advancedDirectives#<BR>

							#component.stpt-person.insurance#<BR>
							</font>
						</TD>
					</TR>
				</TABLE>
			}
		);
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	my $eventId = $page->param('event_id');
	
	$page->field('event_id', $eventId);
	$page->field('person_id', $page->param('person_id'));
	$page->field('med_verified_by', $page->session('user_id'));
	
	$page->param('_verified_', $STMTMGR_COMPONENT_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
		'sel_populateMedVerifyDialog', $eventId));
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $eventId = $page->field('event_id');
	
 	$page->schemaAction(
		'Sch_Verify', $page->param('_verified_') ? 'update' : 'add',
		event_id => $eventId,
		person_id => $page->field('person_id') || undef,
		med_verified_by => $page->field('med_verified_by'),
		med_verify_date => $page->field('med_verify_date'),
		owner_org_id => $page->session('org_internal_id'),
	);
	
	my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

	my $itemId = $eventAttribute->{item_id};
	my $verifyFlags = $eventAttribute->{value_intb};
	$verifyFlags |= App::Component::WorkList::PatientFlow::VERIFYFLAG_MEDICAL;
		
	$page->schemaAction(
		'Event_Attribute', 'update',
		item_id => $itemId,
		value_intB => $verifyFlags,
	);
	
	$self->handlePostExecute($page, $command, $flags);
}

1;