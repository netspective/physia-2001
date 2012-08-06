#########################################################################
package App::Billing::Output::Html::Template;
#########################################################################
use strict;
use vars qw(@ISA);

# this object is inherited from App::Billing::Output::Driver
use App::Billing::Output::Html::Worker;

use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type, %params) = @_;
	$params{data} = {
		claimProgramNameFECA => undef,
		claimProgramNameMedicare => undef,
		claimProgramNameMedicaid => undef,
		claimProgramNameChampus => undef,
		claimProgramNameChampva => undef,
		claimProgramNameGHP => undef,
		claimProgramNameOther => undef,
		insuredId => undef,
		patientName => undef,
		patientDateOfBirth => undef,
		patientSexM => undef,
		patientSexF => undef,
		insuredName => undef,
		patientAddress => undef,
		patientAddressCity => undef,
		patientAddressState => undef,
		patientAddressZipCode => undef,
		patientAddressTelephone => undef,
		patientInsuredRelationSelf => undef,
		patientInsuredRelationSpouse => undef,
		patientInsuredRelationChild => undef,
		patientInsuredRelationOther => undef,
		insuredAddress => undef,
		insuredAddressCity => undef,
		insuredAddressState => undef,
		insuredAddressZipCode => undef,
		insuredAddressTelephone => undef,
		patientStatusSingle => undef,
		patientStatusMarried => undef,
		patientStatusOther => undef,
		patientStatusEmployment => undef,
		patientStatusStudentFullTime => undef,
		patientStatusStudentPartTime => undef,
		otherInsuredName => undef,
		otherInsuredPolicyGroupName => undef,
		otherInsuredDateOfBirth => undef,
		otherInsuredSexM => undef,
		otherInsuredSexF => undef,
		otherInsuredEmployerOrSchoolName => undef,
		otherInsuredInsurancePlanOrProgramName => undef,
		insuredPolicyGroupName => undef,
		insuredDateOfBirth => undef,
		insuredSexM => undef,
		insuredSexF => undef,
		insuredEmployerOrSchoolName => undef,
		insuredInsurancePlanOrProgramName => undef,
		insuredAnotherHealthBenefitPlanY => undef,
		insuredAnotherHealthBenefitPlanN => undef,
		treatmentDateOfIllnessInjuryPregnancy => undef,
		treatmentDateOfSameOrSimilarIllness => undef,
		datePatientUnableToWorkFrom => undef,
		datePatientUnableToWorkTo => undef,
		nameOfReferingPhysicianOrOther => undef,
		treatmentIdOfReferingPhysician => undef,
		treatmentHospitilizationDateFrom => undef,
		treatmentHospitilizationDateTo => undef,
		treatmentDiagnosisPrimary => undef,
		treatmentDiagnosisSecondary => undef,
		treatmentDiagnosisTertiary => undef,
		treatmentDiagnosisOther => undef,
		treatmentOutsideLab => undef,
		treatmentOutsideLabCharges => undef,
		treatmentMedicaidResubmission => undef,
		treatmentResubmissionReference => undef,
		treatmentPriorAuthorizationNo => undef,
		procedure1DateOfServiceFrom => undef,
		procedure1DateOfServiceTo => undef,
		procedure1PlaceOfService => undef,
		procedure1TypeOfService => undef,
		procedure1Cpt => undef,
		procedure1Modifier => undef,
		procedure1CodePointer => undef,
		procedure1Charges => undef,
		procedure1DaysOrUnits => undef,
		procedure1Emergency => undef,
		procedure2DateOfServiceFrom => undef,
		procedure2DateOfServiceTo => undef,
		procedure2PlaceOfService => undef,
		procedure2TypeOfService => undef,
		procedure2Cpt => undef,
		procedure2Modifier => undef,
		procedure2CodePointer => undef,
		procedure2Charges => undef,
		procedure2DaysOrUnits => undef,
		procedure2Emergency => undef,
		procedure3DateOfServiceFrom => undef,
		procedure3DateOfServiceTo => undef,
		procedure3PlaceOfService => undef,
		procedure3TypeOfService => undef,
		procedure3Cpt => undef,
		procedure3Modifier => undef,
		procedure3CodePointer => undef,
		procedure3Charges => undef,
		procedure3DaysOrUnits => undef,
		procedure3Emergency => undef,
		procedure4DateOfServiceFrom => undef,
		procedure4DateOfServiceTo => undef,
		procedure4PlaceOfService => undef,
		procedure4TypeOfService => undef,
		procedure4Cpt => undef,
		procedure4Modifier => undef,
		procedure4CodePointer => undef,
		procedure4Charges => undef,
		procedure4DaysOrUnits => undef,
		procedure4Emergency => undef,
		procedure5DateOfServiceFrom => undef,
		procedure5DateOfServiceTo => undef,
		procedure5PlaceOfService => undef,
		procedure5TypeOfService => undef,
		procedure5Cpt => undef,
		procedure5Modifier => undef,
		procedure5CodePointer => undef,
		procedure5Charges => undef,
		procedure5DaysOrUnits => undef,
		procedure5Emergency => undef,
		procedure6DateOfServiceFrom => undef,
		procedure6DateOfServiceTo => undef,
		procedure6PlaceOfService => undef,
		procedure6TypeOfService => undef,
		procedure6Cpt => undef,
		procedure6Modifier => undef,
		procedure6CodePointer => undef,
		procedure6Charges => undef,
		procedure6DaysOrUnits => undef,
		procedure6Emergency => undef,
		physicianFederalTaxId => undef,
		physicianTaxTypeIdEin => undef,
		physicianTaxTypeIdSsn => undef,
		providerLicense => undef,
		patientAccountNo => undef,
		claimAcceptAssignmentY => undef,
		claimAcceptAssignmentN => undef,
		claimTotalCharge => undef,
		claimAmountPaid => undef,
		claimBalance => undef,
		organizationName => undef,
		organizationAddress => undef,
		organizationCityStateZipCode => undef,
		physicianName => undef,
		physicianAddress => undef,
		physicianCityStateZipCode => undef,
		physicianTelephone => undef,
		physicianGrp => undef,
		physicianPin => undef,
		transProviderName => undef,
		providerSignatureDate => undef,
		signatureInsured => undef,
		signaturePatient => undef,
		signaturePatientDate => undef,
		payerName => undef,
		payerAddress => undef,
		comments => undef,
	};
	return bless \%params, $type;
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

