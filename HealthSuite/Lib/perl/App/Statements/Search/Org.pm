##############################################################################
package App::Statements::Search::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

use vars qw(@ISA @EXPORT $STMTMGR_ORG_SEARCH $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG_SEARCH);
use vars qw($STMTFMT_SEL_ORG);

$STMTFMT_SEL_ORG = qq{
			select distinct o.org_id, o.name_primary, o.category
			from org o, org_category cat
			where
				cat.parent_id = o.org_id and
				%whereCond%
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID', url => 'javascript:chooseEntry("#&{?}#")'},
				{ head => 'Primary Name' },
				{ head => 'Category'},
			],
};

$STMTMGR_ORG_SEARCH = new App::Statements::Search::Org(
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(o.org_id) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(o.org_id) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_primname' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(o.name_primary) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_primname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(o.name_primary) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_category' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(cat.member_name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_category_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'upper(cat.member_name) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'RK',
		'Search/Org',
		'Updated the Org select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'RK',
		'Search/Org',
		'Created simple reports instead of using createOutput function.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '03/07/2000', 'RK',
		'Search/Org',
		'Updated the Sql statement to show the org only once even when it has multiple categories.'],
);
1;
