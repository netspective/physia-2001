###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_EA0;
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
	'EA0';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $zeros = "0";
	my $refClaimTreatment = $inpClaim->{treatment};
	my $refClaimDiagnosis = $inpClaim->{diagnosis};
	my $procedureRef = $inpClaim->{procedures};
	my $currentProcedure = $procedureRef->[$container->getSequenceNo()-1];
	# my @diagnosis = split (/','/,$currentProcedure->getDiagnosisCode());
	my $diagnosis = $refClaimDiagnosis;
	my $i;

	my @tempDiagnosis = ['','','',''];

	if ($#$diagnosis > -1)
	{
		if($#$diagnosis > 3)
		{
			for $i (0..3)
			{
				$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] = $diagnosis->[$i]->getDiagnosis;
				$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] =~ s/\.//;
			}
		}
		else
		{
			for $i (0..$#$diagnosis)
			{
				$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] = $diagnosis->[$i]->getDiagnosis;
				$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] =~ s/\.//;
			}
		}

	}

	my $externalCause = $inpClaim->getSymptomExternalCause();
	my $accidentIndicator;


	$externalCause =~ s/\.//;

	if($inpClaim->getConditionRelatedToAutoAccident() eq 'Y')
	{
		$accidentIndicator  = 'A';
	}
	elsif(($inpClaim->getConditionRelatedToAutoAccident() eq 'N') && ($inpClaim->getConditionRelatedToAutoAccident() eq 'Y'))
	{
		$accidentIndicator  = 'O';
	}
	elsif(($inpClaim->getConditionRelatedToAutoAccident() eq 'N') && ($inpClaim->getConditionRelatedToAutoAccident() eq 'N'))
	{
		$accidentIndicator  = 'N';
	}


my %payerType = (THIN_MEDICARE . "" =>
	sprintf("%-3s%-2s%-17s%-1s%-1s%-1s%-8s%-5s%-1s%-2s%-2s%-1s%-1s%-8s%-1s%-8s%-1s%-8s%-8s%-15s%-15s%-1s%-9s%-20s%-12s%-1s%-2s%-8s%-8s%-1s%7s%-5s%-5s%-5s%-5s%-1s%-1s%-8s%-33s%-1s%-1s%-2s%-2s%-1s%-1s%-2s%-15s%-8s%-8s%-1s%-3s%-3s%-6s%-15s%-10s",
	$self->recordType(),
	$spaces, # reserved filler															   # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),			   # patient control number
	substr($inpClaim->getConditionRelatedToEmployment(),0 , 1),			   # employment related indicator
	substr($accidentIndicator, 0, 1),		   # accident indicator
	substr($inpClaim->getSymptomIndicator(),0,1),						   # symptom indicator
	substr($refClaimTreatment->getDateOfIllnessInjuryPregnancy(), 0, 8),   # Accident symptom date
	substr(($inpClaim->getConditionRelatedToAutoAccident() eq 'O') ? $inpClaim->getSymptomExternalCause() : $spaces,0,5),     # external cause of accident
	substr((($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/) ? $inpClaim->getResponsibilityIndicator() : $spaces),0,1),	# responsibility indicator
	substr($inpClaim->getConditionRelatedToAutoAccidentPlace(), 0, 2),     # accident state
	substr($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/ ? $inpClaim->getAccidentHour() : $spaces,0,2),   # accident hour
	$spaces,							   # abuse indicator
	substr($inpClaim->getInformationReleaseIndicator,0,1),				   # release of information indicator
	substr($inpClaim->getInformationReleaseDate,0,8),								   # release of information date
	substr(($inpClaim->{treatment}->getDateOfSameOrSimilarIllness ne '') ? 'Y' : 'N',0,1),   							   # same similar symptom indicator
	substr($inpClaim->{treatment}->getDateOfSameOrSimilarIllness,0,8),	   						   # same similar symptom date
	substr($inpClaim->getDisabilityType(),0,1),							   # disability type
	substr($refClaimTreatment->getDatePatientUnableToWorkFrom(), 0, 8),    # disability from date
	substr($refClaimTreatment->getDatePatientUnableToWorkTo(), 0, 8), 	   # disability to date
	substr($refClaimTreatment->getIDOfReferingPhysician(),	0, 15),		   # referring provider id number
	$spaces,															   # referring provider UPIN
	$spaces, # refering provider tax type
	$spaces, # refering provider tax id
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderLastName(): $spaces, 0, 20),
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderFirstName(): $spaces, 0, 12),
	substr($refClaimTreatment->getIDOfReferingPhysician() ne "" ? $refClaimTreatment->getRefProviderMiName(): $spaces, 0, 1),
	substr($refClaimTreatment->getReferingPhysicianState(), 0, 2),  		# refering provider state
	substr($refClaimTreatment->getHospitilizationDateFrom(), 0, 8), 		# hospitiliztion date from
	substr($refClaimTreatment->getHospitilizationDateTo(), 0, 8),   		# hospitaliztion date to
	substr($refClaimTreatment->getOutsideLab(), 0, 1),						# laboratory indicator
	$zeros.$self->numToStr(4,2,$refClaimTreatment->getOutsideLabCharges()), # laboratory charges
	substr($tempDiagnosis[0], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[1], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[2], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[3], 0, 5),  # if 1 then print else space
	substr($inpClaim->{payToProvider}->getAssignIndicator(),0,1),    # assignment indicator
