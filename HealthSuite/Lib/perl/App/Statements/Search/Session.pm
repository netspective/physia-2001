##############################################################################
package App::Statements::Search::Session;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;

use vars qw(@ISA @EXPORT @CHANGELOG $STMTMGR_SESSION_SEARCH $STMTMGR_SESSIONACTIVITY_SEARCH $STMTFMT_SEL_SESSION $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_SESSION_SEARCH);

$STMTFMT_SEL_SESSION = qq{
			select p.person_id, short_sortable_name, to_char(first_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') first_access, to_char(last_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') last_access, remote_host, remote_addr
			from person_session ps, person p
			where	(status between ? and ?) and
				p.person_id = ps.person_id and
				%whereCond% and
				org_id = ?

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
		{ head => 'User ID', url => 'javascript:chooseEntry("#&{?}#")' },
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
			whereCond => 'ps.person_id like ? ',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);


@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'RK',
		'Search/Session',
		'Updated the Session select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'MAF',
		'Search/Session',
		'Created simple reports instead of using createOutput function.'],
);

1;
