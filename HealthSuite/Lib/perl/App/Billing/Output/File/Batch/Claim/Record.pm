###################################################################################
package App::Billing::Output::File::Batch::Claim::Record;
###################################################################################

use strict;
use Carp;

sub new
{
	my ($type,%params) = @_;
	
	return bless \%params,$type;
}



1;
