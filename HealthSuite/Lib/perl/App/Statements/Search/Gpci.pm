##############################################################################
package App::Statements::Search::Gpci;
##############################################################################

use strict;
use Data::Publish;
use DBI::StatementManager;

use base 'Exporter';
use base 'DBI::StatementManager';

#use Exporter;
#use DBI::StatementManager;
#@ISA    = qw(Exporter DBI::StatementManager);

use vars qw(@EXPORT $STMTMGR_GPCI_SEARCH);
@EXPORT = qw($STMTMGR_GPCI_SEARCH);

my $BASE_SQL = qq{
	select gpci_id, to_char(eff_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
	to_char(eff_end_date, '$SQLSTMT_DEFAULTDATEFORMAT'), locality_name, state, county
	from Ref_Gpci
	%whereCond%
	order by state, locality_name
};

my $PUBLISH_DEFN = {
	columnDefn =>
	[
		{ head => 'ID', url => 'javascript:chooseItem("/search/gpci/id/#&{?}#")'},
		{ head => 'Begin', colIdx => 1},
		{ head => 'End', colIdx => 2},
		{ head => 'Locality', colIdx => 3},
		{ head => 'State', colIdx => 4},
		{ head => 'County', colIdx => 5},
	],
};


$STMTMGR_GPCI_SEARCH = new App::Statements::Search::Gpci(
	'sel_GPCI_state' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'where ltrim(rtrim(upper(state))) like upper(?)',
		publishDefn => $PUBLISH_DEFN,
	},
	
	'sel_GPCI_locality' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'where upper(locality_name) like upper(?)',
		publishDefn => $PUBLISH_DEFN,
	},

	'sel_GPCI_carrierNo' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'where upper(carrier_number) like upper(?)',
		publishDefn => $PUBLISH_DEFN,
	},

	'sel_GPCI_county' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'where upper(county) like upper(?)',
		publishDefn => $PUBLISH_DEFN,
	},
	
	'sel_GPCI_id' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'where gpci_id = ?',
		publishDefn => $PUBLISH_DEFN,
	},
	
);

1;
