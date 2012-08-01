##############################################################################
package App::Data::Transform;
##############################################################################

use strict;
use Carp;
use App::Data::Manipulate;

use vars qw(@ISA);
@ISA = qw(App::Data::Manipulate);

sub transform
{
	my ($self, $flags, $collection, %params) = @_;

	$self->prepare($flags, $collection, \%params);
	$self->process($flags, $collection, \%params);
	$self->conclude($flags, $collection, \%params);
}

sub prepare
{
	#my ($self, $flags, $collection, $params) = @_;
}

sub process
{
	my ($self, $flags, $collection, $params) = @_;
	$self->abstract();
}

sub conclude
{
	#my ($self, $flags, $collection, $params) = @_;
}

1;