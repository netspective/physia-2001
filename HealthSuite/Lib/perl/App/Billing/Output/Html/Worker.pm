#########################################################################
package App::Billing::Output::Html::Worker;
#########################################################################
use strict;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::Html::Template);
# this object is inherited from App::Billing::Output::Driver
use constant DATEFORMAT_USA => 1;
use constant CLAIM_TYPE_WORKCOMP => 6;
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
	$self->populatePhysician($claim);
	$self->populateTreatment($claim);
	$self->populateClaim($claim);
	$self->populateOrganization($claim);
	my $tb = $self->populateProcedures($claim, $procesedProc);
	$self->populateDiagnosis($claim, $tb);
	$self->concatSpace();
}

sub populatePatient
{
	my ($self, $claim) = @_;
	my $patient = $claim->getCareReceiver();
	my $patientAddress = $patient->getAddress();
	my $data = $self->{data};

	$data->{patientAccountNo} = $patient->getAccountNo();
	$data->{patientName} = $patient->getLastName() . " " . $patient->getFirstName() . " " . $patient->getMiddleInitial();
	$data->{patientDateOfBirth} = $patient->getDateOfBirth(DATEFORMAT_USA);
	$data->{patientSexM} = $patient->getSex() eq 'M' ? "Checked" : "";
	$data->{patientSexF} = $patient->getSex() eq 'F' ? "Checked" : "";
	$data->{patientAddress} = $patientAddress->getAddress1() . " " . $patientAddress->getAddress2();
	$data->{patientAddressCity} = $patientAddress->getCity();
	$data->{patientAddressState} = $patientAddress->getState();
	$data->{patientAddressTelephone} = $patientAddress->getTelephoneNo();
	$data->{patientAddressZipCode} = $patientAddress->getZipCode();
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

	$data->{insuredName} = $claim->{insured}->[$claimType]->getEmployerOrSchoolName;
	my $dataA = $insured->getEmployerAddress;
	$data->{insuredAddressCity} = $dataA->getCity;
	$data->{insuredAddressState} = $dataA->getState;
	$data->{insuredAddressTelephone} = $dataA->getTelephoneNo;
	$data->{insuredAddressZipCode} = $dataA->getZipCode;
	$data->{insuredAddress} = $dataA->getAddress1 . " " . $dataA->getAddress2;
#	$data->{insuredId} = $claim->{careReceiver}->getSsn();
	$data->{insuredId} = $insured->getSsn();
	$data->{insuredPolicyGroupName} = $insured->getPolicyGroupOrFECANo;
#	$data->{insuredPolicyGroupName} = "N/A";
	$data->{signatureInsured} = uc($claim->{careReceiver}->getSignature()) =~ /M|B/ ? 'Signature on File' : "Signature on File";
	$data->{insuredAnotherHealthBenefitPlanN} =  "Checked" ;
	my $payer = $claim->{payer};
	$data->{payerName} = $payer->getName();
	my $payerAddress = $payer->getAddress();
  $data->{payerAddress} = $payerAddress->getAddress1() . " <br> " . $payerAddress->getCity() . " " . $payerAddress->getState(). " " . $payerAddress->getZipCode();
#	my $address = $claim->getCareReceiver()->getEmployerAddress();

#	if ($address ne "")
#	{
#		$data->{payerAddress} = $address->getAddress1() . " <br> " . $address->getCity() . " " . $address->getState(). " " . $address->getZipCode();
#	}
}

sub populatePhysician
{
	my ($self, $claim) = @_;
	my $physician = $claim->getPayToProvider();
#	my $servicePhysician = $claim->getRenderingProvider();
	my $billingFacility = $claim->getPayToOrganization();
	my $billingFacilityAddress = $billingFacility->getAddress();
	my $data = $self->{data};

	$data->{physicianAddress} = $billingFacilityAddress->getAddress1 . " " . $billingFacilityAddress->getAddress2;
	$data->{physicianCityStateZipCode} = $billingFacilityAddress->getCity . " " . $billingFacilityAddress->getState . " " . $billingFacilityAddress->getZipCode;
	$data->{physicianFederalTaxId} = $billingFacility->getTaxId eq "" ? $billingFacility->getTaxId : $billingFacility->getTaxId;
	$data->{physicianName} = $billingFacility->getName;
	$data->{physicianTaxTypeIdEin} = $billingFacility->getTaxId ne "" ? "Checked" : "";
#	$data->{physicianTaxTypeIdSsn} = uc($physician->getTaxTypeId) eq 'S' ? "Checked" : "";
	$data->{physicianTelephone} = $billingFacilityAddress->getTelephoneNo(1);
	$data->{physicianPin} = $physician->getPIN;
	$data->{physicianGrp} = $billingFacility->getGRP;
	$data->{providerLicense} = $physician->getProfessionalLicenseNo;
}

sub populateTreatment
{
	my ($self, $claim) = @_;
	my $treatment = $claim->getTreatment();
	my $data = $self->{data};

	$data->{treatmentDateOfIllnessInjuryPregnancy} = $treatment->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA);
	$data->{treatmentDateOfSameOrSimilarIllness} = $treatment->getDateOfSameOrSimilarIllness(DATEFORMAT_USA);
	$data->{treatmentOutsideLabY} = "";
	$data->{treatmentOutsideLabN} = "";

}

sub populateClaim
{
	my ($self, $claim) = @_;
	my $physician = $claim->getPayToProvider();
	my $physicianAddress = $physician->getAddress();
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
#	$data->{claimTotalCharge} = $claim->getTotalCharge;
#	$data->{claimBalance} = $claim->getTotalCharge;
	$data->{claimTotalCharge} = "Contd";
	$data->{claimAmountPaid} =  "Contd";
	$data->{claimBalance} =  "Contd";

	$data->{transProviderName} = $physician->getName();
	$data->{providerSignatureDate} = uc($claim->getInvoiceDate);

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


1;