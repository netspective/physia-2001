##############################################################################
package XAP::Component::Menu::Tabs;
##############################################################################

use strict;
use Exporter;

use XAP::Component;
use XAP::Component::Menu;

use base qw(XAP::Component::Menu Exporter);
use fields qw(tableAttrs cellAttrs cellSelAttrs cellPadding);

XAP::Component->registerXMLTagClass('menu', ['type', { 'tabs' => __PACKAGE__ } ]);

sub init
{
	my XAP::Component::Menu::Tabs $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{cellAttrs} = exists $params{cellAttrs} ? $params{cellAttrs} : '';
	$self->{cellSelAttrs} = exists $params{cellSelAttrs} ? $params{cellSelAttrs} : 'bgcolor="#777777"';
	$self->{tableAttrs} = exists $params{tableAttrs} ? $params{tableAttrs} : 'cellpadding="3" cellspacing="0" border="0"';

	$self;
}

sub applyXML
{
	my XAP::Component::Menu::Tabs $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my $separator = ' | ';
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag;
		
		my $chAttrs = $chContent->[0];
		if($chTag eq 'cell-attrs')
		{
			if($chAttrs->{type} && $chAttrs->{type} eq 'active')
			{
				$self->{cellSelAttrs} = getTagTextOnly($chContent);
			}
			else
			{
				$self->{cellAttrs} = getTagTextOnly($chContent);
			}
		}
		elsif($chTag eq 'table-attrs')
		{
			$self->{tableAttrs} = getTagTextOnly($chContent);
		}
	}
	$self;
}

sub getBodyHtml
{
	my XAP::Component::Menu::Tabs $self = shift;
	my ($page, $flags) = (shift, shift);
	my (@menuItems) = @_;
	my $activeURL = $page->getActiveURL();

	my @html = ();
	my $items = @menuItems ? \@menuItems : $self->{items};
	
	my $anchorAttrs = $self->{anchorAttrs} ? " $self->{anchorAttrs}" : '';
	my $anchorSelAttrs = $self->{anchorSelAttrs} ? " $self->{anchorSelAttrs}" : $anchorAttrs;
	my $cellAttrs = $self->{cellAttrs} ? " $self->{cellAttrs}" : '';
	my $cellSelAttrs = $self->{cellSelAttrs} ? " $self->{cellSelAttrs}" : $cellAttrs;
	
	if(ref $items->[0] eq 'ARRAY')
	{
		foreach (@$items)
		{
			my $href = $_->[1];
			push(@html, ($_->[2] ? "$_->[2] " : '') .
				($href eq $activeURL ? "<td$cellSelAttrs>&nbsp;<a href='$href'$anchorSelAttrs><b>$_->[0]</b>&nbsp;</a></td>" : "<td$cellAttrs><a href='$href'$anchorAttrs>$_->[0]</a>&nbsp;</td>")
				);
		}
	}
	else
	{
		foreach (@$items)
		{
			my $href = $_->getURL($page);
			my $icon = ($_->{icon} && ! $flags & MENUBODYFLAG_IGNOREICONS) ? "<img SRC='$_->{icon}' border=0> " : '';
			push(@html, 
				($href eq $activeURL ? "<td$cellSelAttrs>&nbsp;$icon <a href='$href'$anchorSelAttrs><b>@{[$_->getCaption()]}</b></a>&nbsp;</td>" : "<td$cellAttrs>$icon <a href='$href'$anchorAttrs>@{[$_->getCaption()]}</a>&nbsp;</td>")
				);
		}
	}
	return qq{<table $self->{tableAttrs}><tr valign="bottom">} . join('', @html) . '</tr></table>';
}

1;