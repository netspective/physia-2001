##############################################################################
package App::Billing::Claim::Patient;
##############################################################################

use strict;
use App::Billing::Claim::Person;
use App::Billing::Claim::Entity;
use Devel::ChangeLog;
use vars qw(@CHANGELOG);
use vars qw(@ISA);

use constant DATEFORMAT_USA => 1;
@ISA = qw(App::Billing::Claim::Person);

#
#   -- This modlue contains all patient's data
#   -- which is given in HCFA 1500 Form
#

sub new
{
	my ($type) = shift;;
	my $self = new App::Billing::Claim::Person(@_);
	$self->{accountNo} = undef;
	$self->{relationshipToInsured} = undef;
	$self->{signature} = undef;
	$self->{tpo} = undef;
	$self->{legalIndicator} = undef;
	$self->{poNumber} = undef;
	$self->{multipleIndicator} = undef;
	$self->{legalRepData} = undef;
	$self->{lastSeenDate} = undef;

	return bless $self, $type;
}



 sub getPoNumber
{

	my $self = shift;
	
	return $self->{poNumber};
}

sub setPoNumber
{

	my ($self, $value) = @_;
	
	$self->{poNumber} = $value;
}

sub getLastSeenDate
{

	my ($self, $formatIndicator) = @_;

	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{lastSeenDate}) : $self->{lastSeenDate};
}

sub setLastSeenDate
{
	my ($self,$value) = @_;
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
	my ($self,$value) = @_;

	$self->{tpo} = $value;
}

sub getlegalIndicator
{

	my $self = shift;
	
	return $self->{legalIndicator};
}

sub setlegalIndicator
{
	my ($self,$value) = @_;

	$self->{legalIndicator} = $value;
}


sub getMultipleIndicator
{

	my $self = shift;
	
	return $self->{multipleIndicator};
}

sub setMultipleIndicator
{
	my ($self,$value) = @_;

	$self->{multipleIndicator} = $value;
}

sub getSignature
{

	my $self = shift;
	
	return $self->{signature};
}

sub setSignature
{
	my ($self,$value) = @_;

	$self->{signature} = $value;
}

sub getAccountNo
{

	my $self = shift;
	
	return $self->{accountNo};
}

sub setAccountNo
{
	my ($self,$value) = @_;

	$self->{accountNo} = $value;
}

sub getRelationshipToInsured
{
	my ($self) = @_;
	
	return $self->{relationshipToInsured};
}

sub setRelationshipToInsured
{
	my ($self,$value) = @_;
	my $temp = 
		{ 
			'0' => '01',
			'10' => '02',
			'12' => '03',
			'99' => '99',
			'SELF' => '01',
			'SPOUSE' => '02',
			'CHILD' => '03',
			'OTHER' => '99',
		};
	
	$self->{relationshipToInsured} = $temp->{uc($value)};
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

sub printVal
{
	my ($self) = @_;
	foreach my $key (keys(%$self))
	{
		print " patient $key = " . $self->{$key} . " \n";
	}

}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Patient','setLastSeenDate use convertDateToCCYYMMDD  to change the date formats'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/21/1999', 'SSI', 'Billing Interface/Claim Patient','Patient relationship to insured has domain form 0 => 01,1 => 02,3 => 03,4 => 99,SELF => 01,SPOUSE => 02,CHILD => 03,OTHER => 99'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Patient','convertDateToMMDDYYYYFromCCYYMMDD implemented here. its basic function is to convert the date format from  CCYYMMDD to dd-mmm-yy'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/11/2000', 'SSI', 'Billing Interface/Claim Patient','getLastSeenDate can be provided with argument of DATEFORMAT_USA(constant 1) to get the date in mmddyyyy format'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '04/20/2000', 'SSI', 'Billing Interface/Claim Patient','Patient Relation ship to insured value updated'],

);

1;
