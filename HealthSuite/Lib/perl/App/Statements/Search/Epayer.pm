##############################################################################
package App::Statements::Search::Epayer;
##############################################################################

use strict;
use Data::Publish;
use DBI::StatementManager;

use base 'Exporter';
use base 'DBI::StatementManager';

use vars qw(@EXPORT $STMTMGR_EPAYER_SEARCH);
@EXPORT = qw($STMTMGR_EPAYER_SEARCH);

my $BASE_SQL = qq{
	select * from Ref_Epayer
	where
	%whereCond%
		and psource like ?
	order by name
};

my $PUBLISH_DEFN = {
	columnDefn =>
	[
		{ head => 'ID 1', url => qq{javascript:chooseItem("/search/epayer/id/#&{?}#", "#&{?}#", false)} },
		{ head => 'ID 2', url => qq{javascript:chooseItem("/search/epayer/id2/#&{?}#", "#&{?}#", false)} },
		{ head => 'Name', },
	],
};


$STMTMGR_EPAYER_SEARCH = new App::Statements::Search::Epayer(
	'sel_name' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{upper(name) like upper(?)},
		publishDefn => $PUBLISH_DEFN,
		
	},
	'sel_id' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{upper(id) like upper(?)},
		publishDefn => $PUBLISH_DEFN,		
	},
	'sel_id2' => 
	{
		sqlStmt => $BASE_SQL,
		whereCond => qq{upper(id2) like upper(?)},
		publishDefn => $PUBLISH_DEFN,		
	},
	
);

1;
