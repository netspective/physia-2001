##############################################################################
package App::Statements::Search::EnvoyPayer;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_ENVOYPAYER_SEARCH
	$STMTRPTDEFN_DEFAULT $STMTFMT_SEL_ENVOYPAYER);
@ISA = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ENVOYPAYER_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_ENVOYPAYER = qq{
	SELECT
		id,
		name
	FROM ref_envoy_payer
	WHERE
		%whereCond%
		AND rownum <= $LIMIT
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID',dAlign => 'CENTER', url => q{javascript:chooseEntry('#&{?}#')}, },
				{ head => 'Name',dAlign => 'CENTER', tAlign=>'LEFT'},
			],
};

$STMTMGR_ENVOYPAYER_SEARCH = new App::Statements::Search::EnvoyPayer(
	'sel_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'UPPER(name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'UPPER(name) LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'id LIKE ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);

1;
