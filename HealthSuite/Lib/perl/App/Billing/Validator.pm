##############################################################################
package App::Billing::Validator;
##############################################################################

#
# this is the base class, made up mostly of abstract methods that describes
# how any billing data validator should operated. This class is derived from
# App::Billing::Driver so it inherits all the normal behavior of any driver.
#

use strict;
use Carp;
use App::Billing::Driver;
require App::Billing::Locale::USCodes;
use Devel::ChangeLog;

use vars qw(@CHANGELOG);

use constant VALIDATORFLAGS_DEFAULT => 0;
use constant GREATER => 7;
use constant LESS => 1;
use constant EQUAL => 2;
use constant NOT_EQUAL => 20;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;
use constant NOT_ALL => 3;
use constant INDIVIDUAL_NAME => 4;
use constant ORGANIZATION_NAME=> 5;
use constant CHECK_EXACT_VALUES => 50;
use constant CHECK_CHARACTERS => 60;



sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}

# read/write a generic property for this class
#
sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getId
{
	$_[0]->abstract();
	# THIS METHOD IS NOW REQUIRED TO BE OVERIDDEN IN ANY DERIVED CLASS
	#return 'base';
}

sub getName
{
	$_[0]->abstract();
	# THIS METHOD IS NOW REQUIRED TO BE OVERIDDEN IN ANY DERIVED CLASS
	#return 'Base Input Class';
}

#
# getCallSequences returns either a single string or and array reference indicating the
# times when the validator should be called -- the options are
#   'Input' -- called for any input driver
#   'Input_XXX' -- called for input driver with id XXX
#   'Claim' -- called for validating the claim (after Input is complete)
#   'Output' -- called for any output driver
#   'Output_YYY' -- called for output driver with id XXX (not class name
#

sub getCallSequences
{
	$_[0]->abstract();
	# return, for example, 'Input_XXX' or
	# return ['Input', 'Output_YYY'];
}

#
# the $parent object is the App::Billing::Validators instance that is calling this object
# $callSeq will contact 'Input', 'Input_XXX', 'Claim', 'Output', or 'Output_YYY'
# $vFlags is reserved for now, always pass in App::Billing::Validator::VALIDATORFLAGS_DEFAULT
# $claim and $claimList should be obvious
#


sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString); 

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
	return $fg; 
}


sub checkLength
{
	my ($self, $condition, $positionFrom, $positionTo, $value, $length,$claim,$fld) = @_;
	if($value ne '')
	{
		if ($condition == (GREATER + EQUAL))
		{
			if (length($value) >= $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1000 ', $fld.' Length is greater than or equal to '.$length,$self->{claim});
			}
		}
		elsif ($condition == (GREATER))
		{
			if (length($value) > $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1000 ', $fld.' Length is greater than '.$length,$self->{claim});
			}
		}	
		elsif ($condition == (LESS + EQUAL))
		{
			if (length($value) <= $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1001 ' ,$fld.' Length is less than or equal to '.$length,$self->{claim});
			}
		}
		elsif ($condition == (LESS))
		{
			if (length($value) < $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1001 ' ,$fld.' Length is less than '.$length,$self->{claim});
			}
		}	
		elsif ($condition == EQUAL)
		{
			if (length($value) == $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1002 ' , $fld.' Length is equal to '.$length,$self->{claim});
			}
		}
		elsif ($condition == NOT_EQUAL)
		{
			if (length($value) != $length)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1002 ' , $fld.' Length is not equal to '.$length,$self->{claim});
			}
		}
	}	
}

