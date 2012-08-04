##############################################################################
package App::Billing::Claim::Treatment;
##############################################################################

#
# this object encapsulates a single "treatment" item in the HCFA 1500
#

use strict;

use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type, %params) = @_;

	$params{dateOfIllnessInjuryPregnancy} = undef;
	$params{dateOfSameOrSimilarIllness} = undef;
	$params{datePatientUnableToWorkFrom} = undef;
	$params{datePatientUnableToWorkTo} = undef;
	$params{hospitilizationDateFrom} = undef;
	$params{hospitilizationDateTo} = undef;
	$params{outsideLab} = undef;
	$params{outsideLabCharges} = undef;
	$params{medicaidResubmission} = undef;
	$params{resubmissionReference} = undef;
	$params{priorAuthorizationNo} = undef;

	# This has to be moved in Claim as Referring Physician

	$params{idOfReferingPhysician} = undef;
	$params{refProviderLastName} = undef;
	$params{refProviderFirstName} = undef;
	$params{refProviderMiName} = undef;
	$params{referingPhysicianIDIndicator} = undef; # Only for Envoy
	$params{referingPhysicianState} = undef;
	$params{id} = undef;

	# TWCC Values

	$params{returnToLimitedWorkAnticipatedDate} = undef;
	$params{maximumImpovementAnticipatedDate} = undef;
	$params{returnToFullTimeWorkAnticipatedDate} = undef;
	$params{injuryHistory} = undef;
	$params{pastMedicalHistory} = undef;
	$params{clinicalFindings} = undef;
	$params{laboratoryTests} = undef;
	$params{treatmentPlan} = undef;
	$params{referralInfo61} = undef;
	$params{referralSelection} = undef;
	$params{referralInfo64} = undef;
	$params{medications61} = undef;
	$params{medications64} = undef;
	$params{prognosis} = undef;
	$params{dateMailedToEmployee} = undef;
	$params{dateMailedToInsurance} = undef;

	$params{activityType} = undef;
	$params{activityDate} = undef;
	$params{reasonForReport} = undef;
	$params{changeInCondition} = undef;
	$params{complianceByEmployee} = undef;

	$params{maximumImprovement} = undef;
	$params{maximumImprovementDate} = undef;
	$params{impairmentRating} = undef;
	$params{doctorType} = undef;
	$params{examiningDoctorType} = undef;
	$params{maximumImprovementAgreement} = undef;
	$params{impairmentRatingAgreement} = undef;

	return bless \%params, $type;
}

sub setId
{
	my ($self,$value) = @_;
	$self->{id} = $value;
}

sub getId
{
	my $self = shift;
	return $self->{id};
}

sub setReferringProvider
{
	my ($self, $value) = @_;
	$self->{referringProvider} = $value;
}

sub getReferringProvider
{
	my ($self) = @_;
	return $self->{referringProvider};
}

sub setReferringOrganization
{
	my ($self, $value) = @_;
	$self->{referringOrganization} = $value;
}

sub getReferringOrganization
{
	my ($self) = @_;
	return $self->{referringOrganization};
}

sub setReferingPhysicianState
{
	my ($self, $value) = @_;
	$self->{referingPhysicianState} = $value;
}

sub setReferingPhysicianIDIndicator
{
	my ($self, $value) = @_;
	$self->{referingPhysicianIDIndicator} = $value;
}

sub setRefProviderMiName
{
	my ($self, $value) = @_;
	$self->{refProviderMiName} = $value;
}

sub setRefProviderFirstName
{
	my ($self, $value) = @_;
	$self->{refProviderFirstName} = $value;
}

sub setRefProviderLastName
{
	my ($self, $value) = @_;
	$self->{refProviderLastName} = $value;
}

sub getReferingPhysicianState
{
	my $self = shift;
	return $self->{referingPhysicianState};
}


sub getReferingPhysicianIDIndicator
{
	my $self = shift;
	return $self->{referingPhysicianIDIndicator};
}


sub getRefProviderMiName
{
	my $self = shift;
	return $self->{refProviderMiName};
}

sub getRefProviderFirstName
{
	my $self = shift;
	return $self->{refProviderFirstName};
}

sub getRefProviderLastName
{
	my $self = shift;
	return $self->{refProviderLastName};
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getResubmissionReference
{
	my $self = shift;
	return $self->{resubmissionReference};
}

sub setResubmissionReference
{
	my ($self, $value) = @_;
	$self->{resubmissionReference} =  $value;
}

sub getDateOfIllnessInjuryPregnancy
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfIllnessInjuryPregnancy}) : $self->{dateOfIllnessInjuryPregnancy};
}

sub getDateOfSameOrSimilarIllness
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfSameOrSimilarIllness}) : $self->{dateOfSameOrSimilarIllness};
}

