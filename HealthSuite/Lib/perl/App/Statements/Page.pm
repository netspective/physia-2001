##############################################################################
package App::Statements::Page;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_PAGE);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PAGE);

$STMTMGR_PAGE = new App::Statements::Page(

	'sel_SessionInfo' => qq{
		select * 
		from Persess_View_Count 
		where person_id = ?
			and view_init >= trunc(sysdate)
			and view_scope = ?
			and view_key   = ?
	},
	
	'upd_count' => qq{
		update Persess_View_Count
		set view_count = view_count +1,
			view_latest = sysdate
		where person_id = ?
			and view_init >= trunc(sysdate)
			and view_scope = ?
			and view_key   = ?
	},
	
	'ins_newKey' => qq{
		insert into Persess_View_Count
		(session_id, person_id, view_scope, view_key, view_count, view_caption, view_arl, view_init, view_latest)
		values
		(?         , ?         , ?        , ?       , 1         , ?           , ?       , sysdate  , sysdate)
	},

	'person.mySessionViewCount' => {
		sqlStmt => qq{
			select view_caption, view_count, %simpleStamp:view_init%,	
				%simpleStamp:view_latest%, view_arl
			from Persess_View_Count 
			where person_id = ?
				and view_init > trunc(sysdate)
			order by view_count DESC
		},
		sqlStmtBindParamDescr => ['Person ID for the perSess_View_Count table '],
		
		publishDefn => {
			columnDefn => [
				{ head=> 'Target', url => '#4#' },
				{ head=> 'Count', dAlign => 'right' },
				{ head=> 'Init View' },
				{ head=> 'Last View' },
			],
			#bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		},
		publishDefn_panel =>
		{
			# automatically inherits columnDefn and other items from publishDefn
			style => 'panel.static',
			flags => 0,
			frame => { heading => 'My Activity View Count' },
		},
		publishDefn_panelTransp =>
		{
			# automatically inherits columnDefn and other items from publishDefn
			style => 'panel.transparent.static',
			inherit => 'panel',
		},

		publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_PAGE->createHtml($page, $flags, 'person.mySessionViewCount', [$personId] ); },
		publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_PAGE->createHtml($page, $flags, 'person.mySessionViewCount', [$personId], 'panel'); },
		publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_PAGE->createHtml($page, $flags, 'person.mySessionViewCount', [$personId], 'panelEdit'); },
		publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_PAGE->createHtml($page, $flags, 'person.mySessionViewCount', [$personId], 'panelTransp'); },
	},
);
	
1;
