#########################################################################
package App::Billing::Output::Html::Worker;
#########################################################################
use strict;
use vars qw(@ISA);
@ISA = qw(App::Billing::Output::Html::Template);
# this object is inherited from App::Billing::Output::Driver
use Devel::ChangeLog;
use vars qw(@CHANGELOG);
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

	$data->{patientName} = $patient->getLastName() . " " . $patient->getFirstName() . " " . $patient->getMiddleInitial();
	$data->{patientDateOfBirth} = $patient->getDateOfBirth(DATEFORMAT_USA);
	$data->{patientSexM} = $patient->getSex() eq 'M' ? "Checked" : "";
	$data->{patientSexF} = $patient->getSex() eq 'F' ? "Checked" : "";
	$data->{patientAddress} = $patientAddress->getAddress1() . " " . $patientAddress->getAddress2();
	$data->{patientAddressCity} = $patientAddress->getCity();
	$data->{patientAddressState} = $patientAddress->getState();
	$data->{patientAddressTelephone} = $patientAddress->getTelephoneNo();
	$data->{patientAddressZipCode} = $patientAddress->getZipCode();
}

sub populateInsured
{
	my ($self, $claim) = @_;
	my $claimType = $claim->getClaimType();
	my $insured = $claim->{insured}->[$claimType];
	my $insuredAddress = $insured->getAddress();
	my $data = $self->{data};

	$data->{insuredName} = $claim->{careReceiver}->getEmployerOrSchoolName ;
	my $dataA = $claim->{careReceiver}->getEmployerAddress;
	$data->{insuredAddressCity} = $dataA->getCity;
	$data->{insuredAddressState} = $dataA->getState;
	$data->{insuredAddressTelephone} = $dataA->getTelephoneNo;
	$data->{insuredAddressZipCode} = $dataA->getZipCode;
	$data->{insuredAddress} = $dataA->getAddress1 . " " . $dataA->getAddress2;
	$data->{insuredId} = $claim->{careReceiver}->getSsn();
	$data->{insuredPolicyGroupName} = "N/A"; $insured->getPolicyGroupOrFECANo;
}

sub populatePhysician
{
	my ($self, $claim) = @_;
	my $physician = $claim->getPayToOrganization();
	my $physicianAddress = $physician->getAddress();
	my $data = $self->{data};

	$data->{physicianAddress} = $physicianAddress->getAddress1 . " " . $physicianAddress->getAddress2;
	$data->{physicianCityStateZipCode} = $physicianAddress->getCity . " " . $physicianAddress->getState . " " . $physicianAddress->getZipCode;
	$data->{physicianFederalTaxId} = $physician->getFederalTaxId;
	$data->{physicianName} = $physician->getName;
	$data->{physicianTaxTypeIdEin} = $physician->getFederalTaxId ne '' ? "Checked" : "";
#	$data->{physicianTaxTypeIdSsn} = uc($physician->getTaxTypeId) eq 'S' ? "Checked" : "";
#	$data->{physicianPin} = $physician->getPIN;
#	$data->{physicianGrp} = $physician->getGRP;
}

sub populateTreatment
{
	my ($self, $claim) = @_;
	my $treatment = $claim->getTreatment();
	my $data = $self->{data};

	$data->{treatmentDateOfIllnessInjuryPregnancy} = $treatment->getDateOfIllnessInjuryPregnancy(DATEFORMAT_USA);
	$data->{treatmentDateOfSameOrSimilarIllness} = $treatment->getDateOfSameOrSimilarIllness(DATEFORMAT_USA);
}

sub populateClaim
{
	my ($self, $claim) = @_;
	my $physician = $claim->getRenderingProvider();
	my $physicianAddress = $physician->getAddress();
	my $data = $self->{data};
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
	$data->{claimTotalCharge} = $claim->getTotalCharge;
	$data->{transProviderName} = $claim->getTransProviderName();
}

@CHANGELOG =
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '02/16/2000', 'SSI', 'Billing Interface/PDF Claim','Procedure are displayed on descending order of charges. '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '04/19/2000', 'SSI', 'Billing Interface/PDF Claim','transFacilityId is added to reflect the box31 of HCFA. '],

);

1;