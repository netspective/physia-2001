##############################################################################
package App::Statements::Search::Epayer;
##############################################################################

use strict;
use Data::Publish;
use DBI::StatementManager;
use App::Universal;
use base qw(Exporter DBI::StatementManager);
use vars qw(@EXPORT $STMTMGR_EPAYER_SEARCH);
@EXPORT = qw($STMTMGR_EPAYER_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

my $BASE_SQL = qq{
	SELECT *
	FROM ref_epayer
	WHERE
		%whereCond%
		AND rownum <= $LIMIT
	ORDER BY name
};


my $PUBLISH_DEFN = {
	columnDefn =>
	[
		{ head => 'Payer ID',hAlign=>'left', url => q{javascript:chooseItem('/search/epayer/id/#&{?}#', '#&{?}#', false)} },
		#{ head => 'Envoy Payer ID', url => q{javascript:chooseItem('/search/epayer/id2/#&{?}#', '#&{?}#', false)} },
		{ head => 'Name', },
	],
};


$STMTMGR_EPAYER_SEARCH = new App::Statements::Search::Epayer(
	'sel_name' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(name) LIKE UPPER(?) AND psource = ? },
		publishDefn => $PUBLISH_DEFN,
		
	},
	'sel_id' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(id) LIKE UPPER(?) AND psource = ?},
		publishDefn => $PUBLISH_DEFN,		
	},
	'sel_id2' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{UPPER(id2) LIKE UPPER(?)},
		publishDefn => $PUBLISH_DEFN,		
	},
	
);

1;
