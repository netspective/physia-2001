##############################################################################
package XAP::Component::Menu;
##############################################################################

use strict;
use Exporter;

use XAP::Component;

use base qw(XAP::Component Exporter);
use fields qw(items anchorAttrs anchorSelAttrs);

use vars qw(@EXPORT);
use enum qw(BITMASK:MENUBODYFLAG_ IGNOREICONS);

@EXPORT = qw(
	MENUBODYFLAG_IGNOREICONS
	);

#
# items can contain MenuItem components or simple array refs
# if simple array refs are present, then they must contain the following:
# 0 - caption
# 1 - href
# 2 - icon
# 3 - flags
#

sub init
{
	my XAP::Component::Menu $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{items} = exists $params{items} ? $params{items} : undef;
	$self->{anchorAttrs} = exists $params{anchorAttrs} ? $params{anchorAttrs} : '';
	$self->{anchorSelAttrs} = exists $params{anchorSelAttrs} ? $params{anchorSelAttrs} : '';
	$self->clearFlag(COMPFLAG_URLADDRESSABLE);

	$self;
}

sub applyXML
{
	my XAP::Component::Menu $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my @items = ();
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag;
		my $chAttrs = $chContent->[0];

		if($chTag eq 'menu-item')
		{
			push(@items, [$chAttrs->{caption} || 'No menu caption', $chAttrs->{href} || 'No menu href', $chAttrs->{icon} ? "<img src='$chAttrs->{icon}' border=0>" : '']);
		}
		elsif($chTag eq 'anchor-attrs')
		{
			if($chAttrs->{type} && $chAttrs->{type} eq 'active')
			{
				$self->{anchorSelAttrs} = getTagTextOnly($chContent);
			}
			else
			{
				$self->{anchorAttrs} = getTagTextOnly($chContent);
			}
		}
	}
	$self->{items} = \@items if @items;
	$self;
}

1;