sub concatSpace
{
	my ($self) = @_;
	my $key;
	my $data = $self->{data};

	foreach $key (keys %$data)
	{
		$data->{$key} = ($data->{$key} eq "" ? '&nbsp' : $data->{$key});
	}
}
sub doInit
{
	my ($self) = @_;
	my $key;
	my $data = $self->{data};

	foreach $key (keys %$data)
	{
		$data->{$key} = undef;
	}
}

sub populatePatient
{
	my ($self, $claim) = @_;
	my $patient = $claim->getCareReceiver();
	my $patientAddress = $patient->getAddress();
	my $claimType = $claim->getClaimType();
	my $insured = $claim->{insured}->[$claimType];
	my $data = $self->{data};

	$data->{patientName} = $patient->getLastName() . " " . $patient->getFirstName() . " " . $patient->getMiddleInitial();
	$data->{patientDateOfBirth} = $patient->getDateOfBirth(DATEFORMAT_USA);
	$data->{patientSexM} = $patient->getSex() eq 'M' ? "Checked" : "";
	$data->{patientSexF} = $patient->getSex() eq 'F' ? "Checked" : "";
	$data->{patientAccountNo} = $patient->getAccountNo();
	$data->{patientAddress} = $patientAddress->getAddress1() . " " . $patientAddress->getAddress2();
	$data->{patientAddressCity} = $patientAddress->getCity();
	$data->{patientAddressState} = $patientAddress->getState();
	$data->{patientAddressTelephone} = $patientAddress->getTelephoneNo();
	$data->{patientAddressZipCode} = $patientAddress->getZipCode();
	$data->{patientStatusEmployment} = $patient->getEmploymentStatus() ne "" ? "checked" : "";
#	$data->{patientInsuredRelationSelf} = (uc($patient->getRelationshipToInsured) =~ /1|SELF/) ? "checked" : "";
#	$data->{patientInsuredRelationSpouse} = (uc($patient->getRelationshipToInsured) =~ /2|SPOUSE/) ? "checked" : "";
#	$data->{patientInsuredRelationChild} = (uc($patient->getRelationshipToInsured) =~ /3|5|6|CHILD/) ? "checked" : "";
#	$data->{patientInsuredRelationOther} = (uc($patient->getRelationshipToInsured) =~ /4|7|8|9|10|11|12|13|14|15|16|17|18|19|50|99|OTHER/) ? "checked" : "";
	$data->{patientInsuredRelationSelf} = (uc($insured->getRelationshipToPatient) =~ /01/) ? "checked" : "";
	$data->{patientInsuredRelationSpouse} = (uc($insured->getRelationshipToPatient) =~ /02/) ? "checked" : "";
	$data->{patientInsuredRelationChild} = (uc($insured->getRelationshipToPatient) =~ /03|04|05|06/) ? "checked" : "";
	$data->{patientInsuredRelationOther} = (uc($insured->getRelationshipToPatient) =~ /07|08|09|10|11|12|13|14|15|16|17|18|19|99/) ? "checked" : "";
	$data->{patientStatusSingle} = uc(($patient->getStatus) =~ /S/) ? "checked" : "";
	$data->{patientStatusMarried} = uc($patient->getStatus) =~ /M/ ? "checked" : "";
	$data->{patientStatusOther} = uc($patient->getStatus) =~ /U|D|W|X|P/ ? "checked" : "";
	$data->{patientStatusStudentFullTime} = uc($patient->getStudentStatus)  =~ /STUDENT \(FULL-TIME\)|F|0/ ? "checked" : "";
	$data->{patientStatusStudentPartTime} = uc($patient->getStudentStatus)  =~ /STUDENT \(PART-TIME\)|P|1/ ? "checked" : "";
	$data->{signaturePatient} = uc($patient->getSignature()) =~ /C|S|B|P/ ? 'Signature on File' : "Signature on File";
#	$data->{signaturePatientDate} = uc(uc($patient->getSignature()) =~ /C|S|B|P/ ? $patient->getSignatureDate(): "")
	$data->{signaturePatientDate} = uc($claim->getInvoiceDate);
}

