##############################################################################
package App::Statements::Search::Appointment;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;
use App::Universal;

my $EVENTATTRTYPE_PATIENT = App::Universal::EVENTATTRTYPE_PATIENT;
my $EVENTATTRTYPE_PHYSICIAN = App::Universal::EVENTATTRTYPE_PHYSICIAN;

use vars qw(@ISA @EXPORT @CHANGELOG $STMTMGR_APPOINTMENT_SEARCH $STMTFMT_SEL_APPOINTMENT $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_APPOINTMENT_SEARCH);

my $APPOINTMENT_COLUMNS = qq
{ patient.complete_name,
	to_char(event.start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT') as start_time,
	ep2.value_text as resource_id,
	aat.caption as patient_type,
	event.subject,
	et.caption as event_type,
	stat.caption,
	event.facility_id,
	event.remarks,
	event.event_id,
	scheduled_by_id,
	to_char(scheduled_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as scheduled_stamp,
	patient.person_id as patient_id
};

my $STMTFMT_SEL_APPOINTMENT = qq{
	select
		$APPOINTMENT_COLUMNS
	from person patient, appt_attendee_type aat,
		event_attribute ep2, event_attribute ep1,
		event_type et, event, appt_status stat
	where event.facility_id like ?
		and event.start_time between to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
		and ep1.parent_id = event.event_id
		and ep2.parent_id = event.event_id
		and ep1.value_type = $EVENTATTRTYPE_PATIENT
		and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
		and patient.person_id = ep1.value_text
		and ep2.value_text like ?
		and event.event_status = stat.id
		and stat.id between ? and ?
		and aat.id = ep1.value_int
		and et.id = event.event_type
	order by event.start_time, event.event_id
};

my $STMTFMT_SEL_APPOINTMENT_CONFLICT = qq{
	select
		$APPOINTMENT_COLUMNS
	from person patient, appt_attendee_type aat,
		event_attribute ep2, event_attribute ep1,
		event_type et, event, appt_status stat
	where (event.parent_id = ?)
		and ep1.parent_id = event.event_id
		and ep2.parent_id = event.event_id
		and ep1.value_type = $EVENTATTRTYPE_PATIENT
		and ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
		and patient.person_id = ep1.value_text
		and stat.id = event.event_status
		and aat.id = ep1.value_int
		and et.id = event.event_type
	order by event.start_time, event.event_id
};


$STMTRPTDEFN_DEFAULT =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'Appointments',
	#},

	columnDefn =>
	[
		{ head => 'Appointment', colIdx => 1,
			url => 'javascript: document.search_form != null ? chooseEntry("#9#") : ""' },
		{
			head => 'Details',
			dataFmt => q{
				<a href='/person/#12#/profile' title='#12# Profile'
					style='text-decoration:none'>#0#</a>
				(<I>#3#</I>)<BR>
				#6# with #2# at #7#<BR>
				Appt Type: #5#<BR>
				Subject: <b>#4#</b><BR>
				#8# <br>
				Scheduled by #10# <br>
				on #11#
			}
		},
	],
	#rowSepStr => '',
};

$STMTMGR_APPOINTMENT_SEARCH = new App::Statements::Search::Appointment(
	'sel_appointment' =>
	{
		_stmtFmt => $STMTFMT_SEL_APPOINTMENT,
		publishDefn => $STMTRPTDEFN_DEFAULT,
	},

	'sel_conflict_appointments' =>
		{
			_stmtFmt => $STMTFMT_SEL_APPOINTMENT_CONFLICT,
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'MAF',
		'Search/Appointment',
		'Created simple reports instead of using createOutput function.'
	],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '03/19/2000', 'TVN',
		'Search/Appointment',
		'Revised query to use Attribute value_type instead of item_name.'
	],

);

1;
