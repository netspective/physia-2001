###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::HA0;
###################################################################################

use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'HA0';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	
	return "";
}

1;
