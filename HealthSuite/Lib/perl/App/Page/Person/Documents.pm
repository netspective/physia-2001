##############################################################################
package App::Page::Person::Documents;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person);

use vars qw(%RESOURCE_MAP $QDL);
%RESOURCE_MAP = (
	'person/documents' => {},
	);


sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-person'}->{'documents'});
	my $personId = $self->param('person_id') || $self->session('person_id');

	my @tabs = ();
	foreach my $child (keys %$children)
	{
		my $childRes = $children->{$child};
		my $id = $childRes->{_id};
		$id =~ s/^page\-//;
		my $href = $id;
		$href =~ s{^person}{person/$personId};
		my $caption = defined $childRes->{_tabCaption} ? $childRes->{_tabCaption} : (defined $childRes->{_title} ? $childRes->{_title} : 'caption');
		push @tabs, [ $caption, "/$href", $id ];
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


sub prepare_view
{
	my ($self) = @_;
}

1;