sub getDatePatientUnableToWorkFrom
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{datePatientUnableToWorkFrom}) : $self->{datePatientUnableToWorkFrom};
}

sub getDatePatientUnableToWorkTo
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{datePatientUnableToWorkTo}) : $self->{datePatientUnableToWorkTo};
}

sub getIDOfReferingPhysician
{
	my $self = shift;
	return $self->{idOfReferingPhysician};
}

sub getHospitilizationDateFrom
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{hospitilizationDateFrom}) : $self->{hospitilizationDateFrom};
}

sub getHospitilizationDateTo
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{hospitilizationDateTo}) : $self->{hospitilizationDateTo};
}

sub getOutsideLab
{
	my $self = shift;
	return $self->{outsideLab};
}

sub getOutsideLabCharges
{
	my $self = shift;
	return $self->{outsideLabCharges};
}

sub getMedicaidResubmission
{
	my $self = shift;
	return $self->{medicaidResubmission};
}

sub getPriorAuthorizationNo
{
	my $self = shift;
	return $self->{priorAuthorizationNo};
}

sub setDateOfIllnessInjuryPregnancy
{
	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfIllnessInjuryPregnancy} = $value;
}

sub setDateOfSameOrSimilarIllness
{
	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfSameOrSimilarIllness} = $value;
}

sub setDatePatientUnableToWorkFrom
{
	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{datePatientUnableToWorkFrom} = $value;
}

sub setDatePatientUnableToWorkTo
{

	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{datePatientUnableToWorkTo} = $value;
}

sub setIDOfReferingPhysician
{
	my ($self,$value) = @_;
	$self->{idOfReferingPhysician} = $value;
}

sub setHospitilizationDateFrom
{
	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{hospitilizationDateFrom} = $value;
}

sub setHospitilizationDateTo
{
	my ($self,$value) = @_;
	$value =~ s/  00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{hospitilizationDateTo} = $value;
}

sub setOutsideLab
{
	my ($self,$value) = @_;
	$self->{outsideLab} = $value;
}

sub setOutsideLabCharges
{
	my ($self,$value) = @_;
	$self->{outsideLabCharges} = $value;
}

sub setMedicaidResubmission
{
	my ($self,$value) = @_;
	$self->{medicaidResubmission} = $value;
}

sub setPriorAuthorizationNo
{
	my ($self,$value) = @_;
	$self->{priorAuthorizationNo} = $value;
}

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence =
	{
		JAN => '01', FEB => '02', MAR => '03', APR => '04',
		MAY => '05', JUN => '06', JUL => '07', AUG => '08',
		SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
	};
	$date =~ s/-//g;
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
}

sub convertDateToMMDDYYYYFromCCYYMMDD
{
	my ($self, $date) = @_;
	if ($date ne "")
	{
		return substr($date,4,2) . '/' . substr($date,6,2) . '/' . substr($date,0,4) ;
	}
	else
	{
		return "";
	}
}

sub getReturnToLimitedWorkAnticipatedDate
{
	my $self = shift;
	return $self->{returnToLimitedWorkAnticipatedDate};
}

sub getMaximumImprovementAnticipatedDate
{
	my $self = shift;
	return $self->{maximumImpovementAnticipatedDate};
}

sub getReturnToFullTimeWorkAnticipatedDate
{
	my $self = shift;
	return $self->{returnToFullTimeWorkAnticipatedDate};
}

sub getInjuryHistory
{
	my $self = shift;
	return $self->{injuryHistory};
}

sub getPastMedicalHistory
{
	my $self = shift;
	return $self->{pastMedicalHistory};
}

sub getClinicalFindings
{
	my $self = shift;
	return $self->{clinicalFindings};
}

sub getLaboratoryTests
{
	my $self = shift;
	return $self->{laboratoryTests};
}

sub getTreatmentPlan
{
	my $self = shift;
	return $self->{treatmentPlan};
}

sub getReferralInfo61
{
	my $self = shift;
	return $self->{referralInfo61};
}

sub getReferralInfo64
{
	my $self = shift;
	return $self->{referralInfo64};
}

sub getReferralSelection
{
	my $self = shift;
	return $self->{referralSelection};
}

sub getMedications61
{
	my $self = shift;
	return $self->{medications61};
}

sub getMedications64
{
	my $self = shift;
	return $self->{medications64};
}

sub getPrognosis
{
	my $self = shift;
	return $self->{prognosis};
}

sub getDateMailedToEmployee
{
	my $self = shift;
	return $self->{dateMailedToEmployee};
}

sub getDateMailedToInsurance
{
	my $self = shift;
	return $self->{dateMailedToInsurance};
}

