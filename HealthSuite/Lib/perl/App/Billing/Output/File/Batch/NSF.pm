###################################################################################
package App::Billing::Output::File::Batch::NSF;
###################################################################################

use strict;
use Carp;




use App::Billing::Output::File::Batch::Claim::NSF;
use App::Billing::Output::File::Batch::Header::NSF1;
use App::Billing::Output::File::Batch::Header::NSF2;
use App::Billing::Output::File::Batch::Trailer::NSF;

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


	$self->prepareBatchHeader($tempClaims,$params{outArray}, $params{nsfType});

	$self->{nsfClaimObjs} = new App::Billing::Output::File::Batch::Claim::NSF();

	for $tempClaimValue (0..$#$tempClaims)
	{
		if ($tempClaimValue ne undef)
		{
			$self->{nsfClaimObjs}->processClaim($tempClaims->[$tempClaimValue],$params{outArray}, $params{nsfType});

			$self->{batchServiceLineCount} += $self->{nsfClaimObjs}->getCountXXX('fA0XXX');
			$self->{batchRecordCount} += $self->{nsfClaimObjs}->getCountXXX();
			$self->{batchClaimCount} += $self->{nsfClaimObjs}->getCountXXX('cXXX');

    		$self->{batchTotalCharges} += $self->{nsfClaimObjs}->{totalClaimCharges};

    	}
	}





	$self->prepareBatchTrailer($tempClaims,$params{outArray}, $params{nsfType});


}

sub prepareBatchHeader
{
	my ($self,$tempClaims,$outArray, $nsfType) = @_;

	$self->incCountXXX('bXXX');
	$self->{nsfBatchHeader1Obj} = new App::Billing::Output::File::Batch::Header::NSF1;
	push(@$outArray,$self->{nsfBatchHeader1Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $nsfType));

    $self->incCountXXX('bXXX');
 	$self->{nsfBatchHeader2Obj} = new App::Billing::Output::File::Batch::Header::NSF2;
 	push(@$outArray,$self->{nsfBatchHeader2Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $nsfType));

	$self->{batchRecordCount} += $self->getCountXXX('bXXX');
}

sub prepareBatchTrailer
{
	my ($self,$tempClaims,$outArray, $nsfType) = @_;

	$self->incCountXXX('yXXX');

	$self->{batchRecordCount} += $self->getCountXXX('yXXX');
	$self->{nsfBatchTrailerObj} = new App::Billing::Output::File::Batch::Trailer::NSF;
    push(@$outArray,$self->{nsfBatchTrailerObj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaims, $nsfType));

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

sub checkSamePayToAndRenderProvider
{
	my ($shift,$tempClaim) = @_;

	if ((($tempClaim->{payToProvider}->{address}->getAddress1()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress1())) &&
		(($tempClaim->{payToProvider}->{address}->getAddress2()) eq  ($tempClaim->{renderingProvider}->{address}->getAddress2())) &&
		(($tempClaim->{payToProvider}->{address}->getCity()) eq  ($tempClaim->{renderingProvider}->{address}->getCity())) &&
		(($tempClaim->{payToProvider}->{address}->getState()) eq  ($tempClaim->{renderingProvider}->{address}->getState())) &&
		(($tempClaim->{payToProvider}->{address}->getZipCode()) eq  ($tempClaim->{renderingProvider}->{address}->getZipCode())))
	{
		return 0;
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
		return 0;
	}
	else
	{
		return 0;
	}
}


1;


