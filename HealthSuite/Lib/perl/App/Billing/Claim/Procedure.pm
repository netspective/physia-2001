##############################################################################
package App::Billing::Claim::Procedure;
##############################################################################

use strict;

#
# this object encapsulates a single "procedure" line in the HCFA 1500
#
use Devel::ChangeLog;
use vars qw(@CHANGELOG);
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
	$param{localUse} = undef;
	$param{disallowedCostContainment} = undef;
	$param{disallowedOther} = undef;
	$param{diagnosis} = undef;
	$param{comments} = undef;
	$param{itemId} = undef;
	$param{extendedCost} = undef;
	$param{balance} = undef;
	$param{totalAdjustments} = undef;
	$param{reference} = undef;
	$param{cptName} = undef;
	$param{itemType} = undef;
	$param{caption} = undef;

	return bless \%param, $type;
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


sub getLocalUse
{
	my $self = shift;
	return $self->{localUse};
}

sub setLocalUse
{
	my ($self, $value) = @_;
	$self->{localUse} = $value;
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
	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
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

@CHANGELOG =
(
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Procedure','convertDateToCCYYMMDD implemented here. its basic function is to convert the date format from dd-mmm-yy to CCYYMMDD'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Procedure','Change log is implemented'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Procedure','setDateOfServiceFrom,setDateOfServiceTo use convertDateToCCYYMMDD  to change the date formats'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/22/1999', 'SSI', 'Billing Interface/Claim Procedure','Emergency indicator now has domain Y,N'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/22/1999', 'SSI', 'Billing Interface/Claim Procedure','Type of service is converted to two digit value'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Procedure','convertDateToMMDDYYYYFromCCYYMMDD implemented here. its basic function is to convert the date format from  CCYYMMDD to ddmmyyyy'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Procedure','getDateOfServiceFrom,getDateOfServiceTo can be provided with argument of DATEFORMAT_USA(constant 1) to get the date in mmddyyyy format'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/18/1999', 'SSI', 'Billing Interface/Claim Procedure','Emergency indicator set as 1=>Y, 0 =>N'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/18/2000', 'SSI', 'Billing Interface/Claim Procedure','reference property added which holds a reference number per invoice item'],

);

1;
