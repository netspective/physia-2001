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

	$self->{nsfBatchObjs} = [];
	$self->{nsfBatchObjsIndex} = 0;
	$self->{fileServiceLineCount} = 0;
	$self->{fileRecordCount} = 0;
	$self->{fileClaimCount} = 0;
	$self->{batchCount} = 0;
	$self->{fileTotalCharges} = 0;
	$self->{batchSequenceNo} = 0;

	$self->{nsfType} = $params{nsfType};
	$self->{payerType} = $params{payerType};
	$self->{serialNumber} = $params{serialNumber};

	# get claims from Claims collection and put it in claims array
	my $tempClaims = $params{claimList}->getClaim();

	# To get data for the header and trailer of File record
	my $confData = $self->getHeaderTrailerData($tempClaims);


	# preparing the File header and put the formatted string in $params{outArray}
	$self->prepareFileHeader($confData, $tempClaims,$params{outArray}, $params{payerType});

	# Creating Batch object
	 $self->{nsfBatchObjs} = new App::Billing::Output::File::Batch::THIN();

	# get hash of key, where keys are provider ids and again each key we get array of claims
	# this array of claim is infact a bacth of claims
	my $claimsCollection = $self->getBatches($tempClaims);

	# taking out key (i.e. provider id) from a hash one by one
	foreach my $key(keys %$claimsCollection)
	{
		# get array reference of claims stored against a partcular key
		my $selectedClaims =  $claimsCollection->{$key};

		# create a claims collection for every new key
		my $tempCollection = new App::Billing::Claims;

		# taking out each claim one by one and add it in claims collection
		# so that claims collection can be passed Batch object
		for my $claimsIndex(0..$#$selectedClaims)
		{
			$tempCollection->addClaim($selectedClaims->[$claimsIndex])
		}

		# calling batch object and passing parameters to it.
		$self->{nsfBatchObjs}->processBatch(batchSequenceNo => $self->generateBatchSequenceNo(),claimList => $tempCollection, outArray => $params{outArray}, nsfType => $params{nsfType}, payerType => $params{payerType});

		# Updating statistics after processing each batch
		$self->{fileServiceLineCount} +=	$self->{nsfBatchObjs}->{batchServiceLineCount};
		$self->{fileRecordCount} += $self->{nsfBatchObjs}->{batchRecorCount};
		$self->{fileClaimCount} += $self->{nsfBatchObjs}->{batchClaimCount};
		$self->{batchCount}++;
		$self->{fileTotalCharges} += $self->{nsfBatchObjs}->{batchTotalCharges};

	} # end of for loop


	# preparing File Trailer  and put the formatted string in $params{outArray}
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



# This method will pickup the Providedr ID of each claim and make batches on the basis of that.

sub getBatches
{
	my ($self,$claims) = @_;
	my ($providerID,$claimValue);

    # Following two collections are being made for making sperate bathes for specific payers
    #

	my $tempBatches = {};

	for my $claimIndex (0..$#$claims)
	{
		$providerID = $claims->[$claimIndex]->{payToProvider}->getTaxId();
		$providerID =~ s/ //g;
		$providerID =~ s/\-//g;

		push(@{$tempBatches->{$providerID}},$claims->[$claimIndex]);
	} # end of claims list loop

	return $tempBatches;
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


sub getHeaderTrailerData
{

    my ($self, $tempClaims) = @_;
	#my ($hash,$value,$key,$tempSerial);
	my $params1 = {};


	$params1->{SUBMITTER_ID} = 'S03135';
	$params1->{SUBMISSION_SERIAL_NO} = $self->numToStr(6,0,$self->{serialNumber});
	$params1->{SUBMITTER_NAME} = 'PHYSIA';
	$params1->{ADDRESS_1} = 'PHYSIA CORPORATION';
	$params1->{ADDRESS_2} = '260 N. SAM HOUSTON PKWY EAST, SUITE 220';
	$params1->{CITY} = 'HOUSTON';
	$params1->{STATE} = 'TX';
	$params1->{ZIP_CODE} = '77060';
	$params1->{REGION} = '';
	$params1->{CONTACT} = '';
	$params1->{TELEPHONE_NUMBER} = '2814476800';
	$params1->{RECEIVER_ID} = substr($tempClaims->[0]->{policy}->[0]->getPayerId(),0,5);
	$params1->{RECEIVER_TYPE_CODE} = $tempClaims->[0]->{policy}->[0]->getSourceOfPayment(); #'F';
	$params1->{VERSION_CODE_NATIONAL} = '00301';
	$params1->{VERSION_CODE_LOCAL} = '00301';
	$params1->{TEST_PRODUCTION_INDICATOR} = 'TEST';
	$params1->{PASSWORD} = 'PHYSIA'; # to be included # problem of 29 and 30
	$params1->{RETRANSMISSION_STATUS} = '0';
	$params1->{RECEIVER_SUB_ID} = '2274';
	$params1->{VENDOR_SOFTWARE_UPDATE} = '52';
	$params1->{VENDOR_SOFTWARE_VERSION} = '0021';

	return $params1;
}


1;

