###################################################################################
package App::Billing::Output::File::Batch::Header::NSF1;
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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];

	my $claimPayToProvider = $firstClaim->{payToOrganization};
	my $claimRenderingProvider = $firstClaim->{renderingProvider};
	my $emcId;
	my $taxId;
	my $taxIdType;

	if ($claimPayToProvider->getTaxId() ne '')
	{
		$taxId = $claimPayToProvider->getTaxId();
		$taxId =~ s/-//g;
		$taxIdType = 'E';
	}
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

my %nsfType = ( NSF_HALLEY . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%13s%-14s",
	  $self->recordType(),
	  substr($emcId,0,15), # group provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
  	  $self->numToStr(9,0,$taxId),  # ne '') ? $claimCareProvider->getTaxId() : $spaces,
	  $spaces, #substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($taxIdType,0,1), # taxId Type
	  $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # reserved filler
      $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # reserved filler
	  $spaces, # commercial no.
	  $spaces, # provider XTID
	  $spaces, # other no2.
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,18),
	  $spaces, #substr($claimPayToProvider->getLastName(),0,20),
	  $spaces, #substr($claimPayToProvider->getFirstName(),0,10),
	  $spaces, #substr($claimPayToProvider->getMiddleInitial(),0,1),
	  substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # reserved filler
	  $spaces, # filler local
	  ),
	  NSF_THIN . "" =>
	  sprintf("%-3s%-15s%-3s%4d%-6s%-9s%-6s%-1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%-1s%-3s%-15s%-15s%-15s%-15s%-1s%-26s",
	  $self->recordType(),
	  substr($emcId,0,15), # group provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()), # batch no
	  $self->numToStr(6,0,$container->getSequenceNo()),  # batch id
  	  $self->numToStr(9,0,$claimPayToProvider->getTaxId()),  # ne '') ? $claimCareProvider->getTaxId() : $spaces,
	  $spaces, # reserved
	  substr($claimPayToProvider->getTaxTypeId(),0,1), # taxId Type
	  $spaces, # national provider id
	  substr($claimRenderingProvider->getPIN(),0,6), # prov UPIN-USIN id
	  $spaces, # reserved filler
      $spaces, # prov medicaid no
	  $spaces, # prov champus no
	  $spaces, # prov blue sheild no
	  $spaces, # prov commercial no.
	  $spaces, # prov no 1
	  $spaces, # prov no 2
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,33),
	  $spaces, #substr($claimPayToProvider->getLastName(),0,20),
	  $spaces, #substr($claimPayToProvider->getFirstName(),0,10),
	  $spaces, #substr($claimPayToProvider->getMiddleInitial(),0,1),
	  substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license number
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # prov participate ind
	  $spaces, # filler national
	  ),
	  NSF_ENVOY . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%13s%-12s%1s%1s",
	  $self->recordType(),
	  substr($emcId,0,15), # emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
  	  $self->numToStr(9,0,$claimPayToProvider->getTaxId()),  # ne '') ? $claimCareProvider->getTaxId() : $spaces,
	  $spaces, #substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($claimPayToProvider->getTaxTypeId(),0,1), # taxId Type
	  substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'C')) ? $claimPayToProvider->getMedicareId() : $spaces,0,10), # medicare no.
	  $spaces, # provider UPIN USIN ID
	  $spaces, # reserved field
      substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'D')) ? $claimPayToProvider->getMedicaidId() : $spaces,0,10) , # medicaid no.
	  substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'H')) ? $claimPayToProvider->getChampusId() : $spaces,0,10), # champus no.
	  substr((($firstClaim->getFilingIndicator() =~ /['P','M']/) || ($firstClaim->getSourceOfPayment() =~ /['G','P']/)) ? $spaces : $spaces,0,13), # $claimPayToProvider->getBlueShieldId() bluesield no.
	  $spaces, # commercial no.
	  $spaces, # other no1.
	  $spaces, # other no2.
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,18),
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $spaces : $spaces,0,20), # $claimPayToProvider->getLastName()
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $spaces : $spaces,0,10), # $claimPayToProvider->getFirstName()
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $spaces : $spaces,0,1), # $claimPayToProvider->getMiddleInitial()
	  substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # filler national
	  $spaces, # filler local
	  $spaces, # reserved filler
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? 'N' : 'Y',0,1)
	  )
   );

   	return $nsfType{$nsfType};
}


1;


