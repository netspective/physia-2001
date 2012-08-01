##############################################################################
package App::Billing::SuperBill::SuperBillComponent;
##############################################################################

use strict;


sub new
{
	my ($type, %params) = @_;

	$params{header} = undef;
	$params{count} = undef;
	$params{cpt} = [];
	$params{description} = [];

	return bless \%params, $type;
}

sub addCpt
{
	my ($self, $value) = @_;
	push(@{$self->{cpt}}, $value);
}

sub getCpt
{
	my ($self, $no) = @_;
	return $self->{cpt}->[$no];
}

sub addDescription
{
	my ($self, $value) = @_;
	push(@{$self->{description}}, $value);
}

sub getDescription
{
	my ($self, $no) = @_;
	return $self->{description}->[$no];
}

sub setCount
{
	my ($self, $value) = @_;
	$self->{count} = $value;
}

sub getCount
{
	my ($self) = @_;
	return $self->{count};
}

sub setHeader
{
	my ($self, $value) = @_;
	$self->{header} = $value;
}

sub getHeader
{
	my ($self) = @_;
	return $self->{header};
}


1;