##############################################################################
package App::Statements::Search::OtherService;
##############################################################################

use strict;
use Data::Publish;
use DBI::StatementManager;
use App::Universal;
use base qw(Exporter DBI::StatementManager);
use vars qw(@EXPORT $STMTMGR_OTHERSERVICE_SEARCH);
@EXPORT = qw($STMTMGR_OTHERSERVICE_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

my $BASE_SQL = qq{
	SELECT 	oce.modifier,oce.name
	FROM 	offering_catalog_entry oce, offering_catalog oc 		
	WHERE	oc.org_internal_id = :1
	AND	oc.catalog_id = 'OTHER'
	AND	oce.catalog_id = oc.internal_catalog_id
	AND	oc.catalog_type = 5
	AND	%whereCond%
	AND 	rownum <= $LIMIT
	ORDER BY name
};


my $PUBLISH_DEFN = {
	columnDefn =>
	[
		{ head => 'Code',hAlign=>'left', url => q{javascript:chooseItem('/search/epayer/id/#&{?}#', '#&{?}#', false)} },
		{ head => 'Name', },
	],
};


$STMTMGR_OTHERSERVICE_SEARCH = new App::Statements::Search::OtherService(
	'sel_other_service_code_like' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(oce.modifier) LIKE :2},
		publishDefn => $PUBLISH_DEFN,
		
	},
	'sel_other_service_name_like' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(oce.name) LIKE :2},
		publishDefn => $PUBLISH_DEFN,		
	},
	'sel_other_service_code' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(oce.modifier) = :2},
		publishDefn => $PUBLISH_DEFN,
		
	},
	'sel_other_service_name' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(oce.name) = :2},
		publishDefn => $PUBLISH_DEFN,		
	},

	
);

1;
