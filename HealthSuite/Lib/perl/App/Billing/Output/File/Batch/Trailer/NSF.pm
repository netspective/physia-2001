###################################################################################
package App::Billing::Output::File::Batch::Trailer::NSF;
###################################################################################

use strict;
use Carp;

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
	
	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
	return $fg; 
}


sub formatData
{
	my ($self, $container, $flags, $inpClaim) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];
	my $claimPayToProvider = $firstClaim->{payToProvider};

	return sprintf("%-3s%-15s%-3s%4s%-6s%-9s%-6s%7s%7s%7s%9s%-121s%-114s%9s",
	  $self->recordType(),
	  $spaces, #emc provider id
	  $self->batchType(),
	  $self->numToStr(4,0,$container->getSequenceNo()),
	  $spaces, # batch id
	  $self->numToStr(9,0,$claimPayToProvider->getFederalTaxId()),
	  $spaces, # reserved filler
	  $self->numToStr(7,0,$container->{batchServiceLineCount}),
	  $self->numToStr(7,0,$container->{batchRecordCount}),
	  $self->numToStr(7,0,$container->{batchClaimCount}),
	  $self->numToStr(7,2,$container->{batchTotalCharges}),
	  $spaces, # filler national
	  $spaces, # filler local
	  $self->numToStr(9,0,'0')
	  );
}

1;
