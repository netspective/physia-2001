##############################################################################
package App::Page::Redirect;
##############################################################################

use strict;
use App::Page;
use App::Universal;

use vars qw(@ISA);
@ISA = qw(App::Page);

sub prepare
{
	my ($self) = @_;
	my $rsrc = $self->param('arl_resource');

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
