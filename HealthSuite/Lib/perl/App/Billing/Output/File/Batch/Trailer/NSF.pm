###################################################################################
package App::Billing::Output::File::Batch::Trailer::NSF;
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
	'YA0';
}

sub batchType
{
	'100';
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


sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];
	my $claimPayToProvider = $firstClaim->{payToOrganization};
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
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%7s%7s%7s%9s%-121s%-123s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
	  $self->numToStr(9,0,$taxId),
	  $spaces, # reserved filler
	  $self->numToStr(7,0,$container->{batchServiceLineCount}),
	  $self->numToStr(7,0,$container->{batchRecordCount}),
	  $self->numToStr(7,0,$container->{batchClaimCount}),
	  $self->numToStr(7,2,$container->{batchTotalCharges}),
	  $spaces, # filler national
	  $spaces, # filler local
	  ),
	  NSF_THIN . "" =>
	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%7s%7s%7s%9s%-244s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()), # batch no
	  $spaces, # batch id
	  $self->numToStr(9,0,$claimPayToProvider->getTaxId()),
	  $spaces, # reserved filler
	  $self->numToStr(7,0,$container->{batchServiceLineCount}),
	  $self->numToStr(7,0,$container->{batchRecordCount}),
	  $self->numToStr(7,0,$container->{batchClaimCount}),
	  $self->numToStr(7,2,$container->{batchTotalCharges}),
	  $spaces, # filler national
	  ),
	  NSF_ENVOY . "" =>
  	  sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%7s%7s%7s%9s%-121s%-114s%9s",
	  $self->recordType(),
	  substr($emcId,0,15), #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
	  $self->numToStr(9,0,$claimPayToProvider->getTaxId()),
	  $spaces, # reserved filler
	  $self->numToStr(7,0,$container->{batchServiceLineCount}),
	  $self->numToStr(7,0,$container->{batchRecordCount}),
	  $self->numToStr(7,0,$container->{batchClaimCount}),
	  $self->numToStr(7,2,$container->{batchTotalCharges}),
	  $spaces, # filler national
	  $spaces, # filler local
	  $self->numToStr(9,0,'0')
	  )
   );

   	return $nsfType{$nsfType};
}




1;
