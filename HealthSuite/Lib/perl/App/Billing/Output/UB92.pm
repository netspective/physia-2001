##############################################################################
package App::Billing::Output::UB92;
##############################################################################

#
# this class creates an UB92 entry for a single Claim or multiple claims

use constant UB92DEST_ARRAY => 0;
use constant UB92DEST_FILE => 1;

use strict;
use App::Billing::Output::Driver;
use App::Billing::Claims;
use App::Billing::Output::File::UB92;
use App::Billing::Output::Validate::EnvoyPayer;
use App::Billing::Output::Validate::UB92;
use vars qw(@ISA);

#
# this object is inherited from App::Billing::Output::Driver
#
@ISA = qw(App::Billing::Output::Driver);

sub processClaims
{
	my ($self,%params) = @_;
	my $outArray = $params{outArray};
	my $claimsList;
	
	if ($params{destination} == UB92DEST_FILE)
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
	
	$self->{nsfFileObj} = new App::Billing::Output::File::UB92();
	$self->{nsfFileObj}->processFile(claimList => $claimsList, outArray => $params{outArray});
	
	if ($params{destination} == UB92DEST_FILE)
	{
		$self->createOutputFile($params{outArray});
		die 'outFile parameter required' unless $params{outFile};
	}

	return 1;
	#return $self->haveErrors();   # return 1 if successful, 0 if not
}

sub registerValidators
{
	 my ($self, $validators) = @_;
	
     $validators->register(new App::Billing::Output::Validate::EnvoyPayer);
     $validators->register(new App::Billing::Output::Validate::UB92);
}

sub getPayerName
{
	my ($self,$claim) = @_;
	
   return $claim->{insured}->getInsurancePlanOrProgramName();
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


