##############################################################################
package App::Billing::Claim::Diagnosis;
##############################################################################

#
# this object encapsulates a single "diagnosis" item in the HCFA 1500
#

use vars qw(@ISA);
use strict;

sub new
{
	my ($type, %params) = @_;
	$params{diagnosis} = undef;
	$params{diagnosisPosition} = undef;
	return bless \%params, $type;
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getDiagnosis
{
	my $self = shift;
	return $self->{diagnosis};
}

sub setDiagnosis
{
	my ($self,$value) = @_;
	$value =~ s/ //g;
	$self->{diagnosis} = $value;
}

sub setDiagnosisPosition
{
	my ($self,$value) = @_;
	$self->{diagnosisPosition} = $value;
}

sub getDiagnosisPosition
{
	my $self = shift;
	return $self->{diagnosisPosition};
}

1;
