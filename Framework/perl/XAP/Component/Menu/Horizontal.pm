##############################################################################
package XAP::Component::Menu::Horizontal;
##############################################################################

use strict;
use Exporter;

use XAP::Component;
use XAP::Component::Menu;

use base qw(XAP::Component::Menu Exporter);
use fields qw(itemSeparator);

use vars qw(@EXPORT);
use constant MENUITEMSEPARATOR_BAR			=> " | ";
use constant MENUITEMSEPARATOR_ARROWLBLUE	=> " <IMG SRC='/resources/icons/arrow-right-lblue'> ";

@EXPORT = qw(
	MENUITEMSEPARATOR_ARROWLBLUE MENUITEMSEPARATOR_BAR
	);

XAP::Component->registerXMLTagClass('menu', ['type', { 'horizontal' => __PACKAGE__ } ]);

sub init
{
	my XAP::Component::Menu::Horizontal $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{itemSeparator} = exists $params{itemSeparator} ? $params{itemSeparator} : MENUITEMSEPARATOR_BAR;

	$self;
}

sub applyXML
{
	my XAP::Component::Menu::Horizontal $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my $separator = ' | ';
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		$separator = getTagTextOnly($chContent) if $chTag && $chTag eq 'separator';
	}
	$self->{itemSeparator} = $separator;

	$self;
}

sub getBodyHtml
{
	my XAP::Component::Menu::Horizontal $self = shift;
	my ($page, $flags) = (shift, shift);
	my (@menuItems) = @_;
	my $activeURL = $page->getActiveURL();

	my @html = ();
	my $items = @menuItems ? \@menuItems : $self->{items};
	my $anchorAttrs = $self->{anchorAttrs} ? " $self->{anchorAttrs}" : '';
	my $anchorSelAttrs = $self->{anchorSelAttrs} ? " $self->{anchorSelAttrs}" : $anchorAttrs;
	if(ref $items->[0] eq 'ARRAY')
	{
		foreach (@$items)
		{
			my $href = $_->[1];
			push(@html, ($_->[2] ? "$_->[2] " : '') . '<nobr>' . 
				($href eq $activeURL ? "<a href='$href'$anchorSelAttrs><b>$_->[0]</b></a>" : "<a href='$href'$anchorAttrs>$_->[0]</a>")
				. '</nobr>'
				);
		}
	}
	else
	{
		foreach (@$items)
		{
			my $href = $_->getURL($page);
			push(@html, '<nobr>' . (($_->{icon} && ! $flags & MENUBODYFLAG_IGNOREICONS) ? "<img SRC='$_->{icon}'> " : '') .
				($href eq $activeURL ? "<a href='$href'$anchorSelAttrs><b>@{[$_->getCaption()]}</b></a>" : "<a href='$href'$anchorAttrs>@{[$_->getCaption()]}</a>")
				. '</nobr>'
				);
		}
	}
	return join($self->{itemSeparator}, @html);
}

1;