##############################################################################
package App::Billing::SuperBill::SuperBill;
##############################################################################

use strict;

sub new
{
	my ($type, %params) = @_;

	$params{orgName} = undef;
	$params{taxId} = undef;
	$params{date} = undef;
	$params{time} = undef;
	$params{patient} = undef; # person object
	$params{doctor} = undef; # person object
	$params{location} = undef; # organization object
	$params{insurance} = undef; # organization object
	$params{reason} = undef;
	
	$params{superBillComponents} = [];

	return bless \%params, $type;
}

sub setOrgName
{
	my ($self, $value) = @_;
	$self->{orgName} = $value;
}

sub getOrgName
{
	my ($self) = @_;
	return $self->{orgName};
}

sub setTaxId
{
	my ($self, $value) = @_;
	$self->{taxId} = $value;
}

sub getTaxId
{
	my ($self) = @_;
	return $self->{taxId};
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

sub setTime
{
	my ($self, $value) = @_;
	$self->{time} = $value;
}

sub getTime
{
	my ($self) = @_;
	return $self->{time};
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

sub setDoctor
{
	my ($self, $value) = @_;
	$self->{doctor} = $value;
}

sub getDoctor
{
	my ($self) = @_;
	return $self->{doctor};
}

sub setLocation
{
	my ($self, $value) = @_;
	$self->{location} = $value;
}

sub getLocation
{
	my ($self) = @_;
	return $self->{location};
}

sub setInsurance
{
	my ($self, $value) = @_;
	$self->{insurance} = $value;
}

sub getInsurance
{
	my ($self) = @_;
	return $self->{insurance};
}

sub setReason
{
	my ($self, $value) = @_;
	$self->{reason} = $value;
}

sub getReason
{
	my ($self) = @_;
	return $self->{reason};
}

sub addSuperBillComponent
{
	my $self = shift;
	my $listRef = $self->{superBillComponents};
	foreach (@_)
	{
		die 'only App::Billing::SuperBill::SuperBillComponent objects are allowed here'
			unless $_->isa('App::Billing::SuperBill::SuperBillComponent');
		push(@{$listRef}, $_);
	}
}

sub getSuperBillComponent
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return $self->{superBillComponents}->[$no];
}

1;
