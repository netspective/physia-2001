###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::DA0;
###################################################################################

use strict;
use Carp;
use App::Billing::Output::File::Batch::Claim::Record::NSF;

# for exporting NSF Constants
use App::Billing::Universal;



use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'DA0';
}



sub wasLastPayerMedicare
{
	my ($self, $flags, $inpClaim) = @_;

	#print "Payer ID is: ", $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(), "\n";
	#print "Payer is: ", $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getName , "\n";

	if ($flags->{RECORDFLAGS_NONE} > 0)
	{
		my $testName = $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE} - 1]->getName();
		if($testName eq	'Medicare')
		{
			return 1;
		}
	}
	return 0;
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $refClaimInsured = $inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}];
	my $refClaimCareReceiver = $inpClaim->{careReceiver};
	my $refSourceOfPayment = {'MEDICARE' => 'C', 'MEDICADE' => 'D', 'CHAMPUS' => 'H', 'CHAMPVA' => ' ', 'GROUP' => ' ', 'FECA' => ' ', 'OTHER' => 'Z'};


    my $wasPayerMedicare = wasLastPayerMedicare($self, $flags, $inpClaim);

	my $insSequence = $container->getSequenceNo();
	
my %nsfType = (NSF_HALLEY . "" =>
	sprintf("%-3s%-2s%-17s%1s%1s%-2s%-5s%-4s%-17s%-16s%-20s%-17s%-16s%1s%-15s%-15s%1s%1s%2s%-17s%-8s%-20s%-10s%-2s%1s%-3s%1s%-8s%1s%1s%-7s%-25s%-15s%-1s%-28s%-7s%-9s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($refClaimCareReceiver->getAccountNo(),0,17),
	
	# Filing Indicator = 'P' if primary, 'I' otherwise
	substr($inpClaim->getFilingIndicator($insSequence),0,1), 	# 'P',or 'M' or 'I'
	
	substr(($wasPayerMedicare == 1) ? 'Z' : $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getSourceOfPayment(),0,1),
	substr(($wasPayerMedicare == 1) ? 'MG' : $refClaimInsured->getTypeCode(),0,2),   # insurance type code
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),0,5),           # payer organization id
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),length($inpClaim->getPayerId())-4,4),#$spaces,  # payer claim office number
#	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getName,0,17),#substr($refClaimInsured->getInsurancePlanOrProgramName(),0,17),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getName(),0,17),
 	$spaces,										 # payer name filler
	substr($refClaimInsured->getPolicyGroupOrFECANo(),0,20),
	$spaces,   										 # Group name
	$spaces,				  					     # Group name filler
	substr($refClaimInsured->getHMOIndicator(),0,1), # PPO/HMO Indicator
	substr($refClaimInsured->getHMOId(),0,15),  	 # PPO/HMO Id
	substr($inpClaim->{treatment}->getPriorAuthorizationNo(),0,15),
	substr(($wasPayerMedicare == 1) ? 'Y' : $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAcceptAssignment(), 0, 1),
	substr($inpClaim->{careReceiver}->getSignature(),0,1),	 # patient signature source
	substr($refClaimInsured->getRelationshipToPatient(),0,2),
	substr($refClaimInsured->getMemberNumber(), 0, 17),
	$spaces,  # insured id filler
	substr($refClaimInsured->getLastName(), 0, 20),
	substr($refClaimInsured->getFirstName(), 0, 10),
	$spaces,										 #First Name Filler
	substr($refClaimInsured->getMiddleInitial(), 0, 1),
	$spaces,                                         # insured generation
	substr($refClaimInsured->getSex(), 0, 1),
	substr($refClaimInsured->getDateOfBirth(), 0, 8),
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1),
	substr($refClaimInsured->getOtherInsuranceIndicator(), 0, 1),
	$spaces,										 # insurance locaion id
	$spaces,										 # medicaid id number
	$spaces,										 # payclass for MII (RADCON)
	$spaces,										 # payee number
	$spaces, 										 # med reserve
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),0,7),  # halley payer id
	substr($refClaimInsured->getMedigapNo(),0,9),	# medigap id
	),
	NSF_THIN . "" =>
	sprintf("%-3s%-2s%-17s%-1s%-1s%2s%-5s%-4s%-33s%-20s%-33s%-1s%-15s%-15s%-1s%-1s%-2s%-25s%-20s%-12s%-1s%-3s%-1s%-8s%-1s%-1s%-7s%-25s%-25s%-1s%-1s%-33s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($refClaimCareReceiver->getAccountNo(),0,17),
	substr($inpClaim->getFilingIndicator(),0,1), 	# 'P',or 'M' or 'I'
	substr(($wasPayerMedicare == 1) ? 'Z' : $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getSourceOfPayment(),0,1),
	substr(($wasPayerMedicare == 1) ? 'MG' : $refClaimInsured->getTypeCode(),0,2),   # insurance type code
#	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),0,5),           # payer organization id
#	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),length($inpClaim->getPayerId())-4,4),#$spaces,  # payer claim office number
	substr(($wasPayerMedicare == 1) ? $inpClaim->{insured}->[0]->getMedigapNo() : $inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),0,5), # Organiation Payer Id
