###################################################################################
package App::Billing::Output::File::Batch::Header::NSF2;
###################################################################################

#use strict;
use Carp;

use vars qw(@CHANGELOG);

# for exporting NSF Constants
use App::Billing::Universal;


sub new
{
	my ($type,%params) = @_;
	
	return \%params,$type;
}
	
sub recordType
{
	'BA1';
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
	my $claimPayToOrganization = $firstClaim->{payToOrganization};
	my $claimPayToProvider = $firstClaim->{payToProvider};
	my $claimRenderingProvier = $firstClaim->{renderingProvider};
	
	my $claimPayToOrganizationAddress = $claimPayToOrganization->{address};
	my $claimPayToProviderAddress = $claimPayToProvider->{address};
	my $claimRenderingProvierAddress = $claimRenderingProvier->{address};
	
	my $emcId;
	
	for my $eachClaim (0..$#$inpClaim)
	{
		$emcId = $inpClaim->[$eachClaim]->getEMCId();
		
		if ($emcId ne "")
		{
			last;
		}
	}

my %nsfType = ( NSF_HALLEY . "" =>		
	  sprintf("%-3s%-15s%-3s%4d%-6s%-3s%-30s%-30s%-20s%-2s%-9s%-10s%-30s%-30s%-20s%-2s%-9s%-10s%-42s%-42s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
	  substr($claimPayToOrganization->getOrganizationType(),0,3), # type organization
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress1() : $spaces,0,30),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress2() : $spaces,0,30),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getCity() : $spaces,0,20),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getState() : $spaces,0,2),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getZipCode().$self->numToStr(9 - length($claimRenderingProvierAddress->getZipCode()),0,$claimRenderingProvierAddress->getZipCode()) : $spaces,0,5),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getTelephoneNo(): $spaces,0,10), # service Phone No.
	  substr($claimPayToProviderAddress->getAddress1(),0,30),
	  substr($claimPayToProviderAddress->getAddress2(),0,30),
	  substr($claimPayToProviderAddress->getCity(),0,20),
	  substr($claimPayToProviderAddress->getState(),0,2),
  	  substr($claimPayToProviderAddress->getZipCode(),0,5).$self->numToStr(9 - length($claimPayToProviderAddress->getZipCode()),0,$claimPayToOrganizationAddress->getZipCode()),
	  substr($claimPayToProviderAddress->getTelephoneNo(),0,10),
	  $spaces, # filler national
	  $spaces, # filler local
	  ),
	  NSF_ENVOY . "" => 
	  sprintf("%-3s%-15s%-3s%4d%-6s%-3s%-30s%-30s%-20s%-2s%-9s%-10s%-30s%-30s%-20s%-2s%-9s%-10s%-42s%-42s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
	  substr($claimPayToOrganization->getOrganizationType(),0,3), # type organization
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress1() : $spaces,0,30),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress2() : $spaces,0,30),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getCity() : $spaces,0,20),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getState() : $spaces,0,2),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getZipCode().$self->numToStr(9 - length($claimRenderingProvierAddress->getZipCode()),0,$claimRenderingProvierAddress->getZipCode()) : $spaces,0,5),
	  substr(($container->checkSamePayToAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getTelephoneNo(): $spaces,0,10), # service Phone No.
	  substr($claimPayToProviderAddress->getAddress1(),0,30),
	  substr($claimPayToProviderAddress->getAddress2(),0,30),
	  substr($claimPayToProviderAddress->getCity(),0,20),
	  substr($claimPayToProviderAddress->getState(),0,2),
  	  substr($claimPayToProviderAddress->getZipCode(),0,5).$self->numToStr(9 - length($claimPayToProviderAddress->getZipCode()),0,$claimPayToOrganizationAddress->getZipCode()),
	  substr($claimPayToProviderAddress->getTelephoneNo(),0,10),
	  $spaces, # filler national
	  $spaces, # filler local
	  )
	 ); 
	 
	 return $nsfType{$nsfType}; 
}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/30/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of BA1 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']
);

1;