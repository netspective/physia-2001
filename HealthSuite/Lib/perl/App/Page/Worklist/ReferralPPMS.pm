##############################################################################
package App::Page::Worklist::ReferralPPMS;
##############################################################################

use strict;

use App::Page::WorkList;
use App::ResourceDirectory;
use base qw(App::Page::WorkList);
use vars qw(%RESOURCE_MAP);
use constant BASEARL => '/worklist/referralppms';


%RESOURCE_MAP = (
	'worklist/referralppms' => {
			_title =>'Referrals Work List',
			_iconSmall =>'images/page-icons/worklist-patient-flow',
			_iconMedium =>'images/page-icons/worklist-patient-flow',
			_iconLarge => 'images/page-icons/worklist-patient-flow',
			_views => [
				{caption => 'Work List' , name => 'main',},
				{caption => 'Setup', name => 'setup',},
			],
	},
);


#sub prepare_view_main
#{
#	my ($self) = @;
#}


########################################################
# Worklist Setup View
########################################################
#sub prepare_view_setup
#{
#	my ($self) = @_;
#
#	my $dialog = new App::Dialog::WorklistSetup::ReferralPPMS(schema => $self->{schema});
#	$self->addContent('<br>');
#	$dialog->handle_page($self, 'add');
#	return 1;
#}


########################################################
# Setup Tabs for  Worklist
########################################################
sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-worklist'}->{'referralppms'});

	my @tabs = ();
	foreach my $child (keys %$children)
	{
		my $childRes = $children->{$child};
		my $id = $childRes->{_id};
		$id =~ s/^page\-//;
		my $caption = defined $childRes->{_tabCaption} ? $childRes->{_tabCaption} : (defined $childRes->{_title} ? $childRes->{_title} : 'caption');
		push @tabs, [ $caption, "/$id", $id ];
	}

	my $tabsHtml = $self->getMenu_Tabs(
		App::Page::MENUFLAGS_DEFAULT,
		'arl_resource',
		\@tabs,
		{
			selColor => '#CDD3DB',
			selTextColor => 'black',
			unselColor => '#E5E5E5',
			unselTextColor => '#555555',
			highColor => 'navy',
			leftImage => 'images/design/tab-top-left-corner-white',
			rightImage => 'images/design/tab-top-right-corner-white'
		}
	);

	return [qq{<br><div align="left"><table border="0" cellspacing="0" cellpadding="0" bgcolor="white"><tr>$tabsHtml</tr></table></div>}];
}


########################################################
# Handle the page display
########################################################
sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'main');

		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	};



	my $menu = ($self->{page_menu_sibling} = []);
	my $resourceMap = %RESOURCE_MAP->{'worklist/referralppms'};
	my $urlPrefix = BASEARL; #"/" . $self->param('arl_resource');
	foreach my $view (@{$resourceMap->{_views}})
	{
		push @$menu, [ $view->{caption}, "$urlPrefix/$view->{name}", $view->{name} ];
	}
	$self->{page_menu_siblingSelectorParam} = '_pm_view';



	#If the refresh option is not set then set refresh param to zero
	unless($params=~m/refresh=1/)
	{
		$self->param('refresh',0) ;
	}
	$self->param('_dialogreturnurl', BASEARL);
	$self->printContents();
	return 0;
}


sub getContentHandlers
{
	return ('prepare_view_$_pm_view=main$');
}


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	my $baseArl = '/worklist/referralppms';

	$self->addLocatorLinks(
		['ReferralPPMS', BASEARL],
	);

	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		unless($self->hasPermission("page" . BASEARL))
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information.
						Permission page@{[ BASEARL ]} is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
	}
}


1;