# 	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getName,0,17),#substr($refClaimInsured->getInsurancePlanOrProgramName(),0,17),
	$spaces, # PayerClaim Office No
	substr($refClaimInsured->getInsurancePlanOrProgramName(),0,33), # payer name filler
	substr($refClaimInsured->getPolicyGroupOrFECANo(),0,20), # Group No
	$spaces, # Group Name
	substr($refClaimInsured->getHMOIndicator(),0,1), # PPO/HMO Indicator
	substr($refClaimInsured->getHMOId(),0,15),  	 # PPO/HMO Id
	substr(($wasPayerMedicare == 1) ? 'Y' : $inpClaim->{treatment}->getPriorAuthorizationNo(),0,15),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAcceptAssignment(), 0, 1),
	substr($inpClaim->{careReceiver}->getSignature(),0,1),	 # patient signature source
	substr($refClaimInsured->getRelationshipToPatient(),0,2),
	substr($refClaimInsured->getMemberNumber(), 0, 25),
	substr($refClaimInsured->getLastName(), 0, 20),
	substr($refClaimInsured->getFirstName(), 0, 12),
	substr($refClaimInsured->getMiddleInitial(), 0, 1),
	$spaces,                                         # insured generation
	substr($refClaimInsured->getSex(), 0, 1),
	substr($refClaimInsured->getDateOfBirth(), 0, 8),
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1),
	substr($refClaimInsured->getOtherInsuranceIndicator(), 0, 1),
	$spaces,										 # insurance locaion id
	$spaces,										 # medicaid id number
	$spaces,										 # supplemental patient id
	$spaces,										 # assign 4081 ind
	$spaces, 										 # cob routing ind
	$spaces,										 # filler national
	),
	NSF_ENVOY . "" =>
	sprintf("%-3s%-2s%-17s%1s%1s%-2s%-5s%-4s%-17s%-16s%-20s%-17s%-16s%1s%-15s%-15s%1s%1s%2s%-17s%-8s%-20s%-10s%-2s%1s%-3s%1s%-8s%1s%1s%-7s%-25s%-13s%-47s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($refClaimCareReceiver->getAccountNo(),0,17),
	substr($inpClaim->getFilingIndicator(),0,1), 	# 'P',or 'M' or 'I'
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getSourceOfPayment(),0,1),
	substr($refClaimInsured->getTypeCode(),0,2),   # insurance type code
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),0,5),           # payer organization id
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getPayerId(),length($inpClaim->getPayerId())-4,4),#$spaces,  # payer claim office number
 	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getName,0,17),#substr($refClaimInsured->getInsurancePlanOrProgramName(),0,17),
 	$spaces,										 # payer name filler
	substr($refClaimInsured->getPolicyGroupOrFECANo(),0,20),
	$spaces,   										 # Group name
	$spaces,				  					     # Group name filler
	substr($refClaimInsured->getHMOIndicator(),0,1), # PPO/HMO Indicator
	substr($refClaimInsured->getHMOId(),0,15),  	 # PPO/HMO Id
	substr($inpClaim->{treatment}->getPriorAuthorizationNo(),0,15),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAcceptAssignment(), 0, 1),
	substr($inpClaim->{careReceiver}->getSignature(),0,1),	 # patient signature source
	$self->numToStr(2, 0, $refClaimInsured->getRelationshipToPatient()),
	substr($refClaimInsured->getSsn(), 0, 17),
	$spaces,  # insured id filler
	substr($refClaimInsured->getLastName(), 0, 20),
	substr($refClaimInsured->getFirstName(), 0, 10),
	$spaces,										 #First Name Filler
	substr($refClaimInsured->getMiddleInitial(), 0, 1),
	$spaces,                                         # insured generation
	substr($refClaimInsured->getSex(), 0, 1),
	substr($refClaimInsured->getDateOfBirth(), 0, 8),
	substr($refClaimCareReceiver->getEmploymentStatus(), 0, 1),
	substr($refClaimInsured->getOtherInsuranceIndicator(), 0, 1),
	$spaces,										 # insurance locaion id
	$spaces,										 # medicaid id number
	$spaces,										 # filler national
	$spaces											 # filler local
	)
  );

  return $nsfType{$nsfType};
}