#	'A',
	substr($inpClaim->{payToProvider}->getSignatureIndicator(),0,1), # signature indicator
	substr($inpClaim->{payToProvider}->getSignatureDate(),0,8),					# signature date
	substr($refClaimTreatment->getOutsideLab() == 'Y' ? $inpClaim->{renderingOrganization}->getName() : $spaces , 0, 33),
	substr($inpClaim->{payToProvider}->getDocumentationIndicator,0,1),	# documentation indicator
	substr($inpClaim->{payToProvider}->getDocumentationType(),0,1),		# documentation type
	$spaces,															# functional status code
	substr($inpClaim->getSpProgramIndicator(),0,2),						# special program indicator
	$spaces,															# champus non-availability indicator
	$spaces,													        # supervising provider indicator
	substr($refClaimTreatment->getMedicaidResubmission(), 0, 2),
	substr($refClaimTreatment->getResubmissionReference(), 0, 15),
	substr($inpClaim->{careReceiver}->getLastSeenDate,0,8),							# date last seen
	substr($inpClaim->getdateDocSent,0,8),											# date documentation sent
	$spaces,															# homebound indicator
	$spaces,															# blood units paid
	$spaces, 															# blood units remaining
	$spaces, 															# CPO prov number
	$spaces, 															# IDE number
	$spaces,															# filler national
	),
	THIN_COMMERCIAL . "" =>
	sprintf("%-3s%-2s%-17s%-1s%-1s%-1s%-8s%-5s%-1s%-2s%-2s%-1s%-1s%-8s%-1s%-8s%-1s%-8s%-8s%-15s%-15s%-1s%-9s%-20s%-12s%-1s%-2s%-8s%-8s%-1s%7s%-5s%-5s%-5s%-5s%-1s%-1s%-8s%-33s%-1s%-1s%-2s%-2s%-1s%-1s%-2s%-15s%-8s%-8s%-1s%-3s%-3s%-6s%-15s%-10s",
	$self->recordType(),
	$spaces, # reserved filler															   # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),			   # patient control number
	substr($inpClaim->getConditionRelatedToEmployment(),0 , 1),			   # employment related indicator
	substr($accidentIndicator, 0, 1),		   # accident indicator
	substr($inpClaim->getSymptomIndicator(),0,1),						   # symptom indicator
	substr($refClaimTreatment->getDateOfIllnessInjuryPregnancy(), 0, 8),   # Accident symptom date
	substr(($inpClaim->getConditionRelatedToAutoAccident() eq 'O') ? $inpClaim->getSymptomExternalCause() : $spaces,0,5),     # external cause of accident
	substr((($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/) ? $inpClaim->getResponsibilityIndicator() : $spaces),0,1),	# responsibility indicator
	substr($inpClaim->getConditionRelatedToAutoAccidentPlace(), 0, 2),     # accident state
	substr($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/ ? $inpClaim->getAccidentHour() : $spaces,0,2),   # accident hour
	$spaces,							   # abuse indicator
	substr($inpClaim->getInformationReleaseIndicator,0,1),				   # release of information indicator
	substr($inpClaim->getInformationReleaseDate,0,8),								   # release of information date
	substr(($inpClaim->{treatment}->getDateOfSameOrSimilarIllness ne '') ? 'Y' : 'N',0,1),   							   # same similar symptom indicator
	substr($inpClaim->{treatment}->getDateOfSameOrSimilarIllness,0,8),	   						   # same similar symptom date
	substr($inpClaim->getDisabilityType(),0,1),							   # disability type
	substr($refClaimTreatment->getDatePatientUnableToWorkFrom(), 0, 8),    # disability from date
	substr($refClaimTreatment->getDatePatientUnableToWorkTo(), 0, 8), 	   # disability to date
	substr($refClaimTreatment->getIDOfReferingPhysician(),	0, 15),		   # referring provider id number
	$spaces,															   # referring provider UPIN
	$spaces, # refering provider tax type
	$spaces, # refering provider tax id
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderLastName(): $spaces, 0, 20),
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderFirstName(): $spaces, 0, 12),
	substr($refClaimTreatment->getIDOfReferingPhysician() ne "" ? $refClaimTreatment->getRefProviderMiName(): $spaces, 0, 1),
	substr($refClaimTreatment->getReferingPhysicianState(), 0, 2),  		# refering provider state
	substr($refClaimTreatment->getHospitilizationDateFrom(), 0, 8), 		# hospitiliztion date from
	substr($refClaimTreatment->getHospitilizationDateTo(), 0, 8),   		# hospitaliztion date to
	substr($refClaimTreatment->getOutsideLab(), 0, 1),						# laboratory indicator
	$zeros.$self->numToStr(4,2,$refClaimTreatment->getOutsideLabCharges()), # laboratory charges
	substr($tempDiagnosis[0], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[1], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[2], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[3], 0, 5),  # if 1 then print else space
	substr($inpClaim->{payToProvider}->getAssignIndicator(),0,1),    # assignment indicator
