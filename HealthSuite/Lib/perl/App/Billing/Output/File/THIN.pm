###################################################################################
package App::Billing::Output::File::THIN;
###################################################################################

use strict;
use Carp;



use App::Billing::Claims;
use App::Billing::Output::File::Batch::THIN;
use App::Billing::Output::File::Header::THIN;
use App::Billing::Output::File::Trailer::THIN;

# for exporting NSF Constants
use App::Billing::Universal;



sub new
{
	my ($type,%params) = @_;
		
	return bless \%params,$type;
}

sub processFile
{
	my ($self,%params) = @_;
	my $strRef;
	my $batchWiseClaimsCollection;
		
	# get claims from Claims collection and put it in claims array
	my $tempClaims = $params{claimList}->getClaim();
	
			
	$self->{batches} = [];
	$self->{batchesIndex}= 0;
	$self->{nsfBatchObjs} = [];
	$self->{nsfBatchObjsIndex} = 0;
	$self->{batchWiseClaims} = [];
	$self->{batchWiseClaimsIndex} = 0;	
	
	$self->{fileServiceLineCount} = 0;	
	$self->{fileRecordCount} = 0;	
	$self->{fileClaimCount} = 0;	
	$self->{batchCount} = 0;	
	$self->{fileTotalCharges} = 0;
	$self->{batchSequenceNo} = 0;	
	
	$self->{nsfType} = $params{nsfType};	
	$self->{payerType} = $params{payerType};
	
	
	 $self->makeBatches($tempClaims);
	 $self->makeSelectedClaimsList($tempClaims);
			
	 my $confData = $self->readFile($tempClaims);
	

	# preparing the File header
	$self->prepareFileHeader($confData, $tempClaims,$params{outArray}, $params{payerType});

	# reference of claims collection array in which each collection represent a batch
	 my $tempBatchList =   $self->{batchWiseClaims};
	
	
	 $self->{nsfBatchObjs} = new App::Billing::Output::File::Batch::THIN();


	# taking out collection of claims one by one		
	
	 for $batchWiseClaimsCollection (0..$#$tempBatchList)
	{
	
		$self->{nsfBatchObjs}->processBatch(batchSequenceNo => $self->generateBatchSequenceNo(),claimList => $tempBatchList->[$batchWiseClaimsCollection], outArray => $params{outArray}, nsfType => $params{nsfType}, payerType => $params{payerType});
		$self->{fileServiceLineCount} +=	$self->{nsfBatchObjs}->{batchServiceLineCount}; 
		$self->{fileRecordCount} += $self->{nsfBatchObjs}->{batchRecorCount};
		$self->{fileClaimCount} += $self->{nsfBatchObjs}->{batchClaimCount};
		$self->{batchCount}++;
		$self->{fileTotalCharges} += $self->{nsfBatchObjs}->{batchTotalCharges};
	} # end of for loop

	
	# preparing File Trailer
	$self->prepareFileTrailer($confData, $tempClaims,$params{outArray}, $params{payerType});

}

# to generate sequence of batch
sub generateBatchSequenceNo
{
	my $self = shift;
	$self->{batchSequenceNo} = 1;
	return $self->numToStr(4,0,$self->{batchSequenceNo});
}

# responsible to create file header object and getting formatted string of record
sub prepareFileHeader
{
	my ($self, $confData, $tempClaims, $outArray, $payerType) = @_;
	
	$self->{fileHeaderObj} = new App::Billing::Output::File::Header::THIN;
	push(@$outArray,$self->{fileHeaderObj}->formatData($confData,$self,'0',$tempClaims, $payerType));
}

# responsible to create file trailer object and getting formatted string of record
sub prepareFileTrailer
{
	my ($self,$confData, $tempClaims,$outArray, $payerType) = @_;	
		
	$self->{fileTrailerObj} =  new App::Billing::Output::File::Trailer::THIN;
	push(@$outArray,$self->{fileTrailerObj}->formatData($confData,$self,{RECORDFLAGS_NONE => 0}, $tempClaims, $payerType)); 
}

# this method will search all the claims and make an array and each element contains
# providerId which is the basis of batch changing
# it will accept Claims list which is same passed to processFile method

sub makeBatches
{
	my ($self,$claims) = @_;
	my ($providerID,$claimValue);

   
    # Following two collections are being made for making sperate bathes for specific payers
    #

	for $claimValue (0..$#$claims)
	{
    	$providerID = $claims->[$claimValue]->{payToOrganization}->getFederalTaxId();
			
			$providerID =~ s/ //g;
			if ($providerID eq '')
			{
				$providerID = 'BLANK';
			}
		
			# add it in array without duplication
			if ($self->checkForDuplicate($providerID) eq 0) 
			{
				$self->{batches}->[$self->{batchesIndex}++] = $providerID;
			}
	
	} # end of claims list loop
		
	
}


# this method will create collections of selected claims according to their 
# respective batches
# it will accept Claims list which is same passed to processFile
sub makeSelectedClaimsList
{
	my ($self,$claims) = @_;
	my ($batchValue,$claim,$selectedClaims,$providerID, $counter);
	
	# get reference of batches array
	my $tempBatches = $self->{batches};
	# fetch each element i.e. claim from claims array one by one
	
		#my @payerCodes = (MEDICARE, MEDICAID, WORKERSCOMP);
	
	# Following lines will add batches which were made on the basis of medicare, medicaid etc.
		#foreach my $payerKey(keys %{$self->{payerClaimsBatch}})
		#{
	   	#if($self->{payerClaimsBatch}->{$payerKey}->getStatistics()->{count} > 0)
	   	#{
	   	 	# $self->{batchWiseClaims}->[$self->{batchWiseClaimsIndex}++] = $self->{payerClaimsBatch}->{$payerKey};
	   	#}	
		
		#}	
	
	# if due to non-existence of ProviederID batches does not exist then  
	# put them in one collection
	if ($#$tempBatches == -1)
	{
		# create a new Claims object
		$selectedClaims = new App::Billing::Claims;

		# get element from claims array one by one i.e. one claim at a time
		foreach $claim (@$claims)
		{
			my $payerId = $claim->{payToOrganization}->getFederalTaxId();
			
			# if particular payer id does not exist then add that claim into 
			# a seperate claims collection 
			if (!(grep{$_ eq $payerId} @{$self->{batches}}))
			{
				$selectedClaims->addClaim($claim);
			}

		}
			
		# when list of selected claims is complete add its reference in array
		$self->{batchWiseClaims}->[$self->{batchWiseClaimsIndex}++] = $selectedClaims;
	}		
	else
	{
		# if batches exist then
		# get element from batches one by one
		foreach $batchValue (@$tempBatches)
		{
			# create a new Claims object
			$selectedClaims = new App::Billing::Claims;

			# get element from claims array one by one i.e. one claim at a time
			foreach $claim (@$claims)
			{
					$counter++;
					$providerID = $claim->{payToOrganization}->getFederalTaxId();
					
					$providerID =~ s/ //g;
					if ($providerID eq "")
					{
						$providerID = 'BLANK';
					}
					
					if ($providerID eq $batchValue)
					{
						# if it is then add that claim in selected list
						$selectedClaims->addClaim($claim);
					}
										
			}	# end of loop of claims
			
			# when list of selected claims is complete add its reference in array
			$self->{batchWiseClaims}->[$self->{batchWiseClaimsIndex}++] = $selectedClaims;
			
		} # loop back to create another selected claims list and store it in array
	
	}
	
}

sub numToStr
{
	my($self,$len,$lenDec,$tarString) = @_;
	my @temp1 = split(/\./,$tarString);
	$temp1[0]=substr($temp1[0],0,$len);
	$temp1[1]=substr($temp1[1],0,$lenDec);

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
	return $fg;
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

sub readFile
{
    
    my ($self, $tempClaims) = @_;   
	#my ($hash,$value,$key,$tempSerial);
	my $params1 = {};
	
	#$params1->{RECEIVER_ID} = '13305';
	$params1->{SUBMITTER_ID} = '13305';
	$params1->{SUBMISSION_SERIAL_NO} = '000001';
	$params1->{SUBMITTER_NAME} = 'PHYSIA';
	$params1->{ADDRESS_1} = 'PHYSIA CORPORATION';
	$params1->{ADDRESS_2} = '260 N. SAM HOUSTON PKWY EAST, SUITE 220';
	$params1->{CITY} = 'HOUSTON';
	$params1->{STATE} = 'TX';
	$params1->{ZIP_CODE} = '77060';
	$params1->{REGION} = '';
	$params1->{CONTACT} = '';
	$params1->{TELEPHONE_NUMBER} = '2814476800';
	$params1->{RECEIVER_ID} = $tempClaims->[0]->getPayerId();
	$params1->{RECEIVER_TYPE_CODE} = $tempClaims->[0]->getSourceOfPayment(); #'F';
	$params1->{VERSION_CODE_NATIONAL} = '00301';
	$params1->{VERSION_CODE_LOCAL} = '00301';
	$params1->{TEST_PRODUCTION_INDICATOR} = 'TEST';
	$params1->{PASSWORD} = 'PHYSIA'; # to be included # problem of 29 and 30
	$params1->{RETRANSMISSION_STATUS} = '0';
	$params1->{RECEIVER_SUB_ID} = '2274';
	$params1->{VENDOR_SOFTWARE_UPDATE} = '52';
	$params1->{VENDOR_SOFTWARE_VERSION} = '0021';
	#open(CONF,"conf.txt");
	#my $abc='abc';
	#while ($abc ne '')
	#{
	#	$abc = (<CONF>);
	
	#	chop $abc;
	#	($hash,$value) = split(/=/,$abc);
	#		$params1->{$hash} = $value;

	#}
	#close(CONF);
	
	#open(CONFNEW,">conf.txt");

	#foreach $key (keys %$params1)
	#{
			
	#	if ($key ne '')
	#	{
	#		if($key eq 'SUBMISSION_SERIAL_NO')
	#		{
	#			$tempSerial = $params1->{$key} + 1;
	#			print CONFNEW "$key=$tempSerial\n";
				
	#		}
	#		else
	#		{
	#			print CONFNEW "$key=$params1->{$key}\n";	
	#		}
	#	}
	
	 #}

	# close(CONFNEW);

	
	#open(VALID,">>valid.txt");
	#print VALID $self->getDate,",",$params1->{SUBMISSION_SERIAL_NO},"\n";
	#close(VALID);
		
	return $params1;
}


1;

