###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FA0;
###################################################################################


#use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;

@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	 'FA0';
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
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};
	
	my $proccdureRef = $inpClaim->{procedures};
	my $currentProcedure = $proccdureRef->[$container->getSequenceNo()-1];
	my $i;
	my $zero = "0";
	my $pointer = $container->getSequenceNo();
	my @modifier = split (/ /,$currentProcedure->getModifier());
	my @diagnosis = split (/\,/,$self->diagnosisPtr($inpClaim,$currentProcedure->getDiagnosis()));
	
	
	
	
	# modifier are separated by to spaces '  '
	
my %payerType = (THIN_MEDICARE . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%-1s%-1s%-1s%1s%4s%4s%-1s%-1s%-1s%-15s%-15s%-2s%-1s%7s%7s%-1s%-1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%3s%2s%3s%3s%-8s%3s%7s%7s%-1s%7s%7s%7s%7s%7s%-10s%-1s%-9s%-1s%-1s%-7s%-14s%-1s%-1s%-1s%-1s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											            # line item control number
	substr($currentProcedure->getDateOfServiceFrom(),0,8), 			#ccyy/mm/dd Service Date from
	substr($currentProcedure->getDateOfServiceTo(),0,8),			#ccyy/mm/dd Service Date To
	substr($currentProcedure->getPlaceOfService(),0,2), # Place of service
	substr($currentProcedure->getTypeOfService(),0,2),	# type of service
	substr($currentProcedure->getCPT(),0,5),			# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$self->numToStr(5,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$self->numToStr(4,0,$currentProcedure->getDaysOrUnits()),   # units of service
	$self->numToStr(4,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
	substr($currentProcedure->getEmergency(),0,1),						  # Emergency Indicator
	substr($currentProcedure->getCOB(),0,1),							  # COB Indicator	
	$spaces, 															  # HPSA Indicator	
	substr($inpClaim->{renderingProvider}->getProviderId(),0,15),		  # Rendering Provider ID	
	substr($inpClaim->{treatment}->getIDOfReferingPhysician(),0,15),	  # Referring Provider ID	
	$spaces, 															  # Referring Provider State	 
	'N',	 															  # Purchase service indicator	
	$self->numToStr(5,2,$currentProcedure->getDisallowedCostContainment()), 	  # Disallowed Cost containment
	$self->numToStr(5,2,$currentProcedure->getDisallowedOther()),	  		      # Disallowed Other
	$spaces, 															  # Review by code indicator
	substr($inpClaim->{careReceiver}->getMultipleIndicator(),0,1),		  # multiple procedure indicator
	$spaces, 															  # Mammography certification number
	$spaces, 															  # Class Findings
	$spaces,  															  # Podiatry service condition	
	$spaces, 															  # CLIA number
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),				  # Primary Paid amount	
	$modifier[3] ne "" ? substr($modifier[3],0,2) : $spaces, 	          # HCPCS Modifier 4
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 		  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	'N',	 															  # Hospice Employed provider indicator	
	$spaces, #substr($inpClaim->getHGBHCTDate(),0,8),								  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	substr($inpClaim->getSerumCreatineDate(),0,8),						  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount
	$spaces,															  # types of units ind
	$spaces, 															  # approved amount
	$spaces, 															  # paid amount	
	$spaces, 															  # Bene Liability Amount	
	$spaces,															  # Balance Bill limit chg	
	$spaces,															  # limit chg percent
	$spaces,															  # perform prov phone
	$spaces,															  # perform prov tax type 
	$spaces,															  # perform prov tax id
	$spaces,															  # perform prov assign ind
	$spaces,															  # Pretransplant indicator
	$spaces,															  # ICD-10-PCS
	$spaces,															  # Universal Product code
	$spaces,															  # Diag Pointer - 5
	$spaces,															  # Diag Pointer - 6
	$spaces,															  # Diag Pointer - 7
	$spaces,															  # Diag Pointer - 8
	),
	THIN_COMMERCIAL . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%-1s%-1s%-1s%1s%4s%4s%-1s%-1s%-1s%-15s%-15s%-2s%-1s%7s%7s%-1s%-1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%3s%2s%3s%3s%-8s%3s%7s%7s%-1s%7s%7s%7s%7s%7s%-10s%-1s%-9s%-1s%-1s%-7s%-14s%-1s%-1s%-1s%-1s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											            # line item control number
	substr($currentProcedure->getDateOfServiceFrom(),0,8), 			#ccyy/mm/dd Service Date from
	substr($currentProcedure->getDateOfServiceTo(),0,8),			#ccyy/mm/dd Service Date To
	substr($currentProcedure->getPlaceOfService(),0,2), # Place of service
	substr($currentProcedure->getTypeOfService(),0,2),	# type of service
	substr($currentProcedure->getCPT(),0,5),			# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$self->numToStr(5,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$self->numToStr(4,0,$currentProcedure->getDaysOrUnits()),   # units of service
	$self->numToStr(4,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
	substr($currentProcedure->getEmergency(),0,1),						  # Emergency Indicator
	substr($currentProcedure->getCOB(),0,1),							  # COB Indicator	
	$spaces, 															  # HPSA Indicator	
	substr($inpClaim->{renderingProvider}->getProviderId(),0,15),		  # Rendering Provider ID	
	substr($inpClaim->{treatment}->getIDOfReferingPhysician(),0,15),	  # Referring Provider ID	
	$spaces, 															  # Referring Provider State	 
	$spaces, 															  # Purchase service indicator	
	$self->numToStr(5,2,$currentProcedure->getDisallowedCostContainment()), 	  # Disallowed Cost containment
	$self->numToStr(5,2,$currentProcedure->getDisallowedOther()),	  		      # Disallowed Other
	$spaces, 															  # Review by code indicator
	substr($inpClaim->{careReceiver}->getMultipleIndicator(),0,1),		  # multiple procedure indicator
	$spaces, 															  # Mammography certification number
	$spaces, 															  # Class Findings
	$spaces,  															  # Podiatry service condition	
	$spaces, 															  # CLIA number
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),				  # Primary Paid amount	
	$modifier[3] ne "" ? substr($modifier[3],0,2) : $spaces, 	          # HCPCS Modifier 4
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 		  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	$spaces, 															  # Hospice Employed provider indicator	
	$spaces, #inpClaim->getHGBHCTDate(),											  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	$spaces, #$inpClaim->getSerumCreatineDate(), 									  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount
	$spaces,															  # types of units ind
	$spaces, 															  # approved amount
	$spaces, 															  # paid amount	
	$spaces, 															  # Bene Liability Amount	
	$spaces,															  # Balance Bill limit chg	
	$spaces,															  # limit chg percent
	$spaces,															  # perform prov phone
	$spaces,															  # perform prov tax type 
	$spaces,															  # perform prov tax id
	$spaces,															  # perform prov assign ind
	$spaces,															  # Pretransplant indicator
	$spaces,															  # ICD-10-PCS
	$spaces,															  # Universal Product code
	$spaces,															  # Diag Pointer - 5
	$spaces,															  # Diag Pointer - 6
	$spaces,															  # Diag Pointer - 7
	$spaces,															  # Diag Pointer - 8
	),
	THIN_BLUESHIELD . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%-1s%-1s%-1s%1s%4s%4s%-1s%-1s%-1s%-15s%-15s%-2s%-1s%7s%7s%-1s%-1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%3s%2s%3s%3s%-8s%3s%7s%7s%-1s%7s%7s%7s%7s%7s%-10s%-1s%-9s%-1s%-1s%-7s%-14s%-1s%-1s%-1s%-1s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											            # line item control number
	substr($currentProcedure->getDateOfServiceFrom(),0,8), 			#ccyy/mm/dd Service Date from
	substr($currentProcedure->getDateOfServiceTo(),0,8),			#ccyy/mm/dd Service Date To
	substr($currentProcedure->getPlaceOfService(),0,2), # Place of service
	substr($currentProcedure->getTypeOfService(),0,2),	# type of service
	substr($currentProcedure->getCPT(),0,5),			# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$self->numToStr(5,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$self->numToStr(4,0,$currentProcedure->getDaysOrUnits()),   # units of service
	$self->numToStr(4,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
	substr($currentProcedure->getEmergency(),0,1),						  # Emergency Indicator
	substr($currentProcedure->getCOB(),0,1),							  # COB Indicator	
	$spaces, 															  # HPSA Indicator	
	substr($inpClaim->{renderingProvider}->getProviderId(),0,15),		  # Rendering Provider ID	
	substr($inpClaim->{treatment}->getIDOfReferingPhysician(),0,15),	  # Referring Provider ID	
	$spaces, 															  # Referring Provider State	 
	$spaces, 															  # Purchase service indicator	
	$self->numToStr(5,2,$currentProcedure->getDisallowedCostContainment()), 	  # Disallowed Cost containment
	$self->numToStr(5,2,$currentProcedure->getDisallowedOther()),	  		      # Disallowed Other
	$spaces, 															  # Review by code indicator
	substr($inpClaim->{careReceiver}->getMultipleIndicator(),0,1),		  # multiple procedure indicator
	$spaces, 															  # Mammography certification number
	$spaces, 															  # Class Findings
	$spaces,  															  # Podiatry service condition	
	$spaces, 															  # CLIA number
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),				  # Primary Paid amount	
	$modifier[3] ne "" ? substr($modifier[3],0,2) : $spaces, 	          # HCPCS Modifier 4
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 		  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	$spaces, 															  # Hospice Employed provider indicator	
	$spaces, #inpClaim->getHGBHCTDate(),											  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	$spaces, #$inpClaim->getSerumCreatineDate(), 									  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount
	$spaces,															  # types of units ind
	$spaces, 															  # approved amount
	$spaces, 															  # paid amount	
	$spaces, 															  # Bene Liability Amount	
	$spaces,															  # Balance Bill limit chg	
	$spaces,															  # limit chg percent
	$spaces,															  # perform prov phone
	$spaces,															  # perform prov tax type 
	$spaces,															  # perform prov tax id
	$spaces,															  # perform prov assign ind
	$spaces,															  # Pretransplant indicator
	$spaces,															  # ICD-10-PCS
	$spaces,															  # Universal Product code
	$spaces,															  # Diag Pointer - 5
	$spaces,															  # Diag Pointer - 6
	$spaces,															  # Diag Pointer - 7
	$spaces,															  # Diag Pointer - 8
	),
	THIN_MEDICAID . "" =>
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%-1s%-1s%-1s%1s%4s%4s%-1s%-1s%-1s%-15s%-15s%-2s%-1s%7s%7s%-1s%-1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%3s%2s%3s%3s%-8s%3s%7s%7s%-1s%7s%7s%7s%7s%7s%-10s%-1s%-9s%-1s%-1s%-7s%-14s%-1s%-1s%-1s%-1s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											            # line item control number
	substr($currentProcedure->getDateOfServiceFrom(),0,8), 			#ccyy/mm/dd Service Date from
	substr($currentProcedure->getDateOfServiceTo(),0,8),			#ccyy/mm/dd Service Date To
	substr($currentProcedure->getPlaceOfService(),0,2), # Place of service
	substr($currentProcedure->getTypeOfService(),0,2),	# type of service
	substr($currentProcedure->getCPT(),0,5),			# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$self->numToStr(5,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$self->numToStr(4,0,$currentProcedure->getDaysOrUnits()),   # units of service
	$self->numToStr(4,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
	substr($currentProcedure->getEmergency(),0,1),						  # Emergency Indicator
	substr($currentProcedure->getCOB(),0,1),							  # COB Indicator	
	$spaces, 															  # HPSA Indicator	
	substr($inpClaim->{renderingProvider}->getProviderId(),0,15),		  # Rendering Provider ID	
	substr($inpClaim->{treatment}->getIDOfReferingPhysician(),0,15),	  # Referring Provider ID	
	$spaces, 															  # Referring Provider State	 
	$spaces, 															  # Purchase service indicator	
	$self->numToStr(5,2,$currentProcedure->getDisallowedCostContainment()), 	  # Disallowed Cost containment
	$self->numToStr(5,2,$currentProcedure->getDisallowedOther()),	  		      # Disallowed Other
	$spaces, 															  # Review by code indicator
	substr($inpClaim->{careReceiver}->getMultipleIndicator(),0,1),		  # multiple procedure indicator
	$spaces, 															  # Mammography certification number
	$spaces, 															  # Class Findings
	$spaces,  															  # Podiatry service condition	
	$spaces, 															  # CLIA number
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),				  # Primary Paid amount	
	$modifier[3] ne "" ? substr($modifier[3],0,2) : $spaces, 	          # HCPCS Modifier 4
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 		  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	$spaces, 															  # Hospice Employed provider indicator	
	$spaces, #inpClaim->getHGBHCTDate(),											  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	$spaces, #$inpClaim->getSerumCreatineDate(), 									  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount
	$spaces,															  # types of units ind
	$spaces, 															  # approved amount
	$spaces, 															  # paid amount	
	$spaces, 															  # Bene Liability Amount	
	$spaces,															  # Balance Bill limit chg	
	$spaces,															  # limit chg percent
	$spaces,															  # perform prov phone
	$spaces,															  # perform prov tax type 
	$spaces,															  # perform prov tax id
	$spaces,															  # perform prov assign ind
	$spaces,															  # Pretransplant indicator
	$spaces,															  # ICD-10-PCS
	$spaces,															  # Universal Product code
	$spaces,															  # Diag Pointer - 5
	$spaces,															  # Diag Pointer - 6
	$spaces,															  # Diag Pointer - 7
	$spaces,															  # Diag Pointer - 8
	)
  );
 
 	return $payerType{$payerType};
 
}


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FB0;
###################################################################################


