###################################################################################
package App::Billing::Output::File::Batch::Header::THIN1;
###################################################################################

use strict;
use Carp;



# for exporting NSF Constants
use App::Billing::Universal;


sub new
{
	my ($type,%params) = @_;

	return \%params,$type;
}

sub recordType
{
	'BA0';
}

sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
	return $fg;
}


sub batchType
{
	'100';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];

	my $claimPayToProvider = $firstClaim->{payToProvider};
	my $claimRenderingProvider = $firstClaim->{renderingProvider};
	my $emcId;
	my $taxId;
	my $taxIdType;

	if ($claimPayToProvider->getTaxId() ne '')
	{
		$taxId = $claimPayToProvider->getTaxId();
		$taxId =~ s/-//g;
		$taxIdType = 'S';
	}
	#elsif($claimPayToProvider->getFederalTaxId() ne '')
	#{
	#	$taxId = $claimPayToProvider->getFederalTaxId();
	#	$taxId =~ s/-//g;
	#	$taxIdType = 'E';
	#}
	else
	{
		$taxIdType = '';
	}


	for my $eachClaim (0..$#$inpClaim)
	{
		$emcId = $inpClaim->[$eachClaim]->getEMCId();

		if ($emcId ne "")
		{
			last;
		}
	}

my %payerType = ( THIN_MEDICARE . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%1s%-26s",
	  $self->recordType(),
	  $spaces, #substr($emcId,0,15), # emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $self->numToStr(6,0,$container->getSequenceNo()), #batch id
  	  $self->numToStr(9,0,$taxId),  # ne '') ? $claimCareProvider->getFederalTaxId() : $spaces,
	  $spaces, #substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($taxIdType,0,1), # taxId Type
	  substr($claimPayToProvider->getMedicareId(),0,15), # provider medicare no.
	  $spaces, # reserved filler
	  $spaces, # reserved filler
      $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # commercial no.
	  $spaces, # provider XTID
	  $spaces, # other no2.
	  $spaces, # substr(($taxIdType =~ /['E','X']/) ? $claimPayToProvider->getName() : $spaces ,0,33),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getLastName() : $spaces,0,20),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getFirstName(): $spaces,0,12),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getMiddleInitial(): $spaces,0,1),
	  $spaces, # substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # reserved filler
	  $spaces, # filler local
	  ),
	  THIN_COMMERCIAL . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%1s%-26s",
	  $self->recordType(),
	  $spaces, #substr($emcId,0,15), # group provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()), # batch no
	  $self->numToStr(6,0,$container->getSequenceNo()),  # batch id
  	  $self->numToStr(9,0,$taxId),  # ne '') ? $claimCareProvider->getFederalTaxId() : $spaces,
	  $spaces, # reserved
	  substr($taxIdType,0,1), # taxId Type
	  $spaces, # national provider id
	  substr($claimRenderingProvider->getPIN(),0,6), # prov UPIN-USIN id
	  $spaces, # reserved filler
      substr($claimPayToProvider->getMedicaidId(),0,15), # medicaid no.
	  $spaces, # prov champus no
	  substr($claimPayToProvider->getMedicareId(),0,15), # blueshield no to be filled
	  $spaces, # prov commercial no.
	  $spaces, # prov no 1
	  $spaces, # prov no 2
	  $spaces, # substr(($taxIdType =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,33),
	  substr(($taxIdType eq 'S') ? $claimPayToProvider->getLastName() : $spaces,0,20),
	  substr(($taxIdType eq 'S') ? $claimPayToProvider->getFirstName(): $spaces,0,12),
	  substr(($taxIdType eq 'S') ? $claimPayToProvider->getMiddleInitial(): $spaces,0,1),
	  substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license number
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # prov participate ind
	  $spaces, # filler national
	  ),
	  THIN_MEDICAID . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%1s%-26s",
	  $self->recordType(),
	  $spaces, #substr($emcId,0,15), # emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $self->numToStr(6,0,$container->getSequenceNo()), #batch id
  	  $self->numToStr(9,0,$taxId),  # ne '') ? $claimCareProvider->getFederalTaxId() : $spaces,
	  $spaces, #substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($taxIdType,0,1), # taxId Type
	  $spaces,
	  $spaces, # reserved filler
	  $spaces, # reserved filler
      substr($claimPayToProvider->getMedicaidId(),0,15), # medicaid no.
	  $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # commercial no.
	  $spaces, # provider XTID
	  $spaces, # other no2.
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,33),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getLastName() : $spaces,0,20),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getFirstName(): $spaces,0,12),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getMiddleInitial(): $spaces,0,1),
	  $spaces, # substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # reserved filler
	  $spaces, # filler local
	  ),
	  THIN_BLUESHIELD . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%1s%-26s",
	  $self->recordType(),
	  $spaces, #substr($emcId,0,15), # emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $self->numToStr(6,0,$container->getSequenceNo()), #batch id
  	  $self->numToStr(9,0,$taxId),  # ne '') ? $claimCareProvider->getFederalTaxId() : $spaces,
	  $spaces, #substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($taxIdType,0,1), # taxId Type
	  $spaces,
	  $spaces, # reserved filler
	  $spaces, # reserved filler
      $spaces, # reserved filler
	  $spaces, # reserved filler
	  substr($claimPayToProvider->getMedicareId(),0,15), # blueshield no to be filled
	  $spaces, # commercial no.
	  $spaces, # provider XTID
	  $spaces, # other no2.
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,33),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getLastName() : $spaces,0,20),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getFirstName(): $spaces,0,12),
	  $spaces, # substr(($claimPayToProvider->getTaxTypeId() eq 'S') ? $claimRenderingProvider->getMiddleInitial(): $spaces,0,1),
	  $spaces, # substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # reserved filler
	  $spaces, # filler local
	  )
   );

   	return $payerType{$payerType};
}


1;


