###################################################################################
package App::Billing::Output::File::Batch::Claim::Header::NSF1;
###################################################################################

use strict;
use Carp;
use Devel::ChangeLog;

use vars qw(@CHANGELOG);

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
	'CA0';
}


sub formatData
{
	my ($self, $container, $flags, $inpClaim) = @_;
	my $spaces = ' ';
	my $zeros = "0";
	my $refClaimCareReceiver = $inpClaim->{careReceiver};
	my $refClaimCareReceiverAddress = $refClaimCareReceiver->{address};
		

	return sprintf("%-3s%1s%1s%-17s%-20s%-10s%-2s%1s%-3s%-8s%1s%1s%-18s%-12s%-30s%-15s%-5s%-2s%-9s%-10s%1s%1s%1s%1s%-8s%1s%1s%-2s%1s%-9s%-17s%-13s%-2s%-6s%-20s%-43s%-14s%-10s",
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
	);
	
}

@CHANGELOG =
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'AUF',
	'Billing Interface/Validating CA0 Header',
	'All dates are now interperated from DD-MON-YY to CCYYMMDD format by '.
	'using convertDateToCCYYMMDD in CA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Validating CA0 Header',
	'All Codes of Gender are now interprated from 0,1,2 to U,M,F in CA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'AUF',
	'Billing Interface/Validating CA0 Header',
	'All the changes in Codes of Gender and use of convertDateToCCYYMMDD has been removed from CA0, the Claim object will provide formatted data'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/17/2000', 'AUF',
	'Billing Interface/Validating CA0 Header',
	'Spaces has been put in TPO Participation Indicator as advised by Envoy in its 16-FEB-2000 e-mail to Mr. Yousuf']

);
	
1;
