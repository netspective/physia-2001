##############################################################################
package XAP::Component::Path;
##############################################################################

use strict;
use Exporter;

use XAP::Component;
use XAP::Component::File;
use XAP::Component::File::Unknown;
use XAP::Component::Exception;
use XAP::Component::Menu;
use XAP::Component::Menu::Vertical;

use base qw(XAP::Component::File Exporter);
use fields qw(childMenu);

use enum qw(:PUBLSTYLE_ MENU TABS);

use constant IMAGE_PATHCLOSED	=> '/resources/icons/folder-orange-closed.gif';
use constant IMAGE_PATHOPEN 	=> '/resources/icons/folder-orange-open.gif';

XAP::Component->registerXMLTagClass('path', __PACKAGE__);

sub init
{
	my XAP::Component::Path $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{icon} = IMAGE_PATHCLOSED;
	$self->{childMenu} = new XAP::Component::Menu::Vertical();
	$self;
}

sub applyXML
{
	my XAP::Component::Path $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
		
	#
	# if there is a "src" attribute, we want to load all the components from an a given directory
	# (which MUST be relative to active path and can not be an absolute path)
	#
	if(my $source = $attrs->{src})
	{
		my XAP::Component::Path $childPath = $self->addPath($source, id => $attrs->{id}, caption => $attrs->{caption} || $attrs->{heading}, heading => $attrs->{heading} || $attrs->{caption});
		if(my $translate = $attrs->{'translate-url-params'})
		{
			my @items = split(/,/, $translate);
			$childPath->{translateURLParams} = scalar(@items) > 1 ? \@items : $translate;
		}
	}
	else
	{
		$self->{caption} = $attrs->{caption} if exists $attrs->{caption};
		$self->{heading} = $attrs->{heading} if exists $attrs->{heading};
	}

	#for(my $child = 1; $child < $childCount; $child += 2)
	#{
	#	my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
	#	next unless $chTag;
	#
	#	my $chAttrs = $chContent->[0];
	#	if($chTag eq 'template')
	#	{
	#	}
	#}
	$self;
}

sub getBodyHtml
{
	my XAP::Component::Path $self = shift;
	my ($page, $flags) = @_;

	return $self->{childMenu}->getBodyHtml($page, $flags, $self->getChildrenAsMenuItems($page));
}

1;