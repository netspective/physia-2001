###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::NSF2;
###################################################################################

use strict;
use Carp;


sub new
{
	my ($type,%params) = @_;
	
	return \%params,$type;
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

sub recordType
{
	'CA1';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim) = @_;
	my $spaces = ' ';
	my $zeros = 0;

	return sprintf("%-3s%-2s%-17s%-10s%3d%7d%6d%-9s%1s%-262s",
	$self->recordType(),
	$spaces,
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	$spaces,
	$self->numToStr(3,0,$zeros),
	$self->numToStr(7,0,$zeros),
	$self->numToStr(6,0,$zeros),
	$spaces,
	$spaces,
	$spaces
	);
}

1;