#	'A',
	substr($inpClaim->{payToProvider}->getSignatureIndicator(),0,1), # signature indicator
	substr($inpClaim->{payToProvider}->getSignatureDate(),0,8),					# signature date
	substr($refClaimTreatment->getOutsideLab() == 'Y' ? $inpClaim->{renderingOrganization}->getName() : $spaces , 0, 33),
	substr($inpClaim->{payToProvider}->getDocumentationIndicator,0,1),	# documentation indicator
	substr($inpClaim->{payToProvider}->getDocumentationType(),0,1),		# documentation type
	$spaces,															# functional status code
	substr($inpClaim->getSpProgramIndicator(),0,2),						# special program indicator
	$spaces,															# champus non-availability indicator
	$spaces,													        # supervising provider indicator
	substr($refClaimTreatment->getMedicaidResubmission(), 0, 2),
	substr($refClaimTreatment->getResubmissionReference(), 0, 15),
	substr($inpClaim->{careReceiver}->getLastSeenDate,0,8),							# date last seen
	substr($inpClaim->getdateDocSent,0,8),											# date documentation sent
	$spaces,															# homebound indicator
	$spaces,															# blood units paid
	$spaces, 															# blood units remaining
	$spaces, 															# CPO prov number
	$spaces, 															# IDE number
	$spaces,															# filler national
	),
	THIN_BLUESHIELD . "" =>
	sprintf("%-3s%-2s%-17s%-1s%-1s%-1s%-8s%-5s%-1s%-2s%-2s%-1s%-1s%-8s%-1s%-8s%-1s%-8s%-8s%-15s%-15s%-1s%-9s%-20s%-12s%-1s%-2s%-8s%-8s%-1s%7s%-5s%-5s%-5s%-5s%-1s%-1s%-8s%-33s%-1s%-1s%-2s%-2s%-1s%-1s%-2s%-15s%-8s%-8s%-1s%-3s%-3s%-6s%-15s%-10s",
	$self->recordType(),
	$spaces, # reserved filler															   # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),			   # patient control number
	substr($inpClaim->getConditionRelatedToEmployment(),0 , 1),			   # employment related indicator
	substr($accidentIndicator, 0, 1),		   # accident indicator
	substr($inpClaim->getSymptomIndicator(),0,1),						   # symptom indicator
	substr($refClaimTreatment->getDateOfIllnessInjuryPregnancy(), 0, 8),   # Accident symptom date
	substr(($inpClaim->getConditionRelatedToAutoAccident() eq 'O') ? $inpClaim->getSymptomExternalCause() : $spaces,0,5),     # external cause of accident
	substr((($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/) ? $inpClaim->getResponsibilityIndicator() : $spaces),0,1),	# responsibility indicator
	substr($inpClaim->getConditionRelatedToAutoAccidentPlace(), 0, 2),     # accident state
	substr($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/ ? $inpClaim->getAccidentHour() : $spaces,0,2),   # accident hour
	$spaces,							   # abuse indicator
	substr($inpClaim->getInformationReleaseIndicator,0,1),				   # release of information indicator
	substr($inpClaim->getInformationReleaseDate,0,8),								   # release of information date
	substr(($inpClaim->{treatment}->getDateOfSameOrSimilarIllness ne '') ? 'Y' : 'N',0,1),   							   # same similar symptom indicator
	substr($inpClaim->{treatment}->getDateOfSameOrSimilarIllness,0,8),	   						   # same similar symptom date
	substr($inpClaim->getDisabilityType(),0,1),							   # disability type
	substr($refClaimTreatment->getDatePatientUnableToWorkFrom(), 0, 8),    # disability from date
	substr($refClaimTreatment->getDatePatientUnableToWorkTo(), 0, 8), 	   # disability to date
	substr($refClaimTreatment->getIDOfReferingPhysician(),	0, 15),		   # referring provider id number
	$spaces,															   # referring provider UPIN
	$spaces, # refering provider tax type
	$spaces, # refering provider tax id
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderLastName(): $spaces, 0, 20),
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderFirstName(): $spaces, 0, 12),
	substr($refClaimTreatment->getIDOfReferingPhysician() ne "" ? $refClaimTreatment->getRefProviderMiName(): $spaces, 0, 1),
	substr($refClaimTreatment->getReferingPhysicianState(), 0, 2),  		# refering provider state
	substr($refClaimTreatment->getHospitilizationDateFrom(), 0, 8), 		# hospitiliztion date from
	substr($refClaimTreatment->getHospitilizationDateTo(), 0, 8),   		# hospitaliztion date to
	substr($refClaimTreatment->getOutsideLab(), 0, 1),						# laboratory indicator
	$zeros.$self->numToStr(4,2,$refClaimTreatment->getOutsideLabCharges()), # laboratory charges
	substr($tempDiagnosis[0], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[1], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[2], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[3], 0, 5),  # if 1 then print else space
	substr($inpClaim->{payToProvider}->getAssignIndicator(),0,1),    # assignment indicator