#use strict;
use Carp;


# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);

sub recordType
{
	'FB0';
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
	
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $zero = "0";
	my $Patient = $inpClaim->{careReceiver};
	
my %payerType = (THIN_MEDICARE . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%7s%7s%7s%7s%-15s%-2s%-15s%-2s%4s%4s%-11s%7s%-15s%-8s%2s%-1s%-1s%-1s%-1s%-1s%-15s%-9s%-33s%-30s%-30s%-20s%-9s%-10s%3s%-1s%-3s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,	# line item control no
	$self->numToStr(5,2,$zero), #pr svc charge
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(4,0,$zero), 
	$self->numToStr(4,0,$zero), 
	$spaces,
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$self->numToStr(2,0,$zero,), # spec pricing indicator
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(3,0,$zero), 
	$spaces, # payment type ind
	$spaces  # filler national
	),
	THIN_COMMERCIAL . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%7s%7s%7s%7s%-15s%-2s%-15s%-2s%4s%4s%-11s%7s%-15s%-8s%2s%-1s%-1s%-1s%-1s%-1s%-15s%-9s%-33s%-30s%-30s%-20s%-9s%-10s%3s%-1s%-3s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,	# line item control no
	$self->numToStr(5,2,$zero), #pr svc charge
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(4,0,$zero), 
	$self->numToStr(4,0,$zero), 
	$spaces,
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$self->numToStr(2,0,$zero,), # spec pricing indicator
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(3,0,$zero), 
	$spaces, # payment type ind
	$spaces  # filler national
	),
	THIN_MEDICAID . "" =>
	sprintf('%-3s%-2s%-17s%-17s%7s%7s%7s%7s%-15s%-2s%-15s%-2s%4s%4s%-11s%7s%-15s%-8s%2s%-1s%-1s%-1s%-1s%-1s%-15s%-9s%-33s%-30s%-30s%-20s%-9s%-10s%3s%-1s%-3s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,	# line item control no
	$self->numToStr(5,2,$zero), #pr svc charge
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(4,0,$zero), 
	$self->numToStr(4,0,$zero), 
	$spaces,
	$self->numToStr(5,2,$zero), 
	$spaces,
	$spaces,
	$self->numToStr(2,0,$zero,), # spec pricing indicator
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(3,0,$zero), 
	$spaces, # payment type ind
	$spaces  # filler national
	)
  );
  
  return $payerType{$payerType};
		
}


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FB1;
###################################################################################

