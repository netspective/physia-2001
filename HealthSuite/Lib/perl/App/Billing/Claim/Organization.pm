##############################################################################
package App::Billing::Claim::Organization;
##############################################################################

use strict;
use App::Billing::Claim::Entity;

use vars qw(@ISA);

@ISA = qw(App::Billing::Claim::Entity);

#
#   -- here is the organization's data 
#   -- that is required in a HCFA 1500 or NSF output
#
sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Entity(@_);
	
	$self->{name} = undef;
	$self->{id} = undef;
	$self->{grp} = undef;
	$self->{address} = undef;
	$self->{federalTaxId} = undef;	
	$self->{specialityId} = undef;
	$self->{organizationType} = undef;
	$self->{type} = undef;

	return bless $self, $type;
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getType
{
	my ($self) = @_;
	
	return $self->{type};
}

sub setType
{
	my ($self,$value) = @_;

	$self->{type} = $value;
}

sub setOrganizationType
{
	my ($self,$value) = @_;
	$self->{organizationType} = $value;
   
}

sub getOrganizationType
{
	my $self = shift;
	return $self->{organizationType};
}

sub setGRP
{
	my ($self,$value) = @_;
	
	$self->{grp} = $value;
}

sub getGRP
{
	my $self = shift;
	
	return $self->{grp};
}

sub getFederalTaxId
{
	my $self = shift;
	return $self->{federalTaxId};
}

sub getName
{
	my $self = shift;
	return $self->{name};
}

sub getAddress
{
	my $self = shift;
	return $self->{address};
}

sub setSpecialityId
{
	my ($self,$value) = @_;
	$self->{specialityId} = $value;
}

sub getSpecialityId
{
	my $self = shift;
	return $self->{specialityId};
}

sub setName
{
	my ($self,$value) = @_;
	$self->{name} = $value;
}
sub setFederalTaxId
{
	my ($self,$value) = @_;
	$self->{federalTaxId} = $value;
}

sub setAddress
{
	my ($self,$value) = @_;
	$self->{address} = $value;
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

sub printVal
{
	my ($self) = @_;
	foreach my $key (keys(%$self))
	{
		print " patient $key = " . $self->{$key} . " \n";
	}

}

1;
