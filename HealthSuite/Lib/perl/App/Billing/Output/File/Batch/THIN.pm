###################################################################################
package App::Billing::Output::File::Batch::THIN;
###################################################################################

use strict;
use Carp;




use App::Billing::Output::File::Batch::Claim::THIN;
use App::Billing::Output::File::Batch::Header::THIN1;
use App::Billing::Output::File::Batch::Header::THIN2;
use App::Billing::Output::File::Batch::Trailer::THIN;

# for exporting NSF Constants
use App::Billing::Universal;


sub new
{
	my ($type,%params) = @_;
			
	return bless \%params,$type;
}


sub setSequenceNo
{
	my ($self,$no) = @_;
	
	$self->{sequenceNo} = $no;  
}

sub getSequenceNo
{
	my $self = shift;
	
	return $self->{sequenceNo};
}


sub incCountXXX
{
	my ($self,$property) = @_;
	
	$self->{$property}++ ;  
}

sub getCountXXX
{
	my ($self,$property) = @_;
	
	if ($property eq undef)
	{
		return ($self->{bXXX} + $self->{yXXX});	
	}
	else
	{
		return $self->{$property};
	}
}

sub processBatch
{
	my ($self,%params) = @_;
	my $tempClaimValue;
	my $strRef;
	my $i=1;
	
	my $tempClaims = $params{claimList}->getClaim();
	
	$self->setSequenceNo($params{batchSequenceNo});

	$self->{claims} = [];
	$self->{nsfClaimObjs}=0;
	$self->{batchServiceLineCount}=0;	
	$self->{batchRecordCount}=0;	
	$self->{batchClaimCount}=0;	
	$self->{batchTotalCharges}=0;	
	$self->{bXXX}=0;
	$self->{yXXX}=0;
	
	
	$self->prepareBatchHeader($tempClaims,$params{outArray}, $params{payerType});
		
	$self->{nsfClaimObjs} = new App::Billing::Output::File::Batch::Claim::THIN();
			
	for $tempClaimValue (0..$#$tempClaims)
	{				
		if ($tempClaimValue ne undef) 
		{
			$self->{nsfClaimObjs}->processClaim($tempClaims->[$tempClaimValue],$params{outArray}, $params{nsfType}, $params{payerType});
			
			$self->{batchServiceLineCount} += $self->{nsfClaimObjs}->getCountXXX('fA0XXX');
			$self->{batchRecordCount} += $self->{nsfClaimObjs}->getCountXXX();
			$self->{batchClaimCount} += $self->{nsfClaimObjs}->getCountXXX('cXXX');	
			
   		$self->{batchTotalCharges} += $self->{nsfClaimObjs}->{totalClaimCharges};	
    	}
	}

	
	
	$self->prepareBatchTrailer($tempClaims,$params{outArray}, $params{payerType});
	
	
}

sub prepareBatchHeader
{
	my ($self,$tempClaims,$outArray, $payerType) = @_;
			
	$self->incCountXXX('bXXX');
	$self->{nsfBatchHeader1Obj} = new App::Billing::Output::File::Batch::Header::THIN1;
	push(@$outArray,$self->{nsfBatchHeader1Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $payerType));	
	
	if ($payerType eq THIN_COMMERCIAL)
	{
	    $self->incCountXXX('bXXX');
 		$self->{nsfBatchHeader2Obj} = new App::Billing::Output::File::Batch::Header::THIN2;
	 	push(@$outArray,$self->{nsfBatchHeader2Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $payerType));
 	}
 	
	$self->{batchRecordCount} += $self->getCountXXX('bXXX');
}

sub prepareBatchTrailer
{
	my ($self,$tempClaims,$outArray, $payerType) = @_;

	$self->incCountXXX('yXXX');
	
	$self->{batchRecordCount} += $self->getCountXXX('yXXX');
	$self->{nsfBatchTrailerObj} = new App::Billing::Output::File::Batch::Trailer::THIN;
    push(@$outArray,$self->{nsfBatchTrailerObj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $payerType));
	
}


sub checkSamePayToAndRenderProvider
{
	my ($shift,$tempClaim) = @_;
		
	if ((($tempClaim->{payToProvider}->{address}->getAddress1()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress1())) &&
		(($tempClaim->{payToProvider}->{address}->getAddress2()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress2())) &&
		(($tempClaim->{payToProvider}->{address}->getCity()) eq  ($tempClaim->{renderingProvider}->{address}->getCity())) &&
		(($tempClaim->{payToProvider}->{address}->getState()) eq  ($tempClaim->{renderingProvider}->{address}->getState())) &&
		(($tempClaim->{payToProvider}->{address}->getZipCode()) eq  ($tempClaim->{renderingProvider}->{address}->getZipCode())))
	{
		return 1;
	}
	else
	{
		return 0;
	}
}	 			
	   	

sub checkSamePayToOrgAndRenderProvider
{
	my ($shift,$tempClaim) = @_;
		
	if ((($tempClaim->{payToOrganization}->{address}->getAddress1()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress1())) &&
		(($tempClaim->{payToOrganization}->{address}->getAddress2()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress2())) &&
		(($tempClaim->{payToOrganization}->{address}->getCity()) eq  ($tempClaim->{renderingProvider}->{address}->getCity())) &&
		(($tempClaim->{payToOrganization}->{address}->getState()) eq  ($tempClaim->{renderingProvider}->{address}->getState())) &&
		(($tempClaim->{payToOrganization}->{address}->getZipCode()) eq  ($tempClaim->{renderingProvider}->{address}->getZipCode())))
	{
		return 1;
	}
	else
	{
		return 0;
	}
}	 			


1;

