##############################################################################
package App::Billing::Claim::Treatment;
##############################################################################

use strict;

use Devel::ChangeLog;
use vars qw(@CHANGELOG);
use constant DATEFORMAT_USA => 1;
#
# this object encapsulates a single "treatment" item in the HCFA 1500
#

sub new
{
	my ($type, %params) = @_;
	
	$params{dateOfIllnessInjuryPregnancy} = undef;
	$params{dateOfSameOrSimilarIllness} = undef;
	$params{datePatientUnableToWorkFrom} = undef;
	$params{datePatientUnableToWorkTo} = undef;
	$params{nameOfReferingPhysicianOrOther} = undef;
	$params{idOfReferingPhysician} = undef;
	$params{hospitilizationDateFrom} = undef;
	$params{hospitilizationDateTo} = undef;
	$params{reservedForLocalUse} = undef;
	$params{outsideLab} = undef;
	$params{outsideLabCharges} = undef;
	$params{medicaidResubmission} = undef;
	$params{resubmissionReference} = undef;
	$params{priorAuthorizationNo} = undef;
	
	$params{refProviderLastName} = undef;
	$params{refProviderFirstName} = undef;
	$params{refProviderMiName} = undef;
	$params{referingPhysicianIDIndicator} = undef;
	$params{referingPhysicianState} = undef;
	$params{id} = undef;

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

sub getNameOfReferingPhysicianOrOther
{
	my $self = shift;
	
	return $self->getRefProviderLastName . $self->getRefProviderFirstName . $self->getRefProviderMiName;
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

sub getReservedForLocalUse
{
	my $self = shift;
	return $self->{reservedForLocalUse};
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

sub setNameOfReferingPhysicianOrOther
{
	my ($self,$value) = @_;
	
	$self->{nameOfReferingPhysicianOrOther} = $value;
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

sub setReservedForLocalUse
{
	my ($self,$value) = @_;
	$self->{reservedForLocalUse} = $value;
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
	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
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

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Treatment','setSignatureDate use convertDateToCCYYMMDD  to change the date formats'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Treatment','setDateOfIllnessInjuryPregnancy, setDateOfSameOrSimilarIllness, setDatePatientUnableToWorkFrom, setDatePatientUnableToWorkTo, setHospitilizationDateFrom, setHospitilizationDateTo use convertDateToCCYYMMDD  to change the date formats'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Treatment','convertDateToMMDDYYYYFromCCYYMMDD implemented here. its basic function is to convert the date format from  CCYYMMDD to ddmmyyyy'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Treatment','getDateOfIllnessInjuryPregnancy, getDateOfSameOrSimilarIllness, getDatePatientUnableToWorkFrom, getDatePatientUnableToWorkTo, getHospitilizationDateFrom, getHospitilizationDateTo can be provided with argument of DATEFORMAT_USA(constant 1) to get the date in mmddyyyy format'],
	
);

1;

