#########################################################################
package App::Billing::Output::Html::FloridaMedicaid;
#########################################################################
use strict;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::Html::Template);
# this object is inherited from App::Billing::Output::Driver
use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type) = @_;
	my $self = new App::Billing::Output::Html::Template;
	return bless $self, $type;
}

sub populateTemplate
{
	my ($self, $claim, $procesedProc) = @_;
	
	$self->populatePatient($claim);
	$self->populateInsured($claim);
	$self->populateOtherInsured($claim);
	$self->populatePhysician($claim);
	$self->populateOrganization($claim);
	$self->populateTreatment($claim);
	$self->populateClaim($claim, $procesedProc);
	$self->populatePayer($claim);
	my $tb = $self->populateProcedures($claim, $procesedProc);
	$self->populateDiagnosis($claim, $tb);
	$self->concatSpace();
	
}

sub populateInsured
{
	my ($self, $claim) = @_;
	my $claimType = $claim->getClaimType();
	my $insured = $claim->{insured}->[$claimType];
	my $insuredAddress = $insured->getAddress();
	my $data = $self->{data};

	if ($claim->{careReceiver}->getId eq $claim->{insured}->[$claimType]->getId)
	{
		$data->{insuredName} = 'SAME';
	}
	else
	{
		$data->{insuredName} = $claim->{insured}->[$claimType]->getLastName() . " " . $claim->{insured}->[$claimType]->getFirstName() . " " . $claim->{insured}->[$claimType]->getMiddleInitial();
		$data->{insuredDateOfBirth} = $insured->getDateOfBirth(DATEFORMAT_USA);
		$data->{insuredSexM} = $insured->getSex() eq 'M' ? "Checked" : "";
		$data->{insuredSexF} = $insured->getSex() eq 'F' ? "Checked" : "";
		my $dataA = $claim->{insured}->[$claimType]->getAddress();
		$data->{insuredAddressCity} = $dataA->getCity;
		$data->{insuredAddressState} = $dataA->getState;
		$data->{insuredAddressTelephone} = $dataA->getTelephoneNo;
		$data->{insuredAddressZipCode} = $dataA->getZipCode;
		$data->{insuredAddress} = $dataA->getAddress1 . " " . $dataA->getAddress2;
	}
	
	$data->{insuredId} = $claim->{insured}->[$claimType]->getMemberNumber();
	$insured = $claim->{insured}->[0];
	$data->{insuredEmployerOrSchoolName} = $insured->getEmployerOrSchoolName;
	$data->{insuredInsurancePlanOrProgramName} = $insured->getInsurancePlanOrProgramName;
	$data->{insuredPolicyGroupName} = $insured->getPolicyGroupOrFECANo; # || $insured->getPolicyGroupName;

	$data->{signatureInsured} = uc($claim->{careReceiver}->getSignature()) =~ /M|B/ ? 'Signature on File' : "Signature on File";
}

