##############################################################################
package App::Billing::Claim::Patient;
##############################################################################

#
#   -- This modlue contains all patient's data
#   -- which is given in HCFA 1500 Form
#

use strict;

use App::Billing::Claim::Person;
use App::Billing::Claim::Entity;

use vars qw(@ISA);

use constant DATEFORMAT_USA => 1;

@ISA = qw(App::Billing::Claim::Person);

sub new
{
	my ($type) = shift;;
	my $self = new App::Billing::Claim::Person(@_);
	$self->{accountNo} = undef;
	$self->{signature} = undef;
	$self->{tpo} = undef;		# to be removed
	$self->{legalIndicator} = undef;
	$self->{multipleIndicator} = undef;		# to be removed
	$self->{lastSeenDate} = undef;		# to be removed
	$self->{signatureDate} = undef;
	$self->{visitDate} = undef;

	return bless $self, $type;
}

sub getLastSeenDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{lastSeenDate}) : $self->{lastSeenDate};
}

sub setLastSeenDate
{
	my ($self, $value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{lastSeenDate} = $value;
}

sub getTPO
{
	my $self = shift;
	return $self->{tpo};
}

sub setTPO
{
	my ($self, $value) = @_;
	$self->{tpo} = $value;
}

sub getlegalIndicator
{
	my $self = shift;
	return $self->{legalIndicator};
}

sub setlegalIndicator
{
	my ($self, $value) = @_;
	$self->{legalIndicator} = $value;
}

sub getMultipleIndicator
{
	my $self = shift;
	return $self->{multipleIndicator};
}

sub setMultipleIndicator
{
	my ($self, $value) = @_;
	$self->{multipleIndicator} = $value;
}

sub getSignature
{
	my $self = shift;
	return $self->{signature};
}

sub setSignature
{
	my ($self, $value) = @_;
	$self->{signature} = $value;
}

sub getSignatureDate
{
	my $self = shift;
	return $self->{signatureDate};
}

sub setSignatureDate
{
	my ($self, $value) = @_;
	$self->{signatureDate} = $value;
}

sub getAccountNo
{
	my $self = shift;
	return $self->{accountNo};
}

sub setAccountNo
{
	my ($self, $value) = @_;
	$self->{accountNo} = $value;
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

sub getVisitDate
{
	my $self = shift;
	return $self->{visitDate};
}

sub setVisitDate
{
	my ($self, $value) = @_;
	$self->{visitDate} = $value;
}

1;
