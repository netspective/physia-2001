###################################################################################
package App::Billing::Output::File::Batch::Claim::Trailer::THIN;
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
	'XA0';
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


sub formatData
{

	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';

my %payerType = (THIN_MEDICARE . "" =>
	sprintf("%-3s%-2s%-17s%2s%2s%2s%2s%2s%2s%3s%-40s%7s%7s%7s%7s%7s%7s%7s%7s%7s%-16s%-103s%-61s",
	$self->recordType(),
	$spaces, # not used
	$inpClaim->{careReceiver}->getAccountNo(),
	$self->numToStr(2,0,$container->getCountXXX('cXXX')),
	$self->numToStr(2,0,$container->getCountXXX('dXXX')),
	$self->numToStr(2,0,$container->getCountXXX('eXXX')),
	$self->numToStr(2,0,$container->getCountXXX('fXXX') + $container->getCountXXX('fA0XXX')),
	$self->numToStr(2,0,$container->getCountXXX('gXXX')),
	$self->numToStr(2,0,$container->getCountXXX('hXXX')),
	$self->numToStr(3,0,$container->getCountXXX()),
	$spaces,
	$self->numToStr(5,2,abs($inpClaim->getTotalCharge())),
	$self->numToStr(5,2,abs($container->{totalDisallowedCostContainmentCharges})),
	$self->numToStr(5,2,abs($container->{totalDisallowedOtherCharges})),
	$self->numToStr(5,2,abs($container->{totalAllowedAmount})),
	$self->numToStr(5,2,abs($container->{totalDeductibleAmount})),
	$self->numToStr(5,2,abs($container->{totalCoinsuranceAmount})),
	$self->numToStr(5,2,abs($inpClaim->{payer}->getAmountPaid())), # payer total amount paid
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())), # patient amount paid i.e. total adjusted amount from invoice
	$self->numToStr(5,2,abs($container->{totalPurchaseServiceCharges})),
	$spaces, # provider discount amount
	$spaces, # remarks
	$spaces, # filler national
	),
	THIN_COMMERCIAL . "" =>
	sprintf("%-3s%-2s%-17s%2s%2s%2s%2s%2s%2s%3s%-40s%7s%7s%7s%7s%7s%7s%7s%7s%7s%-16s%-103s%-61s",
	$self->recordType(),
	$spaces, # not used
	$inpClaim->{careReceiver}->getAccountNo(),
	$self->numToStr(2,0,$container->getCountXXX('cXXX')),
	$self->numToStr(2,0,$container->getCountXXX('dXXX')),
	$self->numToStr(2,0,$container->getCountXXX('eXXX')),
	$self->numToStr(2,0,$container->getCountXXX('fXXX') + $container->getCountXXX('fA0XXX')),
	$self->numToStr(2,0,$container->getCountXXX('gXXX')),
	$self->numToStr(2,0,$container->getCountXXX('hXXX')),
	$self->numToStr(3,0,$container->getCountXXX()),
	$spaces,
	$self->numToStr(5,2,abs($inpClaim->getTotalCharge())),
	$self->numToStr(5,2,abs($container->{totalDisallowedCostContainmentCharges})),
	$self->numToStr(5,2,abs($container->{totalDisallowedOtherCharges})),
	$self->numToStr(5,2,abs($container->{totalAllowedAmount})),
	$self->numToStr(5,2,abs($container->{totalDeductibleAmount})),
	$self->numToStr(5,2,abs($container->{totalCoinsuranceAmount})),
	$self->numToStr(5,2,abs($inpClaim->{payer}->getAmountPaid())), # payer total amount paid
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())), # patient amount paid i.e. total adjusted amount from invoice
	$self->numToStr(5,2,abs($container->{totalPurchaseServiceCharges})),
	$spaces, # provider discount amount
	$spaces, # remarks
	$spaces, # filler national
	),
	THIN_MEDICAID . "" =>
	sprintf("%-3s%-2s%-17s%2s%2s%2s%2s%2s%2s%3s%-40s%7s%7s%7s%7s%7s%7s%7s%7s%7s%-16s%-103s%-61s",
	$self->recordType(),
	$spaces, # not used
	$inpClaim->{careReceiver}->getAccountNo(),
	$self->numToStr(2,0,$container->getCountXXX('cXXX')),
	$self->numToStr(2,0,$container->getCountXXX('dXXX')),
	$self->numToStr(2,0,$container->getCountXXX('eXXX')),
	$self->numToStr(2,0,$container->getCountXXX('fXXX') + $container->getCountXXX('fA0XXX')),
	$self->numToStr(2,0,$container->getCountXXX('gXXX')),
	$self->numToStr(2,0,$container->getCountXXX('hXXX')),
	$self->numToStr(3,0,$container->getCountXXX()),
	$spaces,
	$self->numToStr(5,2,abs($inpClaim->getTotalCharge())),
	$self->numToStr(5,2,abs($container->{totalDisallowedCostContainmentCharges})),
	$self->numToStr(5,2,abs($container->{totalDisallowedOtherCharges})),
	$self->numToStr(5,2,abs($container->{totalAllowedAmount})),
	$self->numToStr(5,2,abs($container->{totalDeductibleAmount})),
	$self->numToStr(5,2,abs($container->{totalCoinsuranceAmount})),
	$self->numToStr(5,2,abs($inpClaim->{payer}->getAmountPaid())), # payer total amount paid
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())), # patient amount paid i.e. total adjusted amount from invoice
	$self->numToStr(5,2,abs($container->{totalPurchaseServiceCharges})),
	$spaces, # provider discount amount
	$spaces, # remarks
	$spaces, # filler national
	),
	THIN_BLUESHIELD . "" =>
	sprintf("%-3s%-2s%-17s%2s%2s%2s%2s%2s%2s%3s%-40s%7s%7s%7s%7s%7s%7s%7s%7s%7s%-16s%-103s%-61s",
	$self->recordType(),
	$spaces, # not used
	$inpClaim->{careReceiver}->getAccountNo(),
	$self->numToStr(2,0,$container->getCountXXX('cXXX')),
	$self->numToStr(2,0,$container->getCountXXX('dXXX')),
	$self->numToStr(2,0,$container->getCountXXX('eXXX')),
	$self->numToStr(2,0,$container->getCountXXX('fXXX') + $container->getCountXXX('fA0XXX')),
	$self->numToStr(2,0,$container->getCountXXX('gXXX')),
	$self->numToStr(2,0,$container->getCountXXX('hXXX')),
	$self->numToStr(3,0,$container->getCountXXX()),
	$spaces,
	$self->numToStr(5,2,abs($inpClaim->getTotalCharge())),
	$self->numToStr(5,2,abs($container->{totalDisallowedCostContainmentCharges})),
	$self->numToStr(5,2,abs($container->{totalDisallowedOtherCharges})),
	$self->numToStr(5,2,abs($container->{totalAllowedAmount})),
	$self->numToStr(5,2,abs($container->{totalDeductibleAmount})),
	$self->numToStr(5,2,abs($container->{totalCoinsuranceAmount})),
	$self->numToStr(5,2,abs($inpClaim->{payer}->getAmountPaid())), # payer total amount paid
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())), # patient amount paid i.e. total adjusted amount from invoice
	$self->numToStr(5,2,abs($container->{totalPurchaseServiceCharges})),
	$spaces, # provider discount amount
	$spaces, # remarks
	$spaces, # filler national
	)
  );

  	return $payerType{$payerType};
}


1;