sub populateOtherInsured
{
	my ($self, $claim) = @_;
	my $data = $self->{data};
	my $claimType = $claim->getClaimType();
	my $insured1 = $claim->{insured}->[$claimType];
	my $insured2 = $claim->{insured}->[$claimType + 1];

	if (($insured1 ne "") && ($insured2 ne ""))
	{

		if ($insured2->getInsurancePlanOrProgramName ne "")
		{
			if(uc($insured1->getInsurancePlanOrProgramName) eq "MEDICARE")
			{
				$data->{otherInsuredName} = $insured2->getLastName() . " " . $insured2->getFirstName() . " " . $insured2->getMiddleInitial();
				$data->{insuredAnotherHealthBenefitPlanY} =  "Checked" ;
				$data->{otherInsuredDateOfBirth} = $insured2->getDateOfBirth(DATEFORMAT_USA);
				$data->{otherInsuredSexM} = $insured2->getSex() eq 'M' ? "Checked" : "";
				$data->{otherInsuredSexF} = $insured2->getSex() eq 'F' ? "Checked" : "";
				$data->{otherInsuredEmployerOrSchoolName} = $insured2->getEmployerOrSchoolName;
				$data->{otherInsuredInsurancePlanOrProgramName} = $insured2->getMedigapNo; # $insured2->getInsurancePlanOrProgramName;
				my $groupNumber = $insured2->getMemberNumber() . " " . $insured2->getPolicyGroupOrFECANo; # || $insured2->getPolicyGroupName;
				$data->{otherInsuredPolicyGroupName} =  "MEDIGAP " . $groupNumber;
			}
			else
			{
				$data->{otherInsuredName} = $insured2->getLastName() . " " . $insured2->getFirstName() . " " . $insured2->getMiddleInitial();
				$data->{insuredAnotherHealthBenefitPlanY} =  "Checked" ;
				$data->{otherInsuredDateOfBirth} = $insured2->getDateOfBirth(DATEFORMAT_USA);
				$data->{otherInsuredSexM} = $insured2->getSex() eq 'M' ? "Checked" : "";
				$data->{otherInsuredSexF} = $insured2->getSex() eq 'F' ? "Checked" : "";
				$data->{otherInsuredEmployerOrSchoolName} = $insured2->getEmployerOrSchoolName;
				$data->{otherInsuredInsurancePlanOrProgramName} = $insured2->getInsurancePlanOrProgramName;
				$data->{otherInsuredPolicyGroupName} = $insured2->getPolicyGroupOrFECANo; # || $insured2->getPolicyGroupName;
			}
		}
		elsif (($insured1->getInsurancePlanOrProgramName ne "" ) && ($insured2->getInsurancePlanOrProgramName ne ""))
			{
				$data->{insuredAnotherHealthBenefitPlanY} =  "Checked" ;
			}
		elsif (($insured2->getInsurancePlanOrProgramName eq ""))
			{
				$data->{insuredAnotherHealthBenefitPlanN} =  "Checked" ;
				$data->{otherInsuredName} = "None";
			}
	}
}


sub populateClaim
{
	my ($self, $claim, $procesedProc) = @_;
#	my $physicianAddress = $physician->getAddress();
	my $data = $self->{data};
	$data->{claimAcceptAssignmentN} = uc($claim->getAcceptAssignment) eq 'N' ? "Checked" : "";
	$data->{claimAcceptAssignmentY} = (uc($claim->getAcceptAssignment) eq 'Y') || ($claim->getAcceptAssignment eq '') ? "Checked" : "";
	$data->{claimConditionRelatedToEmploymentPatientY} = uc($claim->getConditionRelatedToEmployment) eq 'Y' ? "Checked" : "";
	$data->{claimConditionRelatedToEmploymentPatientN} = uc($claim->getConditionRelatedToEmployment) eq 'N' ? "Checked" : "";
	$data->{claimConditionRelatedToAutoAccidentY} = uc($claim->getConditionRelatedToAutoAccident) eq 'Y' ? "Checked" : "";
	$data->{claimConditionRelatedToAutoAccidentN} =	uc($claim->getConditionRelatedToAutoAccident) eq 'N' ? "Checked" : "";
	$data->{claimConditionRelatedToAutoAccidentPlace} = uc($claim->getConditionRelatedToAutoAccidentPlace);
	$data->{claimConditionRelatedToOtherAccidentY} = uc($claim->getConditionRelatedToOtherAccident) eq 'Y' ? "Checked" : "";
	$data->{claimConditionRelatedToOtherAccidentN} = uc($claim->getConditionRelatedToOtherAccident) eq 'N' ? "Checked" : "";
	$data->{claimProgramNameChampus} = uc($claim->getProgramName) eq 'CHAMPUS' ? "Checked" : "";
	$data->{claimProgramNameChampva} = uc($claim->getProgramName) eq 'CHAMPVA' ? "Checked" : "";
	$data->{claimProgramNameGHP} = uc($claim->getProgramName) eq 'GROUP HEALTH PLAN' ? "Checked" : "";
	$data->{claimProgramNameMedicaid} = uc($claim->getProgramName) eq 'MEDICAID' ? "Checked" : "";
	$data->{claimProgramNameMedicare} = uc($claim->getProgramName) eq 'MEDICARE' ? "Checked" : "";
	$data->{claimProgramNameOther} = uc($claim->getProgramName) eq 'OTHER' ? "Checked" : "";
	$data->{claimProgramNameFECA} = uc($claim->getProgramName) eq 'FECA' ? "Checked" : "";

	$data->{claimTotalCharge} = "Contd";
	$data->{claimBalance} =  "Contd";

	my $physician = $claim->getRenderingProvider();
	$data->{transProviderName} = $physician->{completeName};
	$data->{providerSignatureDate} = uc($claim->getInvoiceDate);

}

