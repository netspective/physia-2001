##############################################################################
package App::Statements::Search::Person;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA);

use vars qw(@ISA @EXPORT $STMTMGR_PERSON_SEARCH $ITEMNAME_PATH $STMTFMT_SEL_PERSON $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PERSON_SEARCH);

$ITEMNAME_PATH = 'Home';
$STMTFMT_SEL_PERSON = qq{
			select	per.person_id, per.complete_name as name, per.ssn,
					to_char(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT'),
					att.value_text as value_text,
					cat.category
			from 	person per, person_org_category cat, person_attribute att
			where	per.person_id = cat.person_id(+)
					and per.person_id = att.parent_id(+)
					and att.value_type(+) = @{[ App::Universal::ATTRTYPE_PHONE ]}
					and att.item_name(+) = '$ITEMNAME_PATH'
					and %whereCond%
					%catCond%
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
				{ head => 'Type'},

			],
};

my %personTemplates = (
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.person_id) = ?',
			 orderBy => 'order by per.person_id',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.person_id) like ?',
			 orderBy => 'order by per.person_id',
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
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.ssn like ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.date_of_birth = ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.date_of_birth like ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'att.value_text = ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'att.value_text like ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	);

#
# HEY! If you add anything to @categories you must add the array index below
#
my @categories = ('physician', 'nurse', 'staff', 'patient', 'associate');
my @categorySqls = ();
foreach my $category (@categories)
{
	my $sqls = {};
	push(@categorySqls, $sqls);

	my @tmplKeys = keys %personTemplates;
	foreach (@tmplKeys)
	{
		my %sqlData = %{$personTemplates{$_}};
		$sqlData{catCond} = $category eq 'associate' ? "and cat.category in ('Physician', 'Nurse', 'Staff')" : "and cat.category = '\u$category'";
		$sqls->{"$_\_$category"} = \%sqlData;
	}
}

# If you add anything to @categories, you must also add it below as $categorySqls[x]
$STMTMGR_PERSON_SEARCH = new App::Statements::Search::Person(
	%personTemplates,
	%{$categorySqls[0]},
	%{$categorySqls[1]},
	%{$categorySqls[2]},
	%{$categorySqls[3]},
	%{$categorySqls[4]},
);

1;
