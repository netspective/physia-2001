use strict;


push @INC, 'C:/ActivePerl/lib/App/Billing/Output';
use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::NSF;
use App::Billing::Validators;
use App::Billing::Output::PDF;

# for exporting NSF Constants
use App::Billing::Universal;


# For Oracle 8
#**************************************************************************
use constant cntStr => 'dbi:Oracle:HOST = 196.16.16.77;sid=ORCL;PORT = 1521';
use constant userId => 'physia';
use constant passWd => 'physia';

#use constant cntStr => 'dbi:Oracle:HOST = 63.96.146.5;sid=SDEDBS03;PORT = 1521';
#use constant userId => 'pro01';
#use constant passWd => 'pro';
#**************************************************************************


# For Access
#**************************************************************************
#use constant cntStr => 'dbi:ODBC:Physia';
#use constant userId => '';
#use constant passWd => '';
#**************************************************************************

use constant DEFAULT_VFLAGS => 0;

sub main
{
	my $claimList = new App::Billing::Claims;
	my $valMgr = new App::Billing::Validators;
	my $input = new App::Billing::Input::DBI;
	# my $pp = new pdflib;
	
	
	
	$input->registerValidators($valMgr);

	if($input->populateClaims($claimList,
				connectStr => cntStr, UID => userId, PWD => passWd,
				invoiceIds => [179], valMgr => $valMgr))
	{
		if($valMgr->haveErrors() == 0)
		{
			# really, the $output line should depend upon the claimProcessor method
			# but for now all we do is process NSF.
			#
			my $output = new App::Billing::Output::NSF;
			   $output->registerValidators($valMgr, NSF_HALLEY);
			#
			# call any validators that registered themselves as "Claim" validators
			#
			my $claims = $claimList->getClaim();

			if($valMgr->haveErrors() == 0)
			{
	#			$pp->processClaim(claimList => $claimList);
				}
						
			  #  $valMgr->validateClaim('Output', DEFAULT_VFLAGS, $claimList);
			

			foreach my $claim (@$claims)
			{
				# any validator types registered as 'Claim_Payer_Envoy_1234' will now be
				# called -- this would be like "validate claim for Envoy payer 1234"
				# -- if there are none, nothing should happen
				# $valMgr->validateClaim('Claim_' . $claim->getProgramName() , DEFAULT_VFLAGS, $claim);

			   # $valMgr->validateClaim('Claim_Payer', DEFAULT_VFLAGS, $claim);				
			}
			
#			printErrors($valMgr,"NSF ERRORS");
			
#			print $valMgr->haveErrors(),"\n";
						
			if($valMgr->haveErrors() == 0)
			{
				my $st = $claimList->getStatistics;
							
											
				my @outArray = ();
				
				if ($valMgr->haveErrors() == 0)
				{			
		  			 # PRINT TEST.TXT FILE
		  			 my $tempClaims = $claimList->getClaim();
		  			 
		  			 my $outResult = $output->processClaims(destination => NSFDEST_FILE, 
		  			 										outArray => \@outArray, 
															outFile => 'Halley1.txt',
		  			 										claimList => $claimList, 
		  			 										validationMgr => $valMgr,
		  			 										encryptKeyFile => 'encrypt.txt',
		  			 										nsfType => NSF_HALLEY,
		  			 										FLAG_STRIPDASH => '1');
		  			 
		  			 # PRINT TEST.PDF FILE
#		  			 $pp->processClaim(claimList => $claimList);
		  			 
		  			 print " Total Claims Processed = $st->{count} \n ";
		  			 
					# ONE STYLE: $valMgr->validateClaims('Output', DEFAULT_VFLAGS, $claimList);
					# ANOTHER STYLE: $valMgr->validateClaims('Output_'.$output->id(), DEFAULT_VFLAGS, $claimList);
				}
				else
				{
					printErrors($valMgr,"NSF ERRORS");
								
				}
				
			}
			else
			{
				printErrors($valMgr,"CLAIM VALIDATORS");
			}
		}
		else
		{
			printErrors($valMgr,"DBI ERRORS");
		}
	}
	else
	{
		# put errors into a claims error file
	}

}

main();


sub printErrors 
{
	my ($valMgr,$header) = @_;
	my $errors = $valMgr->getErrors();
	my $warnings = $valMgr->getWarnings();
	my ($error, $warning);
				 
	open(CLAIMFILE,">claimerror.txt");
	print CLAIMFILE "$header","\n\n\n";
	foreach $error (@$errors)
	{
		print CLAIMFILE @$error,"\n";
				
	}
	
	print CLAIMFILE "\n\n\n\nWARNINGS\n\n\n\n";
	
	foreach $warning (@$warnings)
	{
		print CLAIMFILE @$warning, "\n";
	}
	
	close(CLAIMFILE);
}
