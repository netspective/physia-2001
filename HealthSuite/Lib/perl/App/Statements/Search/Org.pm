##############################################################################
package App::Statements::Search::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use vars qw(@ISA);

use vars qw(@ISA @EXPORT $STMTMGR_ORG_SEARCH $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG_SEARCH);
use vars qw($STMTFMT_SEL_ORG $STMTFMT_SEL_ORG_CAT);

$STMTFMT_SEL_ORG = qq{
			select distinct o.org_id, o.name_primary, o.category, decode(t.group_name, 'other', 'main', t.group_name)
			from org o, org_category cat, org_type t
			where
				cat.parent_id = o.org_id and
				cat.member_name = t.caption and
				cat.member_name = (
					select caption from org_type
					where id = (
						select min(id)
						from org_type, org_category
						where parent_id = o.org_id and caption = member_name
					)
				) and
				%whereCond% and owner_org_id = ?
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID', url => 'javascript:chooseEntry("#&{?}#", null, null, "#3#")'},
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

1;
