##############################################################################
package App::Billing::Claim::Insured;
##############################################################################

#
#   -- This modlue contains all insured's data
#   -- which is given in HCFA 1500 Form
#

use strict;

use App::Billing::Claim::Person;
use App::Billing::Claim::Entity;

use vars qw(@ISA);

@ISA = qw(App::Billing::Claim::Person);

use constant DEFAULT_RELATION_SHIP_TO_PATIENT => '01';
use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Person(@_);

	$self->{relationshipToPatient} = undef;
	$self->{policyGroupName} = undef;
	$self->{policyGroupOrFECANo} = undef;
	$self->{otherInsuranceIndicator} = undef;
	$self->{insurancePlanOrProgramName} = undef;
	$self->{anotherHealthBenefitPlan} = undef;
	$self->{typeCode} = undef;
	$self->{hmoIndicator} = undef;
	$self->{hmoId} = undef;
	$self->{effectiveDate} = undef;
	$self->{terminationDate} = undef;
	$self->{billSequence} = undef;		# to be removed
	$self->{bcbsPlanCode} = undef;
	$self->{memberNumber} = undef;
	$self->{medigapNo} = undef;

	return bless $self, $type;
}

sub getMemberNumber
{
	my ($self) = @_;
	return $self->{memberNumber};
}

sub setMemberNumber
{
	my ($self, $value) = @_;
	$self->{memberNumber} = $value;
}

sub getMedigapNo
{
	my ($self) = @_;
	return $self->{medigapNo};
}

sub setMedigapNo
{
	my ($self, $value) = @_;
	$self->{medigapNo} = $value;
}

sub getBillSequence
{
	my ($self) = @_;
	return $self->{billSequence};
}

sub setBillSequence
{
	my ($self, $value) = @_;
	$self->{billSequence} = $value;
}

sub getEffectiveDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{effectiveDate}) : $self->{effectiveDate};
}

sub setEffectiveDate
{
	my ($self, $value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{effectiveDate} = $value;
}

sub getTerminationDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{terminationDate}) : $self->{terminationDate};
}

sub setTerminationDate
{
	my ($self, $value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{terminationDate} = $value;
}

sub getRelationshipToPatient
{
	my ($self) = @_;
	return (($self->{relationshipToPatient} eq "") ? DEFAULT_RELATION_SHIP_TO_PATIENT : $self->{relationshipToPatient});
}

sub setRelationshipToPatient
{
	my ($self, $value) = @_;
	$self->{relationshipToPatient} = length($value) == 1 ? "0" . $value : $value;
}

sub getPolicyGroupName
{
	my $self = shift;
	return $self->{policyGroupName};
}

sub setPolicyGroupName
{
	my ($self, $value) = @_;
	$self->{policyGroupName} = $value;
}

sub getTypeCode
{
	my $self = shift;
	return $self->{typeCode};
}

sub setTypeCode
{
	my ($self, $value) = @_;
	$self->{typeCode} = $value;
}

sub getHMOIndicator
{
	my $self = shift;
	return $self->{hmoIndicator};
}

sub setHMOIndicator
{
	my ($self, $value) = @_;
	$self->{hmoIndicator} = $value;
}

sub getHMOId
{
	my $self = shift;
	return $self->{hmoId};
}

sub setHMOId
{
	my ($self, $value) = @_;
	$self->{hmoId} = $value;
}

sub getOtherInsuranceIndicator
{
	my $self = shift;
	return $self->{otherInsuranceIndicator};
}

sub setOtherInsuranceIndicator
{
	my ($self, $value) = @_;
	$self->{otherInsuranceIndicator} = $value;
}

sub getPolicyGroupOrFECANo
{
	my $self = shift;
	return $self->{policyGroupOrFECANo};
}

sub getInsurancePlanOrProgramName
{
	my $self = shift;
	return $self->{insurancePlanOrProgramName};
}

sub getAnotherHealthBenefitPlan
{
	my $self = shift;
	return $self->{anotherHealthBenefitPlan};
}

sub setAnotherHealthBenefitPlan
{
	my ($self, $value) = @_;
	$self->{anotherHealthBenefitPlan} = $value;
}

sub setPolicyGroupOrFECANo
{
	my ($self, $value) = @_;
	$self->{policyGroupOrFECANo} = $value;
}

sub setInsurancePlanOrProgramName
{
	my ($self, $value) = @_;
	$self->{insurancePlanOrProgramName} = $value;
}

sub setAcceptAssignment
{
	my ($self, $treat) = @_;
	my $temp =
	{
		'0' => 'N',
		'NO'  => 'N',
		'1'  => 'Y',
		'YES'  => 'Y',
	};
	$self->{acceptAssignment} = $temp->{uc($treat)};
}

sub getAcceptAssignment
{
	my ($self) = @_;
	return $self->{acceptAssignment};
}

sub setBcbsPlanCode
{
	my($self, $value) = @_;
	$self->{bcbsPlanCode} = $value;
}

sub getBcbsPlanCode
{
	my $self = shift;
	return $self->{bcbsPlanCode};
}

1;
