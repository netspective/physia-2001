##############################################################################
package XAP::Component::File;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(fileName);

sub init
{
	my XAP::Component::File $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{fileName} = exists $params{fileName} ? $params{fileName} : undef;

	$self;
}

1;