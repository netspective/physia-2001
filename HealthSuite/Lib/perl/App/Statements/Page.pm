##############################################################################
package App::Statements::Page;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PAGE);

$STMTMGR_PAGE = new App::Statements::Page(

	'sel_SessionInfo' => qq{
		select * 
		from Persess_View_Count 
		where session_id = ?
			and view_scope = ?
			and view_key   = ?
	},
	
	'upd_count' => qq{
		update Persess_View_Count
		set Count = Count +1,
			view_latest = sysdate
		where session_id = ?
			and view_scope = ?
			and view_key   = ?
	},
	
	'ins_newKey' => qq{
		insert into Persess_View_Count
		(session_id, view_scope, view_key, view_caption, count, view_init, view_latest)
		values
		(?         , ?         , ?       , ?           , 1    , sysdate  , sysdate)
	},
	
	
);
	
1;
