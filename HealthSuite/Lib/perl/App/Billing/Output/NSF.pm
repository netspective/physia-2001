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
    	my $testcount  = $claimsList->getClaim();
    	# creat the THIN.pm of File directory once	
    	$self->{nsfTHINFileObj} = new App::Billing::Output::File::THIN();

		# creates logical files for multiple payers
		foreach my $key(keys %$claimsCollection)
		{
			my $testKeyCount  = $claimsCollection->{$key}->getClaim();
			# Sometimes there is no claim in a collection , so to avoid problems on empty
			# claims list we ignore it
			if ($#$testKeyCount > -1)
			{
	    		$self->{nsfTHINFileObj}->processFile(claimList => $claimsCollection->{$key}, outArray => $params{outArray}, nsfType => $params{nsfType}, payerType => $key)
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
	
	$claimsCollection->{App::Billing::Universal::THIN_MEDICARE} = new App::Billing::Claims; # C for Medicare
	$claimsCollection->{App::Billing::Universal::THIN_MEDICAID} = new App::Billing::Claims; # D for Medicaid
	$claimsCollection->{App::Billing::Universal::THIN_COMMERCIAL} = new App::Billing::Claims; # G BlueShield
	$claimsCollection->{App::Billing::Universal::THIN_BLUESHIELD} = new App::Billing::Claims; # F Commercial


	for $i (0..$#$claims)
	{
		my $srcOfPayment = $claims->[$i]->{policy}->[0]->getSourceOfPayment();
		$srcOfPayment =~ s/ //g;
		my $error = " 0";
		if(grep{$_ eq $srcOfPayment} (App::Billing::Universal::THIN_MEDICARE, App::Billing::Universal::THIN_MEDICAID, App::Billing::Universal::THIN_COMMERCIAL, App::Billing::Universal::THIN_BLUESHIELD))
		{
			$claimsCollection->{$srcOfPayment}->addClaim($claims->[$i]); 
	
		}
		else # default payer is commercial
		{
			$claimsCollection->{App::Billing::Universal::THIN_COMMERCIAL}->addClaim($claims->[$i]);		
	
		}
	}
	# make four different collections of claims on the basis of Payer which could
	# be Commercial, Medicare, Medicaid and BlueShield
	# return the hash in which key will be THIN_XXX (XXX could be medicare, medicaid etc.)
	# against each key in hash there is an array of selected claims
	
	return $claimsCollection;
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


