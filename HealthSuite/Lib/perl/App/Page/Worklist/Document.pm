##############################################################################
package App::Page::Worklist::Document;
##############################################################################

use strict;
use SDE::CVS ('$Id: Document.pm,v 1.1 2000-11-08 02:44:34 robert_jenks Exp $', '$Name:  $');
use App::Page::WorkList;
use App::ResourceDirectory;
use base qw(App::Page::WorkList);
use vars qw(%RESOURCE_MAP);
use constant BASEARL => '/worklist/documents';
%RESOURCE_MAP = (
	'worklist/documents' => {
		_title => 'Document Work Lists',
		_iconSmall => 'images/page-icons/worklist-patient-flow',
		_iconMedium => 'images/page-icons/worklist-patient-flow',
		_iconLarge => 'images/page-icons/worklist-patient-flow',
		},
	);


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	my $baseArl = '/worklist/documents';

	$self->addLocatorLinks(
		['Documents', BASEARL],
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


sub prepare_view
{
	my $self = shift;

	$self->addContent("Document Work Lists");
}


sub getContentHandlers
{
	return ('prepare_view');
}


sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('person_id', $self->session('person_id')) unless $self->param('person_id');

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1] || 'date');
		$self->param('noControlBar', 1);

		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->param('_dialogreturnurl', BASEARL);
	$self->printContents();
	return 0;
}


sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-worklist'}->{'documents'});

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


1;
