###################################################################################
package App::Billing::Output::File::NSF;
###################################################################################

use strict;
use Carp;



use App::Billing::Claims;
use App::Billing::Output::File::Batch::NSF;
use App::Billing::Output::File::Header::NSF;
use App::Billing::Output::File::Trailer::NSF;

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
	my $confData;
	
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
	
	$self->{medicareClaimsList} = new App::Billing::Claims;
	$self->{medicaidClaimsList} = new App::Billing::Claims;
	$self->{workerscompClaimsList} = new App::Billing::Claims;
	
    $self->{payerClaimsBatch} = {	4 => $self->{medicareClaimsList},
					5 => $self->{medicaidClaimsList},
					6 => $self->{workerscompClaimsList}
				 };	

	
	$self->makeBatches($tempClaims);
	$self->makeSelectedClaimsList($tempClaims);
	my $st =$params{claimList}->getStatistics;


	
	$confData = $self->readFile();
	

	$self->prepareFileHeader($confData, $tempClaims,$params{outArray}, $params{nsfType});

	my $tempBatchList =   $self->{batchWiseClaims};
	
		 	
	$self->{nsfBatchObjs} = new App::Billing::Output::File::Batch::NSF();

		
	for $batchWiseClaimsCollection (0..$#$tempBatchList)
	{
		my $test = $tempBatchList->[$batchWiseClaimsCollection]->getClaim();
			
		$self->{nsfBatchObjs}->processBatch(batchSequenceNo => $self->generateBatchSequenceNo(),claimList => $tempBatchList->[$batchWiseClaimsCollection], outArray => $params{outArray}, nsfType => $params{nsfType});
		$self->{fileServiceLineCount} +=	$self->{nsfBatchObjs}->{batchServiceLineCount}; 
		$self->{fileRecordCount} += $self->{nsfBatchObjs}->{batchRecorCount};
		$self->{fileClaimCount} += $self->{nsfBatchObjs}->{batchClaimCount};
		$self->{batchCount}++;
		$self->{fileTotalCharges} += $self->{nsfBatchObjs}->{batchTotalCharges};
	}

	$self->prepareFileTrailer($confData, $tempClaims,$params{outArray}, $params{nsfType});

}

sub generateBatchSequenceNo
{
	my $self = shift;
	$self->{batchSequenceNo} = 1;
	return $self->numToStr(4,0,$self->{batchSequenceNo});
}

sub prepareFileHeader
{
	my ($self, $confData, $tempClaims, $outArray, $nsfType) = @_;
	
	$self->{fileHeaderObj} = new App::Billing::Output::File::Header::NSF;
	push(@$outArray,$self->{fileHeaderObj}->formatData($confData,$self,'0',$tempClaims, $nsfType));
}

