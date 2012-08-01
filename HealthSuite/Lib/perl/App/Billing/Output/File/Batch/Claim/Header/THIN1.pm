###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::THIN1;
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


sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0].$temp1[1]."0" x ($lenDec - length($temp1[1]));
	return $fg;
}

sub recordType
{
	'CA0';
}


sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $zeros = "0";
	my $refClaimCareReceiver = $inpClaim->{careReceiver};
	my $refClaimCareReceiverAddress = $refClaimCareReceiver->{address};

my %payerType = (THIN_MEDICARE . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%1s%-3s%-8s%1s%1s%-30s%-30s%-20s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-15s%-6s%-87s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 12), # patient first name
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 30), # patient address 1
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 30), # patient address 2 filler
	substr($refClaimCareReceiverAddress->getCity(), 0, 20), # patient city
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr($refClaimCareReceiver->getStatus(), 0, 1), # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 1),    # patient date of death
	substr($inpClaim->{insured}->[$inpClaim->getClaimType()]->getAnotherHealthBenefitPlan(), 0, 1), # other insurance indicator
	'C',  # claim editing indicator
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces, # filler
	),
	THIN_COMMERCIAL . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%1s%-3s%-8s%1s%1s%-30s%-30s%-20s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-15s%-6s%-87s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 12), # patient first name
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 30), # patient address 1
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 30), # patient address 2
	substr($refClaimCareReceiverAddress->getCity(), 0, 20), # patient city
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr($refClaimCareReceiver->getStatus(), 0, 1), # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 8),    # patient date of death
	substr($inpClaim->{insured}->[$inpClaim->getClaimType()]->getAnotherHealthBenefitPlan(), 0, 1), # other insurance indicator
	'F',      # claim editing indicator
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces,  # filler national
	),
	THIN_MEDICAID . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%1s%-3s%-8s%1s%1s%-30s%-30s%-20s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-15s%-6s%-87s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 12), # patient first name
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 30), # patient address 1
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 30), # patient address 2 filler
	substr($refClaimCareReceiverAddress->getCity(), 0, 20), # patient city
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr($refClaimCareReceiver->getStatus(), 0, 1), # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 1),    # patient date of death
	substr($inpClaim->{insured}->[$inpClaim->getClaimType()]->getAnotherHealthBenefitPlan(), 0, 1), # other insurance indicator
	$spaces,  # claim editing indicator
	'F ',     # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces, # filler
	),
	THIN_BLUESHIELD . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%1s%-3s%-8s%1s%1s%-30s%-30s%-20s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-15s%-6s%-87s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 12), # patient first name
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 30), # patient address 1
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 30), # patient address 2 filler
	substr($refClaimCareReceiverAddress->getCity(), 0, 20), # patient city
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr($refClaimCareReceiver->getStatus(), 0, 1), # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 1),    # patient date of death
	substr($inpClaim->{insured}->[$inpClaim->getClaimType()]->getAnotherHealthBenefitPlan(), 0, 1), # other insurance indicator
	$spaces, # claim editing indicator
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces, # filler
	)
  );

  return $payerType{$payerType};

}

1;
