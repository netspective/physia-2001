###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FA0;
###################################################################################


#use strict;
use Carp;

# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
use Devel::ChangeLog;

@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);
use vars qw(@CHANGELOG);

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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
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
	
my %nsfType = (NSF_HALLEY . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%1s%1s%1s%1s%4s%4s%1s%1s%1s%-15s%-15s%-2s%1s%7s%7s%1s%1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%2s%2s%3s%3s%-8s%3s%7s%7s%-2s%-8s%8s%-1s%-8s%7s%-1s%-12s%-9s%-1s%-1s%-7s%-14s%-1s%-1s%-1s%-1s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											# line item control number
	$currentProcedure->getDateOfServiceFrom(), 			#ccyy/mm/dd Service Date from
	$currentProcedure->getDateOfServiceTo(),			#ccyy/mm/dd Service Date To
	sprintf("%02d", substr($currentProcedure->getPlaceOfService(),0,2)), # Place of service
	$currentProcedure->getTypeOfService(),				# type of service
	$currentProcedure->getCPT(),						# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$zero.$self->numToStr(4,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$zero.$self->numToStr(2,0,$currentProcedure->getDaysOrUnits()).$zero, # units of service
	$zero.$self->numToStr(3,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
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
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),					  # Primary Paid amount	
	substr($modifier[3],0,2),											  # HCPCS Modifier 4	
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 			  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	$spaces, 															  # Hospice Employeed provider indicator	
	$inpClaim->getHGBHCTDate(),											  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	$inpClaim->getSerumCreatineDate(), 									  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount	
	$spaces, 															  # HCPCS Mood 5	
	$spaces,															  # Date lab services ordered	
	$spaces,															  # Other paid amount
	$spaces,															  # Concurrent medically directed anesthesia
	$spaces,															  # Service misc date
	$spaces,															  # Service balance due
	$spaces,															  # Individual consideration ind.
	$spaces,															  # Filler
	$spaces,															  # Filler
	$spaces,															  # Public hospital indicator
	$spaces,															  # Pretransplant indicator
	$spaces,															  # ICD-10-PCS
	$spaces,															  # Universal Product code
	$spaces,															  # Diag Pointer - 5
	$spaces,															  # Diag Pointer - 6
	$spaces,															  # Diag Pointer - 7
	$spaces,															  # Diag Pointer - 8
	),
	NSF_ENVOY . "" =>
	sprintf('%-3s%-2s%-17s%-17s%-8s%-8s%-2s%-2s%-5s%-2s%-2s%-2s%7s%1s%1s%1s%1s%4s%4s%1s%1s%1s%-15s%-15s%-2s%1s%7s%7s%1s%1s%-10s%-9s%-3s%-15s%7s%-2s%-3s%1s%1s%1s%-8s%3s%2s%3s%3s%-8s%3s%7s%7s%-81s%2s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, 											# line item control number
	$currentProcedure->getDateOfServiceFrom(), 			#ccyy/mm/dd Service Date from
	$currentProcedure->getDateOfServiceTo(),			#ccyy/mm/dd Service Date To
	substr($currentProcedure->getPlaceOfService(),0,2), # Place of service
	$currentProcedure->getTypeOfService(),				# type of service
	$currentProcedure->getCPT(),						# HCPCS Procedure Code
	$modifier[0] ne "" ? substr($modifier[0],0,2) : $spaces, # HCPCS Modifier 1
	$modifier[1] ne "" ? substr($modifier[1],0,2) : $spaces, # HCPCS Modifier 2	
	$modifier[2] ne "" ? substr($modifier[2],0,2) : $spaces, # MCPCS Modifier 3
	$zero.$self->numToStr(4,2,abs($currentProcedure->getExtendedCost())), # Line Charges
	$diagnosis[0] ne "" ? substr($diagnosis[0],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[1] ne "" ? substr($diagnosis[1],0,1) : $spaces,  # if 1 then print else space
	$diagnosis[2] ne "" ? substr($diagnosis[2],0,1) : $spaces,  # if 1 then print else space 
	$diagnosis[3] ne "" ? substr($diagnosis[3],0,1) : $spaces,  # if 1 then print else space
	$zero.$self->numToStr(2,0,$currentProcedure->getDaysOrUnits()).$zero, # units of service
	$zero.$self->numToStr(3,0,$inpClaim->getAnesthesiaOxygenMinutes()),   # Anesthesia/Oxygen minutes
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
	$self->numToStr(5,2,abs($inpClaim->getAmountPaid())),					  # Primary Paid amount	
	substr($modifier[3],0,2),											  # HCPCS Modifier 4	
	substr($inpClaim->{renderingProvider}->getSpecialityId(),0,3), 			  # Provider Speciality	
	$spaces, 															  # Podiatry therapy indicator	
	$spaces, 															  # Podiatry therapy type	
	$spaces, 															  # Hospice Employeed provider indicator	
	$inpClaim->getHGBHCTDate(),											  # HGB/HCT Date	
	$self->numToStr(3,0,$zero),											  # Hemoglobin Result	
	$self->numToStr(2,0,$zero),											  # Hematocrit Result
	$self->numToStr(3,0,$zero),											  # Ptient weight
	$self->numToStr(3,0,$zero),											  # Epoetin Dosage	
	$inpClaim->getSerumCreatineDate(), 									  #	Serum Creatine Date
	$self->numToStr(3,0,$zero),											  # Creatine Results	
	$self->numToStr(5,2,$zero), 										  # Obligated to accept amount	
	$self->numToStr(5,2,$zero), 										  # Drug discount amount	
	$spaces, 															  # Filler national	
	$self->numToStr(2,0,$pointer)										  # RT-FA@ Pointer	
	)
  );
 
 	return $nsfType{$nsfType};
 
}