sub checkValue
{
	
	my ($self, $condition, $value1, $value2, $claim, $fld) = @_;
	if(($value1 ne '') || ($value2 ne ''))
	{
		if ($condition == (GREATER + EQUAL))
		{
			if ($value1 >= $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1000 ', $fld,$self->{claim});
			}
		}
		
		elsif ($condition == (GREATER))
		{
			if ($value1 > $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1000 ', $fld,$self->{claim});
			}
		}	
		elsif ($condition == (LESS + EQUAL))
		{
			if ($value1 <= $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1001 ' ,$fld,$self->{claim});
			}
		}
		elsif ($condition == (LESS))
		{
			if ($value1 < $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1001 ' ,$fld,$self->{claim});
			}	
		}	
		elsif ($condition == EQUAL)
		{
			if ($value1 != $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1002 ' , $fld,$self->{claim});
			}	
		}
		elsif ($condition == NOT_EQUAL)
		{
			if ($value1 == $value2)
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1002 ' , $fld,$self->{claim});
			}
		}
	}
}


sub checkAlpha
{
	my ($self, $condition, $positionFrom, $positionTo, $value,$claim,$fld) = @_;
	my $tempValue;
	
	if($value ne '')
	{
		if (($positionFrom ne '') && ($positionTo ne ''))
		{	
			$tempValue = substr($value,$positionFrom-1,$positionTo-1);
		}	
		else
		{
			$tempValue = $value;
		}	
	
		if ($condition == CONTAINS)
		{
			if (($value =~ /\d/) || ($value =~ /\W/))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains Non-Alpha characters',$self->{claim});
			}	
		}	
		elsif ($condition == NOT_CONTAINS)
		{
			if (not (($value =~ /\d/) || ($value =~ /\W/)))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains Alpha characters',$self->{claim});
			}
		}		
		elsif ($condition == NOT_ALL)
		{
			if (not($value =~ /\d/))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains All Alpha characters',$self->{claim});
		
			}
		}
	}
}




sub checkAlphanumeric
{
	my ($self, $condition, $positionFrom, $positionTo, $value, $claim, $fld) = @_;
	my $tempValue;
	
	if($value ne '')
	{
		if (($positionFrom ne '') && ($positionTo ne ''))
		{	
			$tempValue = substr($value,$positionFrom-1,$positionTo-1);
		}	
		else
		{
			$tempValue = $value;
		}	
		if ($condition == CONTAINS)
		{
			if ($tempValue =~ /\W/i)
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains Non-Alphanumeric characters',$self->{claim});
			}
		}	
		elsif ($condition == NOT_CONTAINS)
		{
			if ($tempValue =~ /\w/i)
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains Alphanumeric characters',$self->{claim});
			}
		}		
		elsif ($condition == NOT_ALL)
		{
			if (not($tempValue =~ /\W/i))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1003 ', $fld.' Contains All Alphanumeric characters',$self->{claim});
			}
		}
	}
}


