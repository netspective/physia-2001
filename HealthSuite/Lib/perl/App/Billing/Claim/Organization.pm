##############################################################################
package App::Billing::Claim::Organization;
##############################################################################

#
#   -- here is the organization's data
#   -- that is required in a HCFA 1500 or NSF output
#

use strict;

use App::Billing::Claim::Entity;
use App::Billing::Universal;

use vars qw(@ISA);

@ISA = qw(App::Billing::Claim::Entity);

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Entity(@_);

	$self->{name} = undef;
	$self->{id} = undef;
	$self->{grp} = undef;
	$self->{address} = undef;
	$self->{specialityId} = undef;
	$self->{organizationType} = undef;
	$self->{type} = undef;
	$self->{CLIA} = undef;
	$self->{employerNumber} = undef;
	$self->{medicaidId} = undef;
	$self->{medicareId} = undef;
	$self->{bcbsId} = undef;
	$self->{workersComp} = undef;
	$self->{taxId} = undef;
	$self->{taxTypeId} = undef;
	$self->{insType} = undef;
	$self->{railroad} = undef;
	$self->{internalId} = undef;

	return bless $self, $type;
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub setInsType
{
	my ($self, $value) = @_;
	$self->{insType} = $value;
}

sub getInsType
{
	my $self = shift;
	return $self->{insType};
}

sub setInternalId
{
	my ($self, $value) = @_;
	$self->{internalId} = $value;
}

sub getInternalId
{
	my $self = shift;
	return $self->{internalId};
}

sub setRailroadId
{
	my ($self, $value) = @_;
	$self->{railroad} = $value;
}

sub getRailroadId
{
	my $self = shift;
	return $self->{railroad};
}

sub setTaxTypeId
{
	my ($self,$value) = @_;
	my $temp =
	{
		'0' => 'E',
		'1' => 'S',
		'2' => 'X',
	};
	$self->{taxTypeId} = $temp->{$value};
}

sub getTaxTypeId
{
	my ($self) = @_;
	return $self->{taxTypeId};
}

sub getTaxId
{
	my ($self) = @_;
	return $self->{taxId};
}

sub setTaxId
{
	my ($self,$value) = @_;
	$self->{taxId} = $value;
}

sub getCLIA
{
	my ($self) = @_;
	return $self->{CLIA};
}

sub setCLIA
{
	my ($self,$value) = @_;
	$self->{CLIA} = $value;
}

sub getEmployerNumber
{
	my ($self) = @_;
	return $self->{employerNumber};
}

sub setEmployerNumber
{
	my ($self,$value) = @_;
	$self->{employerNumber} = $value;
}

sub getMedicaidId
{
	my ($self) = @_;
	return $self->{medicaidId};
}

sub setMedicaidId
{
	my ($self,$value) = @_;
	$self->{medicaidId} = $value;
}

sub getMedicareId
{
	my ($self) = @_;
	return $self->{medicareId};
}

sub setMedicareId
{
	my ($self,$value) = @_;
	$self->{medicareId} = $value;
}

sub getWorkersComp
{
	my ($self) = @_;
	return $self->{workersComp};
}

sub setWorkersComp
{
	my ($self,$value) = @_;
	$self->{workersComp} = $value;
}

sub getBCBSId
{
	my ($self) = @_;
	return $self->{bcbsId};
}

sub setBCBSId
{
	my ($self,$value) = @_;
	$self->{bcbsId} = $value;
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
	my @ids;
	$ids[MEDICARE]= $self->getMedicareId();
	$ids[MEDICAID]= $self->getMedicaidId();
	$ids[BCBS]= $self->getBCBSId();
	$ids[RAILROAD] = $self->getRailroadId();
	$ids[WORKERSCOMP] = $self->getWorkersComp();
	my @payerCodes =(MEDICARE, MEDICAID, BCBS, RAILROAD, WORKERSCOMP);
	my $tempInsType = $self->{insType};
	my $temp = ((grep{$_ eq $tempInsType} @payerCodes) ? $ids[$self->{insType}] : $self->{grp});
	return $temp;
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

1;
