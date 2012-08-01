##############################################################################
package App::Statements::Search::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_ORG_SEARCH $STMTRPTDEFN_DEFAULT
	$STMTFMT_SEL_ORG $STMTFMT_SEL_ORG_CAT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_ORG = qq{
	SELECT *
	FROM (
		SELECT
			DISTINCT o.org_id,
			o.name_primary,
			o.category,
			DECODE(t.group_name, 'other', 'main', t.group_name)
		FROM
			org o,
			org_category cat,
			org_type t
		WHERE
			cat.parent_id = o.org_internal_id
			AND	cat.member_name = t.caption
			AND	cat.member_name = (
				SELECT caption
				FROM org_type
				WHERE id = (
					SELECT MIN(id)
					FROM
						org_type,
						org_category
					WHERE
						parent_id = o.org_internal_id
						AND caption = member_name
				)
			) 
			AND	%whereCond%
			AND (
				owner_org_id IS NULL
				OR owner_org_id = ?
			)
		ORDER BY o.org_id
	)
	WHERE rownum <= $LIMIT
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID', url => q{javascript:chooseEntry('#&{?}#', null, null, '#3#')}, },
				{ head => 'Primary Name' },
				{ head => 'Category'},
			],
};

$STMTMGR_ORG_SEARCH = new App::Statements::Search::Org(
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(o.org_id) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(o.org_id) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_primname' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(o.name_primary) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_primname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(o.name_primary) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_category' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(cat.member_name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_category_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG,
			whereCond => 'UPPER(cat.member_name) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

1;