sub checkValidValues
{
	my ($self,$condition, $valuesFlag, $positionFrom,$positionTo,$value,$claim, $fld, @values ) = @_;
	my ($tempValue, $digitList,$wordList,$i,$j,$passed);
	my @wordValues;
	my @digitValues;


	if (($value ne "") && ($#values > -1))
	{
		# check wether the positions are given or not
		$tempValue = (($positionFrom ne '') && ($positionTo ne '')) ? substr($value,$positionFrom-1,$positionTo):$value;
		
		if ($condition == CONTAINS)
		{ 
 			if ($valuesFlag == CHECK_CHARACTERS)
 		  	{  
				my $val2 = join("@@",@values);
			
				$val2 =~ s/([-,\\])/\\$1/g;

				@values = split("@@",$val2);
			
				my $m = length($value);

				if ($value !~ /[@values]{$m}/)
				{
					$self->{valMgr}->addError($self->getId . "  " . $self->{claim}->getPayerId() . "  " . $self->{claim}->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
					#$self->{valMgr}->addError($self->getId . "  " . $self->{claim}->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});

					return;
				}

		  	}
		  	
		  	if ($valuesFlag == CHECK_EXACT_VALUES)
 		  	{
	 			 my $val5 = "(".join(")|(",@values).")";	

			 	 if ($val5 !~ /$value/)
				 {
					$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
					return;
			 	 } 
		  	}
		  
	  
		}
		else
		{
		
			if ($valuesFlag == CHECK_CHARACTERS)
			{  
				my $val2 = join("@@",@values);
				
				$val2 =~ s/([-,\\])/\\$1/g;

				@values = split("@@",$val2);
			
				my $m = length($value);

				if ($value =~ /[@values]{$m}/)
				{
					$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
					return;
				}
			}
		  	
		   	if ($valuesFlag == CHECK_EXACT_VALUES)
 		   	{
	 			my $val5 = "(".join(")|(",@values).")";

			 	if ($val5 =~ /$value/)
			 	{
					$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
					return;
			 	} 
		   	}
		  
		}
	}	
}

sub checkSameCharacter
{
	my ($self,$condition,$positionFrom,$positionTo,$value,$claim,$fld, @characterList) = @_;
	my ($tempValue,$length,$list,$val,@values);
	
	if($value ne '')
	{
		# check wether the positions are given or not
		$tempValue = (($positionFrom ne '') && ($positionTo ne '')) ? substr($value,$positionFrom-1,$positionTo):$value;
	
		$length = length($tempValue);

		foreach $val (@characterList)
		{
			$val = $val x $length;
			push(@values, $val);
		}		
			
		$list = "(".join(")|(",@values).")";

		if ($condition == CONTAINS)
		{
			if (not $tempValue =~ /$list/)
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
			}	
		}
		else
		{
			if ($tempValue =~ /$list/)
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1004 ', $fld.' Contains Invalid values ',$self->{claim});
	    	}
		}  	
	}
}

sub isRequired
{
	my ($self,$value,$claim,$fld) = @_;
	
	if ($value eq '')
	{
		$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1005 ', $fld.' Value is required ',$self->{claim});
	}
}



sub notRequired
{
	my ($self,$value,$claim,$fld) = @_;
	
	if ($value ne '')
	{
		$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1005 ', $fld.' Value must be empty ',$self->{claim});
	}
}

sub getYear
{
	
	my $self = shift;
	
	my $date = localtime();
	my @dateStr = substr(localtime(),20,4);

	@dateStr = reverse(@dateStr);

	return $dateStr[0];
}

sub getMonth
{
	my $self = shift;
	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
				   		 MAY => '05', JUN => '06', JUL => '07', AUG => '08',
				 		 SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
						};
	
	my $date = localtime();
	my $month = $monthSequence->{uc(substr(localtime(),4,3))};

	return $month;
}

sub getDay
{
	
	my $self = shift;
	my $day = substr(localtime(),8,2);
	$day =~ s/ /0/;
	return $day;
}


sub checkDate
{
	my ($self, $condition, $val, $claim, $fld,$targetDate) = @_;
	
	my $date = (($targetDate eq "") ? $self->getYear.$self->getMonth.$self->getDay : $targetDate) ;
	
	if($val ne '')
	{
		if ($condition == (GREATER + EQUAL))
		{
			if($val < $date)
			{
				my $msg = (($targetDate eq "") ? ' Must be greater than or equal to current date' : '');
				$self->{valMgr}->addError($self->getId() . "  " .$claim->getPayerId()."  ". $claim->getId(),' 1006 ', $fld . $msg ,$self->{claim});	
				return;
			}		
		}
		elsif  ($condition == (LESS + EQUAL))
		{
			if($val > $date)
			{
				my $msg = (($targetDate eq "") ? ' Must be less than current date' : '');
				$self->{valMgr}->addError($self->getId() . "  " .$claim->getPayerId()."  ". $claim->getId(),' 1006 ',$fld . $msg,$self->{claim});	
				return;
			}
		}
		elsif ($condition == EQUAL)
		{
			if($date != $val)
			{
				my $msg = (($targetDate eq "") ? ' Must be equal than current date' : '');
				$self->{valMgr}->addError($self->getId() . "  " .$claim->getPayerId()."  ". $claim->getId(),' 1006 ',$fld . $msg ,$self->{claim});	
				return;
			}
		}
	}
}


