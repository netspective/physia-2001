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

my $EVENTATTRTYPE_APPOINTMENT = App::Universal::EVENTATTRTYPE_APPOINTMENT;

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
	[
		{ head => 'Time',
			colIdx => 1,
			url => q{javascript: ! isActionPopupWindow() ? chooseEntry('#9#') : window.close()},
			options => PUBLCOLFLAG_DONTWRAP,
		},

		{ head => 'Account / Chart',
			dataFmt => 'Account: #14#<br>Chart: #15#'
		},

		{
			head => 'Details',
			dataFmt => q{<nobr>
				<a href="javascript:chooseItem('/person/#12#/profile')" title='View #12# Profile'
					style='text-decoration:none'>#0# (#12#)</a>
				- #3# </nobr> <BR>
				Home Phone: <b>#5#</b> <BR>
				<i>#6#</i> with
				<a href="javascript:chooseItem('/search/appointment/#2#')"
					title='View #2# Appointments' style='text-decoration:none'>#2#</a>
				at
				<a href="javascript:chooseItem('/search/appointment//#7#')"
					title='View #7# Appointments' style='text-decoration:none'>#7#</a>
				<BR>
				Appt Type: #13#<BR>
				Reason for Visit: <b>#4#</b><BR>
				#8# <br>
				Scheduled by #10# <br>
				on #11#
			}
		},
	],
};

my $APPOINTMENT_COLUMNS = qq
{	patient.simple_name,
	TO_CHAR(event.start_time - ?, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS start_time,
	ea.value_textB AS resource_id,
	aat.caption AS patient_type,
	event.subject,
	pa.value_text as home_phone,
	stat.caption,
	org.org_id,
	event.remarks,
	event.event_id,
	scheduled_by_id,
	TO_CHAR(scheduled_stamp - ?, '$SQLSTMT_DEFAULTSTAMPFORMAT') AS scheduled_stamp,
	patient.person_id AS patient_id,
	at.caption as appt_type,
	(SELECT value_text
		FROM Person_Attribute  pa
		WHERE pa.parent_id = patient.person_id
			AND pa.item_name = 'Patient/Account Number'
	) as account_number,
	(SELECT value_text
		FROM Person_Attribute  pa
		WHERE pa.parent_id = patient.person_id
			AND pa.item_name = 'Patient/Chart Number'
	) as chart_number
};

my $APPOINTMENT_TABLES = qq{
	Person patient,
	Appt_Attendee_Type aat,
	Event_Attribute ea,
	Event,
	Appt_Status stat,
	Org,
	Appt_Type at,
	Person_Attribute pa
};

my $STMTFMT_SEL_APPOINTMENT = qq{
	SELECT *
	FROM (
		SELECT
$APPOINTMENT_COLUMNS
		FROM
$APPOINTMENT_TABLES
		WHERE
			upper(Org.org_id) like upper(?)
			AND Event.facility_id = org.org_internal_id
			AND Event.start_time BETWEEN
				TO_DATE(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				AND TO_DATE(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			AND ea.parent_id = event.event_id
			AND ea.value_type = $EVENTATTRTYPE_APPOINTMENT
			AND patient.person_id = ea.value_text
			AND upper(ea.value_textB) LIKE upper(?)
			AND Event.event_status = stat.id
			AND stat.id BETWEEN ? and ?
			AND aat.id = ea.value_int
			AND Event.owner_id = ?
			AND at.appt_type_id (+) = Event.appt_type
			AND pa.parent_id = patient.person_id (+)
			AND pa.value_type = 10
			AND pa.item_name = 'Home'
		%orderBy%
	)
	WHERE rownum <= $LIMIT
};

my $STMTFMT_SEL_APPOINTMENT_CONFLICT = qq{
	SELECT *
	FROM (
		SELECT
$APPOINTMENT_COLUMNS
		FROM
$APPOINTMENT_TABLES
		WHERE
			event.facility_id = org.org_internal_id
			AND event.parent_id = ?
			AND ea.parent_id = event.event_id
			AND ea.value_type = $EVENTATTRTYPE_APPOINTMENT
			AND patient.person_id = ea.value_text
			AND stat.id = event.event_status
			AND aat.id = ea.value_int
			AND event.owner_id = ?
			AND at.appt_type_id (+) = Event.appt_type
			AND pa.parent_id = patient.person_id (+)
			AND pa.value_type = 10
			AND pa.item_name = 'Home'
		%orderBy%
	)
	WHERE rownum <= $LIMIT
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
		orderBy => 'ORDER BY upper(patient.name_last), upper(patient.name_first), upper(patient.name_middle)',
	},

	'sel_appointment_orderbyAccount' =>
		{
			sqlStmt => $STMTFMT_SEL_APPOINTMENT,
			publishDefn => $STMTRPTDEFN_DEFAULT,
			orderBy => 'ORDER BY upper(account_number)',
	},

	'sel_appointment_orderbyChart' =>
		{
			sqlStmt => $STMTFMT_SEL_APPOINTMENT,
			publishDefn => $STMTRPTDEFN_DEFAULT,
			orderBy => 'ORDER BY upper(chart_number) ',
	},

);

1;