1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::DA1;
###################################################################################


use strict;
use Carp;
use App::Billing::Output::File::Batch::Claim::Record::NSF;

# for exporting NSF Constants
use App::Billing::Universal;

use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);


sub recordType
{
	'DA1';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';

my %nsfType = (NSF_HALLEY . "" =>
	sprintf("%-3s%-2s%-17s%-30s%-30s%-20s%-2s%-9s%7s%7s%7s%7s%7s%7s%1d%-2s%-2s%-2s%1s%-2s%1s%-8s%-8s%7s%-8s%-8s%-8s%-8s%-8s%-9s%-15s%-8s%-9s%-15s%-8s%-9s%-9s%-1s%-8s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress1(),0,25), # Payer Address1
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress2(),0,25), # Payer Address2
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getCity(),0,15), # Payer City
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getState(),0,2), # Payer State
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getZipCode(),0,9), # Payer ZipCode
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedCostContainment()), # Disallowed Cost Containment Amount
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedOther()), # Disallowed Other Amount
	$spaces, # Allowed Amount
	$spaces, # Deductible Amount
	$spaces, # Coinsurance Amount
	$self->numToStr(5, 2, abs($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAmountPaid())), # Payer Amount Paid
	$spaces, # Zero Amount Indicator
	$spaces, # Adjudication Indicator 1
	$spaces, # Adjudication Indicator 2
	$spaces, # Adjudication Indicator 3
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorBranch(),0,1), # Champus Sponsor branch
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorGrade(),0,2), # Champus sponsor grade
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorStatus(),0,1), # Champus sponsor status
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getEffectiveDate(),0,8), # Insurance Card effective date
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getTerminationDate(),0,8), # Insurance Card Termination Date
	$self->numToStr(5,2,$inpClaim->getBalance()), # Balance Due
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Filler
	$spaces, # Contract agreement Indicator
	$spaces, # Filler local
	),
	NSF_THIN . "" =>
	sprintf("%-3s%-2s%-17s%-30s%-30s%-20s%-2s%-9s%7s%7s%7s%7s%7s%7s%-1s%-2s%-2s%-2s%1s%-2s%1s%-8s%-8s%7s%-8s%-8s%-8s%-8s%-8s%9s%-15s%-8s%9s%-15s%-8s%9s%9s%-1s%-8s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress1(),0,25), # Payer Address1
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress2(),0,25), # Payer Address2
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getCity(),0,15), # Payer City
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getState(),0,2), # Payer State
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getZipCode(),0,9), # Payer ZipCode
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedCostContainment()), # Disallowed Cost Containment Amount
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedOther()), # Disallowed Other Amount
	$spaces, # Allowed Amount
	$spaces, # Deductible Amount
	$spaces, # Coinsurance Amount
	$self->numToStr(5, 2, abs($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAmountPaid())), # Payer Amount Paid
	$spaces, # Zero Amount Indicator
	$spaces, # Adjudication Indicator 1
	$spaces, # Adjudication Indicator 2
	$spaces, # Adjudication Indicator 3
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorBranch(),0,1), # Champus Sponsor branch
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorGrade(),0,2), # Champus sponsor grade
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorStatus(),0,1), # Champus sponsor status
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getEffectiveDate(),0,8), # Insurance Card effective date
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getTerminationDate(),0,8), # Insurance Card Termination Date
	$self->numToStr(5,2,$inpClaim->getBalance()), # Balance Due
	$spaces, # EOMB date1
	$spaces, # EOMB date2
	$spaces, # EOMB date3
	$spaces, # EOMB date4
	$spaces, # claim receipt date
	$spaces, # amount paid to bene
	$spaces, # bene check/eff trace no
	$spaces, # bene check date
	$spaces, # amt paid to provider
	$spaces, # prov check/eff trace no
	$spaces, # prov check date
	$spaces, # interest paid
	$spaces, # approved amount
	$spaces, # Contract agreement Indicator
	$spaces, # Filler local
	),
	NSF_ENVOY . "" =>
	sprintf("%-3s%-2s%-17s%-30s%-30s%-20s%-2s%-9s%7s%7s%7s%7s%7s%7s%1d%-2s%-2s%-2s%1s%-2s%1s%-8s%-8s%7s%-63s%-68s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress1(),0,25), # Payer Address1
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getAddress2(),0,25), # Payer Address2
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getCity(),0,15), # Payer City
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getState(),0,2), # Payer State
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->{address}->getZipCode(),0,9), # Payer ZipCode
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedCostContainment()), # Disallowed Cost Containment Amount
	$spaces,# $self->intToStr(5,2,$inpClaim->getDisallowedOther()), # Disallowed Other Amount
	$spaces, # Allowed Amount
	$spaces, # Deductible Amount
	$spaces, # Coinsurance Amount
	$self->numToStr(5, 2, abs($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getAmountPaid())), # Payer Amount Paid
	$spaces, # Zero Amount Indicator
	$spaces, # Adjudication Indicator 1
	$spaces, # Adjudication Indicator 2
	$spaces, # Adjudication Indicator 3
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorBranch(),0,1), # Champus Sponsor branch
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorGrade(),0,2), # Champus sponsor grade
	substr($inpClaim->{policy}->[$flags->{RECORDFLAGS_NONE}]->getChampusSponsorStatus(),0,1), # Champus sponsor status
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getEffectiveDate(),0,8), # Insurance Card effective date
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getTerminationDate(),0,8), # Insurance Card Termination Date
	$self->numToStr(5,2,$inpClaim->getBalance()), # Balance Due
	$spaces, # Filler National
	$spaces	 # Filler local
	)
 );

 	return $nsfType{$nsfType};
}


