##############################################################################
package App::Page::Admin;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Exporter;
use DBI::StatementManager;

use App::Statements::Admin;
use App::Dialog::Admin::RolePermission;

use App::Configuration;
use App::Configuration;
use App::ImageManager;
use App::ResourceDirectory;
use Data::Publish;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(Exporter App::Page);
%RESOURCE_MAP = (
	'admin' => {
		_views => [
			{name => 'permissions', caption => 'Permissions',},
			{name => 'permissions_add', caption => 'Add Permissions',},
			],
		},
	);

use constant DEFAULT_HIDE_COLUMNS => 'CR_SESSION_ID,CR_STAMP,CR_USER_ID,CR_ORG_ID,VERSION_ID';

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=permissons$');
}

sub initialize
{
	my $self = shift;
	$self->addLocatorLinks(['<IMG SRC="/resources/icons/home-sm.gif" BORDER=0> Adminstration', '/admin']);
	$self->addContent(qq{
	<style>
		body { background-color: white }
		a { text-decoration: none; }
		a.tableNameParToc { text-decoration: none; color: black; font-weight: bold; }
		a.tableNameChlToc { text-decoration: none; color: navy; }
		a:hover { color : red }
		h1 { font-family: arial, helvetica; font-size: 14pt; font-weight: bold; color: darkred; }
		body { font-family: verdana; font-size : 10pt; }
		td { font-family: verdana; font-size: 10pt; }
		th { font-family: arial,helvetica; font-size: 9pt; color: silver}
		select { font-family: tahoma; font-size: 8pt; }
		.coldescr { font-family: arial, helvetica; font-size: 8pt; color: navy }
	</style>
	});

	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	my $permissionName = 'page/admin';
	
	# Set the org ID parameter, which will be used by the components

	unless ($self->param('org_id'))
	{
		$self->param('org_id', $self->session('org_id'));
	}
	
	if ($activeView) 
	{
		$permissionName .= "/$activeView";
	}
	unless($self->hasPermission($permissionName))
	{
		$self->disable(
				qq{
					<br>
					You do not have permission to view this information. 
					Permission $permissionName is required.

					Click <a href='javascript:history.back()'>here</a> to go back.
				});
	}
}

sub prepare_page_content_header
{
	my ($self, $colors, $fonts, $personId, $personData) = @_;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	$self->SUPER::prepare_page_content_header(@_);

	my $orgID = $self->param('org_id') || $self->session('org_id');


	my $urlPrefix = "/admin/$orgID";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Permission', "$urlPrefix/permissions", 'permissions'],
		], ' | ');



	push(@{$self->{page_content_header}}, qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR VALIGN=BOTTOM>
			<TD WIDTH=32>
				$IMAGETAGS{'icon-m/sde'}
			</TD>
			<TD VALIGN=MIDDLE>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					&nbsp;<B>Adminstration</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT VALIGN=MIDDLE>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
			</TR>
		</TABLE>
		});
	return 1;
}

sub prepare_view_permissions
{
	my ($self) = @_;
		
	#$self->param('org_id', $self->session('org_id'));
	my $orgID = $self->param('org_id') || $self->session('org_id');

	my @pathItems = split('/', $self->param('arl'));

	$self->addLocatorLinks(['Permissions', "/admin/$orgID/permissions"]);
	
	if ($self->param('role_id', $pathItems[4]))
	{
		$self->param('internal_role_id', $pathItems[3]);
		$self->addContent($STMTMGR_ADMIN->createHtml($self, STMTMGRFLAG_NONE, 'selAllRolePermission', [$pathItems[3]] ),
		);
	}
	else
	{
		$self->addContent(qq{<BR>});
		$self->addContent(
			$STMTMGR_ADMIN->createHtml($self, STMTMGRFLAG_NONE, 'selAllRolePermission', [$orgID]) );
	}
	return 1;
}

sub prepare_view_permissions_add
{
	my ($self) = @_;
	
	#my $dialog = new App::Dialog::Admin::RolePermission(schema => $self->getSchema(), cancelUrl => "/admin/permission");
	#$dialog->handle_page($self, 'add');

	$self->addContent(qq{
		<BR><TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
				<TR VALIGN=TOP>
					<TD>
						#component.stpe-admin.rolePermissions#<BR>
					</TD>
				</TR>
		</TABLE>
	});

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	
	# If the org ID is not specified on the ARL, the it will be added in the initialize function using the session org id
	# Cannot add session org ID now because we don't have it yet.
	if ($pathItems->[0]) 
	{
		$self->param('org_id', $pathItems->[0]);
	}

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'permissions');
		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->printContents();
	return 0;
}

1;
