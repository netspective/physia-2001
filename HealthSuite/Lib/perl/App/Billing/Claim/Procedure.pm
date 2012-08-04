##############################################################################
package App::Billing::Claim::Procedure;
##############################################################################

#
# this object encapsulates a single "procedure" line in the HCFA 1500
#

use strict;

use constant DATEFORMAT_USA => 1;

sub new
{
	my ($type, %param) = @_;

	$param{dateOfServiceFrom} = undef;
	$param{dateOfServiceTo} = undef;
	$param{placeOfService} = undef;
	$param{typeOfService} = undef;
	$param{cpt} = undef;
	$param{modifier} = undef;
	$param{diagnosisCodePointer} = undef;
	$param{charges} = undef;
	$param{daysOrUnits} = undef;
	$param{familyPlan} = undef;
	$param{emergency} = undef;
	$param{cob} = undef;
	$param{disallowedCostContainment} = undef;
	$param{disallowedOther} = undef;
	$param{diagnosis} = undef;
	$param{comments} = undef;
	$param{itemId} = undef;
	$param{extendedCost} = undef;
	$param{balance} = undef;
	$param{totalAdjustments} = undef;
	$param{reference} = undef;
	$param{flags} = undef;
	$param{caption} = undef;
	$param{adjustments} = [];
	$param{itemType} = undef;
	$param{paymentDate} = undef;
	$param{itemStatus} = undef;
	$param{codeType} = undef;
	$param{explosion} = undef;

	return bless \%param, $type;
}

sub setExplosion
{
	my ($self, $value) = @_;
	$self->{explosion} = $value;
}

sub getExplosion
{
	my $self = shift;
	return $self->{explosion};
}

sub setCodeType
{
	my ($self, $value) = @_;
	$self->{codeType} = $value;
}

sub getCodeType
{
	my $self = shift;
	return $self->{codeType};
}

sub setItemStatus
{
	my ($self, $value) = @_;
	$self->{itemStatus} = $value;
}

sub getItemStatus
{
	my $self = shift;
	return $self->{itemStatus};
}

sub setPaymentDate
{
	my ($self, $value) = @_;
	$self->{paymentDate} = $value;
}

sub getPaymentDate
{
	my $self = shift;
	return $self->{paymentDate};
}

sub setItemType
{
	my ($self, $value) = @_;
	$self->{itemType} = $value;
}

sub getItemType
{
	my $self = shift;
	return $self->{itemType};
}

sub setCaption
{
	my ($self, $value) = @_;
	$self->{caption} = $value;
}

sub getCaption
{
	my $self = shift;
	return $self->{caption};
}

sub setFlags
{
	my ($self, $value) = @_;
	$self->{flags} = $value;
}

sub getFlags
{
	my $self = shift;
	return $self->{flags};
}

sub setReference
{
	my ($self, $value) = @_;
	$self->{reference} = $value;
}

sub getReference
{
	my $self = shift;
	return $self->{reference};
}

sub setTotalAdjustments
{
	my ($self, $value) = @_;
	$self->{totalAdjustments} = $value;
}

sub getTotalAdjustments
{
	my $self = shift;
	return $self->{totalAdjustments};
}

sub setBalance
{
	my ($self, $value) = @_;
	$self->{balance} = $value;
}

sub getBalance
{
	my $self = shift;
	return $self->{balance};
}

sub setExtendedCost
{
	my ($self, $value) = @_;
	$self->{extendedCost} = $value;
}

sub getExtendedCost
{
	my $self = shift;
	return $self->{extendedCost};
}

sub setItemId
{
	my ($self, $value) = @_;
	$self->{itemId} = $value;
}

sub getItemId
{
	my $self = shift;
	return $self->{itemId};
}

sub setComments
{
	my ($self, $value) = @_;
	$self->{comments} = $value;
}

sub getComments
{
	my $self = shift;
	return $self->{comments};
}

sub setDiagnosis
{
	my ($self, $value) = @_;
	$self->{diagnosis} = $value;
}

sub getDiagnosis
{
	my ($self) = @_;
	return $self->{diagnosis};
}

sub setDisallowedCostContainment
{
	my ($self, $value) = @_;
	$self->{disallowedCostContainment} = $value;
}

sub getDisallowedCostContainment
{
	my ($self) = @_;
	return $self->{disallowedCostContainment};
}

sub setDisallowedOther
{
	my ($self, $value) = @_;
	$self->{disallowedOther} = $value;
}

sub getDisallowedOther
{
	my ($self) = @_;
	return $self->{disallowedOther};
}

sub getDateOfServiceFrom
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfServiceFrom}) : $self->{dateOfServiceFrom};
}

sub getDateOfServiceTo
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateOfServiceTo}) : $self->{dateOfServiceTo};
}

sub getPlaceOfService
{
	my $self = shift;
	return $self->{placeOfService};
}

sub getTypeOfService
{
	my $self = shift;
	return $self->{typeOfService};
}

sub getCPT
{
	my $self = shift;
	return $self->{cpt};
}

sub getModifier
{
	my $self = shift;
	return $self->{modifier};
}

sub getDiagnosisCodePointer
{
	my $self = shift;
	return $self->{diagnosisCodePointer};
}

sub getCharges
{
	my $self = shift;
	return $self->{charges};
}

sub getDaysOrUnits
{
	my $self = shift;
	return $self->{daysOrUnits};
}

sub getFamilyPlan
{
	my $self = shift;
	return $self->{familyPlan};
}

sub getEmergency
{
	my $self = shift;
	return $self->{emergency};
}

sub getCOB
{
	my $self = shift;
	return $self->{cob};
}

sub setDateOfServiceFrom
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfServiceFrom} = $value;
}

sub setDateOfServiceTo
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateOfServiceTo} = $value;
}

sub setPlaceOfService
{
	my ($self,$value) = @_;
	$self->{placeOfService} = $value;
}

sub setTypeOfService
{
	my ($self,$value) = @_;
	$value = (length($value) == 1) ? '0' . $value : $value;
	$self->{typeOfService} = $value;
}

sub setCPT
{
	my ($self,$value) = @_;
	$self->{cpt} = $value;
}

sub setModifier
{
	my ($self,$value) = @_;
	$self->{modifier} = $value;
}

sub setDiagnosisCodePointer
{
	my ($self,$value) = @_;
	$self->{diagnosisCodePointer} = $value;
}

sub setCharges
{
	my ($self,$value) = @_;
	$self->{charges} = $value;
}

sub setDaysOrUnits
{
	my ($self,$value) = @_;
	$self->{daysOrUnits} = $value;
}

sub setFamilyPlan
{
	my ($self,$value) = @_;
	$self->{familyPlan} = $value;
}

sub setEmergency
{
	my ($self,$value) = @_;
	my $temp =
	{
		'YES' => 'Y',
		'NO' => 'N',
		'0' => 'N',
		'1' => 'Y',
		'' => 'N',
	};
	$self->{emergency} = $temp->{uc($value)};
}

sub setCOB
{
	my ($self,$value) = @_;
	$self->{cob} = $value;
}

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence =
	{
		JAN => '01', FEB => '02', MAR => '03', APR => '04',
		MAY => '05', JUN => '06', JUL => '07', AUG => '08',
		SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
	};
	$date =~ s/-//g;
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
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

sub addAdjustments
{
	my $self = shift;
	my $adjustmentsListRef = $self->{adjustments};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Adjustment objects are allowed here'
			unless $_->isa('App::Billing::Claim::Adjustment');
		push(@{$adjustmentsListRef}, $_);
	}
}

1;
