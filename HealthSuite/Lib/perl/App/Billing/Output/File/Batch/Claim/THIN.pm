###################################################################################
package App::Billing::Output::File::Batch::Claim::THIN;
###################################################################################

use strict;
use Carp;


# for exporting NSF Constants
use App::Billing::Universal;


use App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_D;
use App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_E;
use App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_F;
use App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_G;
use App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_H;
use App::Billing::Output::File::Batch::Claim::Header::THIN1;
use App::Billing::Output::File::Batch::Claim::Header::THIN2;
use App::Billing::Output::File::Batch::Claim::Header::THIN3;
use App::Billing::Output::File::Batch::Claim::Trailer::THIN;

sub new
{
	my ($type,%params) = @_;

	$params{records} = [];
	$params{sequenceNo} = 0;
	$params{cXXX} = 0;
	$params{dXXX} = 0;
	$params{eXXX} = 0;
	$params{fA0XXX} = 0;
	$params{fXXX} = 0;
	$params{gXXX} = 0;
	$params{hXXX} = 0;
	$params{xXXX} = 0;
	$params{totalClaimCharges} = 0;
	$params{totalDisallowedCostContainmentCharges} = 0;
    $params{totalDisallowedOtherCharges} = 0;
	$params{totalAllowedAmount} = 0;
	$params{totalDeductibleAmount} = 0;
	$params{totalCoinsuranceAmount} = 0;
	$params{totalPatientAmountPaid} = 0;
	$params{totalPurchaseServiceCharges} = 0;

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

	# $property can be Cxx or Dxx etc.
	$self->{$property}++ ;
}

sub getCountXXX
{
	my ($self,$property) = @_;

	if ($property eq undef)
	{
		return ($self->{cXXX} + $self->{dXXX} +  $self->{eXXX} + $self->{fA0XXX} + $self->{fXXX} + $self->{gXXX} + $self->{hXXX} + $self->{xXXX});
	}
	else
	{
		return $self->{$property};
	}
}



