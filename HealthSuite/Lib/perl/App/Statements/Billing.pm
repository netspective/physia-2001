##############################################################################
package App::Statements::Billing;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_BILLING);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_BILLING);

$STMTMGR_BILLING = new App::Statements::Billing (

	'orgNameAndID' => qq
	{
		select name_primary, org_id
		from org
		where org_internal_id = ?
	},

);


1;