sub checkValidDate
{

	my ($self,$date, $claim, $fld) = @_;
	
		
	if(($date ne '') || length($date) > 0)
	{
		# check length of date
		if (length($date) != 8)
		{
			$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1006 ',$fld.' Invalid Date Length ',$self->{claim});
			return;
		}
	
		# check numeric
		if ($date =~ /\D/i)
		{
			$self->{valMgr}->addError($self->getId()."  ".$self->{claim}->getPayerId()."  ".$claim->getId(),' 1006 ',$fld.' Invalid Date Characters ',$self->{claim});
			return;
		}
		# month checking
		if ((substr($date,4,2) > 12) || (substr($date,4,2) < 1))
		{
			$self->{valMgr}->addError($self->getId()."  ".$self->{claim}->getPayerId()."  ".$claim->getId(),' 1006 ',$fld.' Invalid Date Month ',$self->{claim});
			return;
		}
		# day checking
		if ((substr($date,6,2) > 31) || (substr($date,6,2) < 1))
		{
			$self->{valMgr}->addError($self->getId()."  ".$self->{claim}->getPayerId()."  ".$claim->getId(),' 1006 ',$fld.' Invalid Date Day ',$self->{claim});
			return;
		}
	}
}



sub checkValidNames
{
	my ($self,$condition,$lastName,$firstName,$middleInitial,$claim, $fld) = @_;
	my @numbers = ('A'..'Z','a'..'z');
	my $alpha; 
	
	if(($lastName ne '')||($firstName ne '') || ($middleInitial ne ''))
	{
		
		if(($lastName ne '') && ($firstName ne '') && ($middleInitial ne ''))
		{				
			if (($lastName eq '') && ($firstName ne ''))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1200 ',$fld.' First name exist but not Last Name ',$self->{claim});
			}
	 
			if ((($lastName eq '') || ($firstName eq '')) && ($middleInitial ne ''))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1200 ', $fld.' For Middle Initial First and Last name must be present ',$self->{claim});
			} 	

		
		    $alpha = join("",@numbers);
    		if ((not($lastName =~ /^[$alpha]/)) || (not($firstName =~ /^[$alpha]/)) || (not($middleInitial =~ /^[$alpha]/)))
			{
				$self->{valMgr}->addError($self->getId."  ".$claim->getPayerId()."  ".$claim->getId(),' 1200 ', $fld.' Character at position 1 in First,Last and Middle initial must be A-Z ',$self->{claim});
			}
	
			my $tempLast = substr($lastName,1,length($lastName));
			my $tempFirst = substr($firstName,1,length($firstName));
			my $tempMiddle = substr($middleInitial,0,length($middleInitial));
		
			if ($condition == INDIVIDUAL_NAME)
			{
				my @validForIndividual = ('A'..'Z','a'..'z','-',' ');
				$self->checkValidValues(CONTAINS,'','',$tempLast,$claim,$fld . 'Last Name',@validForIndividual);
				$self->checkValidValues(CONTAINS,'','',$tempFirst,$claim,$fld . 'First Name',@validForIndividual);		
				$self->checkValidValues(CONTAINS,'','',$tempMiddle,$claim,$fld . 'Middle Initial',@validForIndividual);
			}
			elsif($condition == ORGANIZATION_NAME)
			{
				my @validForOrganization = ('A'..'Z','a'..'z',0..9,'-',' ',',','&','#');
		
				$self->checkValidValues(CONTAINS,'','',$tempLast,$claim,$fld . 'Last Name',@validForOrganization);
			}
		}
	}
		
}


