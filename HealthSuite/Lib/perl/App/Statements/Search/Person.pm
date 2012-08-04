##############################################################################
package App::Statements::Search::Person;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_PERSON_SEARCH $STMTFMT_SEL_PERSON $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PERSON_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_PERSON = qq{
	SELECT *
	FROM (
		SELECT
			per.person_id,
			per.name_last,
			per.name_first,
			per.ssn,
			TO_CHAR(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT') as dob,
			hphone.value_text AS home_phone,
			account.value_text as account,
			chart.value_text as chart,
			cat.category,
			initcap(per.simple_name) AS name,
			(select 1 from dual
				where exists (select 'x' from transaction t
					where t.trans_owner_id = per.person_id
						and t.trans_status = @{[ App::Universal::TRANSSTATUS_ACTIVE ]}
						and t.trans_type = @{[ App::Universal::TRANSTYPE_ALERTAPPOINTMENT ]}
				)
			) as appt_alert,
			decode(per.gender, 1, 'M', 2, 'F', '') as gender
		FROM
			person per,
			person_org_category cat,
			person_attribute hphone,
			person_attribute account,
			person_attribute chart
		WHERE
			per.person_id = cat.person_id(+) AND
			(per.person_id = hphone.parent_id(+) AND hphone.value_type(+) = @{[ App::Universal::ATTRTYPE_PHONE ]} AND hphone.item_name(+) = 'Home') AND
			(per.person_id = account.parent_id(+) AND account.value_type(+) = 0 AND account.item_name(+) = 'Patient/Account Number') AND
			(per.person_id = chart.parent_id(+) AND chart.value_type(+) = 0 AND chart.item_name(+) = 'Patient/Chart Number') AND
			cat.org_internal_id = ? AND
			%whereCond%
			%catCond%
		%orderBy%
	)
	WHERE rownum <= $LIMIT

};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID',
					url => q{javascript:setSimpleName('#9#', '#10#', '/popup/alerts/#0#');
						chooseEntry('#&{?}#', null, null, '#8#','#9#');
					},
				},
				{ head => 'Last Name' },
				{ head => 'First Name' },
				{ head => 'SSN'},
				{ head => 'Date of Birth'},
				{ head => 'Home Phone'},
				{ head => 'Account'},
				{ head => 'Chart'},
				{ head => 'Type'},

			],
};

use constant ORDERBY_DEFAULT => 'ORDER BY upper(per.name_last), upper(per.name_first)';

my %personTemplates = (
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.person_id = ?',
			 orderBy => 'order by per.person_id',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.person_id like ?',
			 orderBy => 'order by per.person_id',
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.name_last) = ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_lastname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(per.name_last) like ? ',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_anyname' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => '(upper(per.name_last) = ? or upper(per.name_first) = ?)',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_anyname_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => '(upper(per.name_last) like ? or upper(per.name_first) like ? )',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.ssn = ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_ssn_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'per.ssn like ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => "per.date_of_birth = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')",
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_dob_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => "to_char(per.date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT') like ?",
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'hphone.value_text = ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_phone_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'hphone.value_text like ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_account' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(account.value_text) = ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_account_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(account.value_text) like ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_chart' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(chart.value_text) = ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_chart_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_PERSON,
			 whereCond => 'upper(chart.value_text) like ?',
			 orderBy => ORDERBY_DEFAULT,
			 publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	);

#
# HEY! If you add anything to @categories you must add the array index below
#
my @categories = ('physician', 'nurse', 'staff', 'patient', 'associate', 'referring-Doctor', 'physician-ref', 'insured-Person');
my @categorySqls = ();
foreach my $category (@categories)
{
	my $sqls = {};
	push(@categorySqls, $sqls);

	my @tmplKeys = keys %personTemplates;
	foreach (@tmplKeys)
	{
		my %sqlData = %{$personTemplates{$_}};

		if ($category eq 'associate')
		{
			$sqlData{catCond} =  "and cat.category in ('Physician', 'Nurse', 'Staff')";
		}
		elsif ($category eq 'physician-ref')
		{
			$sqlData{catCond} =  "and cat.category in ('Physician', 'Referring-Doctor')";

		}
		else
		{
			 $sqlData{catCond} = "and cat.category = '\u$category'";
		}
		#$sqlData{catCond} = $category eq 'associate' ? "and cat.category in ('Physician', 'Nurse', 'Staff', 'Referring-Doctor')" : "and cat.category = '\u$category'";
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
	%{$categorySqls[5]},
	%{$categorySqls[6]},
	%{$categorySqls[7]}
);

1;
