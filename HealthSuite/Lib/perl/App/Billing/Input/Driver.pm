##############################################################################
package App::Billing::Input::Driver;
##############################################################################

#
# this is the base class, made up mostly of abstract methods that describes
# how any billing data input driver should be created
#
# any methods needed by all Input drivers should be placed in here
#

use strict;
use Carp;
use App::Billing::Driver;


#
# this object is inherited from App::Billing::Driver
#

use vars qw(@ISA);
@ISA = qw(App::Billing::Driver);


sub populateClaim
{
	my ($self,$claimsList,%params) = @_;

	#
	# here is where all input-driver-specific processing would happen
	# -- e.g., open an XML and populate the Claim
	# -- or, open a database connection and populate the claim
	# -- etc.

	return $self->haveErrors();   # return 1 if successful, 0 if not
}

1;