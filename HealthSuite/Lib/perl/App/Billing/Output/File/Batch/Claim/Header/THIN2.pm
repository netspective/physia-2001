###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::THIN2;
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

sub numToStr
{
	my($self,$len,$lenDec,$tarString, $payerType) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0].$temp1[1]."0" x ($lenDec - length($temp1[1]));
	return $fg;
}

sub recordType
{
	'CA1';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $zeros = 0;

my %payerType = (THIN_MEDICARE . "" =>
	sprintf("%-3s%-2s%-17s%-10s%3d%7d%6d%-9s%1s%-200s%-10s%-25s%-7s%-1s%-1s%-1s%-16s",
	$self->recordType(),
	$spaces,
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	$spaces,
	$self->numToStr(3,0,$zeros),
	$self->numToStr(7,0,$zeros),
	$self->numToStr(6,0,$zeros),
	$spaces,
	$spaces,
	$spaces, # filler national
	$spaces, # contact number
	$spaces, # filler
	$spaces, # insured out of pocket #1
	$spaces, # provider adjustment
	$spaces, # late charge claim
	$spaces, # new patient
	$spaces, # filler
	),
	THIN_COMMERCIAL . "" =>
	sprintf("%-3s%-2s%-17s%-10s%3d%7d%6d%9d%-1s%-262s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	$spaces, # purchase order no
	$spaces, # tribe
	$spaces, # residency code
	$spaces, # pat health rec
	$spaces, # auth fac no
	$spaces, # multi claim ind
	$spaces, # filler national
	),
	THIN_MEDICAID . "" =>
	sprintf("%-3s%-2s%-17s%-10s%3d%7d%6d%-9s%1s%-262s",
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
    ),
	THIN_BLUESHIELD . "" =>
	sprintf("%-3s%-2s%-17s%-10s%3d%7d%6d%-9s%1s%-262s",
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
    )
  );

  return $payerType{$payerType};
}

1;