1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::DA2;
###################################################################################


use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;

use App::Billing::Output::File::Batch::Claim::Record::NSF;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'DA2';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $refClaimInsured = $inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}];
	my $refClaimInsuredAddress = $refClaimInsured->{address};

my %nsfType = (NSF_HALLEY . "" =>
	sprintf('%-3s%-2s%-17s%-18s%-12s%-30s%-20s%-2s%-9s%-10s%-8s%-8s%-18s%-15s%-30s%-30s%-20s%-2s%-9s%-12s%-25s%-20s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
  	substr($refClaimInsuredAddress->getAddress1(), 0, 18),
  	$spaces,											#address1 filler
	$spaces,
	substr($refClaimInsuredAddress->getCity(), 0, 20),
	substr($refClaimInsuredAddress->getState(), 0, 2),
	substr($refClaimInsuredAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimInsuredAddress->getZipCode()),0,"0") ,
	substr($refClaimInsuredAddress->getTelephoneNo(), 0, 10),
	$spaces,
	$spaces,
	substr($refClaimInsured->getEmployerOrSchoolName(), 0, 18),
	$spaces,													#Filler of getInsuredEmployerOrSchoolName
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces
	),
	NSF_THIN . "" =>
	sprintf('%-3s%-2s%-17s%-30s%-30s%-20s%-2s%-9s%-10s%-8s%-8s%-33s%-30s%-30s%-20s%-2s%-9s%-12s%-45s%',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
  	substr($refClaimInsuredAddress->getAddress1(), 0, 18),
  	$spaces,	# address2 filler
	substr($refClaimInsuredAddress->getCity(), 0, 20),
	substr($refClaimInsuredAddress->getState(), 0, 2),
	substr($refClaimInsuredAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimInsuredAddress->getZipCode()),0,"0") ,
	substr($refClaimInsuredAddress->getTelephoneNo(), 0, 10),
	$spaces,	# retire date
	$spaces,	# spouse date
	substr($refClaimInsured->getEmployerOrSchoolName(), 0, 18),
	$spaces,	# employer address 1
	$spaces,	# employer address 2
	$spaces,	# employer city
	$spaces,	# employer state
	$spaces,	# employer zip
	$spaces,	# employer id no
	$spaces,	# filler national
	),
	NSF_ENVOY . "" =>
	sprintf('%-3s%-2s%-17s%-18s%-12s%-30s%-20s%-2s%-9s%-10s%-8s%-8s%-18s%-15s%-30s%-30s%-20s%-2s%-9s%-12s%-25s%-20s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
  	substr($refClaimInsuredAddress->getAddress1(), 0, 18),
  	$spaces,											#address1 filler
	$spaces,
	substr($refClaimInsuredAddress->getCity(), 0, 20),
	substr($refClaimInsuredAddress->getState(), 0, 2),
	substr($refClaimInsuredAddress->getZipCode(), 0, 5) . $self->numToStr(9 - length($refClaimInsuredAddress->getZipCode()),0,"0") ,
	substr($refClaimInsuredAddress->getTelephoneNo(), 0, 10),
	$spaces,
	$spaces,
	substr($refClaimInsured->getEmployerOrSchoolName(), 0, 18),
	$spaces,													#Filler of getInsuredEmployerOrSchoolName
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces
	)
  );

	return $nsfType{$nsfType};
}


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::DA3;
###################################################################################