sub populateInsured
{
	my ($self, $claim) = @_;
	my $claimType = $claim->getClaimType();
	my $insured = $claim->{insured}->[$claimType];
	my $insuredAddress = $insured->getAddress();
	my $data = $self->{data};

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
			}
	}
}

sub populatePhysician
{
	my ($self, $claim) = @_;
	my $billingFacility = $claim->getPayToOrganization();
	my $billingPhysician = $claim->getPayToProvider();
	my $billingFacilityAddress = $billingFacility->getAddress();
	my $data = $self->{data};

	$data->{physicianAddress} = $billingFacilityAddress->getAddress1 . " " . $billingFacilityAddress->getAddress2;
	$data->{physicianCityStateZipCode} = $billingFacilityAddress->getCity . " " . $billingFacilityAddress->getState . " " . $billingFacilityAddress->getZipCode;
	$data->{physicianFederalTaxId} = $billingFacility->getTaxId eq "" ? $billingFacility->getTaxId : $billingFacility->getTaxId;
	$data->{physicianName} = $billingFacility->getName;
	$data->{physicianTaxTypeIdEin} = $billingFacility->getTaxId ne '' ? "Checked" : "";
#	$data->{physicianTaxTypeIdSsn} = uc($physician->getTaxTypeId) eq 'S' ? "Checked" : "";
	$data->{physicianPin} = $billingPhysician->getPIN;
	if($billingPhysician->getInsType() ne '99')
	{
		$data->{physicianGrp} = $billingFacility->getGRP;
	}
}

