package App::Billing::Validate::HCFA;
#####################################################################
#####################################################################
use strict;
use Carp;
use App::Billing::Driver;
use App::Billing::Validator;

use constant VALITEMIDX_NAME => 0;
use constant VALITEMIDX_INSTANCE => 1;
use constant VALITEMIDX_ERRCODE => 2;
use constant VALITEMIDX_MESSAGE => 3;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;
use Devel::ChangeLog;

use vars qw(@ISA);
@ISA = qw(App::Billing::Validator);
use vars qw(@CHANGELOG);


use constant VALIDATORFLAGS_DEFAULT => 0;

sub new
{
	my ($type) = @_;
	my $self = new App::Billing::Validator(@_);

	return bless $self, $type;
}


# read/write a generic property for this class
#

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}


sub checkAddress
{
	my ($self,$address,$vFlag,$claim,$parent) = @_;

	if ( (($address->getAddress1() eq "") && 
			($address->getAddress2() eq "" )) && 
			($address->getCity() eq "") && 
			($address->getState() eq "") && 
			($address->getZipCode() eq "") && 
			($address->getTelephoneNo() eq ""))
		{
			$parent->addError($self->getId(),135, "Address is required", $claim);
		}
}

sub validateRequired
{
	my ($self, $vFlag, $claim, $vList,$parent) = @_;
	
	foreach my $item (@$vList)
	{
		my $methodName = $item->[VALITEMIDX_NAME];
		my $object = $item->[VALITEMIDX_INSTANCE];

		if ($object ne "" )
		{
			unless(&$methodName($object))
			{
				$parent->addError($self->getId(), $item->[VALITEMIDX_ERRCODE], $item->[VALITEMIDX_MESSAGE] || "$methodName is required", $claim);
			}
		}
	}
}

sub validateNotRequired
{
	my ($self, $vFlag, $claim, $vList, $parent) = @_;
	
	foreach my $item (@$vList)
	{
		my $methodName = $item->[VALITEMIDX_NAME];
		my $object = $item->[VALITEMIDX_INSTANCE];
		if (($object ne "") && ($methodName ne ""))
		{
			if (&$methodName($object) ne "" )
			{
				$parent->addWarning($self->getId(), $item->[VALITEMIDX_ERRCODE], $item->[VALITEMIDX_MESSAGE] || "$methodName is not required", $claim);
			}
		}
	}
}

sub checkValidValues
{
	my ($self,$condition,$positionFrom,$positionTo,$value,$targetObject, $fld, @values) = @_;
	my ($tempValue, $list);
	
	# check wether the positions are given or not
	$tempValue = (($positionFrom ne '') && ($positionTo ne '')) ? substr($value,$positionFrom-1,$positionTo):$value;
			
	$list = "(".join(")|(",@values).")";

	if ($condition == CONTAINS)
	{
		if (not $tempValue =~ /$list/)
		{
			$self->{valMgr}->addError($self->getId,' 1004 ', $fld.' Contains Invalid values ',$targetObject);
		}	
	}
	else
	{
		if ($tempValue =~ /$list/)
		{
			$self->{valMgr}->addError($self->getId,' 1004 ', $fld.' Contains Invalid values ',$targetObject);
	    }
	}  	
}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'SSI','Billing Interface/Validating HCFA 1500','HCFA: Check procedure is removed']
);

1;

