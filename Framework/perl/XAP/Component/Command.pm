##############################################################################
package XAP::Component::Command;
##############################################################################

use strict;
use Exporter;
use XAP::Component;

use base qw(XAP::Component Exporter);
use fields qw(dialogFlags);

use constant COMPCMDFLAG_FIRSTAVAIL => COMPFLAG_LASTFLAGID;

sub init
{
	my XAP::Component::Command $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{dialogFlags} = exists $params{dialogFlags} ? $params{dialogFlags} : undef;
	$self;
}

sub applyXML
{
	my XAP::Component::Command $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);	
	$self->{dialogFlags} = &XAP::Component::Dialog::createDialogFlagsFromText(undef, $attrs->{when});
	
	#for(my $child = 1; $child < $childCount; $child += 2)
	#{
	#	my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
	#}
	$self;
}

sub execute
{
	my XAP::Component::Command $self = shift;
	my ($page, $flags, $execParams) = @_;
	
	
}

1;