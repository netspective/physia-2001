##############################################################################
package App::Statements::Component::SDE;
##############################################################################

use strict;
use Exporter;
use Date::Manip;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_SDE
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_SDE);

$STMTMGR_COMPONENT_SDE = new App::Statements::Component::SDE(
	'sde.dbstats' => {
		sqlStmt => q{
			SELECT
				sn.name,
				my.value
			FROM
				v$mystat my,
				v$statname sn
			WHERE my.statistic# = sn.statistic#
		},
		publishDefn => {
			columnDefn => [
				{ head => 'Description', },
				{ head => 'Value', },
			],
		},
		publishDefn_panel => {
			style => 'panel',
			frame => { heading => 'Database Session Statistics', -editUrl => '', },
		},
		publishDefn_panelTransp => {
			style => 'panel.transparent',
			inherit => 'panel',
		},
		publishComp_st => sub { my ($page, $flags) = @_; $STMTMGR_COMPONENT_SDE->createHtml($page, $flags, 'sde.dbstats', []); },
		publishComp_stp => sub { my ($page, $flags) = @_; $STMTMGR_COMPONENT_SDE->createHtml($page, $flags, 'sde.dbstats', [], 'panel'); },
		publishComp_stpt => sub { my ($page, $flags) = @_; $STMTMGR_COMPONENT_SDE->createHtml($page, $flags, 'sde.dbstats', [], 'panelTransp'); },
	},
);


1;
