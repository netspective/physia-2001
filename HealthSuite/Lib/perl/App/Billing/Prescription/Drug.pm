##############################################################################
package App::Billing::Prescription::Drug;
##############################################################################

use strict;

sub new
{
	my ($type, %params) = @_;

	$params{drugName} = undef;
	$params{dose} = undef;
	$params{doseUnits} = undef;
	$params{quantity} = undef;
	$params{duration} = undef;
	$params{durationUnits} = undef;
	$params{numRefills} = undef;
	$params{allowSubstitution} = undef;
	$params{allowGeneric} = undef;
	$params{label} = undef;
	$params{labelLanguage} = undef;
	$params{sig} = undef;

	return bless \%params, $type;
}

sub setDrugName
{
	my ($self, $value) = @_;
	$self->{drugName} = $value;
}

sub getDrugName
{
	my ($self) = @_;
	return $self->{drugName};
}

sub setDose
{
	my ($self, $value) = @_;
	$self->{dose} = $value;
}

sub getDose
{
	my ($self) = @_;
	return $self->{dose};
}

sub setDoseUnits
{
	my ($self, $value) = @_;
	$self->{doseUnits} = $value;
}

sub getDoseUnits
{
	my ($self) = @_;
	return $self->{doseUnits};
}

sub setQuantity
{
	my ($self, $value) = @_;
	$self->{quantity} = $value;
}

sub getQuantity
{
	my ($self) = @_;
	return $self->{quantity};
}

sub setDuration
{
	my ($self, $value) = @_;
	$self->{duration} = $value;
}

sub getDuration
{
	my ($self) = @_;
	return $self->{duration};
}

sub setDurationUnits
{
	my ($self, $value) = @_;
	$self->{durationUnits} = $value;
}

sub getDurationUnits
{
	my ($self) = @_;
	return $self->{durationUnits};
}

sub setNumRefills
{
	my ($self, $value) = @_;
	$self->{numRefills} = $value;
}

sub getNumRefills
{
	my ($self) = @_;
	return $self->{numRefills};
}

sub setAllowSubstitution
{
	my ($self, $value) = @_;
	$self->{allowSubstitution} = $value;
}

sub getAllowSubstitution
{
	my ($self) = @_;
	return $self->{allowSubstitution};
}

sub setAllowGeneric
{
	my ($self, $value) = @_;
	$self->{allowGeneric} = $value;
}

sub getAllowGeneric
{
	my ($self) = @_;
	return $self->{allowGeneric};
}

sub setLabel
{
	my ($self, $value) = @_;
	$self->{label} = $value;
}

sub getLabel
{
	my ($self) = @_;
	return $self->{label};
}

sub setLabelLanguage
{
	my ($self, $value) = @_;
	$self->{labelLanguage} = $value;
}

sub getLabelLanguage
{
	my ($self) = @_;
	return $self->{labelLanguage};
}

sub setSig
{
	my ($self, $value) = @_;
	$self->{sig} = $value;
}

sub getSig
{
	my ($self) = @_;
	return $self->{sig};
}

1;