sub checkValidAddress
{
	my ($self,$addressA,$addressB,$city,$state,$zipCode,$claim, $fld) = @_;
	my $values; 
	my @validAddressValues = ('A'..'Z','a'..'z','-',' ',',','&','#','/');
	my @validAddressValuesLines = ('A'..'Z','a'..'z','-',' ',',','&','#','/',0..9);
									
	if(($addressA ne '') || ($addressB ne '') || ($city ne '') || ($state ne '') || ($zipCode ne ''))				 
	{
	 	 if ($addressA ne '')
	 	{
	 		$self->isRequired($city,$claim,$fld . ' City ');
		 	$self->isRequired($state,$claim, $fld . ' State ');
	 		$self->isRequired($zipCode, $claim, $fld . ' Zip Code ');
			$self->checkValidValues(CONTAINS,'','',$addressA,$claim,$fld . ' Address 1',@validAddressValuesLines);
			if ($addressB ne '')
			{
				$self->checkValidValues(CONTAINS,'','',$addressB,$claim,$fld . ' Address 2',@validAddressValuesLines);
			}
	 	}	
	 
 		if ($city ne '')
 		{
 			$self->checkValidValues(CONTAINS,'','',$city,$claim,$fld . ' City ',@validAddressValues);
 			$self->checkLength(LESS,'','',$city,2,$claim,$fld . ' City ');
		}		
	 
	 	if ($state ne '')
 		{
	 	 	
	 	 	$self->checkValidValues(CONTAINS,'','',$state,$claim,$fld . ' State ',App::Billing::Locale::USCodes::getStates());
	 
	 		if ($zipCode ne '')
			{
				$self->checkLength(GREATER,'','',$zipCode,9,$claim,$fld . ' ZipCode ');
				$self->checkValidValues(CONTAINS,'','',$zipCode,$claim,$fld . ' ZipCode ',(0..9));
				
							
				if (not(App::Billing::Locale::USCodes::isValidZipCode($state, $zipCode)))
				{
					$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 1300 ', $fld.' Zip Code out of State Range ',$claim);	
					
				}	  
	    	}		
    	}
    }
}


sub checkValidTelephoneNo
{
	my ($self,$telephoneNo,$area,$claim,$fld) = @_;
	
				
	if ($telephoneNo ne '')
	{
		$self->checkValidValues(CONTAINS,'','',$telephoneNo,$claim,$fld . ' Telephone Number ',(0..9));
		$self->checkLength(NOT_EQUAL,'','',$telephoneNo,10,$claim,$fld . '');
		
		if ($area ne '')
		{
			$self->checkValidValues(CONTAINS,'','',substr($telephoneNo,0,3),$claim,$fld . ' Telephone Number Area Code ',App::Billing::Locale::USCodes::getAreaCodes($area));
		}		
	}
}	


sub getSubmissionSerialNo
{
    my $self = shift;
    
	my ($hash,$value,$key,%params);

	open(CONF,"conf.txt");

	while (<CONF>)
	{
		chop;
		($hash,$value) = split(/=/);
		 $hash =~ s/ //;			
		$params{$hash} = $value;
	}
	
	close(CONF);
		
	return $params{SUBMISSION_SERIAL_NO};
}

sub checkValidSerialAndDate
{
	my ($self,$claim)=@_ ;
	my ($targetdate ,$targetSrl);
	
	$targetdate = $self->getYear().$self->getMonth().$self->getDay();
	$targetSrl = $self->getSubmissionSerialNo();
	
	open (INPUT,'valid.txt');
	my $data={};
	my $abc="JK";
	my ($date, $srl);
	while ( $abc ne "")
	{
		$abc=<INPUT>;
		chomp;
		if  ( $abc ne "")
		{
			($date, $srl) = split (/,/, $abc);
				$data->{$date . $srl} = "1";
		}
	}
	my $target = $targetdate.$targetSrl."\n";
	foreach my $key (keys %$data)
	{
		if ($key eq $target)
			{
				$self->{valMgr}->addError($self->getId.$claim->getPayerId(),' 1300 ', 'AA0: File Date and Serial are matching with previous File ',$claim);
			}
	}
}