@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'AUF',
	'Billing Interface/Output NSF Object',
	'All dates are interperated from DD-MON-YY to CCYYMMDD format in FA0 by using ' .
	'function convertDateToCCYYMMDD'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'AUF',
	'Billing Interface/Output NSF Object',
	'The function convertDateToCCYYMMDD has been removed from FA0, now on Claim object will provide data in required format'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/10/2000', 'AUF',
	'Billing Interface/Output NSF Object',
	'The abs() function is used in getAmountPaid and getCharges() function in FA0 to keep from negative value'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FA0 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']





);


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FAat;
###################################################################################


#use strict;
use Carp;
use vars qw(@CHANGELOG);

# for exporting NSF Constants
use App::Billing::Universal;

use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);


sub recordType
{
	'FA@';
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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};
	my $claimRenderingProvider = $inpClaim->{renderingProvider};
	my $zero = "0";

my %nsfType = (NSF_HALLEY . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%9s%-1s%-17s%-10s%-1s%-3s%-3s%-15s%-18s%-15s%-2s%9s%-178s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, # Line item control number
	$self->numToStr(9,0,$claimRenderingProvider->getFederalTaxId()),  # federal tax id
	substr($inpClaim->getQualifier(),0,1),  # rendering provider name qualifier
	substr(($inpClaim->getQualifier() eq 'O' ? $inpClaim->{renderingOrganization}->getName : $claimRenderingProvider->getLastName()),0,17), # rendering provider last name
	substr(($inpClaim->getQualifier() eq 'O' ? $spaces : $claimRenderingProvider->getFirstName()),0,10), # rendering provider first name
	substr(($inpClaim->getQualifier() eq 'O' ? $spaces : $claimRenderingProvider->getMiddleInitial()),0,1), # rendering provider middle initial
	$spaces, # rendering provider qualification degree
	substr($claimRenderingProvider->getSpecialityId(),0,3), # rendering provider speciality code
	substr($claimRenderingProvider->getNetworkId(),0,15),   # rendering provider network id
	substr($claimRenderingProvider->{address}->getAddress1(),0,18), # rendering address 1
	substr($claimRenderingProvider->{address}->getCity(),0,15), # rendering provider city
	substr($claimRenderingProvider->{address}->getState(),0,2), # rendering provider state
	$claimRenderingProvider->{address}->getZipCode() . $self->numToStr(9 - length($claimRenderingProvider->{address}->getZipCode()),0,"0"), # rendering provider zip code
	$spaces
	),
	NSF_ENVOY . "" =>
	sprintf('%-3s%-2s%-17s%-17s%9s%-1s%-17s%-10s%-1s%-3s%-3s%-15s%-18s%-15s%-2s%9s%-178s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces, # Line item control number
	$self->numToStr(9,0,$claimRenderingProvider->getFederalTaxId()),  # federal tax id
	substr($inpClaim->getQualifier(),0,1),  # rendering provider name qualifier
	substr(($inpClaim->getQualifier() eq 'O' ? $inpClaim->{renderingOrganization}->getName : $claimRenderingProvider->getLastName()),0,17), # rendering provider last name
	substr(($inpClaim->getQualifier() eq 'O' ? $spaces : $claimRenderingProvider->getFirstName()),0,10), # rendering provider first name
	substr(($inpClaim->getQualifier() eq 'O' ? $spaces : $claimRenderingProvider->getMiddleInitial()),0,1), # rendering provider middle initial
	$spaces, # rendering provider qualification degree
	substr($claimRenderingProvider->getSpecialityId(),0,3), # rendering provider speciality code
	substr($claimRenderingProvider->getNetworkId(),0,15),   # rendering provider network id
	substr($claimRenderingProvider->{address}->getAddress1(),0,18), # rendering address 1
	substr($claimRenderingProvider->{address}->getCity(),0,15), # rendering provider city
	substr($claimRenderingProvider->{address}->getState(),0,2), # rendering provider state
	$claimRenderingProvider->{address}->getZipCode() . $self->numToStr(9 - length($claimRenderingProvider->{address}->getZipCode()),0,"0"), # rendering provider zip code
	$spaces
	)
  );
  
  return $nsfType{$nsfType};
  
}

