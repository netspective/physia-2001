##############################################################################
package App::Data::Obtain;
##############################################################################

use strict;
use Carp;
use App::Data::Manipulate;

use vars qw(@ISA);
@ISA = qw(App::Data::Manipulate);

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	#
	# this function is responsible for taking data and populating $self->{data}
	# $self->{data} is a reference to an array of arrays (rows/columns)
	#
	$self->abstract();
}

1;