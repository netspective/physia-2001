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
use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'checkin' => {
		_arl => ['event_id'] 
		},
	);
	
use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Org;
use Date::Manip;
@ISA = qw(App::Dialog::Encounter);

sub initialize
{
	my $self = shift;

	$self->heading('Check-In');

	$self->SUPER::initialize();
	$self->{activityLog} =
			{
				scope =>'person',
				key => "#field.person_id#",
				data => "Checkin <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a> (Appt Time: #field.start_time#)"
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
	$self->updateFieldFlags('checkout_stamp', FLDFLAG_INVISIBLE, 1);
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

	## First, update original event record to checkin status, and any changes
	#my $timeStamp = $page->getTimeStamp();
	
	my $eventId = $page->field('event_id');
	my $returnUrl = $page->field('dupCheckin_returnUrl');
	my ($status, $person, $stamp) = $self->checkEventStatus($page, $eventId);

	if (defined $status)
	{
		return (qq{
			<b style="color:red">This patient has been checked-$status by $person at $stamp.</b>
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
			event_type => $page->field('appt_type') || 100,
			subject => $page->field('subject') || undef,
			duration => $page->field('duration') || 10,
			facility_id => $page->field('service_facility_id'),
			_debug => 0
		) == 0)
		{
			$page->addDebugStmt('Fatal Check-in Error.<br>Event not updated; Transaction not created; Invoice not created; Copay not recorded.');
			return 0;
		}

	# Add Trans and Invoice info
	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
	#$page->endUnitWork();
}

1;