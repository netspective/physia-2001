##############################################################################
package App::Billing::Output::NSF;
##############################################################################

#
# this class creates an NSF entry for a single Claim or multiple claims


use strict;

#use Benchmark;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use App::Billing::Output::File::NSF;
use App::Billing::Output::File::THIN;
use App::Billing::Output::Validate::EnvoyPayer;
use App::Billing::Output::Validate::NSF;
use App::Billing::Output::Validate::PerSe;
use App::Billing::Output::Validate::THIN;
use App::Billing::Output::Strip;


use vars qw(@ISA);

@ISA = qw(App::Billing::Output::Driver);

# for exporting NSF Constants
use App::Billing::Universal;






#
# this object is inherited from App::Billing::Output::Driver
#


sub processClaims
{
	my ($self,%params) = @_;
	my $outArray = $params{outArray};
	my $claimsList;
	
#	my $t0 = new Benchmark;
	
	if ($params{destination} == NSFDEST_FILE)
	{
		$self->{outFile} = $params{outFile};
		die 'outFile parameter required' unless $params{outFile};
	}
	
		die 'claimList parameter required' unless $params{claimList};
	
	$claimsList = $params{claimList};
	
	
	# filtering out rejected claims and make new list of clean claims
	# my $claim;		
	# my $claims = $params{claimList}->getClaim();
	# $claimsList = new App::Billing::Claims;
	# foreach $claim (@$claims)
	# {
	#	if ($claim->haveErrors != 0)
	# {
	#		$claimsList->addClaim($claim);
	#	}	
	# }
	
    if ($params{FLAG_STRIPDASH} ne '')
    {
    	my $strip = new App::Billing::Output::Strip;
    	$strip->strip($claimsList);
    }
    
    if ($params{nsfType} == NSF_THIN) # if NSF type is THIN
    {
    	# get the sorted collections of claims on the basis of claim Type 
    	# which could be commercial, medicare, medicaid and blue shield
    	my $claimsCollection = getClaimsCollectionForTHIN($claimsList);
    	#my $testcount  = $claimsList->getClaim();
    	# creat the THIN.pm of File directory once	
    	$self->{nsfTHINFileObj} = new App::Billing::Output::File::THIN();

		
		
		# creates logical files for multiple payers
		foreach my $key(keys %$claimsCollection)
		{
			my $payerType = '';
			
			my $selectedClaims  = $claimsCollection->{$key};
			
			# Sometimes there is no claim in a collection , so to avoid problems on empty
			# claims list we ignore it
			if ($#$selectedClaims > -1)
			{
				my $tempCollection = new App::Billing::Claims;
				
				for my $tempClaimIndex(0..$#$selectedClaims)
				{
					if ($payerType eq '')
					{
						$payerType = $selectedClaims->[$tempClaimIndex]->{policy}->[0]->getSourceOfPayment();
					}
							
					$tempCollection->addClaim($selectedClaims->[$tempClaimIndex]);	
				}

				# if still there is no source of payment then F (Commercial) will
				# be default source of payment)
				if (($payerType eq '') || !(grep{$_ eq $payerType} (App::Billing::Universal::THIN_COMMERCIAL, App::Billing::Universal::THIN_MEDICARE, App::Billing::Universal::THIN_MEDICAID, App::Billing::Universal::THIN_BLUESHIELD)))
				{
						$payerType = App::Billing::Universal::THIN_COMMERCIAL;
				}
					
	    		$self->{nsfTHINFileObj}->processFile(claimList => $tempCollection, outArray => $params{outArray}, nsfType => $params{nsfType}, payerType => $payerType)
    		}
	    }
	    
	    # To add new line character in the last line inserted in array
	    $params{outArray}->[$#{$params{outArray}}] = $params{outArray}->[$#{$params{outArray}}] . "\n";
    }
    else
    {
    	$self->{nsfFileObj} = new App::Billing::Output::File::NSF();
		$self->{nsfFileObj}->processFile(claimList => $claimsList, outArray => $params{outArray}, nsfType => $params{nsfType});
	}
	
	if ($params{destination} == NSFDEST_FILE)
	{
		$self->createOutputFile($params{outArray});
		die 'outFile parameter required' unless $params{outFile};
	}
	
	#$self->createPGPEncryptFile($params{encryptKeyFile}, $params{outFile});
	
	  #my $t1 = new Benchmark;
	  #my $td = timediff($t1, $t0);
    
	  


	return 1;
	#return $self->haveErrors();   # return 1 if successful, 0 if not
}

sub registerValidators
{
	 my ($self, $validators, $nsfType) = @_;
	 
	 if($nsfType eq NSF_ENVOY)
	 {
	 	
	     $validators->register(new App::Billing::Output::Validate::EnvoyPayer);
	     $validators->register(new App::Billing::Output::Validate::NSF);
     }
     elsif($nsfType eq NSF_HALLEY)
     {
     	
     	$validators->register(new App::Billing::Output::Validate::PerSe);
     }
     elsif($nsfType eq NSF_THIN)
     {
       	$validators->register(new App::Billing::Output::Validate::THIN);
     }
     
}

#sub getPayerName
#{
#	my ($self,$claim) = @_;
	
 #  return $claim->{insured}->getInsurancePlanOrProgramName();
#}

sub getClaimsCollectionForTHIN
{
	my ($claimsList) = @_;
	my $claimsCollection = {};
	my $i;
	my ($test1,$test2);
	
	my $claims = $claimsList->getClaim(); 
	
    my $tempPayer = {};
	
	for $i (0..$#$claims)
	{
		my $payerId = $claims->[$i]->{policy}->[0]->getPayerId();
		push(@{$tempPayer->{$payerId}},$claims->[$i]);
	}	
	
	return $tempPayer;
}

sub createOutputFile
{
	my ($self,$outDataRef) = @_;

	open(OUTFILE,">$self->{outFile}");
	my $outString = join("\n", @{$outDataRef});
	
	print OUTFILE uc($outString);
	close(OUTFILE);	
			
}

1;