sub checkCountOfBatches
{
	my ($self,$claims) = @_;
	my ($providerID,$claimValue);
	
	$self->{batchesIndex} = 0;
	
	# fetch each element i.e. claim from claims array one by one
	for $claimValue (0..$#$claims)
	{
		
		# get the providerID from claim
		$providerID = $claims->[$claimValue]->{payToProvider}->getFederalTaxId();
		# add it in array without duplication
		if ($self->checkForDuplicate($providerID) eq 0)
		{
			$self->{batches}->[$self->{batchesIndex}++] = $providerID;
		}
	}
	if ($self->{batchesIndex} > 98)
	{
		$self->{valMgr}->addError($self->getId.$claims->[0]->getPayerId(),' 2000 ', 'BB0: Number of Batches exceeds from 0099',$claims->[0]);
	}
}


sub checkForDuplicate
{
	my ($self,$value) = @_;
	my $batchValue;
	my $tempBatches = $self->{batches};
	foreach $batchValue (@$tempBatches)
	{
		if ($batchValue eq $value)
		{
			return	1;
		}
	}
	
	return 0;
}


sub getAge
{
	my ($self, $date1, $date2, $years, $months, $days) = @_;
	
	if ($date1 eq '')
	{
		$self->{valMgr}->addError($self->getId()."  ".$self->{claim}->getPayerId()."  ".$self->{claim}->getId(),' 2000 ', 'Patient Date of Birth is Required');
		
		return 0;
	}
	
	if ($date2 eq '')
	{
		$date2 =  $self->getDate();
	}
	
	$$years = substr($date2,0,4) - substr($date1,0,4);
	$$months = (substr($date2,4,2) - substr($date1,4,2));
	$$days  = (substr($date2,6,2) - substr($date1,6,2));
	
	if ($$days < 0)
	{
		$$days = 30 - (($$days) * (-1));
	}
	
	if($$months < 0)
	{
		$$years--;
		$$months = 12 - ($$months * (-1));
	}
	
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

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
				   		 MAY => '05', JUN => '06', JUL => '07', AUG => '08',
				 		 SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
						};
						

	$date =~ s/-//g;
	if (length($date) == 8)
	{
		return $date;
	}
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);	
	}
					
}



sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $claim) = @_;
	$self->abstract();
	# here you can call $self->addError(blah, blah)
	# or $parent->addWarning(blah, blah)
	#
	# BUT DON'T CALL $claim->addError unless you only want the error put into
	# the claim object's error list and not yours _and_ the claim object's errors
	# list
}


sub getDiagnosisPtr
{
	my ($self, $currentClaim,$code ) = @_;
	my $diagnosisMap = {};
	my $ptr;
	
	if ($code ne "")
	{	
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[0]->getDiagnosis()} = 1 
		if defined ($currentClaim->{'diagnosis'}->[0]->getDiagnosis);
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[1]->getDiagnosis()} = 2  
		if defined $currentClaim->{'diagnosis'}->[1]->getDiagnosis;
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[2]->getDiagnosis()} = 3 
		if defined $currentClaim->{'diagnosis'}->[2]->getDiagnosis;
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[3]->getDiagnosis()} = 4 
		if defined $currentClaim->{'diagnosis'}->[3]->getDiagnosis;

		$ptr = $diagnosisMap->{$code};
	}
	else
	{
		$ptr = "";
	}

	
		
	return $ptr;

}



@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'AUF',
	'Billing Interface/Validator.pm',
	'App::Billing::Locale::USCodes class has now been introduced and its functions are used in ' . 
	'functions checkValidAddress and checkValidTelephoneNo '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'AUF',
	'Billing Interface/Validator.pm',
	'Function getZipCodes has been replaced with getAreaCodes in checkValidTelephoneNo function'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/01/2000', 'AUF',
	'Billing Interface/Validator.pm',
	'Function getDiagnosisPtr has been added which returs diagnosis code pointer on the basis of diagnosis code'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/05/2000', 'AUF',
	'Billing Interface/Validator.pm',
	'Now Locale::USCodes is being used as a package rather then a module'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/10/2000', 'AUF',
	'Billing Interface/Validator.pm',
	'Modification in checkValidValues is done, now it will trap any character or word outside the given list'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/12/2000', 'AUF',
	'Billing Interface/Validator.pm',
	'A new parmeter has been added in checkValidValues method and its value could be either CHECK_EXACT_VALUES or CHECK_CHARACTERS']
);

1;