#	'A',
	substr($inpClaim->{payToProvider}->getSignatureIndicator(),0,1), # signature indicator
	substr($inpClaim->{payToProvider}->getSignatureDate(),0,8),					# signature date
	substr($refClaimTreatment->getOutsideLab() == 'Y' ? $inpClaim->{renderingOrganization}->getName() : $spaces , 0, 33),
	substr($inpClaim->{payToProvider}->getDocumentationIndicator,0,1),	# documentation indicator
	substr($inpClaim->{payToProvider}->getDocumentationType(),0,1),		# documentation type
	$spaces,															# functional status code
	substr($inpClaim->getSpProgramIndicator(),0,2),						# special program indicator
	$spaces,															# champus non-availability indicator
	$spaces,													        # supervising provider indicator
	substr($refClaimTreatment->getMedicaidResubmission(), 0, 2),
	substr($refClaimTreatment->getResubmissionReference(), 0, 15),
	substr($inpClaim->{careReceiver}->getLastSeenDate,0,8),							# date last seen
	substr($inpClaim->getdateDocSent,0,8),											# date documentation sent
	$spaces,															# homebound indicator
	$spaces,															# blood units paid
	$spaces, 															# blood units remaining
	$spaces, 															# CPO prov number
	$spaces, 															# IDE number
	$spaces,															# filler national
	),
	THIN_MEDICAID . "" =>
	sprintf("%-3s%-2s%-17s%-1s%-1s%-1s%-8s%-5s%-1s%-2s%-2s%-1s%-1s%-8s%-1s%-8s%-1s%-8s%-8s%-15s%-15s%-1s%-9s%-20s%-12s%-1s%-2s%-8s%-8s%-1s%7s%-5s%-5s%-5s%-5s%-1s%-1s%-8s%-33s%-1s%-1s%-2s%-2s%-1s%-1s%-2s%-15s%-8s%-8s%-1s%-3s%-3s%-6s%-15s%-10s",
	$self->recordType(),
	$spaces, # reserved filler															   # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),			   # patient control number
	substr($inpClaim->getConditionRelatedToEmployment(),0 , 1),			   # employment related indicator
	substr($accidentIndicator, 0, 1),		   # accident indicator
	substr($inpClaim->getSymptomIndicator(),0,1),						   # symptom indicator
	substr($refClaimTreatment->getDateOfIllnessInjuryPregnancy(), 0, 8),   # Accident symptom date
	substr(($inpClaim->getConditionRelatedToAutoAccident() eq 'O') ? $inpClaim->getSymptomExternalCause() : $spaces,0,5),     # external cause of accident
	substr((($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/) ? $inpClaim->getResponsibilityIndicator() : $spaces),0,1),	# responsibility indicator
	substr($inpClaim->getConditionRelatedToAutoAccidentPlace(), 0, 2),     # accident state
	substr($inpClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/ ? $inpClaim->getAccidentHour() : $spaces,0,2),   # accident hour
	$spaces,							   # abuse indicator
	substr($inpClaim->getInformationReleaseIndicator,0,1),				   # release of information indicator
	substr($inpClaim->getInformationReleaseDate,0,8),								   # release of information date
	substr(($inpClaim->{treatment}->getDateOfSameOrSimilarIllness ne '') ? 'Y' : 'N',0,1),   							   # same similar symptom indicator
	substr($inpClaim->{treatment}->getDateOfSameOrSimilarIllness,0,8),	   						   # same similar symptom date
	substr($inpClaim->getDisabilityType(),0,1),							   # disability type
	substr($refClaimTreatment->getDatePatientUnableToWorkFrom(), 0, 8),    # disability from date
	substr($refClaimTreatment->getDatePatientUnableToWorkTo(), 0, 8), 	   # disability to date
	substr($refClaimTreatment->getIDOfReferingPhysician(),	0, 15),		   # referring provider id number
	$spaces,															   # referring provider UPIN
	$spaces, # refering provider tax type
	$spaces, # refering provider tax id
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderLastName(): $spaces, 0, 20),
	substr($tempDiagnosis[0] eq "" ? $refClaimTreatment->getRefProviderFirstName(): $spaces, 0, 12),
	substr($refClaimTreatment->getIDOfReferingPhysician() ne "" ? $refClaimTreatment->getRefProviderMiName(): $spaces, 0, 1),
	substr($refClaimTreatment->getReferingPhysicianState(), 0, 2),  		# refering provider state
	substr($refClaimTreatment->getHospitilizationDateFrom(), 0, 8), 		# hospitiliztion date from
	substr($refClaimTreatment->getHospitilizationDateTo(), 0, 8),   		# hospitaliztion date to
	substr($refClaimTreatment->getOutsideLab(), 0, 1),						# laboratory indicator
	$zeros.$self->numToStr(4,2,$refClaimTreatment->getOutsideLabCharges()), # laboratory charges
	substr($tempDiagnosis[0], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[1], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[2], 0, 5),  # if 1 then print else space
	substr($tempDiagnosis[3], 0, 5),  # if 1 then print else space
	substr($inpClaim->{payToProvider}->getAssignIndicator(),0,1),    # assignment indicator
