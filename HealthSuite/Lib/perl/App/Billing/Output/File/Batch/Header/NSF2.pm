###################################################################################
package App::Billing::Output::File::Batch::Header::NSF2;
###################################################################################

#use strict;
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
	'BA1';
}

sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0].$temp1[1]."0" x ($lenDec - length($temp1[1]));
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
	my $taxId;
	my $taxTypeId;


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
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress1() : $spaces,0,30),
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress2() : $spaces,0,30),
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getCity() : $spaces,0,20),
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getState() : $spaces,0,2),
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getZipCode().$self->numToStr(9 - length($claimRenderingProvierAddress->getZipCode()),0,$claimRenderingProvierAddress->getZipCode()) : $spaces,0,5),
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getTelephoneNo(): $spaces,0,10), # service Phone No.
	  substr($claimPayToProviderAddress->getAddress1(),0,30),
	  substr($claimPayToProviderAddress->getAddress2(),0,30),
	  substr($claimPayToProviderAddress->getCity(),0,20),
	  substr($claimPayToProviderAddress->getState(),0,2),
  	  substr($claimPayToProviderAddress->getZipCode(),0,5).$self->numToStr(9 - length($claimPayToProviderAddress->getZipCode()),0,$claimPayToOrganizationAddress->getZipCode()),
	  substr($claimPayToProviderAddress->getTelephoneNo(),0,10),
	  $spaces, # filler national
	  $spaces, # filler local
	  ),
	  NSF_THIN . "" =>
	  sprintf("%-3s%-15s%-3s%4d%-6s%-3s%-30s%-30s%-20s%-2s%-9s%-10s%-30s%-30s%-20s%-2s%-9s%-10s%-84s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()), # batch no
	  $spaces, # batch id
	  substr($claimPayToOrganization->getOrganizationType(),0,3), # prov type organization
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress1() : $spaces,0,30), # prov svc addr1
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getAddress2() : $spaces,0,30), # prov svc addr2
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getCity() : $spaces,0,20), # prov svc city
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getState() : $spaces,0,2), # prov svc state
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getZipCode().$self->numToStr(9 - length($claimRenderingProvierAddress->getZipCode()),0,$claimRenderingProvierAddress->getZipCode()) : $spaces,0,5), # prov svc zipcode
	  substr(($container->checkSamePayToOrgAndRenderProvider($inpClaim->[0]) eq '0') ? $claimRenderingProvierAddress->getTelephoneNo(): $spaces,0,10), # service Phone No.
	  substr($claimPayToProviderAddress->getAddress1(),0,30), # prov pay to addr1
	  substr($claimPayToProviderAddress->getAddress2(),0,30), # prov pay to addr2
	  substr($claimPayToProviderAddress->getCity(),0,20), # prov pay to city
	  substr($claimPayToProviderAddress->getState(),0,2), # prov pay to state
  	  substr($claimPayToProviderAddress->getZipCode(),0,5).$self->numToStr(9 - length($claimPayToProviderAddress->getZipCode()),0,$claimPayToOrganizationAddress->getZipCode()), # prov pay to zipcode
	  substr($claimPayToProviderAddress->getTelephoneNo(),0,10), # prov pay to phone
	  $spaces, # filler national
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


1;