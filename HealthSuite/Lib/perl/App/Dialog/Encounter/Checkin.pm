##############################################################################
package App::Dialog::Encounter::Checkin;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Encounter;
use App::Dialog::Field::Person;
use App::Universal;
use App::Schedule::Utilities;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'checkin' => {
		_arl => ['event_id']
		},
	);

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Component::Scheduling;
use App::Statements::Org;
use Date::Manip;

use base qw(App::Dialog::Encounter);

sub initialize
{
	my $self = shift;

	$self->heading('Check-In');

	$self->SUPER::initialize();
	$self->{activityLog} =
			{
				scope =>'person',
				key => "#field.person_id#",
				data => qq{Checkin <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a> 
					<br>(Appt Time: #field.start_time#)
				}
	};

	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	# all of the Person::* panes expect a person_id parameter
	# -- we can use field('attendee_id') because it was created in populateData
	if(my $personId = $page->field('attendee_id'))
	{
		$page->param('person_id', $personId);

		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
					#component.stpd-person.contactMethodsAndAddresses#<BR>
					#component.stpd-person.extendedHealthCoverage#<BR>
					#component.stpd-person.accountPanel#<BR>
					#component.stpd-person.careProviders#<BR>
					#component.stpd-person.authorization#<BR>
			});
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$self->updateFieldFlags('batch_fields', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('checkout_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('hosp_org_fields', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('claim_diags', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_heading', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_list', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);

	$page->session('dupCheckin_returnUrl', $page->referer());
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#$page->beginUnitWork("Unable to checkin patient");

	my $eventId = $page->field('parent_event_id') || $page->param('event_id');
	my $returnUrl = $page->field('dupCheckin_returnUrl');
	my ($status, $person, $stamp) = $self->checkEventStatus($page, $eventId);
	
	if (defined $status)
	{
		return (qq{
			<b style="color:red">This patient has been checked-$status by $person on $stamp.</b>
			Click <a href='javascript:location.href="$returnUrl"'>here</a> to go back.
		});
	}
	
	my $eventStatus = App::Universal::EVENTSTATUS_INPROGRESS;
	if ($page->schemaAction(
			'Event', 'update',
			event_id => $eventId || undef,
			event_status => $eventStatus,
			checkin_stamp => $page->field('checkin_stamp'),
			checkin_by_id => $page->session('user_id'),
			remarks => $page->field('remarks') || undef,
			subject => $page->field('subject'),
			facility_id => $page->field('service_facility_id'),
			_debug => 0
		) == 0)
	{
		$page->addDebugStmt('Fatal Check-in Error.<br>Event not updated; Transaction not created; Invoice not created; Copay not recorded.');
		return 0;
	}

	my $confirmed = $page->field('confirmed_info') eq 'Yes' ? 1 : 0;
	
	my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

	my $itemId = $eventAttribute->{item_id};
	my $verifyFlags = $eventAttribute->{value_intb};
	
	$verifyFlags &= ~App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE;
	
	$verifyFlags |= App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE 
		if $confirmed;
		
	$page->schemaAction(
		'Event_Attribute', 'update',
		item_id => $itemId,
		value_intB => $verifyFlags,
	);

	# Add Trans and Invoice info
	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
	#$page->endUnitWork();
}

1;
