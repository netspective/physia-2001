##############################################################################
package App::Statements::Search::EnvoyPayer;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
use vars qw(@ISA @EXPORT $STMTMGR_ENVOYPAYER_SEARCH $STMTRPTDEFN_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ENVOYPAYER_SEARCH);
use vars qw($STMTFMT_SEL_ENVOYPAYER);
$STMTFMT_SEL_ENVOYPAYER = qq{
			select  id, name from REF_Envoy_Payer
			where
				%whereCond%
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'ID',dAlign => 'CENTER', url => 'javascript:chooseEntry("#&{?}#")'},
				{ head => 'Name',dAlign => 'CENTER', tAlign=>'LEFT'},
			],
};

$STMTMGR_ENVOYPAYER_SEARCH = new App::Statements::Search::EnvoyPayer(
	'sel_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'upper(name) = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ENVOYPAYER,
			whereCond => 'upper(name) like ?',
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
			whereCond => 'id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);
@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'RK',
		'Search/Insurance',
		'Updated the select statements by replacing them with _stmtFmt.'],
);

1;