#	'A',
	substr($inpClaim->{payToProvider}->getSignatureIndicator(),0,1), # signature indicator
	substr($inpClaim->{payToProvider}->getSignatureDate(),0,8),					# signature date
	substr($refClaimTreatment->getOutsideLab() == 'Y' ? $inpClaim->{renderingOrganization}->getName() : $spaces , 0, 33),
	substr($inpClaim->{payToProvider}->getDocumentationIndicator,0,1),	# documentation indicator
	substr($inpClaim->{payToProvider}->getDocumentationType(),0,1),		# documentation type
	$spaces,															# functional status code
	substr($inpClaim->getSpProgramIndicator(),0,2),						# special program indicator
	$spaces,															# champus non-availability indicator
	$spaces,													        # supervising provider indicator
	substr($refClaimTreatment->getMedicaidResubmission(), 0, 2),
	substr($refClaimTreatment->getResubmissionReference(), 0, 15),
	substr($inpClaim->{careReceiver}->getLastSeenDate,0,8),							# date last seen
	substr($inpClaim->getdateDocSent,0,8),											# date documentation sent
	$spaces,															# homebound indicator
	$spaces,															# blood units paid
	$spaces, 															# blood units remaining
	$spaces, 															# CPO prov number
	$spaces, 															# IDE number
	$spaces,															# filler national
	)
  );
  	return $payerType{$payerType};

}