#use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);


sub recordType
{
	'FB1';
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
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};
	my $renderingProvider = $inpClaim->{renderingProvider};
	
my %payerType = (THIN_COMMERCIAL . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-33s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-15s%-41s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	substr($renderingProvider->getLastName(),0,20),
	substr($renderingProvider->getFirstName(),0,12),
	substr($renderingProvider->getMiddleInitial(),0,1),
	substr($renderingProvider->getPIN(),0,6), # rendering prov UPIN
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces, # Filler national (it is of 35 characters not of 36 characters
	)
 );
 
 return $payerType{$payerType};
 
}


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FB2;
###################################################################################


#use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;

use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);


sub recordType
{
	'FB2';
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
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};

my %payerType = (THIN_MEDICARE . "" =>
	sprintf('%-3s%-2s%-17s%-17s%-2s%-30s%-30s%-20s%-2s%-9s%-2s%-30s%-30s%-20s%-2s%-9s%-2s%-30s%-30s%-20s%-2s%-9s%-2s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces
	),
	THIN_MEDICAID . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-2s%-30s%-30s%-20s%-2s%-9s%-2s%-30s%-30s%-20s%-2s%-9s%-2s%-30s%-30s%-20s%-2s%-9s%-2s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces
	)
  );

	return $payerType{$payerType};
}


