##############################################################################
package App::Dialog::Admin::RolePermission;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Admin;
use App::Statements::Org;

use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP @EXPORT);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'role-permission' => {
			heading => '$Command Role Permission', 
			_arl => ['role-permission']
		},
);

@EXPORT = qw(%APPT_URLS);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'RolePermission', heading => '$Command Role Permission');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field(
			caption => 'Role: ',
			name => 'roleID',
			fKeyStmtMgr => $STMTMGR_ADMIN,
			fKeyStmt => 'selRoleIDs',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(
			name => 'permissionName',
			type => 'text',
			caption => 'Permission: ',
			size => '35',
			options => FLDFLAG_REQUIRED | FLDFLAG_TRIM,
			hints => ''
		),
		new CGI::Dialog::Field(
			name => 'permissionAccess',
			type => 'enum',
			enum => 'Role_Activity',
			caption => 'Access: ',
			options => FLDFLAG_REQUIRED,
			schema => $schema, 
		),
		
		# hidden fields for updating
		new CGI::Dialog::Field(
			name => 'roleIDOrg',
			type => 'hidden',
		),
		new CGI::Dialog::Field(
			name => 'permissionNameOrg',
			type => 'hidden',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	#my @pathItems = split('/', $page->param('arl'));

	if ($page->param('org_id'))
	{
		my $userId =  $page->session('user_id');
		my $orgIntId = $page->param('org_id');
		#my $roleID = $pathItems[3];
		#my $permissionName = $pathItems[4];
		my $roleID = $page->param('roleid');
		my $permissionName = $page->param('permnam');

		my $RolePermission = $STMTMGR_ADMIN->getRowAsHash($page,
			STMTMGRFLAG_NONE, 'selRolePermission', $orgIntId, $roleID, $permissionName);
		$page->field('permissionName', $RolePermission->{permission_name});
		$page->field('permissionNameOrg', $RolePermission->{permission_name});
		$page->field('roleID', $RolePermission->{role_name_id});
		$page->field('roleIDOrg', $RolePermission->{role_name_id});
		$page->field('permissionAccess', $RolePermission->{role_activity_id});
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $userId =  $page->session('user_id');
	#my $orgId = $page->param('org_id') || $page->session('org_id');
	my $orgId = $page->session('org_id');
	#my $orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $orgId);	
	my $orgIntId = $page->param('org_id');
	my $roleID = $page->field('roleID');
	my $roleIDOrg = $page->field('roleIDOrg');
	my $permissionName = $page->field('permissionName');
	my $permissionNameOrg = $page->field('permissionNameOrg');
	my $roleActivityID = $page->field('permissionAccess');

	if ($command eq 'add')
	{
		$STMTMGR_ADMIN->execute($page, STMTMGRFLAG_NONE, 'delRolePermission', $orgIntId, $roleID, $permissionName);	# can have the same org id, role id, and permission name, but different permission, so must delete to prevent duplicates
		$page->schemaAction('Role_Permission', 'add',
			permission_name => $permissionName,
			role_name_id => $roleID,
			role_activity_id => $roleActivityID,
			org_internal_id => $orgIntId
		);
	}
	elsif ($command eq 'update')
	{
		$STMTMGR_ADMIN->execute($page, STMTMGRFLAG_NONE, 'delRolePermission', $orgIntId, $roleIDOrg, $permissionNameOrg);
		$page->schemaAction('Role_Permission', 'add',
			permission_name => $permissionName,
			role_name_id => $roleID,
			role_activity_id => $roleActivityID,
			org_internal_id => $orgIntId
		);
	}
	elsif ($command eq 'remove')
	{
		$STMTMGR_ADMIN->execute($page, STMTMGRFLAG_NONE, 'delRolePermission', $orgIntId, $roleID, $permissionName);
	}

	$self->handlePostExecute($page, $command, $flags, "/admin/$orgId/permissions");
}

sub customValidate
{
	my ($self, $page) = @_;

	#my ($strFrom, $strTo) = ($page->field('LastNameFrom'), $page->field('LastNameTo'));
	#my $nameRangeFields = $self->getField('LastNameRange')->{fields}->[0];

}

1;
