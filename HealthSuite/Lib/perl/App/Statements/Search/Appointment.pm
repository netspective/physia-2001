##############################################################################
package App::Statements::Search::Appointment;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use vars qw(@ISA @EXPORT $STMTMGR_APPOINTMENT_SEARCH $STMTFMT_SEL_APPOINTMENT
	$STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_APPOINTMENT_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;
my $EVENTATTRTYPE_PATIENT = App::Universal::EVENTATTRTYPE_PATIENT;
my $EVENTATTRTYPE_PHYSICIAN = App::Universal::EVENTATTRTYPE_PHYSICIAN;

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
	[
		{ head => 'Time', 
			colIdx => 1,
			url => q{javascript: document.search_form != null ? chooseEntry('#9#') : ''},
			options => PUBLCOLFLAG_DONTWRAP,
		},

		{ head => 'Chart',
			colIdx => 13,
		},

		{ head => 'Account',
			colIdx => 13,
		},

		{ head => 'Patient', 
			colIdx => 0,
			url => q{javascript:chooseItem('/person/#12#/profile')},
			hint => "View #12# Profile",
			options => PUBLCOLFLAG_DONTWRAP,
		},

		#{ head => 'Appointment',
		#	dataFmt => '#6#',
		#},

		{ head => 'Physician',
			colIdx => 2,
			url => q{javascript:chooseItem('/search/appointment/#2#')},
			hint => "View #2# Appointments",
			#dataFmt => '#2#',
		},

		{ head => 'Facility',
			colIdx => 7,
			url => q{javascript:chooseItem('/search/appointment//#7#')},
			hint => "View #7# Appointments",
			#dataFmt => '#7#',
		},

		#{ head => 'Scheduled By',
		#	dataFmt => '#10#',
		#},

		#{ head => 'Scheduled Date',
		#	dataFmt => '#11#',
		#	options => PUBLCOLFLAG_DONTWRAP,
		#},

		#{
		#	head => 'Details',
		#	dataFmt => q{
		#		<a href='/person/#12#/profile' title='#12# Profile'
		#			style='text-decoration:none'>#0#</a>
		#		(<I>#3#</I>)<BR>
		#		#6# with #2# at #7#<BR>
		#		Appt Type: #5#<BR>
		#		Subject: <b>#4#</b><BR>
		#		#8# <br>
		#		Scheduled by #10# <br>
		#		on #11#
		#	}
		#},
	],
};

my $APPOINTMENT_COLUMNS = 
qq{	patient.simple_name,
		TO_CHAR(event.start_time, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS start_time,
		ep2.value_text AS resource_id,
		aat.caption AS patient_type,
		event.subject,
		et.caption AS event_type,
		stat.caption,
		org.org_id,
		event.remarks,
		event.event_id,
		scheduled_by_id,
		TO_CHAR(scheduled_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS scheduled_stamp,
		patient.person_id AS patient_id,
		'TBD'};

my $APPOINTMENT_TABLES = 
qq{	person patient,
		appt_attendee_type aat,
		event_attribute ep2,
		event_attribute ep1,
		event_type et,
		event,
		appt_status stat,
		org};

my $STMTFMT_SEL_APPOINTMENT = qq{
	SELECT
$APPOINTMENT_COLUMNS
	FROM
$APPOINTMENT_TABLES
	WHERE
		org.org_id like ?
		AND event.facility_id = org.org_internal_id
		AND event.start_time BETWEEN
			TO_DATE(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			AND TO_DATE(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
		AND ep1.parent_id = event.event_id
		AND ep2.parent_id = event.event_id
		AND ep1.value_type = $EVENTATTRTYPE_PATIENT
		AND ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
		AND patient.person_id = ep1.value_text
		AND ep2.value_text LIKE ?
		AND event.event_status = stat.id
		AND stat.id BETWEEN ? and ?
		AND aat.id = ep1.value_int
		AND et.id = event.event_type
		AND event.owner_id = ?
		AND rownum <= $LIMIT
	%orderBy%
};

my $STMTFMT_SEL_APPOINTMENT_CONFLICT = qq{
	SELECT
$APPOINTMENT_COLUMNS
	FROM
$APPOINTMENT_TABLES
	WHERE
		event.facility_id = org.org_internal_id
		AND (event.parent_id = ?)
		AND ep1.parent_id = event.event_id
		AND ep2.parent_id = event.event_id
		AND ep1.value_type = $EVENTATTRTYPE_PATIENT
		AND ep2.value_type = $EVENTATTRTYPE_PHYSICIAN
		AND patient.person_id = ep1.value_text
		AND stat.id = event.event_status
		AND aat.id = ep1.value_int
		AND et.id = event.event_type
		AND event.owner_id = ?
		AND rownum <= $LIMIT
	%orderBy%
};

$STMTMGR_APPOINTMENT_SEARCH = new App::Statements::Search::Appointment(
	'sel_appointment' =>
	{
		sqlStmt => $STMTFMT_SEL_APPOINTMENT,
		publishDefn => $STMTRPTDEFN_DEFAULT,
		orderBy => 'ORDER BY event.start_time, event.event_id',
	},

	'sel_conflict_appointments' =>
	{
		sqlStmt => $STMTFMT_SEL_APPOINTMENT_CONFLICT,
		publishDefn => $STMTRPTDEFN_DEFAULT,
		orderBy => 'ORDER BY event.start_time, event.event_id',
	},

	'sel_appointment_orderbyName' =>
	{
		sqlStmt => $STMTFMT_SEL_APPOINTMENT,
		publishDefn => $STMTRPTDEFN_DEFAULT,
		orderBy => 'ORDER BY patient.name_last, patient.name_first, patient.name_middle',
	},

);

1;