1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::THIN_FE0;
###################################################################################


#use strict;
use Carp;
use vars qw(@CHANGELOG);

# for exporting NSF Constants
use App::Billing::Universal;



use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);


sub recordType
{
	'FE0';
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
	my ($self, $container, $flags, $inpClaim, $payerType) = @_;
	my $spaces = ' ';
	my $zero = "0";
	my $Patient = $inpClaim->{careReceiver};

my %payerType = (THIN_MEDICARE . "" =>
	sprintf('%-3s%-2s%-17s%-17s%-9s%-15s%-2s%7s%7s%-5s%4s%-2s%-20s%-2s%-2s%-1s%-1s%-1s%8s%-50s%-1s%-1s%-1s%-1s%-2s%-4s%-1s%-1s%-133s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$spaces,
	$self->numToStr(3,0,$zero).$zero, 
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,  # Anesthesia Extreme age indicator
	$spaces,  # Anesthesia Modifying Factors
	$spaces,  # Number Concurrent Anesthesia services
	$spaces,  # Amount applied to primary insurance max
	$spaces,  # Primary Insurance rejection reason
	$spaces,  # TPO procedure line change id
	$spaces,  # FEP Indicator
	$spaces,  # Individual Cosideration Indicator
	$spaces,  # 3rd party liability/ medicare override ind.
	$spaces,  # OPC number people in session
	$spaces,  # number of visits
	$spaces,  # Anesthesia physical status
	$spaces,  # How anesthesia services redefined
	$spaces   # filler-national
	),
	THIN_MEDICAID . "" =>
	sprintf('%-3s%-2s%-17s%-17s%-9s%-15s%-2s%7s%7s%-5s%4s%-2s%-20s%-2s%-2s%-206s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$self->numToStr(5,2,$zero), 
	$self->numToStr(5,2,$zero), 
	$spaces,
	$self->numToStr(3,0,$zero).$zero, 
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces
	)
  );
  
  return $payerType{$payerType};
  
}


1;