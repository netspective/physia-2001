##############################################################################
package App::Billing::Claim::Address;
##############################################################################

#
#   -- This modlue contains all person's data (Patient, Physician, Nurse etc)
#   -- which is given in HCFA 1500 Form
#

use strict;
use App::Billing::Claim::Entity;
use vars qw(@ISA);

@ISA = qw(App::Billing::Claim::Entity);

use constant TELEPHONE_FORMAT_DASH => 1;

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Entity(@_);
	$self->{address1} = undef;
	$self->{address2} = undef;
	$self->{zipCode} = undef;
	$self->{state} = undef;
	$self->{city} = undef;
	$self->{telephoneNo} = undef;
	$self->{faxNo} = undef;
	$self->{emailAddress} = undef;
	$self->{pager} = undef;
	$self->{country} = undef;
	return bless $self, $type;
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub setFaxNo
{
	my ($self,$value) = @_;
	$value =~ s/-//g;
	$self->{faxNo} = $value;
}

sub getFaxNo
{
	my ($self, $formatIndicator) = @_;
	return (TELEPHONE_FORMAT_DASH == $formatIndicator) ? $self->convertTelFormat($self->{faxNo}) : $self->{faxNo};
}

sub setEmailAddress
{
	my ($self,$value) = @_;
	$self->{emailAddress} = $value;
}

sub getEmailAddress
{
	my ($self) = @_;
	return $self->{emailAddress};
}

sub setPager
{
	my ($self,$value) = @_;
	$self->{pager} = $value;
}

sub getPager
{
	my ($self) = @_;
	return $self->{pager};
}

sub setCountry
{
	my ($self,$value) = @_;
	$self->{country} = $value;
}

sub getCountry
{
	my ($self) = @_;
	return $self->{country};
}

sub setAddress1
{
	my ($self,$value) = @_;
	$self->{address1} = $value;
}

sub setAddress2
{
	my ($self,$value) = @_;
	$self->{address2} = $value;
}

sub setCity
{
	my ($self,$value) = @_;
	$self->{city} = $value;
}

sub setZipCode
{
	my ($self,$value) = @_;
	$self->{zipCode} = $value;
}

sub setState
{
	my ($self,$value) = @_;
	$self->{state} = $value;
}

sub setTelephoneNo
{
	my ($self,$value) = @_;
	$value =~ s/-//g;
	$self->{telephoneNo} = $value;
}

sub getAddress1
{
	my ($self) = @_;
	return $self->{address1};
}

sub getAddress2
{
	my ($self) = @_;
	return $self->{address2};
}

sub getCity
{
	my ($self) = @_;
	return $self->{city};
}

sub getZipCode
{
	my ($self) = @_;
	return $self->{zipCode};
}

sub getState
{
	my ($self) = @_;
	return $self->{state};
}

sub getTelephoneNo
{
	my ($self, $formatIndicator) = @_;
	return (TELEPHONE_FORMAT_DASH == $formatIndicator) ? $self->convertTelFormat($self->{telephoneNo}) : $self->{telephoneNo};
}

sub convertTelFormat
{
	my ($self, $telephoneNo) = @_;
	if ($telephoneNo ne "")
	{
		return substr($telephoneNo,0,3) . '-' . substr($telephoneNo,3,3) . '-' . substr($telephoneNo,6,4) ;
	}
	else
	{
		return "";
	}
}

1;
