###################################################################################
package App::Billing::Output::File::Trailer::NSF;
###################################################################################



#use strict;
use Carp;

use vars qw(@CHANGELOG);

# for exporting NSF Constants
use App::Billing::Universal;




sub new
{
	my ($type,%params) = @_;
	
	return \%params,$type;
}

sub recordType
{
	'ZA0';
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



sub formatData
{
	my ($self,$confData, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';

my %nsfType = (NSF_HALLEY . ""  =>
	  sprintf("%-3s%-16s%-9s%-5s%-11s%7s%7s%7s%4s%11s%-120s%-120s",
	  $self->recordType(),
	  substr($confData->{SUBMITTER_ID},0,9), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  substr($confData->{RECEIVER_ID},0,5), # receiver id
	  substr($confData->{RECEIVER_SUB_ID},0,11), # receiver sub id
	  $self->numToStr(7,0,$container->{fileServiceLineCount}),
	  $self->numToStr(7,0,$container->{fileRecordCount}),
	  $self->numToStr(7,0,$container->{fileClaimCount}),
	  $self->numToStr(4,0,$container->{batchCount}),
	  $self->numToStr(9,2,$container->{fileTotalCharges}),
  	  $spaces, # filler national
	  $spaces, # filler local
	  )."\n",
	  NSF_THIN . ""  =>
	  sprintf("%-3s%-16s%-9s%-16s%7s%7s%7s%4s%11s%11s%11s%-218s",
	  $self->recordType(),
	  substr($confData->{SUBMITTER_ID},0,16), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  substr($confData->{RECEIVER_ID},0,16), # receiver id
	  $self->numToStr(7,0,$container->{fileServiceLineCount}),
	  $self->numToStr(7,0,$container->{fileRecordCount}),
	  $self->numToStr(7,0,$container->{fileClaimCount}),
	  $self->numToStr(4,0,$container->{batchCount}),
	  $self->numToStr(9,2,$container->{fileTotalCharges}),
  	  $spaces, # file total paid amount
  	  $spaces, # file total allowed amount
	  $spaces, # filler national
	  )."\n",
	  NSF_ENVOY . "" =>
	  sprintf("%-3s%-16s%-9s%-5s%-11s%7s%7s%7s%4s%11s%-120s%-120s",
	  $self->recordType(),
	  substr($confData->{SUBMITTER_ID},0,9), # submitter id (for time being physia id is entered)
	  $spaces, # reserved filler
	  substr($confData->{RECEIVER_ID},0,5), # receiver id
	  substr($confData->{RECEIVER_SUB_ID},0,11), # receiver sub id
	  $self->numToStr(7,0,$container->{fileServiceLineCount}),
	  $self->numToStr(7,0,$container->{fileRecordCount}),
	  $self->numToStr(7,0,$container->{fileClaimCount}),
	  $self->numToStr(4,0,$container->{batchCount}),
	  $self->numToStr(9,2,$container->{fileTotalCharges}),
  	  $spaces, # filler national
	  $spaces, # filler local
	  )."\n" 
  );
  
  return $nsfType{$nsfType};
  
}


@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/30/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of ZA0 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']
);


1;

