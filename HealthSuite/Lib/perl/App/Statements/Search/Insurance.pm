##############################################################################
package App::Statements::Search::Insurance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use vars qw(@ISA @EXPORT $STMTMGR_INSURANCE_SEARCH $STMTFMT_SEL_INSURANCE $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INSURANCE_SEARCH);

$STMTFMT_SEL_INSURANCE = qq{
			select distinct product_name, group_name, group_number, ins_org_id, plan_name from insurance
			where
				%whereCond%
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'Product Name', url => 'javascript:chooseEntry("#&{?}#")'},
				{ head => 'Group Name' },
				{ head => 'Group Number'},				
				{ head => 'Organization', url => 'javascript:chooseEntry("#&{?}#")'},
				{ head => 'Plan Name', url => 'javascript:chooseEntry("#&{?}#")'},
			],
};

$STMTMGR_INSURANCE_SEARCH = new App::Statements::Search::Insurance(
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(product_name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(product_name) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_groupname' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(group_name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_groupname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(group_name) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_groupnum' => qq{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(group_number) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_groupnum_like' => qq{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(group_number) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insorgid' => qq{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(ins_org_id) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insorgid_like' => qq{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'upper(ins_org_id) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);
@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'RK',
		'Search/Insurance',
		'Updated the select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'RK',
		'Search/Insurance',
		'Created simple reports instead of using createOutput function.'],
);

1;
