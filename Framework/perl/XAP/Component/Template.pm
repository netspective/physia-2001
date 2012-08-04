##############################################################################
package XAP::Component::Template;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(bodyTemplate);

XAP::Component->registerXMLTagClass('template', __PACKAGE__);

sub init
{
	my XAP::Component::Template $self = shift;
	$self->SUPER::init(@_);
	$self->clearFlag(COMPFLAG_URLADDRESSABLE);
	$self;
}

sub applyXML
{
	my XAP::Component::Template $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);
	$self->{bodyTemplate} = getTreeAsXMLText($content);
	$self;
}

sub getTemplate
{
	my XAP::Component::Template $self = shift;
	return $self->{bodyTemplate};
}

sub getBodyHtml
{
	my XAP::Component::Template $self = shift;
	my ($page, $flags) = @_;
	
	my $processor = $self->{templateProcessor} ?
		$self->{templateProcessor} :
		new Text::Template(
				TYPE => 'STRING',
				SOURCE => $self->{bodyTemplate},
				PREPEND => q{
					use strict;
					use vars qw($self $page $mc $flags $controller);
					use XAP::Component;
					use XAP::Component::Template;
					},
				DELIMITERS => ['<%', '%>'],
				);

	no strict 'refs';
	my $package = (ref $self) . 'TMPL_NS';
	${"$package\::self"} = $self;
	${"$package\::mc"} = $page->{mainComponent} || $self;     # the main component
	${"$package\::controller"} = $page->{page_controller} || undef;
	${"$package\::page"} = $page;
	${"$package\::flags"} = $flags;

	#return "$self $page $flags";
	return $processor->fill_in(PACKAGE => $package);
}

1;