##############################################################################
package XAP::Component::Menu::Vertical;
##############################################################################

use strict;
use Exporter;

use Data::Publish;
use XAP::Component::Menu;

use base qw(XAP::Component::Menu Exporter);
use fields qw(publishDefn);

XAP::Component->registerXMLTagClass('menu', ['type', { 'vertical' => __PACKAGE__ } ]);

sub init
{
	my XAP::Component::Menu::Vertical $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	my $anchorAttrs = $self->{anchorAttrs} ? " $self->{anchorAttrs}" : $self->{anchorAttrs};
	$self->{publishDefn} =
	{
		flags => PUBLFLAG_HIDEHEAD,
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2>',
		rowSepStr => '',
		frame =>
		{
			headColor => '#FFFFFF',
			borderColor => '#FFFFFF',
			contentColor => '#FFFFFF',
			heading => '#my.heading#',
		},
		columnDefn => [
			{ dataFmt => '<A HREF="#0#"$anchorAttrs><IMG SRC="#2#" BORDER=0></A>' },
			{ dataFmt => '<A HREF="#0#"$anchorAttrs>#1#</A>' }
			],
	};

	$self;
}

sub getBodyHtml
{
	my XAP::Component::Menu::Vertical $self = shift;
	my ($page, $flags) = (shift, shift);
	my (@menuItems) = @_;
	my $activeURL = $page->getActiveURL();

	my @html = ();
	my $publishData = undef;
	if(ref $menuItems[0] eq 'ARRAY')
	{
		$publishData = @menuItems ? \@menuItems : $self->{items};
	}
	else
	{
		my $items = @menuItems ? \@menuItems : $self->{items};
		foreach (@$items)
		{
			my $url = $_->getURL($page);
			push(@$publishData, [$url, $_->getCaption(), $activeURL ? $_->{icon} : $_->{iconSel} ]);
		}
	}
	return createHtmlFromData($page, $self->{flags}, $publishData, $self->{publishDefn});
	#return createHtmlFromData($page, $self->{flags}, $publishData, $self->{publishDefn}, { activePath => $self->getPathAsTree($page) });
}

1;