@CHANGELOG = 
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FA@ has been modified by introducing a hash in which NSF_ENVOY is used as key, which points a Envoy format record string']
);

1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FB0;
###################################################################################


#use strict;
use Carp;


# for exporting NSF Constants
use App::Billing::Universal;


use vars qw(@ISA);
use App::Billing::Output::File::Batch::Claim::Record::NSF;
@ISA = qw(App::Billing::Output::File::Batch::Claim::Record::NSF);
use vars qw(@CHANGELOG);

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
	
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $zero = "0";
	my $Patient = $inpClaim->{careReceiver};
	
my %nsfType = (NSF_HALLEY . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%7s%7s%7s%7s%-15s%-2s%-15s%-2s%4s%4s%-11s%7s%-15s%-8s%2s%1s%1s%1s%1s%1s%-15s%-9s%-33s%-30s%-30s%-20s%-9s%-9s%-3s%-1s%-1s%-2s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$self->numToStr(5,2,$zero), 
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
	$self->numToStr(2,0,$zero,), 
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
	$spaces, # Anesthesia perform
	$spaces, # Generic referring
	$spaces  # filler-local
	),
	NSF_ENVOY . "" =>
	sprintf('%-3s%-2s%-17s%-17s%7s%7s%7s%7s%-15s%-2s%-15s%-2s%4s%4s%-11s%7s%-15s%-8s%2s%1s%1s%1s%1s%1s%-15s%-9s%-33s%-30s%-30s%-20s%-9s%-9s%-3s%-2s%-2s',
	$self->recordType(),
	$self->numToStr(2,0,$container->getSequenceNo()),
	substr($Patient->getAccountNo(),0,17),
	$spaces,
	$self->numToStr(5,2,$zero), 
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
	$self->numToStr(2,0,$zero,), 
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
	$spaces,
	$spaces
	)
  );
  
  return $nsfType{$nsfType};
		
}

@CHANGELOG = 
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FB0 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']

);


1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FB1;
###################################################################################

#use strict;
use Carp;
use vars qw(@CHANGELOG);

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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};
	my $renderingProvider = $inpClaim->{renderingProvider};
	
my %nsfType = (NSF_HALLEY . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-33s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-15s%-3s%-36s%-1s%-1s%-1s',
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
	substr($renderingProvider->getLastName(),0,20),#$spaces,
	substr($renderingProvider->getFirstName(),0,12),#$spaces,
	substr($renderingProvider->getMiddleInitial(),0,1), #$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces,
	$spaces, # Alternate type of service code
	$spaces, # Filler national
	$spaces, # ACR For MII (RADCON)
	$spaces, # CRNA Indicator
	$spaces, # Admitting physician Ind y/n
	),
	NSF_ENVOY . "" =>	
	sprintf('%-3s%-2s%-17s%-17s%-33s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-20s%-12s%-1s%-15s%-15s%-20s%-21s',
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
	$spaces,
	$spaces
	)
 );
 
 return $nsfType{$nsfType};
 
}


@CHANGELOG = 
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FB1 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']
);

1;

###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FB2;
###################################################################################


#use strict;
use Carp;
use vars qw(@CHANGELOG);

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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $Patient = $inpClaim->{careReceiver};

my %nsfType = (NSF_HALLEY . "" =>
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
	NSF_ENVOY . "" =>	
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

	return $nsfType{$nsfType};
}


@CHANGELOG = 
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FB2 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']
);

1;


###################################################################################
package App::Billing::Output::File::Batch::Claim::Record::NSF::FE0;
###################################################################################


#use strict;
use Carp;
use vars qw(@CHANGELOG);

# for exporting NSF Constants
use App::Billing::Universal;



use vars qw(@ISA);
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
	my ($self, $container, $flags, $inpClaim, $nsfType) = @_;
	my $spaces = ' ';
	my $zero = "0";
	my $Patient = $inpClaim->{careReceiver};

my %nsfType = (NSF_HALLEY . "" =>
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
	NSF_ENVOY . "" =>
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
  
  return $nsfType{$nsfType};
  
}

@CHANGELOG = 
(
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/31/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The format method of FE0 has been made capable to generate Halley as well as Envoy NSF format record string by using a hash, in which NSF_HALLEY and NSF_ENVOY are used as keys']
);

1;