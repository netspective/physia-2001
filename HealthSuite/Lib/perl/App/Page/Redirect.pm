##############################################################################
package App::Page::Redirect;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Person;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);

%RESOURCE_MAP = (
	'logout' => {},
	'home' => {},
	'homeorg' => {},
	);


sub prepare
{
	my ($self) = @_;
	my $rsrc = $self->param('arl_resource');

	if (my $newOrgId = $self->param('_switchTo'))
	{
		if (my $newOrgIntId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selOwnerOrgId', $newOrgId))
		{
			if (my $categories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $self->session('person_id'), $newOrgIntId))
			{
				$self->session('org_id', $newOrgId);
				$self->session('org_internal_id', $newOrgIntId);
				$self->session('categories', $categories);
				$self->addCookie(-name => 'defaultOrg', -value => $newOrgId, -expires => '+1y');

				# Reset their permissions
				$self->session('aclPermissions', undef);
				$self->session('aclRoleNames', undef);
				$self->setupACL();
			}
		}

	}

	# when coming from a login, redirect will already be set, so check for it
	unless($self->{page_redirect})
	{
		if($rsrc eq 'homeorg')
		{
			if(my $orgId = $self->session('org_id'))
			{
				$self->redirect("/org/$orgId/profile");
				return;
			}
		}
		elsif($rsrc eq 'home')
		{
			if(my $userId = $self->session('user_id'))
			{
				$self->redirect("/person/$userId/home");
			}
		}
		else
		{
			$self->redirect("/");
		}
	}

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
