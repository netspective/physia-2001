##############################################################################
package App::Billing::Validators;
##############################################################################

use strict;
use Carp;
use App::Billing::Driver;
use App::Billing::Validator;
use vars qw(@ISA);
@ISA = qw(App::Billing::Driver);

sub new
{
	my $type = shift;
	my $self = App::Billing::Driver::new(@_);

	#
	# the validatorMap is structured like this: the key is either 'Input',
	# 'Input_XXX', 'Claim', 'Output', 'Output_YYY' and the value is a reference
	# to a list of validation object instances.
	#
	$self->{validatorMap} = {};
	return bless $self,$type;
}

sub register
{
	my ($self, $validator) = @_;

	die "Only App::Billing::Validator derivatives allowed here" unless ($validator->isa('App::Billing::Validator') );

	my $seq = $validator->getCallSequences();
	my $vMap = $self->{validatorMap};
	if(ref $seq eq 'ARRAY')
	{
		foreach (@$seq)
		{
			push(@{$vMap->{$_}}, $validator);
		}
	}
	elsif($seq)
	{
		push(@{$vMap->{$seq}}, $validator);
	}
	else
	{
		die "No validation calling sequence provided.";
	}
}

sub validateClaim
{
	my ($self, $callSeq, $vFlags, $claim) = @_;
	if(my $vals = $self->{validatorMap}->{$callSeq})
	{
		#
		# if there are any "registered" validators for this callSeq, then
		# just call each validator one at a time -- they will automatically
		# put any errors into our errors list by calling $parent->addError.
		#
		foreach my $childVal (@$vals)
		{
			#
			# if the child validator has a method called
			#   validate_Input, validate_Input_XXX,
			#   validate_Claim, validate_Output, or validate_Output_XXX
			# then call the specific method; otherwise, call the generic
			#   validate method.
			#
			# $self is being passed in because validaotr needs $parent
			#
			my $vMethod = $childVal->can("validate_$callSeq") || $childVal->can('validate');
			&{$vMethod}($childVal, $self, $callSeq, $vFlags, $claim);
		}
	}
}

sub validateClaims
{
	my ($self, $callSeq, $vFlags, $claimList) = @_;

	#
	# this method is identical to validateClaim except it operates
	# on a claimList -- it is duplicated because of performance reasons;
	#

	if(my $vals = $self->{validatorMap}->{$callSeq})
	{
		#
		# if there are any "registered" validators for this callSeq, then
		# just call each validator one at a time -- they will automatically
		# put any errors into our errors list by calling $parent->addError.
		#
		my $claims = $claimList->getClaim();
		foreach my $childVal (@$vals)
		{
			#
			# if the child validator has a method called
			#   validate_Input, validate_Input_XXX,
			#   validate_Claim, validate_Output, or validate_Output_XXX
			# then call the specific method; otherwise, call the generic
			#   validate method.
			#
			# $self is being passed in because validaotr needs $parent
			#
			my $vMethod = $childVal->can("validate_$callSeq") || $childVal->can('validate');
			foreach my $claim (@$claims)
			{
				&{$vMethod}($childVal, $self, $callSeq, $vFlags, $claimList);
			}
		}
	}
}


sub getTime
{
	my $date = localtime();
	my @timeStr = ($date =~ /(\d\d):(\d\d):(\d\d)/);

	return $timeStr[0].$timeStr[1].$timeStr[2];
}

sub getDate
{

	my $self = shift;

	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
				   		 MAY => '05', JUN => '06', JUL => '07', AUG => '08',
				 		 SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
						};

	my $date = localtime();
	my $month = $monthSequence->{uc(substr(localtime(),4,3))};
	my @dateStr = ($month, substr(localtime(),8,2), substr(localtime(),20,4));

	@dateStr = reverse(@dateStr);

	$dateStr[1] =~ s/ /0/;

	return $dateStr[0].$dateStr[2].$dateStr[1];

}




sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0].$temp1[1]."0" x ($lenDec - length($temp1[1]));
	return $fg;
}

1;