##############################################################################
package App::Statements::Admin;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_ADMIN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ADMIN);


my $STMTMGRCOLS_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'Role', dataFmt => '#0#',},
				{ head => 'Permission', dataFmt => '#2#'},
				{ head => 'Status', dataFmt => '#4#'},
			],
	bullets => '/admin/#5#/dlg-update-role-permission?roleid=#1#&permnam=#2#',
	stdIcons =>	{
		delUrlFmt => '/admin/#5#/dlg-remove-role-permission?roleid=#1#&permnam=#2#',
	},
	banner => {
		actionRows =>
		[
			{ caption => qq{ Assign a Role <A HREF= '/admin/#param.org_id#/dlg-add-role-permission'>Permission</A> } },
		],
	},
};

$STMTMGR_ADMIN = new App::Statements::Admin(
	'selAllRolePermission' =>
	{
		sqlStmt => qq{
			select B.role_name, B.role_name_id, A.permission_name, A.role_activity_id, C.caption as role_activity_name, A.org_id
				from role_permission A, role_name B, role_activity C
				where A.org_id = ?
				and A.role_name_id = B.role_name_id 
				and A.role_activity_id = C.id
				order by B.role_name, A.permission_name
		},
		publishDefn => $STMTMGRCOLS_DEFAULT,
	},
	'selRolePermission' =>
	{
		sqlStmt => qq{
			select B.role_name, B.role_name_id, A.permission_name, A.role_activity_id, C.caption as role_activity_name, A.org_id
				from role_permission A, role_name B, role_activity C
				where A.org_id = ?
				and A.role_name_id = ?
				and A.permission_name = ?
				and A.role_activity_id = C.id and A.role_name_id = B.role_name_id
		},
		publishDefn => $STMTMGRCOLS_DEFAULT,
	},
	'delRolePermission' => qq{
		delete from role_permission
			where org_id = ? and role_name_id = ? and permission_name = ?
	},
	'selRoleIDs' => qq{
		select role_name_id, role_name from Role_Name where role_status_id = 0
	},
);

1;
