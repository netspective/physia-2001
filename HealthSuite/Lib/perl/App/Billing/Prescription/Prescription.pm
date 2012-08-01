##############################################################################
package App::Billing::Prescription::Prescription;
##############################################################################

use strict;

sub new
{
	my ($type, %params) = @_;

	$params{physician} = undef;
	$params{practice} = undef;
	$params{patient} = undef;
	$params{date} = undef;
	$params{drugs} = [];

	return bless \%params, $type;
}

sub setPhysician
{
	my ($self, $value) = @_;
	$self->{physician} = $value;
}

sub getPhysician
{
	my ($self) = @_;
	return $self->{physician};
}

sub setPractice
{
	my ($self, $value) = @_;
	$self->{practice} = $value;
}

sub getPractice
{
	my ($self) = @_;
	return $self->{practice};
}

sub setPatient
{
	my ($self, $value) = @_;
	$self->{patient} = $value;
}

sub getPatient
{
	my ($self) = @_;
	return $self->{patient};
}

sub setDate
{
	my ($self, $value) = @_;
	$self->{date} = $value;
}

sub getDate
{
	my ($self) = @_;
	return $self->{date};
}

sub setDrug
{
	my ($self, $value) = @_;
	$self->{drugs} = $value;
}

sub getDrug
{
	my ($self) = @_;
	return $self->{drugs};
}

1;