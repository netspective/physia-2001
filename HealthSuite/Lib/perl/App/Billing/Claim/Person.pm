##############################################################################
package App::Billing::Claim::Person;
##############################################################################

#
#   -- This modlue contains all person's data (Patient, Physician, Nurse etc)
#   -- which is given in HCFA 1500 Form
#

use strict;

use App::Billing::Claim::Entity;

use vars qw(@ISA);

use constant DATEFORMAT_USA => 1;

@ISA = qw(App::Billing::Claim::Entity);

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Entity(@_);
	$self->{id} = undef;
	$self->{firstName} = undef;
	$self->{lastName} = undef;
	$self->{completeName} = undef;
	$self->{middleInitial} = undef;
	$self->{sex} = undef;
	$self->{address} = undef;
	$self->{dateOfBirth} = undef;
	$self->{dateOfDeath} = undef;
	$self->{deathIndicator} = undef;
	$self->{studentStatus} = undef;		# to be removed
	$self->{employmentStatus} = undef;
	$self->{address} = undef;
	$self->{status} = undef;
	$self->{ssn} = undef;
	$self->{type} = undef;
	$self->{employerOrSchoolName} = undef;
	$self->{employerAddress} = undef;
	$self->{employerOrSchoolId} = undef;

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

sub getEmployerAddress
{
	my ($self) = @_;
	return $self->{employerAddress};
}

sub setEmployerAddress
{
	my ($self, $value) = @_;
	$self->{employerAddress} = $value;
}

sub setEmployerOrSchoolName
{
	my ($self, $value) = @_;
	$self->{employerOrSchoolName} = $value;
}

sub getEmployerOrSchoolName
{
	my $self = shift;
	return $self->{employerOrSchoolName};
}

sub setEmployerOrSchoolId
{
	my ($self, $value) = @_;
	$self->{employerOrSchoolId} = $value;
}

sub getEmployerOrSchoolId
{
	my $self = shift;
	return $self->{employerOrSchoolId};
}

sub setType
{
	my ($self,$value) = @_;
	$self->{type} = $value;
}

sub getStatus
{
	my ($self) = @_;
	return $self->{status};
}

sub setSsn
{
	my ($self,$value) = @_;
	$self->{ssn} = $value;
}

sub getSsn
{
	my ($self) = @_;
	return $self->{ssn};
}

sub setStatus
{
	my ($self,$value) = @_;
	my $temp =
	{
		'0' => 'U',
		'1' => 'S',
		'2' => 'M',
		'3' => 'P',
		'4' => 'X',
		'5' => 'D',
		'6' => 'W',
		'UNKNOWN' => 'U',
		'SINGLE' => 'S',
		'MARRIED' => 'M',
		'LEGALLY SEPARATED' => 'X',
		'DIVORCED' => 'D',
		'WIDOWED' => 'W',
		'NOT APPLICABLE'=> 'N',
		'PARTNER' => 'P',
	};
	$self->{status} = $temp->{uc($value)};
}

sub setDeathIndicator
{
	my ($self,$value) = @_;
	$self->{deathIndicator} = $value;
}

sub getDeathIndicator
{
	my ($self,$value) = @_;
	return $self->{deathIndicator};
}

sub getDateOfBirth
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfBirth}) : $self->{dateOfBirth};
}

sub setDateOfBirth
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfBirth} = $value;
}

sub getDateOfDeath
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfDeath}) : $self->{dateOfDeath};
}

sub setDateOfDeath
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfDeath} = $value;
}

sub getEmploymentStatus
{
	my $self = shift;
	return $self->{employmentStatus};
}

sub setEmploymentStatus
{
	my ($self, $value) = @_;
	my $temp =
	{
		'220' => '1',
		'EMPLOYED (FULL-TIME)'  => '1',
		'221'  => '2',
		'EMPLOYED (PART-TIME)'  => '2',
		'222'  => '4',
		'SELF-EMPLOYED'  => '4',
		'223'  => '5',
		'RETIRED'  => '5',
	};
	$self->{employmentStatus} = $temp->{uc($value)};
}

sub setStudentStatus
{
	my ($self, $value) = @_;
	my $temp =
	{
		'224' => 'F',
		'STUDENT (FULL-TIME)'  => 'F',
		'225'  => 'P',
		'STUDENT (PART-TIME)'  => 'P',
		'NONE'  => 'N',
	};
	$self->{studentStatus} = $temp->{uc($value)};
}

sub getStudentStatus
{
	my $self = shift;
	return $self->{studentStatus};
}

sub setId
{
	my ($self,$value) = @_;
	$self->{id} = $value;
}

sub setSex
{
	my ($self,$value) = @_;
	my $temp =
	{
		'0' => 'U',
		'1' => 'M',
		'2' => 'F',
		'3' => 'N',
		'UNKNOWN' => 'U',
		'MALE' => 'M',
		'FEMALE' => 'F',
		'NOT APPLICABLE' => 'N'
	};
	$self->{sex} = $temp->{uc($value)};
}

sub setFirstName
{
	my ($self,$value) = @_;
	$self->{firstName} = $value;
}

sub setLastName
{
	my ($self,$value) = @_;
	$self->{lastName} = $value;
}

sub setMiddleInitial
{
	my ($self,$value) = @_;
	$self->{middleInitial} = $value;
}

sub setName
{
	my ($self,$value) = @_;
	$self->{completeName} = $value;
}

sub setAddress
{
	my ($self,$value) = @_;
	die '$value must be a App::Billing::Claim::Address' unless $value->isa('App::Billing::Claim::Address');
	$self->{address} = $value;
}

sub getId
{
	my ($self) = @_;
	return $self->{id};
}

sub getSex
{
	my ($self) = @_;
	return $self->{sex};
}

sub getFirstName
{
	my ($self) = @_;
	return $self->{firstName};
}

sub getLastName
{
	my ($self) = @_;
	return $self->{lastName}
}

sub getMiddleInitial
{
	my ($self) = @_;
	return $self->{middleInitial};
}

sub getName
{
	my ($self) = @_;
	return $self->{completeName}
}

sub getAddress
{
	my ($self) = @_;
	return $self->{address};
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

1;
