###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::NSF1;
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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $zeros = "0";
	my $refClaimCareReceiver = $inpClaim->{careReceiver};
	my $refClaimCareReceiverAddress = $refClaimCareReceiver->{address};
	my $anotherPlan = '3';

	if($inpClaim->{policy}->[1]->{name} ne '')
	{
		$anotherPlan = '1';
	}


my %nsfType = (NSF_HALLEY . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-10s%-2s%1s%-3s%-8s%1s%1s%-18s%-12s%-30s%-15s%-5s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-13s%-2s%-6s%-4s%-4s%-2s%-1s%-1s%-8s%-2s%-1s%-1s%-1s%-2s%-2s%-8s%-3s%-1s%-8s%-1s%-1s%-1s%-1s%-1s%-1s%-2s%-4s%-1s%-25s",
	$self->recordType(),
	$spaces, # reserved filler
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 10), # patient first name
	$spaces,
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 18), # patient address 1
	$spaces,					# patient address 1 filler
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 18), # patient address 2 filler
	substr($refClaimCareReceiverAddress->getCity(), 0, 15), # patient city
	$spaces,					#city filler
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr(($refClaimCareReceiver->getStatus() =~ /['N','P']/) ? 'U' : $refClaimCareReceiver->getStatus(), 0, 1)  , # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 1),    # patient date of death
	substr($anotherPlan, 0, 1), # other insurance indicator
	'F',  # claim editing indicator
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	$spaces,  # Provider Number Filler 02 spaces
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces,  # local code
	$spaces, # category/serv/type
	$spaces, # referring provider type
	$spaces, # handicaped child program
	$spaces, # chap-childrens health plan
	$spaces, # other referring physician ID
	$spaces, # patient status/condition code
	$spaces, # authorization exception code
	$spaces, # adjustment code
	$spaces, # diagnosis code method
	$spaces, # co-pay bypass code
	$spaces, # abortion/sterilization code
	$spaces, # case manager id
	$spaces, # number of visits referred
	$spaces, # 90 day indicator
	$spaces, # medicare paid date
	$spaces, # additional unit allowance for age
	$spaces, # hypothermia indicator
	$spaces, # additional unit allowance for hypotension
	$spaces, # additional unit allowance for hyperbaric pressure
	$spaces, # additional unit allowance for emergency
	$spaces, # additional unit allowance for swan-ganz unit
	$spaces, # treatment hour
	$spaces, # department code
	$spaces, # filler
	$spaces, # filler
	),
	NSF_THIN . "" =>
	sprintf("%-3s%-2s%-17s%-20s%-12s%-1s%-3s%-8s%-1s%-1s%-30s%-30s%-20s%-2s%-9s%-10s%-1s%-1s%-1s%-1s%-8s%-1s%-1s%-2s%-1s%-9s%-17s%-15s%-6s%-87s",
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
	$spaces,  # claim editing indicator
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces,  # filler national
	),
	NSF_ENVOY . "" =>
	sprintf("%-3s%1s%1s%-17s%-20s%-10s%-2s%1s%-3s%-8s%1s%1s%-18s%-12s%-30s%-15s%-5s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-13s%-2s%-6s%-20s%-43s%-14s%-10s",
	$self->recordType(),
	$spaces, # *** As suggested by Envoy *** # substr(($inpClaim->getSourceOfPayment() eq 'F' ? $spaces : 'B'),0,1), # TPO Participation Indicator
	$spaces, # Type of Transaction
	substr($refClaimCareReceiver->getAccountNo(), 0, 17), # patient control number
	substr($refClaimCareReceiver->getLastName(), 0, 20),  # patient last name
	substr($refClaimCareReceiver->getFirstName(), 0, 10), # patient first name
	$spaces,
	substr($refClaimCareReceiver->getMiddleInitial(), 0, 1), # patient middle initial
	$spaces, # patient generation
	substr($refClaimCareReceiver->getDateOfBirth(), 0, 8), # patient date of birth
	substr($refClaimCareReceiver->getSex(),0,1), # patient sex
	$spaces, # patient type of residence
	substr($refClaimCareReceiverAddress->getAddress1(), 0, 18), # patient address 1
	$spaces,					# patient address 1 filler
	substr($refClaimCareReceiverAddress->getAddress2(), 0, 18), # patient address 2 filler
	substr($refClaimCareReceiverAddress->getCity(), 0, 15), # patient city
	$spaces,					#city filler
	substr($refClaimCareReceiverAddress->getState(), 0, 2), # patient state
	substr($refClaimCareReceiverAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimCareReceiverAddress->getZipCode()),0,"0"), # patient zip code
	substr($refClaimCareReceiverAddress->getTelephoneNo(), 0, 10), # patient telephone no.
	substr($refClaimCareReceiver->getStatus(), 0, 1), # patient marital status
	substr($refClaimCareReceiver->getStudentStatus(), 0, 1), # patient student status
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1), # patient employement status
	substr($refClaimCareReceiver->getDeathIndicator(), 0, 1),    # patient death indicator
	substr(($refClaimCareReceiver->getDeathIndicator() eq 'D' ? $refClaimCareReceiver->getDateOfDeath():$spaces), 0, 1),    # patient date of death
	substr($inpClaim->{insured}->[$inpClaim->getClaimType()]->getAnotherHealthBenefitPlan(), 0, 1), # other insurance indicator
	$spaces,  # CLAIM ADJUDICATION INDICATOR - RECEIVER TYPE
	$spaces,  # TYPE OF CLAIM INDICATOR
	substr($refClaimCareReceiver->getlegalIndicator(),0,1),  # LEGAL REPRESENTATIVE INDICATOR
	$spaces,  # ORIGIN CODE
	$spaces,  # PAYER CLAIM CONTROL NUMBER
	$spaces,  # PROVIDER NUMBER
	$spaces,  # Provider Number Filler 02 spaces
	substr($inpClaim->getId(),0,6),     # CLAIM IDENTIFICATION NUMBER
	$spaces,  # Filler - national
	$spaces,  # Filler - local
	$spaces,   # claim sequence number
	substr($refClaimCareReceiver->getSsn(),0,10)   # patient id
	)
  );

  return $nsfType{$nsfType};

}


1;
