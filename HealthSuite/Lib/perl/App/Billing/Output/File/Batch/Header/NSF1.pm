###################################################################################
package App::Billing::Output::File::Batch::Header::NSF1;
###################################################################################

use strict;
use Carp;
use Devel::ChangeLog;

use vars qw(@CHANGELOG);

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
	my ($self, $container, $flags, $inpClaim) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];
	my $claimPayToProvider = $firstClaim->{payToProvider};
	my $claimRenderingProvider = $firstClaim->{renderingProvider};

	
		
	return sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%1s%-15s%-6s%-6s%-15s%-15s%-15s%-15s%-15s%-15s%-33s%-20s%-12s%1s%-3s%-15s%-15s%-15s%-15s%13s%-12s%1s%1s",
	  $self->recordType(),
	  $spaces, # emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
  	  $self->numToStr(9,0,$claimPayToProvider->getFederalTaxId()),  # ne '') ? $claimCareProvider->getFederalTaxId() : $spaces,
	  substr($claimPayToProvider->getSiteId(),0,6), # site id
	  substr($claimPayToProvider->getTaxTypeId(),0,1), # taxId Type
	  substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'C')) ? $claimPayToProvider->getMedicareId() : $spaces,0,10), # medicare no.
	  $spaces, # provider UPIN USIN ID
	  $spaces, # reserved field
      substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'D')) ? $claimPayToProvider->getMedicaidId() : $spaces,0,10) , # medicaid no.
	  substr((($firstClaim->getFilingIndicator() eq 'P') && ($firstClaim->getSourceOfPayment() eq 'H')) ? $claimPayToProvider->getChampusId() : $spaces,0,10), # champus no.
	  substr((($firstClaim->getFilingIndicator() =~ /['P','M']/) || ($firstClaim->getSourceOfPayment() =~ /['G','P']/)) ? $claimPayToProvider->getBlueShieldId() : $spaces,0,13), # bluesield no.
	  $spaces, # commercial no.
	  $spaces, # other no1.
	  $spaces, # other no2.
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['E','X']/) ? $firstClaim->{payToOrganization}->getName() : $spaces ,0,18),
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $claimPayToProvider->getLastName() : $spaces,0,20),
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $claimPayToProvider->getFirstName() : $spaces,0,10),
	  substr(($claimPayToProvider->getTaxTypeId() =~ /['S']/) ? $claimPayToProvider->getMiddleInitial() : $spaces,0,1),
	  substr($claimPayToProvider->getSpecialityId(),0,3), # speciality code
	  $spaces, # speciality license code
	  $spaces, # state license number
	  $spaces, # dentist license number
	  $spaces, # anesthesia license number
	  $spaces, # filler national
	  $spaces, # filler local
	  $spaces, # reserved filler
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? 'N' : 'Y',0,1)
	  );
}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Output NSF Object',
	'Tax Id Type now on will be interperated from 0,1,2 to E,S,X in BA0 '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'AUF',
	'Billing Interface/Output NSF Object',
	'Tax Id Type conversion has been removed from BA0, now on Claim object will perform this conversion'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/04/2000', 'AUF',
	'Billing Interface/Output NSF Object',
	'Function numstr has been replaced with substr function for Provider Tax Id in BA0']
	
);

1;

	
	