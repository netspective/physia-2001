###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF;
###################################################################################

use strict;
use Carp;

use App::Billing::Output::File::Batch::Claim::Record;
use vars qw(@ISA);

@ISA = qw(App::Billing::Output::File::Batch::Claim::Record);

sub recordType
{
	$_[0]->abstract();
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


sub diagnosisPtr
{
	my ($self, $currentClaim,$codes ) = @_;
	my $diagnosisMap = {};
	my $ptr;
	
	
	if ($currentClaim->{'diagnosis'}->[0] ne "")
	{	
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[0]->getDiagnosis()} = 1; 
	}
	if ($currentClaim->{'diagnosis'}->[1] ne "")
	{	
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[1]->getDiagnosis()} = 2;

	}  
	if ($currentClaim->{'diagnosis'}->[2] ne "")
	{	
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[2]->getDiagnosis()} = 3;

	}
	if ($currentClaim->{'diagnosis'}->[3] ne "")
	{	
		$diagnosisMap->{$currentClaim->{'diagnosis'}->[3]->getDiagnosis()} = 4;

	} 

		my @diagCodes = split(/,/,$codes);
		
		for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
		{
			my $tempVal = $diagCodes[$diagnosisCount];
			
			$tempVal =~ s/ //;
			$tempVal = $tempVal . "";
			
		    $ptr = $ptr . "," . $diagnosisMap->{$tempVal};
		}
	
	$ptr =~ s/,//;

	return $ptr;

}


1;
