##############################################################################
package App::Dialog::Eligibility;
##############################################################################

use strict;
use Carp;

use App::Universal;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Person;
use vars qw(@ISA);
use Date::Manip;
use Date::Calc qw(:all);

use vars qw(@ISA);

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'eligibility', heading => 'Check Eligibility');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Subhead(heading => 'Carrier', name => 'payer_plan_heading'),

		new App::Dialog::Field(caption =>'Carrier',
			name => 'payer_id', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Plan',
			name => 'plan', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Subhead(heading => 'Patient', name => 'patient_heading'),

		new CGI::Dialog::Field(caption => 'Member #',
			name => 'member_id'),

		new CGI::Dialog::Field(caption => 'SSN',
			name => 'ssn'),

		new CGI::Dialog::Field(caption => 'First Name',
			name => 'f_name'),

		new CGI::Dialog::Field(caption => 'Last Name',
			name => 'l_name'),

		new CGI::Dialog::Field(caption => 'Date of Birth',
			name => 'dob'),

		new CGI::Dialog::Subhead(heading => 'Other Details', name => 'other_heading'),

		new CGI::Dialog::Field(caption => 'Date',
			name => 'edate', options => FLDFLAG_REQUIRED),

	);
#	$self->{activityLog} =
#	{
#		scope =>'event',
#		key => "#field.attendee_id#",
#		data => "appointment '#field.attendee_id#' <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a>"
#	};
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}


###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('discard_remarks', FLDFLAG_INVISIBLE, $command =~ m/^(add|update)$/);
	$self->updateFieldFlags('rescheduled', FLDFLAG_INVISIBLE, $command =~ m/^(add|cancel|noshow|update)$/);
	$self->updateFieldFlags('resource_id', FLDFLAG_READONLY, $command =~ m/^(cancel|noshow|update)$/);
	$self->updateFieldFlags('conflict_check', FLDFLAG_INVISIBLE, $command =~ m/^(cancel|noshow)$/);
	$self->updateFieldFlags('roving_physician', FLDFLAG_INVISIBLE, $command =~ m/^(cancel|noshow|update)$/);
	$self->updateFieldFlags('waiting_patients', FLDFLAG_INVISIBLE, $command =~ m/^(add)$/);
}


###############################
# populateData functions
###############################

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $personId = $page->param('person_id');
	my $startStamp = $page->getTimeStamp($page->param('start_stamp'));

	$page->field('attendee_id', $personId);
	$page->field('start_stamp', $startStamp);
	$page->field('resource_id', $page->param('resource_id'));
	$page->field('duration', $page->param('duration'));
	App::Dialog::Appointment::setPhysicianFields($self, $page, $command, $flags);
}


sub customValidate
{
	my ($self, $page) = @_;

	if ($page->field('conflict_check'))
	{
		return unless $page->field('resource_id');
		return unless $page->field('start_stamp');

		my $personId = uc($page->field('attendee_id'));

		$page->param('start_stamp', $page->field('start_stamp'));
		my ($parentEventId, $patientId) = $self->findConflictEvent($page);

		if ($parentEventId)
		{
			unless ($page->field('processConflict'))
			{
				my $startStampField = $self->getField('start_stamp');
				$startStampField->invalidate($page, qq{This time slot is currently booked for $patientId.<br>
				Please select action: <br>
					<input name=_f_whatToDo type=radio value="wl" CHECKED
						onClick="document.dialog._f_whatToDo[0].checked=true"> Place $personId on Waiting List <br>
					<input name=_f_whatToDo type=radio value="db"
						onClick="document.dialog._f_whatToDo[1].checked=true"> Over-Book $personId <br>
					<input name=_f_whatToDo type=radio value="cancel"
						onClick="document.dialog._f_whatToDo[2].checked=true"> Find Another Slot

					<input name=_f_processConflict type=hidden value=1>
					<input name=_f_parent_id type=hidden value="$parentEventId">
				});
			}
		}
		else
		{
			$page->delete('_f_parent_id');
		}
	}
	else
	{
		$page->delete('_f_parent_id');
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $eventId = $page->field('event_id');
	my $timeStamp = $page->getTimeStamp();

	my $parentId = $page->field('parent_id');
	undef $parentId if $page->field('whatToDo') eq 'db';

	if ($page->field('whatToDo') ne 'cancel')
	{
		if ($command eq 'add')
		{
			my $apptID = $page->schemaAction(
				'Event', 'add',
				owner_id => $page->session('org_id') || undef,
				event_type => $page->field('event_type') || undef,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $page->field('start_stamp') || undef,
				duration => $page->field('duration') || undef,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				scheduled_stamp => $timeStamp,
				scheduled_by_id => $page->session('user_id') || undef,
				parent_id => $parentId || undef,
				_debug => 0
			);
			if ($apptID gt 0)
			{
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Patient',
					value_type => App::Universal::EVENTATTRTYPE_PATIENT,
					value_text => $page->field('attendee_id') || undef,
					value_int => $page->field('attendee_type') || 0,
					_debug => 0
					);
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Physician',
					value_type => App::Universal::EVENTATTRTYPE_PHYSICIAN,
					value_text => $page->field('resource_id') || undef,
					_debug => 0
					);
			}
		}
		elsif ($command eq 'update')
		{
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_type => $page->field('event_type') || undef,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $page->field('start_stamp') || undef,
				duration => $page->field('duration') || undef,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				parent_id => $parentId || undef,
				_debug => 0
			);

			$self->handleWaitingList($page, $eventId);
		}
		elsif ($command eq 'noshow' || $command eq 'cancel')
		{
			my $discardType = $command eq 'cancel' ? 0: 1;
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_status => 3,
				discard_type => $discardType,
				discard_by_id => $page->session('user_id') || undef,
				discard_stamp => $timeStamp,
				discard_remarks => $page->field('discard_remarks') || undef,
				_debug => 0
			);

			$self->handleWaitingList($page, $eventId);
		}
		elsif ($command eq 'reschedule')
		{
			#First, update existing appt to discard, then add new appt w/2 property records
			my $discardType = $page->field('rescheduled') eq 'Patient' ? 2 : 3;
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_status => 3,
				remarks => $page->field('remarks') || undef,
				discard_type => $discardType,
				discard_by_id => $page->session('user_id') || undef,
				discard_stamp => $timeStamp,
				discard_remarks => $page->field('discard_remarks') || undef,
				_debug => 0
			);
			my $apptID = $page->schemaAction(
				'Event', 'add',
				owner_id => $page->session('org_id') || undef,
				event_type => $page->field('event_type') || undef,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $page->field('start_stamp') || undef,
				duration => $page->field('duration') || undef,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				scheduled_stamp => $timeStamp,
				scheduled_by_id => $page->session('user_id') || undef,
				parent_id => $parentId || undef,
				_debug => 0
			);
			if ($apptID gt 0)
			{
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Patient',
					value_type => App::Universal::EVENTATTRTYPE_PATIENT,
					value_text => $page->field('attendee_id') || undef,
					value_int => $page->field('attendee_type') || 0,
					_debug => 0
					);
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Physician',
					value_type => App::Universal::EVENTATTRTYPE_PHYSICIAN,
					value_text => $page->field('resource_id') || undef,
					_debug => 0
				);
			}

			$self->handleWaitingList($page, $eventId);
		}
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