use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;

use App::Billing::Output::File::Batch::Claim::Record::NSF;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'DA3';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $refClaimInsured = $inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}];
	my $refClaimInsuredAddress = $refClaimInsured->{address};

my %nsfType = (NSF_THIN . "" =>
	sprintf('%-3s%-2s%-17s%-6s%7s%-6s%7s%-6s%7s%-6s%7s%-6s%7s%-6s%7s%-6s%7s%-5s%-5s%-5s%-5s%-5s%-2s%-1s%7s%7s%7s%7s%-17s%-134s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
	$spaces,	# claim reason code1
	$spaces,	# dollar amount1
	$spaces,	# claim reason code2
	$spaces,	# dollar amount2
	$spaces,	# claim reason code3
	$spaces,	# dollar amount3
	$spaces,	# claim reason code4
	$spaces,	# dollar amount4
	$spaces,	# claim reason code5
	$spaces,	# dollar amount5
	$spaces,	# claim reason code6
	$spaces,	# dollar amount6
	$spaces,	# claim reason code7
	$spaces,	# dollar amount7
	$spaces,	# claim message code1
	$spaces,	# claim message code2
	$spaces,	# claim message code3
	$spaces,	# claim message code4
	$spaces,	# claim message code5
	$spaces,	# claim detail line count
	$spaces,	# claim adjust ind
	$spaces,	# prov adjust amt
	$spaces,	# bene adjust amt
	$spaces,	# orig approved amt
	$spaces,	# orig paid amt
	$spaces,	# orig payer claim control no
	$spaces,	# filler national
	)
  );

	return $nsfType{$nsfType};
}


1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::DAat;
###################################################################################

use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;

use App::Billing::Output::File::Batch::Claim::Record::NSF;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'DA@';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';

my %nsfType = (NSF_ENVOY . "" =>
	sprintf("%-3s%-2s%-17s%-5s%-293s",
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($inpClaim->{careReceiver}->getAccountNo(),0,17),
	substr($inpClaim->{insured}->[$flags->{RECORDFLAGS_NONE}]->getBcbsPlanCode(),0,5),
	$spaces
	)
  );

  	return $nsfType{$nsfType};
}


1;


