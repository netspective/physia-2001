##############################################################################
package App::Dialog::Appointment;
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
use Devel::ChangeLog;
use App::Dialog::Field::RovingResource;
use App::Dialog::Field::Organization;
use App::Schedule::Utilities;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'appointment', heading => '$Command Appointment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $findAvailSlotHint = qq{
		<a href="javascript:doFindLookup(this.form, document.dialog._f_start_stamp,
			'/lookup/apptslot/'+document.dialog._f_resource_id.value+	','
			+document.dialog._f_facility_id.value+',,'+document.dialog._f_duration.value+'/1', null
			,false, 'width=550,height=500,scrollbars,resizable');">Find Next Available Slot</a>
	};

	my $waitingListHint = qq{
		Select Patient to fill this Appointment Slot. &nbsp
		<a href="javascript:doFindLookup(this.form, document.dialog._f_waiting_patients,
			'/schedule-p/handleWaitingList/' + document.dialog._f_event_id.value)">View Details</a>
	};

	my $physField = new App::Dialog::Field::Person::ID(caption => 'Physician',
		name => 'resource_id',
		types => ['Physician'],
		hints => 'Physician ID or select a Roving Physician',
		options => FLDFLAG_REQUIRED,
		size => 32);
	$physField->clearFlag(FLDFLAG_IDENTIFIER); # because we can have roving resources, too.

	$self->addContent(
		# the following hidden fields are needed in the "execute" phase
		new CGI::Dialog::Field(type => 'hidden', name => 'event_id'),

		new App::Dialog::Field::Person::ID(caption => 'Patient',
			name => 'attendee_id', types => ['Patient'],
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Patient Type',
			type => 'enum',
			enum => 'appt_attendee_type',
			name => 'attendee_type',
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Reason for Visit',
			name => 'subject', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Symptoms',
			type => 'memo', name => 'remarks'),

		new CGI::Dialog::Field::TableColumn(caption => 'Event Type',
			name => 'event_type',
			schema => $schema,
			column => 'Event.event_type', typeRange => '100..199'),

		new CGI::Dialog::Field(caption => 'Appointment Time',
			name => 'start_stamp',
			hints => $findAvailSlotHint,
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Check for Conflicts',
			name => 'conflict_check',
			type => 'bool', style => 'check', value => 1),

		new CGI::Dialog::Field(caption => 'Duration',
			name => 'duration',
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selApptDuration',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			options => FLDFLAG_REQUIRED),

		$physField,

		new App::Dialog::Field::RovingResource(physician_field => '_f_resource_id',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
		),

		new App::Dialog::Field::OrgType(
			caption => 'Facility',
			name => 'facility_id'),

		#new CGI::Dialog::Field(caption => 'Facility',
		#	name => 'facility_id',
		#	fKeyStmtMgr => $STMTMGR_SCHEDULING,
		#	fKeyStmt => 'selFacilityList',
		#	fKeyDisplayCol => 1,
		#	fKeyValueCol => 0,
		#	options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => '$Command Remarks',
		 	type => 'memo', name => 'discard_remarks'),

		new CGI::Dialog::Field(caption => "Rescheduled By",
		 	type => 'select',
			selOptions => 'Patient;Office',
			name => 'rescheduled',
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(
			name => 'waiting_patients',
			caption => 'Waiting List',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 1,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selWaitingPatients',
			fKeyStmtBindFields => ['event_id'],
			hints => $waitingListHint,
		),

	);
	$self->{activityLog} =
	{
		scope =>'event',
		key => "#field.attendee_id#",
		data => "appointment '#field.attendee_id#' <a href='/search/appointment'>#field.attendee_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub setPhysicianFields
{
	my ($self, $page, $command, $flags) = @_;
	my $personId = $page->param('attendee_id') || $page->field('attendee_id');
	my $orgId = $page->session('org_id');
	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPrimaryPhysician', $orgId, $personId);
	my $physicianId = $physicianData->{phy};
	$page->field('resource_id', $physicianId) unless $page->field('resource_id');

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

sub makeStateChanges_cancel
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->updateFieldFlags('attendee_id', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('attendee_type', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('event_type', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('subject', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('remarks', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('start_stamp', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('duration', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('facility_id', FLDFLAG_READONLY, 1);
}

sub makeStateChanges_noshow
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->makeStateChanges_cancel($page, $command, $activeExecMode, $dlgFlags);
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

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $eventId = $page->param('event_id');
	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPopulateAppointmentDialog', $eventId);
}

sub populateData_cancel
{
	populateData_update(@_);
}

sub populateData_remove
{
	populateData_update(@_);
}

sub populateData_noshow
{
	populateData_update(@_);
}

sub populateData_reschedule
{
	populateData_update(@_);
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

sub findConflictEvent
{
	my ($self, $page) = @_;

	my ($startDate, $startTime, $am) = split(/ /, $page->field('start_stamp'));
	my $endDate   = UnixDate(DateCalc($startDate, "+1 day"), "%Y,%m,%d");
	$startDate = UnixDate($startDate, "%Y,%m,%d");

	my $day = Date_to_Days(split(/,/, $startDate));
	my $dayMinutes = $day * 24 * 60;

	my $startMinutes = hhmmAM2minutes("$startTime $am") + $dayMinutes +1;
	my $endMinutes   = $startMinutes + $page->field('duration') -2;
	my $minuteRange  = "$startMinutes-$endMinutes";
	my $apptSlot     = new Set::IntSpan($minuteRange);

	my $events = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'selAppointmentConflictCheck', $startDate, $endDate, $page->field('facility_id'),
			$page->field('resource_id'));

	for my $event (@$events)
	{
		my $day = Date_to_Days(split(/,/, $event->{start_day}));
		my $dayMinutes = $day * 24 * 60;

		my $start_minute = hhmm2minutes($event->{start_minute}) + $dayMinutes;
		my $end_minute = $start_minute + $event->{duration};
		my $minute_range =  $start_minute . "-" . $end_minute;
		my $slot = new Set::IntSpan("$minute_range");

		my $intersect = $apptSlot->intersect($slot);
		unless ($intersect->empty())
		{
			next if ($event->{patient_id} eq $page->field('attendee_id'));
			next if ($event->{parent_id});
			return ($event->{event_id}, $event->{patient_id});
		}
	}
	return (undef, undef);
}

sub handleWaitingList
{
	my ($self, $page, $thisEventId) = @_;

	# See if I'm a parent Event
	my $nextInLineEventID = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE,
		'selNextInLineEventID', $thisEventId);

	if ($nextInLineEventID) # I'm a parent
	{
		if (my $replacementEventId = $page->field('waiting_patients'))
		{
			$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updParentEventToNULL', $replacementEventId);
			$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updSetNewParentEvent', $replacementEventId, $thisEventId);
		}
	}

	# if no longer conflict
	my ($parentEventId, $patientId) = $self->findConflictEvent($page);
	unless($parentEventId)
	{
		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updParentEventToNULL', $thisEventId);
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

use constant APPOINTMENT_DIALOG => 'Dialog/Appointment';
@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/30/1999', 'RK',
		APPOINTMENT_DIALOG,
		'Added the setPhysicianFields subroutine to pop-up the primary physician in the Appointment dialog for a patient. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/12/2000', 'RK',
		APPOINTMENT_DIALOG,
		'Deleted session-activity in execute_add subroutine and added activityLog in the sub new subroutine.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/12/2000', 'RK',
		APPOINTMENT_DIALOG,
		'Added handlePostExecute in sub execute subroutine'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/30/2000', 'TVN',
		APPOINTMENT_DIALOG,
		'Added Roving Physician and updated makeStateChanges function.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'TVN',
		APPOINTMENT_DIALOG,
		'Completed implementation for Roving Resource and corrected makeStateChanges function.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/08/2000', 'TVN',
		APPOINTMENT_DIALOG,
		'Completed Appointment Conflict Check.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/18/2000', 'TVN',
		APPOINTMENT_DIALOG,
		'Completed Appointment Waiting List.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/21/2000', 'MAF',
		APPOINTMENT_DIALOG,
		'Fixed attendee_id so it is set to param(person_id) when adding (see populateData_add).'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '02/24/2000', 'TVN',
		APPOINTMENT_DIALOG,
		'Fine-Tune Appointment Waiting List.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/17/2000', 'RK',
		APPOINTMENT_DIALOG,
		'Replaced fkeyxxx select in the dialog with Sql statement from Statement Manager.'],
);

1;
