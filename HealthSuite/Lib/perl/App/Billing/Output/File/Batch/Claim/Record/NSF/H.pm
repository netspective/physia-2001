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

	my $spaces = ' ';
	my $refClaimCareReceiver = $inpClaim->{careReceiver};
	my $proccdureRef = $inpClaim->{procedures};
	my $currentProcedure = $proccdureRef->[$container->getSequenceNo()-1];

	my %nsfType = (
		NSF_HALLEY . "" =>
			sprintf("%-3s%-2s%-17s%17s%-281s",
				$self->recordType(),
				$self->numToStr(2, 0, $container->getSequenceNo()),
				substr($refClaimCareReceiver->getAccountNo(), 0, 17),
				$spaces,
				substr($currentProcedure->getComments(), 0, 281), # comments
			),
	);

  return $nsfType{$nsfType};
}

1;
