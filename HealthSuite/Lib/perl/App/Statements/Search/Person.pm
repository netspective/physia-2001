##############################################################################
package App::Statements::Search::Person;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

use vars qw(@ISA @EXPORT $STMTMGR_PERSON_SEARCH $ITEMNAME_PATH $STMTFMT_SEL_PERSON $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PERSON_SEARCH);

$ITEMNAME_PATH = 'Home';
$STMTFMT_SEL_PERSON = qq{
			select  distinct(per.person_id), per.complete_name as name, per.ssn,
				to_char(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT'),
				att.value_text as value_text
			from 	person per, person_attribute att
			where	att.parent_id = per.person_id
			and att.item_name = '$ITEMNAME_PATH'
			and %whereCond%
			union all
			select  per.person_id, per.complete_name as name, per.ssn,
				to_char(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT'),
				null as value_text
			from 	person per, person_attribute att
			where	att.parent_id = per.person_id
			and 	att.item_name != '$ITEMNAME_PATH'
			and 	per.person_id not in ( select  parent_id
							from   person_attribute
							where  item_name = '$ITEMNAME_PATH'
						)
			and %whereCond%
			group by per.person_id, per.complete_name, per.ssn, to_char(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT')
			%orderBy%
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID', url => 'javascript:chooseEntry("#&{?}#")'},
				{ head => 'Name' },
				{ head => 'SSN'},
				{ head => 'Date of Birth'},
				{ head => 'Home Phone'},

			],
};

$STMTMGR_PERSON_SEARCH = new App::Statements::Search::Person(

	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.person_id) = ?',
			 orderBy => '',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.person_id) like ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.name_last) = ?',
			 orderBy => 'order by name',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.name_last) like ? ',
			 orderBy => 'order by name',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_anyname' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => '(upper(per.name_last) = ? or upper(per.name_first) = ?)',
			 orderBy => 'order by name',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_anyname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => '(upper(per.name_last) like ? or upper(per.name_first) like ? )',
			 orderBy => 'order by name',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.ssn = ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.ssn like ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.date_of_birth = ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.date_of_birth like ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'att.value_text = ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'att.value_text like ?',
			 orderBy => '',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'RK',
		'Search/Person',
		'Updated the Person select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'RK',
		'Search/Person',
		'Created simple reports instead of using createOutput function.'],
);

1;