sub prepareFileTrailer
{
	my ($self,$confData, $tempClaims,$outArray, $nsfType) = @_;	
		
	$self->{fileTrailerObj} =  new App::Billing::Output::File::Trailer::NSF;
	push(@$outArray,$self->{fileTrailerObj}->formatData($confData,$self,{RECORDFLAGS_NONE => 0}, $tempClaims, $nsfType)); 
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

	# fetch each element i.e. claim from claims array one by one
	my @payerCodes = (MEDICARE, MEDICAID, WORKERSCOMP);
	
	for $claimValue (0..$#$claims)
	{
    	my $claimType = $claims->[$claimValue]->getInsType();
    	
	   if ($self->{nsfType} == NSF_HALLEY)
	   {
	 
			 if( grep{$_ eq $claimType} @payerCodes)
			 {
				 $self->{payerClaimsBatch}->{$claimType}->addClaim($claims->[$claimValue]);
			 }
			 else
			 {
				# get the providerID from claim
				#$providerID = $claims->[$claimValue]->{payToProvider}->getFederalTaxId();
				$providerID = $claims->[$claimValue]->getEMCId();
				
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
			 } 
	  }		 
	  elsif ($self->{nsfType} == NSF_ENVOY)
	  {
			#  
		# get the providerID from claim
		$providerID = $claims->[$claimValue]->{payToProvider}->getFederalTaxId();
		# add it in array without duplication
		if ($self->checkForDuplicate($providerID) eq 0)
		{
			$self->{batches}->[$self->{batchesIndex}++] = $providerID;
		}
	  } # end of NSF type checking		 

	} # end of claims list loop
	
	
}


# this method will create collections of selected claims according to their 
# respective batches
# it will accept Claims list which is same passed to processFile
sub makeSelectedClaimsList
{
	my ($self,$claims) = @_;
	my ($batchValue,$claim,$selectedClaims,$providerID);
	
	# get reference of batches array
	my $tempBatches = $self->{batches};
	# fetch each element i.e. claim from claims array one by one
	my @payerCodes = (MEDICARE, MEDICAID, WORKERSCOMP);
	

	# Following lines will add batches which were made on the basis of payers	
	foreach my $payerKey(keys %{$self->{payerClaimsBatch}})
	{
	   if($self->{payerClaimsBatch}->{$payerKey}->getStatistics()->{count} > 0)
	   {
	   	  $self->{batchWiseClaims}->[$self->{batchWiseClaimsIndex}++] = $self->{payerClaimsBatch}->{$payerKey};
	   }	
		
	}	
	
	# if due to non-existence of ProviederID batches does not exist then  
	# put them in one collection
	if ($#$tempBatches == -1)
	{
		# create a new Claims object
		$selectedClaims = new App::Billing::Claims;

		# get element from claims array one by one i.e. one claim at a time
		foreach $claim (@$claims)
		{
			my $claimType = $claim->getInsType();
			if (!(grep{$_ eq $claimType} @payerCodes))
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
				# get providerId from claim
				 if ($self->{nsfType} == NSF_HALLEY)
			     {
					#$providerID = $claim->{payToProvider}->getFederalTaxId();
					$providerID = $claim->getEMCId();
					
					$providerID =~ s/ //g;
					if ($providerID eq "")
					{
						$providerID = 'BLANK';
					}
				}
				elsif($self->{nsfType} == NSF_ENVOY)
				{
					$providerID = $claim->{payToProvider}->getFederalTaxId();
				}
		
				my $claimType = $claim->getInsType();
	 
			 		
				# check it against batch element value
				if (($providerID eq $batchValue) && (!(grep{$_ eq $claimType} @payerCodes)))

				{
					# if it is then add that claim in selected list
					$selectedClaims->addClaim($claim);
				}
			}
		
			# when list of selected claims is complete add its reference in array
			$self->{batchWiseClaims}->[$self->{batchWiseClaimsIndex}++] = $selectedClaims;
		} # loop back to create another selected claims list and store it in array
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
	
	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
	return $fg; 
}


sub readFile
{
    
    my $self = shift;   
	my ($hash,$value,$key,$tempSerial);
	my $params1 = {};
	
	open(CONF,"conf.txt");
	my $abc='abc';
	while ($abc ne '')
	{
		$abc = (<CONF>);
	
		chop $abc;
		($hash,$value) = split(/=/,$abc);
			$params1->{$hash} = $value;

	}
	close(CONF);
	
	open(CONFNEW,">conf.txt");

	foreach $key (keys %$params1)
	{
			
		if ($key ne '')
		{
			if($key eq 'SUBMISSION_SERIAL_NO')
			{
				$tempSerial = $params1->{$key} + 1;
				print CONFNEW "$key=$tempSerial\n";
				
			}
			else
			{
				print CONFNEW "$key=$params1->{$key}\n";	
			}
		}
	
	 }

	 close(CONFNEW);

	
	open(VALID,">>valid.txt");
	print VALID $self->getDate,",",$params1->{SUBMISSION_SERIAL_NO},"\n";
	close(VALID);
		
	return $params1;
}


1;

