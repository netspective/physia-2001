###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::THIN3;
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
	'CB0';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $claimLegalRepresentator = $inpClaim->{legalRepresentator};
	my $claimLegalRepresentatorAddress = $claimLegalRepresentator->{address};

my %payerType = (THIN_COMMERCIAL . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%-1s%-30s%-30s%-20s%-2s%-9s%-10s%-164s",
	$self->recordType(),
	$spaces,	# Reserved Filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17), # Patient Control Number
	substr($claimLegalRepresentator->getLastName ,0,20),    # Last name
	substr($claimLegalRepresentator->getFirstName ,0,12),	# First Name
	substr($claimLegalRepresentator->getMiddleInitial ,0,1),	# Middle Initial
	substr($claimLegalRepresentatorAddress->getAddress1 ,0,30),	# Address 1
	substr($claimLegalRepresentatorAddress->getAddress2 ,0,30),	# Address 2
	substr($claimLegalRepresentatorAddress->getCity ,0,20), 	# City
	substr($claimLegalRepresentatorAddress->getState() ,0,2),	# State
	substr($claimLegalRepresentatorAddress->getZipCode() ,0,9),	# ZipCode
	$spaces,	# Responsible Party Telephone Number
	$spaces,	# Filler National
	),
  );

  return $payerType{$payerType};
}


1;