1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_EA1;
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
	'EA1';
}

sub formatData
{
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $refOrganization = $inpClaim->{renderingOrganization};
	my $refOrganizationAddress = $refOrganization->{address};
	my $spaces = ' ';

my %payerType = (THIN_MEDICARE . "" =>
	sprintf('%-3s%-2s%-17s%-15s%-15s%-30s%-30s%-20s%-2s%-9s%-17s%-8s%-8s%-8s%-8s%-15s%-15s%-20s%-12s%-1s%-2s%-20s%-12s%-1s%-8s%-5s%-5s%-5s%-5s%-2s',
	$self->recordType(),
	$spaces, # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	substr($inpClaim->{treatment}->getOutsideLab() eq "Y" ? $refOrganization->getId():$spaces,0, 15),   # #  FACILITY/LAB ID NUMBER
	$spaces,    # RESERVED FILLER
	substr($refOrganizationAddress->getAddress1(),0,30), # facility address1
	substr($refOrganizationAddress->getAddress2(),0,30), 												#$refOrganization->getAddress2(),	#not used must be a filler
	substr($refOrganizationAddress->getCity(),0, 20), # lab city
	substr($refOrganizationAddress->getState(),0, 2),   # lab state
	substr($refOrganizationAddress->getZipCode().$self->numToStr(9 - length($refOrganizationAddress->getZipCode())),0, 9),
	$spaces,														# madico legal record no
	$spaces,	# RETURN TO WORK DATE
	$spaces,	# CONSULT/SURGERY DATE
	$spaces,	# ADMISSION DATE 2
	$spaces,	# DISCHARGE DATE 2
	$spaces,	# supv prov NPI
	$spaces,	# reserved filler
	$spaces,	# supv prov last
	$spaces,	# supv prov first
	$spaces,	# supv prov middle
	$spaces,	# supv prov state
	$spaces,	# EMT paramedic last
	$spaces,	# EMT paramedic first
	$spaces,	# EMT paramedic middle
	$spaces, 	#  date care assumed
	$spaces, 	#  DX Code - 5
	$spaces, 	#  DX Code - 6
	$spaces, 	#  DX Code - 7
	$spaces, 	#  DX Code - 8
	$spaces, 	#  Filler national
	),
	THIN_COMMERCIAL . "" =>
	sprintf('%-3s%-2s%-17s%-15s%-15s%-30s%-30s%-20s%-2s%-9s%-17s%-8s%-8s%-8s%-8s%-15s%-15s%-20s%-12s%-1s%-2s%-20s%-12s%-1s%-8s%-5s%-5s%-5s%-5s%-2s',
	$self->recordType(),
	$spaces, # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	substr($inpClaim->{treatment}->getOutsideLab() eq "Y" ? $refOrganization->getId():$spaces,0, 15),   # #  FACILITY/LAB ID NUMBER
	$spaces,    # RESERVED FILLER
	substr($refOrganizationAddress->getAddress1(),0,30), # facility address1
	substr($refOrganizationAddress->getAddress2(),0,30), 												#$refOrganization->getAddress2(),	#not used must be a filler
	substr($refOrganizationAddress->getCity(),0, 20), # lab city
	substr($refOrganizationAddress->getState(),0, 2),   # lab state
	substr($refOrganizationAddress->getZipCode().$self->numToStr(9 - length($refOrganizationAddress->getZipCode())),0, 9),
	$spaces,														# madico legal record no
	$spaces,	# RETURN TO WORK DATE
	$spaces,	# CONSULT/SURGERY DATE
	$spaces,	# ADMISSION DATE 2
	$spaces,	# DISCHARGE DATE 2
	$spaces,	# supv prov NPI
	$spaces,	# reserved filler
	$spaces,	# supv prov last
	$spaces,	# supv prov first
	$spaces,	# supv prov middle
	$spaces,	# supv prov state
	$spaces,	# EMT paramedic last
	$spaces,	# EMT paramedic first
	$spaces,	# EMT paramedic middle
	$spaces, 	#  date care assumed
	$spaces, 	#  DX Code - 5
	$spaces, 	#  DX Code - 6
	$spaces, 	#  DX Code - 7
	$spaces, 	#  DX Code - 8
	$spaces, 	#  Filler national
	),
	THIN_BLUESHIELD . "" =>
	sprintf('%-3s%-2s%-17s%-15s%-15s%-30s%-30s%-20s%-2s%-9s%-17s%-8s%-8s%-8s%-8s%-15s%-15s%-20s%-12s%-1s%-2s%-20s%-12s%-1s%-8s%-5s%-5s%-5s%-5s%-2s',
	$self->recordType(),
	$spaces, # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	substr($inpClaim->{treatment}->getOutsideLab() eq "Y" ? $refOrganization->getId():$spaces,0, 15),   # #  FACILITY/LAB ID NUMBER
	$spaces,    # RESERVED FILLER
	substr($refOrganizationAddress->getAddress1(),0,30), # facility address1
	substr($refOrganizationAddress->getAddress2(),0,30), 												#$refOrganization->getAddress2(),	#not used must be a filler
	substr($refOrganizationAddress->getCity(),0, 20), # lab city
	substr($refOrganizationAddress->getState(),0, 2),   # lab state
	substr($refOrganizationAddress->getZipCode().$self->numToStr(9 - length($refOrganizationAddress->getZipCode())),0, 9),
	$spaces,														# madico legal record no
	$spaces,	# RETURN TO WORK DATE
	$spaces,	# CONSULT/SURGERY DATE
	$spaces,	# ADMISSION DATE 2
	$spaces,	# DISCHARGE DATE 2
	$spaces,	# supv prov NPI
	$spaces,	# reserved filler
	$spaces,	# supv prov last
	$spaces,	# supv prov first
	$spaces,	# supv prov middle
	$spaces,	# supv prov state
	$spaces,	# EMT paramedic last
	$spaces,	# EMT paramedic first
	$spaces,	# EMT paramedic middle
	$spaces, 	#  date care assumed
	$spaces, 	#  DX Code - 5
	$spaces, 	#  DX Code - 6
	$spaces, 	#  DX Code - 7
	$spaces, 	#  DX Code - 8
	$spaces, 	#  Filler national
	),
	THIN_MEDICAID . "" =>
	sprintf('%-3s%-2s%-17s%-15s%-15s%-30s%-30s%-20s%-2s%-9s%-17s%-8s%-8s%-8s%-8s%-15s%-15s%-20s%-12s%-1s%-2s%-20s%-12s%-1s%-8s%-5s%-5s%-5s%-5s%-2s',
	$self->recordType(),
	$spaces, # reserved filler
	substr($inpClaim->{careReceiver}->getAccountNo(), 0, 17),
	substr($inpClaim->{treatment}->getOutsideLab() eq "Y" ? $refOrganization->getId():$spaces,0, 15),   # #  FACILITY/LAB ID NUMBER
	$spaces,    # RESERVED FILLER
	substr($refOrganizationAddress->getAddress1(),0,30), # facility address1
	substr($refOrganizationAddress->getAddress2(),0,30), 												#$refOrganization->getAddress2(),	#not used must be a filler
	substr($refOrganizationAddress->getCity(),0, 20), # lab city
	substr($refOrganizationAddress->getState(),0, 2),   # lab state
	substr($refOrganizationAddress->getZipCode().$self->numToStr(9 - length($refOrganizationAddress->getZipCode())),0, 9),
	$spaces,														# madico legal record no
	$spaces,	# RETURN TO WORK DATE
	$spaces,	# CONSULT/SURGERY DATE
	$spaces,	# ADMISSION DATE 2
	$spaces,	# DISCHARGE DATE 2
	$spaces,	# supv prov NPI
	$spaces,	# reserved filler
	$spaces,	# supv prov last
	$spaces,	# supv prov first
	$spaces,	# supv prov middle
	$spaces,	# supv prov state
	$spaces,	# EMT paramedic last
	$spaces,	# EMT paramedic first
	$spaces,	# EMT paramedic middle
	$spaces, 	#  date care assumed
	$spaces, 	#  DX Code - 5
	$spaces, 	#  DX Code - 6
	$spaces, 	#  DX Code - 7
	$spaces, 	#  DX Code - 8
	$spaces, 	#  Filler national
	)
  );

  return $payerType{$payerType};
}

1;

