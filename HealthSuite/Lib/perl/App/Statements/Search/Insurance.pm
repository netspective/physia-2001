##############################################################################
package App::Statements::Search::Insurance;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_INSURANCE_SEARCH $STMTFMT_SEL_INSURANCE
	$STMTRPTDEFN_DEFAULT $STMTRPTDEFN_INSPRODUCT $STMTRPTDEFN_INSPLAN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INSURANCE_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_INSURANCE = qq{
	SELECT
		org.org_id,
		ins.product_name,
		ins.plan_name,
		addr.line1,
		addr.city,
		addr.state,
		ins.ins_internal_id
	FROM
		insurance ins,
		insurance_address addr,
		org
	WHERE
		ins.ins_internal_id = addr.parent_id
		AND org.org_internal_id = ins.ins_org_id
		AND	%whereCond% 
		AND ins.owner_org_id = ?
		%catCond%
		AND rownum <= $LIMIT
	ORDER BY 1
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'Insurance Org', url => q{javascript:chooseEntry('#&{?}#')}, },
				{ head => 'Product Name' },
				{ head => 'Plan Name' },
				{ head => 'Street' },
				{ head => 'City' },
				{ head => 'State' },
			],
};

$STMTRPTDEFN_INSPRODUCT =
{
	columnDefn =>
			[
				{ head => 'Product Name', colIdx => 1, url => q{javascript:chooseItem('/org/#session.org_id#/dlg-update-ins-product/#6#','#&{?}#')}, },
				{ head => 'Insurance Org', colIdx => 0, url => q{javascript:chooseEntry('#&{?}#')}, },
				{ head => 'Street', colIdx => 3 },
				{ head => 'City', colIdx => 4 },
				{ head => 'State', colIdx => 5 },
			],
};

$STMTRPTDEFN_INSPLAN =
{
	columnDefn =>
			[
				{ head => 'Plan Name', colIdx => 2, url => q{javascript:chooseItem('/org/#session.org_id#/dlg-update-ins-plan/#6#','#&{?}#')}, },
				{ head => 'Product Name', colIdx => 1 },
				{ head => 'Insurance Org', colIdx => 0, url => q{javascript:chooseEntry('#&{?}#')}, },
				{ head => 'Street', colIdx => 3 },
				{ head => 'City', colIdx => 4 },
				{ head => 'State', colIdx => 5 },
			],
};


my %insTemplates = (
	'sel_product' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => qq{UPPER(ins.product_name) = REPLACE(?, '%20', ' ')},
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_product_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(ins.product_name) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_plan' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(ins.plan_name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_plan_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(ins.plan_name) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insorgid' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(org.org_id) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_insorgid_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(org.org_id) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_street' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.line1) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_street_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.line1) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_city' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.city) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_city_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.city) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_state' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.state) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_state_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_INSURANCE,
			whereCond => 'UPPER(addr.state) like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

#
# HEY! If you add anything to %categories you must add the array index below
#
my %categories = (
	'insproduct' => {
		publishDefn => $STMTRPTDEFN_INSPRODUCT,
		catCond => 'AND ins.record_type = 1',
		},
	'insplan' => {
		publishDefn => $STMTRPTDEFN_INSPLAN,
		catCond => 'AND ins.record_type = 2',
		},
);

my @categorySqls = ();
foreach my $category (keys %categories)
{
	my $sqls = {};
	push(@categorySqls, $sqls);

	my @tmplKeys = keys %insTemplates;
	foreach my $tmplKey (@tmplKeys)
	{
		my %sqlData = %{$insTemplates{$tmplKey}};
		foreach my $key (keys %{$categories{$category}})
		{
			next unless defined $categories{$category}{$key};
			$sqlData{$key} = $categories{$category}{$key};
		}
		$sqls->{"$tmplKey\_$category"} = \%sqlData;
	}
}

# If you add anything to %categories, you must also add it below as $categorySqls[x]
$STMTMGR_INSURANCE_SEARCH = new App::Statements::Search::Insurance(
	%insTemplates,
	%{$categorySqls[0]},
	%{$categorySqls[1]},
);

1;
