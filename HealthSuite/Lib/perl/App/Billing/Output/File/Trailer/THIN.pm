###################################################################################
package App::Billing::Output::File::Trailer::THIN;
###################################################################################



#use strict;
use Carp;

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

	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0].$temp1[1]."0" x ($lenDec - length($temp1[1]));
	return $fg;
}



sub formatData
{
	my ($self,$confData, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';

my %payerType = (THIN_MEDICAID . ""  =>
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
	  ),
	  THIN_BLUESHIELD . ""  =>
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
	  ),
	  THIN_COMMERCIAL . ""  =>
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
	  ),
	  THIN_MEDICARE . "" =>
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
	  )
  );
  return $payerType{$payerType};
}

1;

