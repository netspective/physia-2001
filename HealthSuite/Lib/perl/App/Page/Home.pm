##############################################################################
package App::Page::Home;
##############################################################################

use strict;
use App::Page;
use App::Universal;

use vars qw(@ISA);
@ISA = qw(App::Page);

#use App::Pane::Channel::News;

sub initialize
{
	my $self = shift;
	if($self->param('arl_resource') eq 'homeorg')
	{
		if(my $orgId = $self->session('org_id'))
		{
			$self->redirect("/org/$orgId/profile");
			return;
		}
	}
	if(my $userId = $self->session('user_id'))
	{
		$self->redirect("/person/$userId/home");
	}
}

sub prepare_page_content_header
{
	my $self = shift;

	push(@{$self->{page_content_header}}, qq{
		<CENTER>
			<IMG SRC='/resources/images/w_restinghands.gif'>
			<IMG SRC='/resources/images/Splash_ani.gif'>
		</CENTER>
	});
	return 1;
}

sub prepare
{
	my ($self) = @_;
	$self->addContent(qq{
		#component.news-top#<BR>
		#component.news-health#
	});
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