sub populateOrganization
{
	my ($self, $claim) = @_;
	my $organization = $claim->getRenderingOrganization();
	my $organizationAddress = $organization->getAddress();
	my $data = $self->{data};

	$data->{organizationAddress} = $organizationAddress->getAddress1 . " " . $organizationAddress->getAddress2;
	$data->{organizationCityStateZipCode} = $organizationAddress->getCity . " " . $organizationAddress->getState . " " . $organizationAddress->getZipCode;
	$data->{organizationName} = $organization->getName;
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
	if(uc($claim->getProgramName) eq 'MEDICARE')
	{
		my $populateCLIA = 0;
		my $proceduresCount = $claim->{procedures};
		if($#$proceduresCount > -1)
		{
			for my $i (0..$#$proceduresCount)
			{
				my $procedure = $claim->getProcedure($i);
				if(uc($procedure->getItemStatus) ne "VOID")
				{
					my $CPT = $procedure->getCPT();
					if(($CPT >= 80000) && ($CPT >= 89999))
					{
						$populateCLIA = 1;
					}
				}
			}
		}
		$data->{treatmentPriorAuthorizationNo} = $claim->{renderingOrganization}->getCLIA;
	}
}

sub populateDiagnosis
{
	my ($self, $claim, $tb) = @_;
	my $data = $self->{data};
	my $dgs = $tb->[0];
	my $dgs1;
	my $dg = {
			1 => 'treatmentDiagnosisPrimary',
			2 => 'treatmentDiagnosisSecondary',
			3 => 'treatmentDiagnosisTertiary',
			4 => 'treatmentDiagnosisOther',
		};

	foreach $dgs1(keys (%$dgs))
	{
		if ($dgs->{$dgs1} < 5)
		{
			$data->{$dg->{$dgs->{$dgs1}}} = $dgs1;
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
	$data->{claimAmountPaid} =  "Contd";
	$data->{claimBalance} =  "Contd";

	my $physician = $claim->getPayToProvider();
	$data->{transProviderName} = $physician->{completeName};
	$data->{providerSignatureDate} = uc($claim->getInvoiceDate);
	$data->{comments} = $self->getComments($claim);

}

sub populatePayer
{
	my ($self, $claim) = @_;
	my $claimType = $claim->getClaimType();
	my $payer = $claim->{policy}->[$claimType];
	my $payerAddress = $payer->getAddress();
	my $data = $self->{data};

    $data->{payerName} = $payer->getName();
    $data->{payerAddress} = $payerAddress->getAddress1() . " <br> " . $payerAddress->getCity() . " " . $payerAddress->getState(). " " . $payerAddress->getZipCode();
}

sub populateProcedures
{
	my ($self, $claim, $procesedProc) = @_;
	my $procedures = $claim->{procedures};
	my $procedureNo = 0;
	my $tb = $self->diagnosisTable($claim, $procesedProc);
	my $procedurest = $tb->[1];
	my $sortedCharges = $self->feeSort($claim, $procedurest);
	my $amount = $sortedCharges->{'sorted amount'};
	my $procNo;
	for (my $i =0; $i <= $#$procedurest;)
	{
		my @procNos = split(/,/,$sortedCharges->{$amount->[$i]});
		foreach $procNo(@procNos)
		{
			my $procedure = $claim->{procedures}->[$procNo];
			if ($procedure ne "")
			{
				if (uc($procedure->getItemStatus) ne "VOID")
				{
					$self->populateProcedure($procedure, $procedureNo, $tb);
					$procedureNo++;
				}
			}
		}
		$i++;
	}
	return $tb;
}

sub feeSort
{
	my ($self, $claim, $targetProcedures) = @_;

	my $procedures = $claim->{procedures};
	my %charges;
	my	$procedure;
	for my $i (0..$#$targetProcedures)
	{
		$procedure = $procedures->[$targetProcedures->[$i]];
		$charges{$procedure->getCharges()} = $targetProcedures->[$i] . "," . $charges{$procedure->getCharges()};
	}
	my @as = sort {$b <=> $a} keys %charges;
	$charges{'sorted amount'} = \@as;
	return \%charges;
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
	$ptr = $ptr . $tb->[0]->{$diagCodes[$diagnosisCount]} . ","  ;
	}
#	my $ptr = $procedure->getDiagnosisCodePointer;
#	$ptr =~ s/ /,/g;
	$ptr = substr($ptr, 0,length($ptr)-1);
	$data->{'procedure' . $i . 'DiagnosisCodePointer'} = $ptr; # join (' ', @$ptr);
	$data->{'procedure' . $i . 'Charges'} = $self->trailingZeros($procedure->getCharges);
	$data->{'procedure' . $i . 'DaysOrUnits'} = substr ('000' . $procedure->getDaysOrUnits(), length('000' . $procedure->getDaysOrUnits()) - 3);
	$data->{'procedure' . $i . 'Emergency'}	 = $procedure->getEmergency;
}




sub diagnosisTable
{
	my ($self, $claim, $processedProc)  = @_;
	my $diag;
	my $procCount;
	my @targetproc;
	my $cod;
	my %diagTable;
	my $tempCount;

	my $procedures = $claim->{procedures};
	for my $i (0..$#$procedures)
	{
		my $procedure = $procedures->[$i];
		if (uc($procedure->getItemStatus) eq "VOID")
		{
			$processedProc->[$i] = 1;
		}
	}

	for my $i (0..$#$procedures)
	{
		if (($diag <= 4) && ($procCount < 6) && ($processedProc->[$i] != 1))
		{
			my $procedure = $procedures->[$i];
			$cod = $procedure->getDiagnosis;
		    $cod =~ s/ //g;
			my @diagCodes = split(/,/, $cod);
			for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
			{
				$tempCount = 0;
				if (not (exists($diagTable{$diagCodes[$diagnosisCount]})))
				{
					$tempCount++;
				}
			}
			if ($tempCount + $diag <= 4)
			{
				for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
				{
					if (not (exists($diagTable{$diagCodes[$diagnosisCount]})))
					{
						$diag++;
						$diagTable{$diagCodes[$diagnosisCount]} = $diag;
					}
				}
				$processedProc->[$i] = 1;
				push(@targetproc, $i);
				$procCount++;
			}
		}
	}
	return 	[\%diagTable, \@targetproc];
}

sub populateFinalCharges
{

	my ($self, $claim) = @_;
	my $data = $self->{data};

	$data->{claimTotalCharge} = $self->trailingZeros($claim->getTotalCharge);
	$data->{claimAmountPaid} = $self->trailingZeros(abs($claim->getTotalChargePaid));
	$data->{claimBalance} = $self->trailingZeros(abs(abs($claim->getTotalCharge) - abs($claim->getTotalChargePaid)));
#	$data->{claimAmountPaid} = $self->trailingZeros(abs($claim->getAmountPaid));
#	$data->{claimBalance} = $self->trailingZeros(abs(abs($claim->getTotalCharge) - abs($claim->getAmountPaid)));

}

sub getComments
{
	my ($self, $claim) = @_;

	my $procedures = $claim->{procedures};
	my $procedure;
	my $comments = '';

	foreach my $i (0..$#$procedures)
	{
		$procedure = $procedures->[$i];
		$comments = $procedure->{comments};
		last if ($procedure->{comments} ne '')
	}
	return $comments;
}

sub trailingZeros
{
	my ($self, $value) = @_;

	my @wholeFraction = split(/\./,$value);
	my $fractionLength = length($wholeFraction[1]);
	my $fraction;
	if($fractionLength == 0)
	{
		$fraction = '00';
	}
	elsif($fractionLength == 1)
	{
		$fraction = $wholeFraction[1] . '0';
	}
	else
	{
		$fraction = substr($wholeFraction[1], 0, 2);
	}
	return $wholeFraction[0] . '.' . $fraction;
}

1;