sub processClaim
{
	my ($self,$tempClaim,$outArray, $nsfType, $payerType) = @_;

	$self->{sequenceNo} = 0;
	$self->{cXXX} = 0;
	$self->{dXXX} = 0;
	$self->{eXXX} = 0;
	$self->{fXXX} = 0;
	$self->{fA0XXX} = 0;
	$self->{gXXX} = 0;
	$self->{hXXX} = 0;
	$self->{xXXX} = 0;
	$self->{totalClaimCharges} = 0;
	$self->{totalDisallowedCostContainmentCharges} = 0;
    $self->{totalDisallowedOtherCharges} = 0;
    $self->{totalAllowedAmount} = 0;
	$self->{totalDeductibleAmount} = 0;
	$self->{totalCoinsuranceAmount} = 0;
	$self->{totalPatientAmountPaid} = 0;
	$self->{totalPurchaseServiceCharges} = 0;

	$self->setSequenceNo(1);
	$self->incCountXXX('cXXX');
	$self->prepareClaimHeader($tempClaim, $outArray, $payerType);

	my $recordCreationCondition = {THIN_MEDICARE . "" => {'DA0' => sub { return 1;},
									'DA1' => sub {return 0;},
									'DA2' => sub {return 0;},
									'DA3' => sub {return 0;},
 									'EA0' => sub { return 1;},
						 			'EA1' => sub { 	return 0;},
 									'FA0' => sub { return 1;},
						 			'FB1' => sub { return 0;}
 											},
					 		 THIN_MEDICAID . "" => {'DA0' => sub { return 1;},
									'DA1' => sub {return 0;},
									'DA2' => sub {return 0;},
									'DA3' => sub {return 0;},
 									'EA0' => sub { return 1;},
						 			'EA1' => sub { 	return 1;},
 									'FA0' => sub { return 1;},
						 			'FB1' => sub { return 0;}
								},
						THIN_BLUESHIELD . "" => {'DA0' => sub { return 1;},
									'DA1' => sub {return 0;},
									'DA2' => sub {return 0;},
									'DA3' => sub {return 0;},
 									'EA0' => sub { return 1;},
						 			'EA1' => sub { 	return 0;},
 									'FA0' => sub { return 1;},
						 			'FB1' => sub { return 0;}
 								},

 					THIN_COMMERCIAL . "" => {'DA0' => sub { return 1;},
									'DA1' => sub {return 0;},
									'DA2' => sub {return 0;},
									'DA3' => sub {return 0;},
 									'EA0' => sub { return 1;},
						 			'EA1' => sub { 	return 0;},
 									'FA0' => sub { return 1;},
						 			'FB1' => sub { return 1;}
 								}


 					};


	my $payerCount = 3; # in all payers maximum 3 D records are allowed
	my @insType = (0, 6, 7);

	for my $payersLoop (1..$payerCount)
	{
		if(&{$recordCreationCondition->{$payerType}->{DA0}} == 1)
		{
			$self->setSequenceNo($payersLoop);
			$self->incCountXXX('dXXX');
			$self->{DA0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_DA0;
    		push(@$outArray,$self->{DA0Obj}->formatData($self, {RECORDFLAGS_NONE => $payersLoop - 1} , $tempClaim, $payerType));
   		}
		if(&{$recordCreationCondition->{$payerType}->{DA1}} == 1)
		{
	   		$self->setSequenceNo($payersLoop);
			$self->incCountXXX('dXXX');
			$self->{DA1Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_DA1;
			push(@$outArray,$self->{DA1Obj}->formatData($self, {RECORDFLAGS_NONE => $payersLoop - 1} , $tempClaim, $payerType));
  		}
		if(&{$recordCreationCondition->{$payerType}->{DA2}} == 1)
		{
   			$self->setSequenceNo($payersLoop);
		   	$self->incCountXXX('dXXX');
			$self->{DA2Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_DA2;
	   		push(@$outArray,$self->{DA2Obj}->formatData($self, {RECORDFLAGS_NONE => $payersLoop - 1} , $tempClaim, $payerType));
		}
		if(&{$recordCreationCondition->{$payerType}->{DA3}} == 1)
		{
   			$self->setSequenceNo($payersLoop);
		   	$self->incCountXXX('dXXX');
			$self->{DA3Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_DA3;
	   		push(@$outArray,$self->{DA3Obj}->formatData($self, {RECORDFLAGS_NONE => $payersLoop - 1} , $tempClaim, $payerType));
		}
   } # end of for loop for payers (DAx)

   if(&{$recordCreationCondition->{$payerType}->{EA0}} == 1)
   {
	   	$self->setSequenceNo(1);
   		$self->incCountXXX('eXXX');
		$self->{EA0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_EA0;
	    push(@$outArray,$self->{EA0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));
   }
   if(&{$recordCreationCondition->{$payerType}->{EA1}} == 1)
   {
	   	$self->setSequenceNo(1);
		$self->incCountXXX('eXXX');
		$self->{EA1Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_EA1;
	   	push(@$outArray,$self->{EA1Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));
   	}
	if(&{$recordCreationCondition->{$payerType}->{FA0}} == 1)
	{
	   	$self->setSequenceNo(1);
   		$self->{FA0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FA0;
   	}
	if(&{$recordCreationCondition->{$payerType}->{FB1}} == 1)
	{
	   	$self->{FB1Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FB1;
    }

   	my $proceduresCount = $tempClaim->{procedures};
   	if($#$proceduresCount > -1)
   	{
	   	for my $i (0..$#$proceduresCount)
   		{

			if(&{$recordCreationCondition->{$payerType}->{FA0}} == 1)
			{
		    	push(@$outArray,$self->{FA0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));
		    }
    		if(&{$recordCreationCondition->{$payerType}->{FB1}} == 1)
			{
		    	push(@$outArray,$self->{FB1Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));
			}

#		    $self->{totalClaimCharges} +=  $tempClaim->{procedures}->[$self->getSequenceNo()-1]->getCharges();
			$self->{totalClaimCharges} +=  $tempClaim->{procedures}->[$self->getSequenceNo()-1]->getExtendedCost();


	    	$self->{totalDisallowedCostContainmentCharges} += $tempClaim->{procedures}->[$self->getSequenceNo()-1]->getDisallowedCostContainment();
	    	$self->{totalDisallowedOtherCharges} += $tempClaim->{procedures}->[$self->getSequenceNo()-1]->getDisallowedOther();
	    	$self->setSequenceNo($self->getSequenceNo()+1);
	   		$self->incCountXXX('fA0XXX');
	   		$self->incCountXXX('fXXX');
		}
	 }
   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('fXXX');
	# $self->{FB0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::FB0;
    # push(@$outArray,$self->{FB0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));

   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('fXXX');
	# $self->{FB1Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::FB1;
    # push(@$outArray,$self->{FB1Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));

   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('fXXX');
	# $self->{FB2Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::FB2;
    # push(@$outArray,$self->{FB2Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));

   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('fXXX');
	# $self->{FE0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::FE0;
    # push(@$outArray,$self->{FE0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));

   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('gXXX');
	# $self->{GC0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::GC0;
    # push(@$outArray,$self->{GC0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));


   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('gXXX');
	# $self->{GDatObj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::GDat;
    # push(@$outArray,$self->{GDatObj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));


   	# $self->setSequenceNo(1);
   	# $self->incCountXXX('hXXX');
	# $self->{HA0Obj} = new App::Billing::Output::File::Batch::Claim::Record::NSF::HA0;
    # push(@$outArray,$self->{HA0Obj}->formatData($self, {RECORDFLAGS_NONE => 0} , $tempClaim, $payerType));

	$self->setSequenceNo(1);
	$self->incCountXXX('xXXX');
	$self->prepareClaimTrailer($tempClaim,$outArray, $payerType);
	# print "Claim says records count = ",$self->getCountXXX(),"\n";
}


sub prepareClaimHeader
{
	my ($self,$tempClaim,$outArray, $payerType) = @_;

	$self->{nsfClaimHeader1Obj} = new App::Billing::Output::File::Batch::Claim::Header::THIN1;
	push(@$outArray,$self->{nsfClaimHeader1Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaim, $payerType));

 	# $self->{nsfClaimHeader2Obj} = new App::Billing::Output::File::Batch::Claim::Header::THIN2;
	# push(@$outArray,$self->{nsfClaimHeader2Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaim, $payerType));

	if ($payerType eq THIN_COMMERCIAL)
	{
		if(($tempClaim->{careReceiver}->getDateOfDeath() ne '') || ($tempClaim->{careReceiver}->getlegalIndicator() eq 'Y'))
		{
			$self->{nsfClaimHeader3Obj} = new App::Billing::Output::File::Batch::Claim::Header::THIN3;
			push(@$outArray,$self->{nsfClaimHeader3Obj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaim, $payerType));
		}
	}

}

sub prepareClaimTrailer
{
	my ($self,$tempClaim,$outArray, $payerType) = @_;

	$self->{nsfClaimTrailerObj} = new App::Billing::Output::File::Batch::Claim::Trailer::THIN;
	push(@$outArray,$self->{nsfClaimTrailerObj}->formatData($self, {RECORDFLAGS_NONE => 0}, $tempClaim, $payerType));

}


#sub getTime
#{
#	my $date = localtime();
#	my @timeStr = ($date =~ /(\d\d):(\d\d):(\d\d)/);

#	return $timeStr[0].$timeStr[1].$timeStr[2];
#}

#sub getDate
#{

#	my $self = shift;

#	my $monthSequence = {JAN => '01', FEB => '02', MAR => '03', APR => '04',
#				   		 MAY => '05', JUN => '06', JUL => '07', AUG => '08',
#				 		 SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
#						};

#	my $date = localtime();
#	my $month = $monthSequence->{uc(substr(localtime(),4,3))};
#	my @dateStr = ($month, substr(localtime(),8,2), substr(localtime(),20,4));

#	@dateStr = reverse(@dateStr);

#	$dateStr[1] =~ s/ /0/;

#	return $dateStr[0].$dateStr[2].$dateStr[1];

#}


#sub numToStr
#{
#	my($self,$len,$lenDec,$tarString) = @_;
#	my @temp1 = split(/\./,$tarString);
#	$temp1[0]=substr($temp1[0],0,$len);
#	$temp1[1]=substr($temp1[1],0,$lenDec);

#	my $fg =  "0" x ($len - length($temp1[0])).$temp1[0]."0" x ($lenDec - length($temp1[1])).$temp1[1];
#	return $fg;
#}

1;




