###################################################################################
package App::Billing::Output::File::Header::NSF;
###################################################################################



#use strict;
use Carp;


# for exporting NSF Constants
use App::Billing::Universal;


sub new
{
	my ($type,%params) = @_;
	$params{data} = undef;
	return \%params,$type;
}

sub recordType
{
	'AA0';
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



sub formatData
{
	my ($self,$confData, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $firstClaim = $inpClaim->[0];
	my $claimPayToProvider = $firstClaim->{payToProvider};
	my $claimPayToProviderAddress = $claimPayToProvider->{address};
	my $refSourceOfPayment = {'MEDICARE' => 'C', 'MEDICADE' => 'D', 'CHAMPUS' => 'H', 'CHAMPVA' => ' ', 'GROUP' => ' ', 'FECA' => ' ', 'OTHER' => 'Z'};

my %nsfType = ( NSF_HALLEY . "" =>
	  sprintf("%-3s%-16s%-9s%-6s%-6s%-33s%-30s%-30s%-20s%-2s%-9s%-5s%-33s%-10s%-8s%-6s%-16s%-1s%5s%5s%-4s%-8s%-1s%-16s%-1s%-5s%-2s%-2s%-28s",
	  substr($self->recordType(),0,3),
	  substr($confData->{SUBMITTER_ID},0,9), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  $spaces, # Submitter Type
	  substr($confData->{SUBMISSION_SERIAL_NO},0,6), # submission serial no.
	  substr($confData->{SUBMITTER_NAME},0,33), # substr($claimCareProvider->getName(),0,33)
	  substr($confData->{ADDRESS_1},0,30), # substr($claimCareProviderAddress->getAddress1(),0,30)
	  substr($confData->{ADDRESS_2},0,30), # substr($claimCareProviderAddress->getAddress2(),0,30)
	  substr($confData->{CITY},0,20), # substr($claimCareProviderAddress->getCity(),0,20)
	  substr($confData->{STATE},0,2), # substr($claimCareProviderAddress->getState(),0,2)
	  substr($confData->{ZIP_CODE},0,9),# substr($claimCareProviderAddress->getZipCode(),0,9)
	  $spaces, # region
	  substr($confData->{CONTACT},0,3), # substr($claimCareProvider->getContact(),0,33)
	  substr($confData->{TELEPHONE_NUMBER},0,10), # substr($claimCareProviderAddress->getTelephoneNo(),0,10)
	  substr($self->getDate(),0,8),
	  substr($self->getTime(),0,6),
	  substr($confData->{RECEIVER_ID},0,16), # receiver id
	  substr($confData->{RECEIVER_TYPE_CODE},0,1),
	  substr($confData->{VERSION_CODE_NATIONAL},0,5), # $self->numToStr(3,2,'200'), # version code national
	  substr($confData->{VERSION_CODE_LOCAL},0,5), # $self->numToStr(3,2,'0'), # version code local
	  substr($confData->{TEST_PRODUCTION_INDICATOR},0,4), # test production indicator
	  $spaces, # user data
	  substr($confData->{RETRANSMISSION_STATUS},0,1), # retransmission status
	  $spaces, # not used
	  $spaces, # not used
	  substr($confData->{VENDOR_SOFTWARE_VERSION},0,5), # $self->numToStr(5,0,'21'), # vendor software version
	  substr($confData->{VENDOR_SOFTWARE_UPDATE},0,2), # $self->numToStr(2,0,'52'), # vendor software update
	  $spaces, # filler national
	  $spaces, # filler local
	  ),
	  NSF_THIN . "" =>
	  sprintf("%-3s%-16s%-9s%-6s%-6s%-33s%-30s%-30s%-20s%-2s%-9s%-5s%-33s%-10s%-8s%-6s%-16s%-1s%5s%5s%-4s%-8s%-1s%-16s%-1s%-5s%-2s%-1s%-8s%-8s%-1s%-8s%-4s",
	  substr($self->recordType(),0,3),
	  substr('S03135',0,16), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  $spaces, # Submitter Type
	  substr($confData->{SUBMISSION_SERIAL_NO},0,6), # submission serial no.
	  substr($confData->{SUBMITTER_NAME},0,33), # substr($claimCareProvider->getName(),0,33)
	  substr($confData->{ADDRESS_1},0,30), # substr($claimCareProviderAddress->getAddress1(),0,30)
	  substr($confData->{ADDRESS_2},0,30), # substr($claimCareProviderAddress->getAddress2(),0,30)
	  substr($confData->{CITY},0,20), # substr($claimCareProviderAddress->getCity(),0,20)
	  substr($confData->{STATE},0,2), # substr($claimCareProviderAddress->getState(),0,2)
	  substr($confData->{ZIP_CODE},0,9),# substr($claimCareProviderAddress->getZipCode(),0,9)
	  $spaces, # region
	  substr($confData->{CONTACT},0,33), # substr($claimCareProvider->getContact(),0,33)
	  substr($confData->{TELEPHONE_NUMBER},0,10), # substr($claimCareProviderAddress->getTelephoneNo(),0,10)
	  substr($self->getDate(),0,8),
	  substr($self->getTime(),0,6),
	  substr($confData->{RECEIVER_ID},0,16), # receiver id
	  substr($confData->{RECEIVER_TYPE_CODE},0,1),
	  substr($confData->{VERSION_CODE_NATIONAL},0,5), # $self->numToStr(3,2,'200'), # version code national
	  substr($confData->{VERSION_CODE_LOCAL},0,5), # $self->numToStr(3,2,'0'), # version code local
	  substr($confData->{TEST_PRODUCTION_INDICATOR},0,4), # test production indicator
	  substr($confData->{PASSWORD},0,8), # Password
	  substr($confData->{RETRANSMISSION_STATUS},0,1), # retransmission status
	  $spaces, # not used
	  $spaces, # not used
	  substr($confData->{VENDOR_SOFTWARE_VERSION},0,5), # $self->numToStr(5,0,'21'), # vendor software version
	  substr($confData->{VENDOR_SOFTWARE_UPDATE},0,2), # $self->numToStr(2,0,'52'), # vendor software update
	  $spaces, # cob file ind
	  $spaces, # process from date
	  $spaces, # process thru date
	  $spaces, # acknowledged request  (required)
	  $spaces, # date of receipt
	  $spaces, # filler national
	  ),
		NSF_ENVOY . ""  =>
 	  sprintf("%-3s%-16s%-9s%-6s%-6s%-33s%-30s%-30s%-20s%-2s%-9s%-5s%-33s%-10s%-8s%-6s%-5s%-11s%-1s%5s%5s%-4s%-8s%-1s%-16s%-1s%-5s%-2s%-2s%-28s",
	  substr($self->recordType(),0,3),
	  substr($confData->{SUBMITTER_ID},0,9), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  $spaces, # reserved filler
	  substr($confData->{SUBMISSION_SERIAL_NO},0,6), # submission serial no.
	  substr($confData->{SUBMITTER_NAME},0,33), # substr($claimCareProvider->getName(),0,33)
	  substr($confData->{ADDRESS_1},0,30), # substr($claimCareProviderAddress->getAddress1(),0,30)
	  substr($confData->{ADDRESS_2},0,30), # substr($claimCareProviderAddress->getAddress2(),0,30)
	  substr($confData->{CITY},0,20), # substr($claimCareProviderAddress->getCity(),0,20)
	  substr($confData->{STATE},0,2), # substr($claimCareProviderAddress->getState(),0,2)
	  substr($confData->{ZIP_CODE},0,9),# substr($claimCareProviderAddress->getZipCode(),0,9)
	  $spaces, # region
	  substr($confData->{CONTACT},0,3), # substr($claimCareProvider->getContact(),0,33)
	  substr($confData->{TELEPHONE_NUMBER},0,10), # substr($claimCareProviderAddress->getTelephoneNo(),0,10)
	  substr($self->getDate(),0,8),
	  substr($self->getTime(),0,6),
	  substr($confData->{RECEIVER_ID},0,5), # receiver id
	  substr($confData->{RECEIVER_SUB_ID},0,11), # receiver sub id
	  substr($confData->{RECEIVER_TYPE_CODE},0,1),
	  substr($confData->{VERSION_CODE_NATIONAL},0,5), # $self->numToStr(3,2,'200'), # version code national
	  substr($confData->{VERSION_CODE_LOCAL},0,5), # $self->numToStr(3,2,'0'), # version code local
	  substr($confData->{TEST_PRODUCTION_INDICATOR},0,4), # test production indicator
	  $spaces, # user data
	  substr($confData->{RETRANSMISSION_STATUS},0,1), # retransmission status
	  $spaces, # not used
	  $spaces, # not used
	  substr($confData->{VENDOR_SOFTWARE_VERSION},0,5), # $self->numToStr(5,0,'21'), # vendor software version
	  substr($confData->{VENDOR_SOFTWARE_UPDATE},0,2), # $self->numToStr(2,0,'52'), # vendor software update
	  $spaces, # filler national
	  $spaces, # filler local
	  )
	);

	return $nsfType{$nsfType};
}

1;

