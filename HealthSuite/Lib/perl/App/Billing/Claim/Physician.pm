##############################################################################
package App::Billing::Claim::Physician;
##############################################################################

#
#   -- This modlue contains all physician's data
#   -- which is given in HCFA 1500 Form

use strict;

use App::Billing::Claim::Entity;
use App::Billing::Claim::Person;
use App::Billing::Universal;

use vars qw(@ISA);

use constant DATEFORMAT_USA => 1;

@ISA = qw(App::Billing::Claim::Person);

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Claim::Person(@_);

#	$self->{name} = undef;

	$self->{pin} = undef;
	$self->{taxId} = undef;
	$self->{insType} = undef;
	$self->{uPIN} = undef;
	$self->{providerId} = undef;
	$self->{assignIndicator} = undef;
	$self->{signatureIndicator} = undef;
	$self->{signatureDate} = undef;
	$self->{specialityId} = undef;
	$self->{qualification} = undef;

	$self->{taxTypeId} = undef;
	$self->{medicareId} = undef;
	$self->{medicaidId} = undef;
	$self->{champusId} = undef;
	$self->{railroadId} = undef;
	$self->{epsdtId} = undef;
	$self->{blueShieldId} = undef;
	$self->{workersComp} = undef;
	$self->{professionalLicenseNo} = undef;

	$self->{documentationIndicator} = undef;		# to be removed
	$self->{documentationType} = undef;		# to be removed
	$self->{siteId} = undef;		# to be removed
	$self->{networkId} = undef;		# to be removed
	$self->{idIndicator} = undef;		# to be removed

	return bless $self, $type;
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

sub getUPIN
{
	my ($self) = @_;
	return $self->{uPIN};
}

sub setUPIN
{
	my ($self,$value) = @_;
	$self->{uPIN} = $value;
}

sub getEPSDT
{
	my ($self) = @_;
	return $self->{epsdtId};
}

sub setEPSDT
{
	my ($self,$value) = @_;
	$self->{epsdtId} = $value;
}

sub getRailroadId
{
	my ($self) = @_;
	return $self->{railroadId};
}

sub setRailroadId
{
	my ($self,$value) = @_;
	$self->{railroadId} = $value;
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

sub getProviderId
{
	my $self = shift;
	my @ids;
	$ids[MEDICARE]= $self->getMedicareId();
	$ids[MEDICAID]= $self->getMedicaidId();
	$ids[BCBS]= $self->getBlueShieldId();
	$ids[CHAMPUS]= $self->getChampusId();
	$ids[RAILROAD]= $self->getRailroadId();
	$ids[EPSDT]= $self->getEPSDT();
	$ids[WORKERSCOMP]= $self->getWorkersComp();
	my @payerCodes =(MEDICARE, MEDICAID, BCBS, CHAMPUS, RAILROAD, EPSDT, WORKERSCOMP);
	my $tempInsType = $self->{insType};
	my $temp = ((grep{$_ eq $tempInsType} @payerCodes) ? $ids[$self->{insType}] : $self->{pin});
	return $temp;
}

sub setDocumentationType
{
	my ($self,$value) = @_;
	$self->{documentationType} = $value;
}

sub getDocumentationType
{
	my $self = shift;
	return $self->{documentationType};
}

sub setNetworkId
{
	my ($self,$value) = @_;
	$self->{networkId} = $value;
}

sub getNetworkId
{
	my ($self) = @_;
	return $self->{networkId};
}
sub setQualification
{
	my ($self,$value) = @_;
	$self->{qualification} = $value;
}

sub getQualification
{
	my ($self) = @_;
	return $self->{qualification};
}

sub setBlueShieldId
{
	my ($self,$value) = @_;
	$self->{blueShieldId} = $value;
}

sub getBlueShieldId
{
	my ($self) = @_;
	return $self->{blueShieldId};
}

sub setIdIndicator
{
	my ($self,$value) = @_;
	$self->{idIndicator} = $value;
}

sub getIdIndicator
{
	my ($self) = @_;
	return $self->{idIndicator};
}

sub setDocumentationIndicator
{
	my ($self,$value) = @_;
	$self->{documentationIndicator} = $value;
}

sub getDocumentationIndicator
{
	my ($self) = @_;
	return $self->{documentationIndicator};
}

sub setSignatureDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{signatureDate} = $value;
}

sub getSignatureDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{signatureDate}) : $self->{signatureDate};
}

sub setSignatureIndicator
{
	my ($self,$value) = @_;
	$self->{signatureIndicator} = $value;
}

sub getSignatureIndicator
{
	my ($self) = @_;
	return $self->{signatureIndicator};
}

sub setAssignIndicator
{
	my ($self,$value) = @_;
	$self->{assignIndicator} = $value;
}

sub getAssignIndicator
{
	my ($self) = @_;
	return $self->{assignIndicator};
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

sub setMedicareId
{
	my ($self,$value) = @_;
	$self->{medicareId} = $value;
}

sub getMedicareId
{
	my ($self) = @_;
	return $self->{medicareId};
}

sub setMedicaidId
{
	my ($self,$value) = @_;
	$self->{medicaidId} = $value;
}

sub getMedicaidId
{
	my ($self) = @_;
	return $self->{medicaidId};
}

sub setChampusId
{
	my ($self,$value) = @_;
	$self->{champusId} = $value;
}

sub getChampusId
{
	my ($self) = @_;
	return $self->{champusId};
}

sub setSpecialityId
{
	my ($self,$value) = @_;
	$self->{specialityId} = $value;
}

sub getSpecialityId
{
	my ($self) = @_;
	return $self->{specialityId};
}

sub setSiteId
{
	my ($self,$value) = @_;
	$self->{siteId} = $value;
}

sub getSiteId
{
	my ($self) = @_;
	return 	$self->{siteId};
}

sub setPIN
{
	my ($self,$value) = @_;
	$self->{pin} = $value;
}

#sub setName
#{
#	my ($self,$value) = @_;
#	$self->{name} = $value;
#}


sub setContact_old
{
	my ($self,$value) = @_;
	$self->{contact} = $value;
}

sub setTaxId
{
	my ($self,$value) = @_;
	$self->{taxId} = $value;
}

sub getPIN
{
	my $self = shift;
	my @ids;
	$ids[MEDICARE]= $self->getMedicareId();
	$ids[MEDICAID]= $self->getMedicaidId();
	$ids[BCBS]= $self->getBlueShieldId();
	$ids[CHAMPUS]= $self->getChampusId();
	$ids[RAILROAD]= $self->getRailroadId();
	$ids[EPSDT]= $self->getEPSDT();
	$ids[WORKERSCOMP]= $self->getWorkersComp();
	my @payerCodes =(MEDICARE, MEDICAID, BCBS, CHAMPUS, RAILROAD, EPSDT, WORKERSCOMP);
	my $tempInsType = $self->{insType};
	my $temp = ((grep{$_ eq $tempInsType} @payerCodes) ? $ids[$self->{insType}] : $self->{pin});
	return $temp;
}

#sub getName
#{
#	my ($self) = @_;
#	return $self->{name};
#}


sub getContact_old
{
	my ($self) = @_;
	return $self->{contact};
}

sub getTaxId
{
	my ($self) = @_;
	return $self->{taxId};
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

sub getProfessionalLicenseNo
{
	my ($self) = @_;
	return $self->{professionalLicenseNo};
}

sub setProfessionalLicenseNo
{
	my ($self,$value) = @_;
	$self->{professionalLicenseNo} = $value;
}

1;