sub populateTreatment
{
	my ($self, $claim) = @_;
	my $treatment = $claim->getTreatment();
	my $data = $self->{data};

	$data->{treatmentDateOfIllnessInjuryPregnancy} = $treatment->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA);
	$data->{treatmentDateOfSameOrSimilarIllness} = $treatment->getDateOfSameOrSimilarIllness(DATEFORMAT_USA);
	$data->{datePatientUnableToWorkFrom} = $treatment->getDatePatientUnableToWorkFrom(DATEFORMAT_USA);
	$data->{datePatientUnableToWorkTo} = $treatment->getDatePatientUnableToWorkTo(DATEFORMAT_USA);
	$data->{treatmentHospitilizationDateFrom} = $treatment->getHospitilizationDateFrom(DATEFORMAT_USA);
	$data->{treatmentHospitilizationDateTo} = $treatment->getHospitilizationDateTo(DATEFORMAT_USA);
	$data->{treatmentIdOfReferingPhysician} = $treatment->getIDOfReferingPhysician;
	$data->{treatmentIdOfReferingPhysician} = '0000001-00' if ($data->{treatmentIdOfReferingPhysician} eq '');
	$data->{treatmentMedicaidResubmission} = $treatment->getMedicaidResubmission;
	if ($treatment->getRefProviderLastName ne "")
	{
		$data->{nameOfReferingPhysicianOrOther} = $treatment->getRefProviderLastName . ", " . $treatment->getRefProviderFirstName  . " " . $treatment->getRefProviderMiName;
	}
	$data->{treatmentOutsideLabY} = uc($treatment->getOutsideLab) eq 'Y' ? "Checked" : "";
	$data->{treatmentOutsideLabN} = uc($treatment->getOutsideLab) eq 'N' ? "Checked" : "";
	$data->{treatmentOutsideLabCharges} = $treatment->getOutsideLabCharges;
	$data->{treatmentPriorAuthorizationNo} = $treatment->getPriorAuthorizationNo;
	$data->{treatmentResubmissionReference} = $treatment->getResubmissionReference;
}

sub populateProcedure
{
	my ($self, $procedure, $i, $tb) = @_;
	my $data = $self->{data};
	$i ++;
	$data->{'procedure' . $i . 'DateOfServiceFrom'} = $procedure->getDateOfServiceFrom(DATEFORMAT_USA);
	$data->{'procedure' . $i . 'DateOfServiceTo'} = $procedure->getDateOfServiceTo(DATEFORMAT_USA);
	$data->{'procedure' . $i . 'PlaceOfService'} = $procedure->getPlaceOfService;
	$data->{'procedure' . $i . 'TypeOfService'}	= $procedure->getTypeOfService;
	$data->{'procedure' . $i . 'Cpt'} = $procedure->getCPT;
	$data->{'procedure' . $i . 'Modifier'} = $procedure->getModifier;
	my $cod = $procedure->getDiagnosis;
	$cod =~ s/ //g;
	my $ptr;
	my @diagCodes = split(/,/, $cod);
	for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
	{
	$ptr = $ptr . $diagCodes[$diagnosisCount] . ","  ;
	}
#	my $ptr = $procedure->getDiagnosisCodePointer;
#	$ptr =~ s/ /,/g;
	$ptr = substr($ptr, 0,length($ptr)-1);
	$data->{'procedure' . $i . 'DiagnosisCodePointer'} = $ptr; # join (' ', @$ptr);
	$data->{'procedure' . $i . 'Charges'} = $procedure->getCharges;
	$data->{'procedure' . $i . 'DaysOrUnits'} = substr ('000' . $procedure->getDaysOrUnits(), length('000' . $procedure->getDaysOrUnits()) - 3);
	$data->{'procedure' . $i . 'Emergency'}	 = $procedure->getEmergency;
}

sub populateFinalCharges
{
	
	my ($self, $claim) = @_;
	my $data = $self->{data};
	
	$data->{claimTotalCharge} = $claim->getTotalCharge;
	$data->{claimBalance} = abs(abs($claim->getTotalCharge) - abs($claim->getTotalChargePaid));

}


1;