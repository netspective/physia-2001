##############################################################################
package App::Statements::Search::Session;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_SESSION_SEARCH 
	$STMTMGR_SESSIONACTIVITY_SEARCH $STMTFMT_SEL_SESSION $STMTRPTDEFN_DEFAULT);
@ISA = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_SESSION_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_SESSION = qq{
	SELECT
		p.person_id,
		short_sortable_name,
		TO_CHAR(first_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') first_access,
		TO_CHAR(last_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') last_access,
		remote_host,
		remote_addr
	FROM
		person_session ps,
		person p
	WHERE
		(status between ? AND ?)
		AND p.person_id = ps.person_id
		AND	%whereCond%
		AND org_id = ?
		AND rownum <= $LIMIT
};

$STMTRPTDEFN_DEFAULT =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'Session',
	#},
	columnDefn =>
	[
		{ head => 'User ID', url => q{javascript:chooseEntry('#&{?}#')}, },
		{ head => 'Name' },
		{ head => 'Start' },
		{ head => 'Last' },
		{ head => 'Location' },
	],
	#rowSepStr => '',
};


$STMTMGR_SESSION_SEARCH = new App::Statements::Search::Session(
	'sel_status_person' =>
		{
			_stmtFmt => $STMTFMT_SEL_SESSION,
			whereCond => 'ps.person_id = ? ',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_status_person_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SESSION,
			whereCond => 'ps.person_id LIKE ? ',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

1;