sub getActivityType
{
	my $self = shift;
	return $self->{activityType};
}

sub getActivityDate
{
	my $self = shift;
	return $self->{activityDate};
}

sub getReasonForReport
{
	my $self = shift;
	return $self->{reasonForReport};
}

sub getChangeInCondition
{
	my $self = shift;
	return $self->{changeInCondition};
}

sub getComplianceByEmployee
{
	my $self = shift;
	return $self->{complianceByEmployee};
}

sub getMaximumImprovementDate
{
	my $self = shift;
	return $self->{maximumImprovementDate};
}

sub getMaximumImprovement
{
	my $self = shift;
	return $self->{maximumImprovement};
}

sub getImpairmentRating
{
	my $self = shift;
	return $self->{impairmentRating};
}

sub getDoctorType
{
	my $self = shift;
	return $self->{doctorType};
}

sub getExaminingDoctorType
{
	my $self = shift;
	return $self->{examiningDoctorType};
}

sub getMaximumImprovementAgreement
{
	my $self = shift;
	return $self->{maximumImprovementAgreement};
}

sub getImpairmentRatingAgreement
{
	my $self = shift;
	return $self->{impairmentRatingAgreement};
}

sub setReturnToLimitedWorkAnticipatedDate
{
	my ($self,$value) = @_;
	$self->{returnToLimitedWorkAnticipatedDate} = $value;
}

sub setMaximumImprovementAnticipatedDate
{
	my ($self,$value) = @_;
	$self->{maximumImpovementAnticipatedDate} = $value;
}

sub setReturnToFullTimeWorkAnticipatedDate
{
	my ($self,$value) = @_;
	$self->{returnToFullTimeWorkAnticipatedDate} = $value;
}

sub setInjuryHistory
{
	my ($self,$value) = @_;
	$self->{injuryHistory} = $value;
}

sub setPastMedicalHistory
{
	my ($self,$value) = @_;
	$self->{pastMedicalHistory} = $value;
}

sub setClinicalFindings
{
	my ($self,$value) = @_;
	$self->{clinicalFindings} = $value;
}

sub setLaboratoryTests
{
	my ($self,$value) = @_;
	$self->{laboratoryTests} = $value;
}

sub setTreatmentPlan
{
	my ($self,$value) = @_;
	$self->{treatmentPlan} = $value;
}

sub setReferralInfo61
{
	my ($self,$value) = @_;
	$self->{referralInfo61} = $value;
}

sub setReferralInfo64
{
	my ($self,$value) = @_;
	$self->{referralInfo64} = $value;
}

sub setReferralSelection
{
	my ($self,$value) = @_;
	$self->{referralSelection} = $value;
}

sub setMedications61
{
	my ($self,$value) = @_;
	$self->{medications61} = $value;
}

sub setMedications64
{
	my ($self,$value) = @_;
	$self->{medications64} = $value;
}

sub setPrognosis
{
	my ($self,$value) = @_;
	$self->{prognosis} = $value;
}

sub setDateMailedToEmployee
{
	my ($self,$value) = @_;
	$self->{dateMailedToEmployee} = $value;
}

sub setDateMailedToInsurance
{
	my ($self,$value) = @_;
	$self->{dateMailedToInsurance} = $value;
}

sub setActivityType
{
	my ($self,$value) = @_;
	$self->{activityType} = $value;
}

sub setActivityDate
{
	my ($self,$value) = @_;
	$self->{activityDate} = $value;
}

sub setReasonForReport
{
	my ($self,$value) = @_;
	$self->{reasonForReport} = $value;
}

sub setChangeInCondition
{
	my ($self,$value) = @_;
	$self->{changeInCondition} = $value;
}

sub setComplianceByEmployee
{
	my ($self,$value) = @_;
	$self->{complianceByEmployee} = $value;
}

sub setMaximumImprovement
{
	my ($self,$value) = @_;
	$self->{maximumImprovement} = $value;
}

sub setMaximumImprovementDate
{
	my ($self,$value) = @_;
	$self->{maximumImprovementDate} = $value;
}

sub setImpairmentRating
{
	my ($self,$value) = @_;
	$self->{impairmentRating} = $value;
}

sub setDoctorType
{
	my ($self,$value) = @_;
	$self->{doctorType} = $value;
}

sub setExaminingDoctorType
{
	my ($self,$value) = @_;
	$self->{examiningDoctorType} = $value;
}

sub setMaximumImprovementAgreement
{
	my ($self,$value) = @_;
	$self->{maximumImprovementAgreement} = $value;
}

sub setImpairmentRatingAgreement
{
	my ($self,$value) = @_;
	$self->{impairmentRatingAgreement} = $value;
}

1;
