##############################################################################
package App::Statements::Search::Gpci;
##############################################################################

use strict;
use Data::Publish;
use DBI::StatementManager;
use App::Universal;
use base 'Exporter';
use base 'DBI::StatementManager';
use vars qw(@EXPORT $STMTMGR_GPCI_SEARCH);
@EXPORT = qw($STMTMGR_GPCI_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

my $BASE_SQL = qq{
	SELECT
		gpci_id,
		TO_CHAR(eff_begin_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
		TO_CHAR(eff_end_date, '$SQLSTMT_DEFAULTDATEFORMAT'),
		locality_name,
		state,
		county
	FROM ref_gpci
	WHERE
		%whereCond%
		AND eff_begin_date <= to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
		AND eff_end_date >= to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
	ORDER BY
		state,
		locality_name
};

my $PUBLISH_DEFN = {
	columnDefn =>
	[
		{ head => 'ID', url => qq{javascript:chooseItem("/search/gpci/id/#&{?}#", "#&{?}#", false)} },
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
		whereCond => 'LTRIM(RTRIM(UPPER(state))) LIKE UPPER(?)',
		publishDefn => $PUBLISH_DEFN,
	},
	
	'sel_GPCI_locality' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'UPPER(locality_name) LIKE UPPER(?)',
		publishDefn => $PUBLISH_DEFN,
	},

	'sel_GPCI_carrierNo' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'UPPER(carrier_number) LIKE UPPER(?)',
		publishDefn => $PUBLISH_DEFN,
	},

	'sel_GPCI_county' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'UPPER(county) LIKE UPPER(?)',
		publishDefn => $PUBLISH_DEFN,
	},
	
	'sel_GPCI_id' =>
	{
		sqlStmt => $BASE_SQL,
		whereCond => 'gpci_id = ?',
		publishDefn => $PUBLISH_DEFN,
	},
	
	'sel_stateForOrg' => qq{
		SELECT caption
		FROM
			states,
			org_address
		WHERE
			parent_id = ?
			AND address_name IN ('Street', 'Shipping', 'Mailing')
			AND LTRIM(RTRIM(states.abbrev)) = LTRIM(RTRIM(org_address.state))
			AND rownum <= $LIMIT
	},
);

1;
