##############################################################################
package App::Billing::Claim::Adjustment;
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
	
	$param{adjsutId} = undef;
	$param{adjustType} = undef;
	$param{adjustAmt} = undef;
	$param{billId} = undef;
	$param{flags} = undef;
	$param{payerType} = undef;
	$param{payerId} = undef;
	$param{planAllow} = undef;
	$param{planPaid} = undef;
	$param{deductible} = undef;
	$param{copay} = undef;
	$param{submitDate} = undef;
	$param{payDate} = undef;
	$param{payType} = undef;
	$param{payMethod} = undef;
	$param{payRef} = undef;
	$param{writeoffCode} = undef;
	$param{writeoffAmt} = undef;
	$param{adjustCodes} = undef;
	$param{netAdjust} = undef;
	$param{comments} = undef;
	$param{authRef} = undef;
	$param{parentId} = undef;
	return bless \%param, $type;
}

sub setWriteoffCode
{
	my ($self, $value) = @_;
	$self->{writeoffCode} = $value;
}

sub getWriteoffCode
{
	my $self = shift;
	return $self->{writeoffCode};
}

sub setParentId
{
	my ($self, $value) = @_;
	$self->{parentId} = $value;
}

sub getParentId
{
	my $self = shift;
	return $self->{parentId};
}

sub setAuthRef
{
	my ($self, $value) = @_;
	$self->{authRef} = $value;
}

sub getAuthRef
{
	my $self = shift;
	return $self->{authRef};
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

sub setNetAdjust
{
	my ($self, $value) = @_;
	$self->{netAdjust} = $value;
}

sub getNetAdjust
{
	my $self = shift;
	return $self->{netAdjust};
}

sub setAdjustCodes
{
	my ($self, $value) = @_;
	$self->{adjustCodes} = $value;
}

sub getAdjustCodes
{
	my $self = shift;
	return $self->{adjustCodes};
}

sub setWriteoffAmt
{
	my ($self, $value) = @_;
	$self->{writeoffAmt} = $value;
}

sub getWriteoffAmt
{
	my $self = shift;
	return $self->{writeoffAmt};
}

sub setPayRef
{
	my ($self, $value) = @_;
	$self->{payRef} = $value;
}

sub getPayRef
{
	my $self = shift;
	return $self->{payRef};
}

sub getSubmitDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{submitDate}) : $self->{submitDate};
}
	
sub setSubmitDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{submitDate} = $value;
}

sub getPayDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{payDate}) : $self->{payDate};
}
	
sub setPayDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{payDate} = $value;
}

sub setPayMethod
{
	my ($self, $value) = @_;
	$self->{payMethod} = $value;
}

sub getPayMethod
{
	my $self = shift;
	return $self->{payMethod};
}

sub setPayType
{
	my ($self, $value) = @_;
	$self->{payType} = $value;
}	

sub getPayType
{
	my $self = shift;
	return $self->{payType};
}	

sub setCopay
{
	my ($self, $value) = @_;
	$self->{copay} = $value;
}

sub getCopay
{
	my ($self) = @_;
	return $self->{copay};
}

sub setDeductible
{
	my ($self, $value) = @_;
	$self->{deductible} = $value;
}

sub getDeductible
{
	my ($self) = @_;
	return $self->{deductible};
}

sub setPlanPaid
{
	my ($self, $value) = @_;
	$self->{planPaid} = $value;
}

sub getPlanPaid
{
	my ($self) = @_;
	return $self->{planPaid};
}

sub getPlanAllow
{
	my $self = shift;
	return $self->{planAllow};
}

sub setPlanAllow
{
	my ($self, $value) = @_;
	$self->{planAllow} = $value;
}

sub getPayerId
{
	my $self = shift;
	return $self->{payerId};
}

sub setPayerId
{
	my ($self,$value) = @_;
	$self->{payerId} = $value;
}

sub getPayerType
{
	my $self = shift;
	return $self->{payerType};
}

sub setPayerType
{
	my ($self,$value) = @_;
	$self->{payerType} = $value;
}

sub getFlags
{
	my $self = shift;
	return $self->{flags};
}

sub setFlags
{
	my ($self,$value) = @_;
	$self->{flags} = $value;
}
sub getBillId
{
	my $self = shift;
	return $self->{billId};
}

sub setBillId
{
	my ($self,$value) = @_;
	$self->{billId} = $value;
}

sub getAdjustAmt
{
	my $self = shift;
	return $self->{adjustAmt};
}

sub setAdjustAmt
{
	my ($self,$value) = @_;
	$self->{adjustAmt} = $value;
}

sub getAdjustType
{
	my $self = shift;
	return $self->{adjustType};
}

sub setAdjustType
{
	my ($self,$value) = @_;
	$self->{adjustType} = $value;
}

sub getAdjsutId
{
	my $self = shift;
	return $self->{adjsutId};
}

sub setAdjsutId
{
	my ($self,$value) = @_;
	$self->{adjsutId} = $value;
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
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Procedure','Adjustment implemented'],

);

1;
