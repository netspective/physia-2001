##############################################################################
package App::Billing::Output::Validate::NSF;
##############################################################################


use App::Billing::Claim;
use App::Billing::Claims;
use App::Billing::Validator;
require App::Billing::Locale::USCodes;
use Devel::ChangeLog;
use Benchmark;


use vars qw(@CHANGELOG);
@ISA = qw(App::Billing::Validator);



use strict;
use constant PAYERINFOIDX_NAME         => 0;
use constant PAYERINFOIDX_VALIDATEFUNC => 1;
use constant GREATER => 7;
use constant LESS => 1;
use constant EQUAL => 2;
use constant NOT_EQUAL => 20;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;
use constant NOT_ALL => 3;
use constant INDIVIDUAL_NAME => 4;
use constant ORGANIZATION_NAME=> 5;
use constant CHECK_EXACT_VALUES => 50;
use constant CHECK_CHARACTERS => 60;






sub validateA
{
	
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;	
	# check serial and date for duplication
	$self->checkValidSerialAndDate($tempClaim);
}

sub validateB
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim, $tempClaims) = @_;
	my $i;
	
		
	my @validTimeCodes = ('00','01','02','03','04','05','06','07','08','09',
						  '10','11','12','13','14','15','16','17','18','19',
						  '20','21','22','23','99');
	my @validSpecialProgramCodes = ('02','03','05','06','07','08','09','10', 
									'A', 'B', 'D', 'W', 'CA', 'CZ', 'C0', 'C9');						  
	my $tempProcedures = $tempClaim->{procedures};
	my @validSpecilityCodes =  (
								'079', '003', '005', '078', '006', '035', '081', '028',
								'007', '030', '093', '046', '008', '010', '001', '002',
								'038', '009', '040', '082', '083', '044', '011', '094',
								'085', '090', '070', '039', '013', '086', '014', '036', 
								'015', '016', '018', '017', '019', '020', '012', '004', 
								'021', '022', '037', '076', '023', '025', '024', '084', 
								'026', '027', '029', '092', '032', '066', '031', '091',
								'033', '099', '034', '077',	'089', '042', '043', '068',
								'064', '062', '067', '065',	'080', '050', '041', '097',
								'048', '072', '071', '074', '075', '073', '087', '059', 
								'049', '095', '069', '055', '056', '057', '058', '045',
								'051', '052', '053', '054', '063', '060', '088', '061',
								'N04', 'N06', 'N07', 'N02', 'N03', 'N05', 'N01', '301', 
								'308', '303', '302', '307', '304', '305', '306'
								);
								 						

#*******************************************************************************************	
# VALIDATIONS FOR BA0
#*******************************************************************************************	
	# checks for Batch Sequence Numbers
	$self->checkCountOfBatches($tempClaims);
		
	#Provider Tax Id
	$self->isRequired($tempClaim->{payToProvider}->getFederalTaxId(),$tempClaim,'BA0:Provider Tax Id');
	$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{payToProvider}->getFederalTaxId(),$tempClaim,'BA0:Provider Tax Id',(0..9));
	
	
	#Provider Site Id
	$self->isRequired($tempClaim->{payToProvider}->getSiteId(),$tempClaim,'BA0:Provider Site ID');
	$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$tempClaim->{payToProvider}->getSiteId(),$tempClaim,'BA0:Provider Site ID',('A'..'Z',0..9));
	
	
	#Provider Tax Id Type
	$self->isRequired($tempClaim->{payToProvider}->getTaxTypeId(),$tempClaim,'BA0:Provider Tax Id Type');
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES , '','',$tempClaim->{payToProvider}->getTaxTypeId(),$tempClaim,'BA0:Provide Tax Id Type',('E','S','X'));
	
	# condition to put E or S or X
	
	#Provider Medicare Number
	if(($tempClaim->getFilingIndicator() =~ /['P','M']/) && ($tempClaim->getSourceOfPayment() eq 'C'))
	{
		$self->isRequired($tempClaim->{payToProvider}->getMedicareId(),$tempClaim,'BA0:Provider Medicare Number');
	}
	
	#Provider Medicaid Id
	if(($tempClaim->getFilingIndicator() =~ /['P','M']/) && ($tempClaim->getSourceOfPayment() eq 'D'))
	{
		$self->isRequired($tempClaim->{payToProvider}->getMedicaidId(),$tempClaim,'BA0:Provider Medicaid Id');
	}
	
	#Provider Champus ID
	if(($tempClaim->getFilingIndicator() =~ /['P','M']/) && ($tempClaim->getSourceOfPayment() eq 'H'))
	{
		$self->isRequired($tempClaim->{payToProvider}->getChampusId(),$tempClaim,'BA0:Provider Champus Id');
	}

	#Provider Blue Shield ID
	if(($tempClaim->getFilingIndicator() =~ /['P','M']/) && ($tempClaim->getSourceOfPayment() =~ /['G','P']/))
	{
		$self->isRequired($tempClaim->{payToProvider}->getBlueShieldId(),$tempClaim,'BA0:Provider Blue Sheild Id');
	}
	
	#Provider Organization Name
	if (($tempClaim->{payToProvider}->getTaxTypeId() =~ /['E','X']/))
	{
		$self->isRequired($tempClaim->{payToOrganization}->getName(),$tempClaim,'BA0:Provider Organization Name '.$tempClaim->{payToOrganization}->getName());
		
				
		$self->checkValidNames(ORGANIZATION_NAME,$tempClaim->{payToOrganization}->getName(),'','',$tempClaim,'BA0:Organization Name');
		$self->notRequired($tempClaim->{payToProvider}->getLastName(),$tempClaim,'BA0:Provider Last Name');
   		$self->notRequired($tempClaim->{payToProvider}->getFirstName(),$tempClaim,'BA0:Provider First Name');
   		$self->notRequired($tempClaim->{payToProvider}->getMiddleInitial(),$tempClaim,'BA0:Provider Middle Initial');
	}
	
	#Provid Last, First and Middle Initial 
	if(($tempClaim->{payToOrganization}->getName() eq "") || ($tempClaim->{payToProvider}->getTaxTypeId() eq 'S'))
	{
		$self->isRequired($tempClaim->{payToProvider}->getLastName(),$tempClaim,'BA0:Provider Last Name');
		$self->isRequired($tempClaim->{payToProvider}->getFirstName(),$tempClaim,'BA0:Provider First Name');
		$self->checkValidNames(INDIVIDUAL_NAME,$tempClaim->{payToProvider}->getLastName(),$tempClaim->{payToProvider}->getFirstName(),$tempClaim->{payToProvider}->getMiddleInitial(),$tempClaim,'BA0:Provider Name');
	}	 
	
	#Provider Speciality Code
	$self->isRequired($tempClaim->{payToProvider}->getSpecialityId(),$tempClaim,'BA0:Provider Speciality Code');
	# $self->checkValidValues(CONTAINS,'','',$tempClaim->{payToProvider}->getSpecialityId(),$tempClaim,'BA0:Provider Speciality Code',@validSpecilityCodes);
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{payToProvider}->getSpecialityId(),$tempClaim,'BA0:Provider Speciality Code',('001'..'099','301'..'308','N01'..'N07'));
	
	
	#Rendering Provider Flag
	#$self->isRequired($tempClaim->{treatment}->getOutsideLab(),$tempClaim,'BA0:Rendering Provider Flag');
	#$self->checkValidValues(CONTAINS,'','',$tempClaim->{treatment}->getOutsideLab(),$tempClaim,'BA0:Rendering Provider Flag',('Y','N'));
	
	

#*******************************************************************************************	
# VALIDATIONS FOR BA1
#*******************************************************************************************	


	#Providers Service Address
	if(($tempClaim->getSourceOfPayment eq 'F') && ($tempClaim->{treatment}->getOutsideLab() eq 'N'))
	{
	   	$self->isRequired($tempClaim->{renderingOrganization}->{address}->getAddress1(),$tempClaim,'BA1:Providers Service Address');
		$self->checkValidAddress($tempClaim->{renderingOrganization}->{address}->getAddress1(),
								$tempClaim->{renderingOrganization}->{address}->getAddress2(),
								$tempClaim->{renderingOrganization}->{address}->getCity(),
								$tempClaim->{renderingOrganization}->{address}->getState(),
								$tempClaim->{renderingOrganization}->{address}->getZipCode(), $tempClaim,'BA1:Providers Service Address');
		
	}
	
		
	$self->checkValidAddress($tempClaim->{renderingOrganization}->{address}->getAddress1(),
								$tempClaim->{renderingOrganization}->{address}->getAddress2(),
								$tempClaim->{renderingOrganization}->{address}->getCity(),
								$tempClaim->{renderingOrganization}->{address}->getState(),
								$tempClaim->{renderingOrganization}->{address}->getZipCode(), $tempClaim,'BA1:Providers Service Address');
						
	$self->checkValidTelephoneNo($tempClaim->{renderingOrganization}->{address}->getTelephoneNo(),
									 $tempClaim->{renderingOrganization}->{address}->getState(),
									 $tempClaim,
									 'BA1:Providers Service Telephone Number Must be in the format: XXXyyyZZZZ, where XXX = Area code, yyy = Exchange, ZZZZ = Station number');

	
	#Providers Pay-To Address
	$self->isRequired($tempClaim->{payToProvider}->{address}->getAddress1(),$tempClaim,'BA1:Providers Pay-To Address');
	$self->checkValidAddress($tempClaim->{payToProvider}->{address}->getAddress1(),
								 $tempClaim->{payToProvider}->{address}->getAddress2(),
								 $tempClaim->{payToProvider}->{address}->getCity(),
								 $tempClaim->{payToProvider}->{address}->getState(),
								 $tempClaim->{payToProvider}->{address}->getZipCode(), $tempClaim,'BA1:Providers Pay-To Address');
    
	
	#Providers Pay-To Telephone Number
	$self->isRequired($tempClaim->{payToProvider}->{address}->getTelephoneNo(),
								  $tempClaim,
								 'BA1:Providers Pay-To Telephone Number');
	
	
							 
	$self->checkValidTelephoneNo($tempClaim->{payToProvider}->{address}->getTelephoneNo(),
									 $tempClaim->{payToProvider}->{address}->getState(),
									 $tempClaim,
									 'BA1:Providers Pay-To Telephone Number');
		
	
}



sub validateC
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	

#*******************************************************************************************	
# VALIDATIONS FOR CAO
#*******************************************************************************************	
	
	my $refClaimCareReceiver = $tempClaim->{careReceiver};
	my $refClaimCareReceiverAddress = $refClaimCareReceiver->{address};
	my $procedures = $tempClaim->{procedures};
	my $i = $#$procedures;
	my ($years,$months,$days);

	# TPO Participation Indicator
	#*** Commented as advised by Envoy ****# 
	#***$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getTPO(),$tempClaim,'CA0:TPO PARTICIPATION INDICATOR must A or B',('A','B')) if defined $refClaimCareReceiver->getTPO(); 
	
	
	# patient control number
	$self->isRequired($refClaimCareReceiver->getAccountNo(),$tempClaim,'CA0:Patient Control Number');
	$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$refClaimCareReceiver->getAccountNo(),$tempClaim,'CA0:May only contain A – Z, 0 – 9, slash, period, comma, space, or hyphen. No other special characters are allowed.',('A'..'Z',0..9, '-', ' ', '.', '/', ',')); 
	
	
	# patient last name patient first name patient middle initial
	$self->isRequired($refClaimCareReceiver->getLastName(),$tempClaim,'CA0:Patient Last Name');
	$self->checkValidNames(INDIVIDUAL_NAME,$refClaimCareReceiver->getLastName(), $refClaimCareReceiver->getFirstName(), $refClaimCareReceiver->getMiddleInitial(), $tempClaim,'CA0:Incorect rendering patient name'); 	
	
	
	# Date of Birth
	
		
	if ($tempClaim->getSourceOfPayment() ne 'C')
	{
		$self->isRequired($refClaimCareReceiver->getDateOfBirth(), $tempClaim, 'CA0:Date of Birth');
	}
    
     	
	if ($i > -1 )
	{
		$self->checkDate(LESS, $refClaimCareReceiver->getDateOfBirth(), $tempClaim, 'CA0:Date of service from ', $tempClaim->{procedures}->[$i]->getDateOfServiceFrom());
	}
	$self->checkValidDate($refClaimCareReceiver->getDateOfBirth(),$tempClaim,'CA0:Patient Date of Birth must be CCYYMMDD'); # patient date of birth
	
		
	# Patient Sex
	$self->isRequired($refClaimCareReceiver->getSex(),$tempClaim,'CA0:Patient sex');
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getSex(),$tempClaim,'CA0:Patient sex must M or F',('M','F')) if defined $refClaimCareReceiver->getSex(); # patient sex
	
	
	# patient address 1  patient address 2 patient city  patient state patient zip code
	$self->checkValidAddress($refClaimCareReceiverAddress->getAddress1(),$refClaimCareReceiverAddress->getAddress2(), $refClaimCareReceiverAddress->getCity(), $refClaimCareReceiverAddress->getState(), $refClaimCareReceiverAddress->getZipCode(),$tempClaim,'CA0:Incorect patient address'); 
	
	
	# patient telephone number
	
	$self->checkValidTelephoneNo($refClaimCareReceiverAddress->getTelephoneNo(),$refClaimCareReceiverAddress->getState(),$tempClaim,'CA0:Incorrect TelephoneNo');
	
	# patient marital status
	if ($tempClaim->getSourceOfPayment eq 'C')
	{
		if ($self->getAge($tempClaim->{careReceiver}->getDateOfBirth(),$tempClaim->{careReceiver}->getDateOfDeath(),\$years, \$months ,\$days) eq 1)
		{
			if($years >= 65 && $years <=69)
			{
				$self->isRequired($refClaimCareReceiver->getStatus(),$tempClaim,'CA0:Patient marital status');
			}	
		}
	}
	
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getStatus(),$tempClaim,'CA0:Patient marital status must be S/M/X/D/W/U/P',('S', 'M', 'X', 'D', 'W', 'U', 'P')) if defined $refClaimCareReceiver->getStatus(); 

	
	# patient student status
	if ($self->getAge($tempClaim->{careReceiver}->getDateOfBirth(), $tempClaim->{careReceiver}->getDateOfDeath() ,\$years, \$months ,\$days) eq 1)
		{
			if(($years > 19) && ($tempClaim->getDisabilityType() eq '4'))
			{
				$self->isRequired($refClaimCareReceiver->getStudentStatus(),$tempClaim,'CA0:Patient student status');
			}	
		}
	
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$refClaimCareReceiver->getStudentStatus(),$tempClaim,'CA0:patient student status must be F/P/N',('F', 'P', 'N')) if defined $refClaimCareReceiver->getStudentStatus(); 
	
	# patient employment status
	if ($tempClaim->getSourceOfPayment eq 'C')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getEmploymentStatus(),$tempClaim,'CA0:Patient employement status ',(1..3,5));
	}
	
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getEmploymentStatus(),$tempClaim,'CA0:Patient employement status  ',(1..6,9)) if defined $refClaimCareReceiver->getEmploymentStatus(); 
	
	# patient death indicator
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$refClaimCareReceiver->getDeathIndicator(),$tempClaim,'CA0:Patient death indicator',('D','N')) if defined $refClaimCareReceiver->getDeathIndicator(); 
	
	# patient date of Death
	if ($refClaimCareReceiver->getDeathIndicator() eq 'D')
	{
		$self->isRequired($refClaimCareReceiver->getDateOfDeath(), $tempClaim, 'CA0:Date of death is required');
	}
	
	$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$refClaimCareReceiver->getDateOfDeath(),$tempClaim,'CA0:Patient date of death should be numeric',(0..9)) if defined $refClaimCareReceiver->getDateOfDeath();
	if ($i > -1)
	{
		$self->checkDate(LESS, $refClaimCareReceiver->getDateOfDeath(), $tempClaim, 'CA0:Date of death Should be less than date of service' , $procedures->[$i]->getDateOfServiceTo()) if defined $refClaimCareReceiver->getDateOfDeath();  
		$self->checkDate(LESS, $refClaimCareReceiver->getDateOfDeath(), $tempClaim, 'CA0:Date of death Should be less than date of service' , $procedures->[$i]->getDateOfServiceFrom()) if defined $refClaimCareReceiver->getDateOfDeath();
	}
	
 #	print $tempClaim->setProgramName,"\n";
	
	# Another Health Benefit Plan
	
	#print $tempClaim->{insured}->[0]->getAnotherHealthBenefitPlan(), "\n";
	
	#if ($tempClaim->getSourceOfPayment eq 'C')
	#{
		$self->isRequired($tempClaim->{insured}->[$tempClaim->getClaimType()]->getAnotherHealthBenefitPlan(), $tempClaim, 'CA0: other insurance indicator') ; # other insurance indicator
	#}
	
	if ($tempClaim->{insured}->[$tempClaim->getClaimType()]->getAnotherHealthBenefitPlan() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{insured}->[$tempClaim->getClaimType()]->getAnotherHealthBenefitPlan(),$tempClaim,'CA0:Patient death indicator',(1..3)); # other insurance indicator
	}

	
	# Legal Indicator
	$self->isRequired($refClaimCareReceiver->getlegalIndicator(),$tempClaim,'CA0:Legal Representative Indicator');
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$refClaimCareReceiver->getlegalIndicator(),$tempClaim,'CA0:Legal Representative Indicator',('Y','N')) if defined $refClaimCareReceiver->getlegalIndicator();   # LEGAL REPRESENTATIVE INDICATOR	
	


#*******************************************************************************************	
# VALIDATIONS FOR CB0
#******************************************************************************************	

	
	my $legalRepresentator = $tempClaim->{legalRepresentator};
	my $legalRepresentatorAddress = $legalRepresentator->getAddress();
	
	if ($tempClaim->{careReceiver}->getlegalIndicator() eq 'Y')
	{
		$self->checkValidNames(INDIVIDUAL_NAME,$legalRepresentator->getLastName(), $legalRepresentator->getFirstName(), $legalRepresentator->getMiddleInitial(), $tempClaim,'CA0:Incorect legal Representator name'); 	# legalRepresentator name
		$self->checkValidAddress($legalRepresentatorAddress->getAddress1(),$legalRepresentatorAddress->getAddress2(), $legalRepresentatorAddress->getCity(), $legalRepresentatorAddress->getState(), $legalRepresentatorAddress->getZipCode(),$tempClaim,'CA0:Incorect Legal Representator Address'); # Legal Representator Address
		$self->isRequired($legalRepresentator->getLastName(),$tempClaim,'CA0:Incorect legal Representator name');
		$self->isRequired($legalRepresentator->getFirstName(),$tempClaim,'CA0:Incorect legal Representator name');
		$self->isRequired($legalRepresentatorAddress->getAddress1(), $tempClaim,'CA0:Incorect Legal Representator Address');
	}

	if ($tempClaim->{careReceiver}->getDateOfDeath() ne '')
	{
		$self->checkValidNames(INDIVIDUAL_NAME,$legalRepresentator->getLastName(), $legalRepresentator->getFirstName(), $legalRepresentator->getMiddleInitial(), $tempClaim,'CA0:Incorect legal Representator name');
	}

}


sub validateD
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	

#*******************************************************************************************	
# VALIDATIONS FOR DA0
#*******************************************************************************************	


	# checks for record type
	
	# checks for Sequence number
	
	# checks for Patient control number
	

	# checks for Claim Filing Indicator

	my $payerCount = $tempClaim->getClaimType();
		
	for my $payerLoop(0..$payerCount)
	{
	
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->getFilingIndicator(),$tempClaim,'DA0:Claim Filing Indicator');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{policy}->[$payerLoop]->getFilingIndicator(),$tempClaim,'DA0:Claim Filing Indicator',('P','M','I'));

		# checks for Source of Payment
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment(),$tempClaim,'DA0:Source of Payment');
	
		if ($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() ne '')
		{
			 $self->isRequired($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment(),$tempClaim,'DA0:Source of Payment');	
			 $self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{policy}->[$payerLoop]->getSourceOfPayment(),$tempClaim,'DA0:Source of Payment',('A'..'N','P','T','V','X','Z'));
			 $self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{policy}->[$payerLoop]->getFilingIndicator(),$tempClaim,'DA0:Claim Filing Indicator',('P','M'));
		}		
	
		# checks for Insurance Type Code
	
		$self->isRequired($tempClaim->{insured}->[$payerLoop]->getTypeCode(), $tempClaim,'DA0:Insurance Type Code');
	
		if ($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'C')
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getTypeCode(),$tempClaim,'DA0:Insurance Type Code',('MP'));
		}
		else
		{
			my @tempInsCode = ('AP','GP','IP','LD','LT','OT','PP','SP');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getTypeCode(),$tempClaim,'DA0:Insurance Type Code',@tempInsCode);
		}
	
		# checks for Payer Organization ID
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->getPayerId(), $tempClaim,'DA0:Payer Organization ID');
	
		# checks for Payer Claim office Number
	
		# checks for Payer name
		$self->isRequired($tempClaim->{insured}->[$payerLoop]->getInsurancePlanOrProgramName(),$tempClaim,'DA0:Payer Name');
	
		# checks for Group Number
		if (($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() =~ m/['D','F','H','I','X']/) && ($tempClaim->{policy}->[$payerLoop]->getFilingIndicator() =~ m/['P','M']/))
		{
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number',('A'..'Z',0..9,'/',' ','-'));
			$self->checkSameCharacter(NOT_CONTAINS,'','',$tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number',('0'));
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number',('123456789','NONE','UNKNOWN','INDIVIDUAL','SELF'));
			if ($tempClaim->{insured}->[$payerLoop]->getId() ne '')
			{
				$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number',($tempClaim->{insured}->[$tempClaim->getClaimType()]->getId()));
			}
			
			
		}
		elsif($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'C')
		{
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo(),$tempClaim,'DA0:Group Number',('A'..'Z',0..9,'/',' ','-',));
		}	

		# checks for Group Name
		# not available
	
		#PPO/HMO indicator
		if(($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'H') && ($tempClaim->{insured}->[$payerLoop]->getHMOId() eq ''))
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{insured}->[$payerLoop]->getHMOIndicator(),$tempClaim,'DA0:PPO/HMO Indicator',('C','E','G','H','I','J','O','P','T','U'));
		}	
		elsif(($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'H') && ($tempClaim->{insured}->[$payerLoop]->getHMOId() ne ''))	
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getHMOIndicator(),$tempClaim,'DA0:PPO/HMO Indicator',('C','E','G','H','I','J','O','P','T','U','N','Y'));
		}
	
	
		#PPO/HMO Id
		if (not($tempClaim->{insured}->[$payerLoop]->getHMOIndicator() =~ m/['Y','N']/))
		{
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getHMOId(),$tempClaim,'DA0:PPO/HMO Id');
		}
	
		# Assignment of Benefit Indicator
	
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->getAcceptAssignment(),$tempClaim,'DA0:Assignment Benefit Indicator');
	
		if($tempClaim->{policy}->[$payerLoop]->getAcceptAssignment() ne '')
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{policy}->[$payerLoop]->getAcceptAssignment(),$tempClaim,'DA0:Assignment Benefit Indicator',('Y','N'));
		}
	
		# Patient Signature source
		if ($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() ne 'C')
		{
			$self->isRequired($tempClaim->{careReceiver}->getSignature(),$tempClaim,'DA0:Patient Signature Source');
		}
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{careReceiver}->getSignature(),$tempClaim,'DA0:Patient Signature Source',('C'));
	
		#Patient relationship to insured
		
		if (substr($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured(),0,1) eq '0')
		{
		
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',substr($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured(),1,1),$tempClaim,
							'DA0:Patient Relationship to insured',(1..19,'99'));
							
		}
		else
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured(),$tempClaim,
							'DA0:Patient Relationship to insured',(1..19,'99'));
		}
						
					
		$self->isRequired($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured(),$tempClaim,'DA0:Patient Relationship to insured');						
																																
		if($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured() eq '99')
		{
			$self->isRequired($tempClaim->getRemarks(),$tempClaim,'DA0:Remarks in XA0');	
		}	
	
		#Insured ID Number
		if($tempClaim->{policy}->[$payerLoop]->getFilingIndicator() =~ m/['P','M']/)
		{
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID');
		}	
	
			
		if($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() ne 'C')
		{
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID May only contain A-Z,0-9',('A'..'Z',0..9));
		}
		else
		{
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID May only contain A-Z,0-9,/,-',('A'..'Z',0..9,'/','-'));	
		}
	
		# Insured Last Name and First Name
		if(($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured() ne '01') && ($tempClaim->{insured}->[$payerLoop]->getRelationshipToInsured() ne '1'))
		{
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getLastName(),$tempClaim,'DA0:Insured Last Name');	
			if($tempClaim->{insured}->[$payerLoop]->getLastName() ne '')
			{
			  $self->isRequired($tempClaim->{insured}->[$payerLoop]->getFirstName(),$tempClaim,'DA0:Insured First Name');
			}
		}	
		
		#group number checking
		if ($tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo() ne "")
		{
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID May not  contain Policy Group or FECA No.',($tempClaim->{insured}->[$payerLoop]->getPolicyGroupOrFECANo()));
		}
	
	
		#payer organization id
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->getPayerId(),$tempClaim,'DA0:Payer ID is Required');
	
		if($tempClaim->{policy}->[$payerLoop]->getPayerId() ne "")
		{

			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID May not contain Payer Id',($tempClaim->{policy}->[$payerLoop]->getPayerId()));
		}
	
		# check same numbers
		$self->checkSameCharacter(NOT_CONTAINS,'','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID',('1','2','3','4','5','6','7','8','9','0'));
		#invalid values
		$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getId(),$tempClaim,'DA0:Insured ID May not Contain 1234567890,NONE,UNKNOWN,INDIVIDUAL,SELF,123456789',('1234567890','NONE','UNKNOWN','INDIVIDUAL','SELF','123456789'));
	
		#Insured Last ,First and Middle Initial
		$self->checkValidNames(INDIVIDUAL_NAME,$tempClaim->{insured}->[$payerLoop]->getLastName(),$tempClaim->{insured}->[$payerLoop]->getFirstName(),$tempClaim->{insured}->[$payerLoop]->getMiddleInitial(),$tempClaim,'DA0:');
	
		#Insured Sex
		if ($tempClaim->{insured}->[$payerLoop]->getSex() ne '')
		{

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getSex(),$tempClaim,'DA0:Insured Sex',('M','F'));
		}
	
		# Insured Employment Status code
		if($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'C')
		{
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getEmploymentStatus(),$tempClaim,'DA0:Inusred Employment Status');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getEmploymentStatus(),$tempClaim,'DA0:Inusred Employment Status',(1..9));
		}		
	
		# Supplemental Insurance Indicator
		if($tempClaim->{insured}->[$payerLoop]->getOtherInsuranceIndicator()	ne '')
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{insured}->[$payerLoop]->getOtherInsuranceIndicator(),('I','P','M','S','W','X','Y','Z'));
		}
	
		# Medicaid ID number
		if($tempClaim->{insured}->[$payerLoop]->getOtherInsuranceIndicator()	eq 'M')
		{
			$self->isRequired($tempClaim->{payToProvider}->getMedicaidId(),$tempClaim,'DA0:Medicaid ID Number');
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{payToProvider}->getMedicaidId(),$tempClaim,'DA0:Medicaid ID Number',('1234567890','NONE','UNKNOWN','INDIVIDUAL','SELF'));
			$self->checkSameCharacter(NOT_CONTAINS,'','',$tempClaim->{payToProvider}->getMedicaidId(),$tempClaim,'DA0:Medicaid ID Number',('0','9'));
		}	



#*******************************************************************************************	
# VALIDATIONS FOR DA1
#*******************************************************************************************
	# checks for Payer Address
		$self->isRequired($tempClaim->{policy}->[$payerLoop]->{address}->getAddress1(),$tempClaim,'DA1:Payer Address');
	
		$self->checkValidAddress($tempClaim->{policy}->[$payerLoop]->{address}->getAddress1(),$tempClaim->{policy}->[$payerLoop]->{address}->getAddress2(),$tempClaim->{policy}->[$payerLoop]->{address}->getCity(),$tempClaim->{policy}->[$payerLoop]->{address}->getState(),$tempClaim->{policy}->[$payerLoop]->{address}->getZipCode(),$tempClaim,'DA1:Payer Address');
	
	# checks for Champus Sponsor Branch, Status, Grade,
	# 	Insurance Card Effective and Termination Date
		if(($tempClaim->{policy}->[$payerLoop]->getSourceOfPayment() eq 'H') && ($tempClaim->{policy}->[$payerLoop]->getClaimFilingIndicator() eq 'P'))
		{
			$self->isRequired($tempClaim->{policy}->[$payerLoop]->getChampusSponsorBranch(),$tempClaim,'DA1:Champus Sponsor Branch');
			$self->isRequired($tempClaim->{policy}->[$payerLoop]->getChampusSponsorGrade(),$tempClaim,'DA1:Champus Sponsor Grade');
			$self->isRequired($tempClaim->{policy}->[$payerLoop]->getChampusSponsorStatus(),$tempClaim,'DA1:Champus Sponsor Status');
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getEffectiveDate(),$tempClaim,'DA1:Insurance Card Effective Date');
			$self->isRequired($tempClaim->{insured}->[$payerLoop]->getTerminationDate(),$tempClaim,'DA1:Insurance Card Termination Date');

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, $tempClaim->{policy}->[$payerLoop]->getChampusSponsorBranch(),$tempClaim,'DA1:Champus Sponsor Branch',(1..7));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, $tempClaim->{policy}->[$payerLoop]->getChampusSponsorGrade(),$tempClaim,'DA1:Champus Sponsor Grade',(46..54));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, $tempClaim->{policy}->[$payerLoop]->getChampusSponsorStatus(),$tempClaim,'DA1:Champus Sponsor Status',(1..3));
			$self->checkValidDate($tempClaim->{insured}->[$payerLoop]->getEffectiveDate(),$tempClaim,'DA1:Insurance Card Termination Date');
			$self->checkValidDate($tempClaim->{insured}->[$payerLoop]->getTerminationDate(),$tempClaim,'DA1:Insurance Card Termination Date');

		}
	
		# payer amount paid
		if ($tempClaim->{policy}->[$payerLoop]->getAmountPaid() ne '')
		{
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, $tempClaim->{policy}->[$payerLoop]->getAmountPaid(),$tempClaim,'DA1:Payer Amount Paid',(0..9));
		}
	

#*******************************************************************************************	
# VALIDATIONS FOR DA2
#*******************************************************************************************	


		# Patien Control Number
		$self->isRequired($tempClaim->{careReceiver}->getAccountNo(),$tempClaim,'DA2:Patient Control Number');
	
		# Insured Address1, Address2, City, State, ZipCode
		$self->checkValidAddress($tempClaim->{insured}->[$payerLoop]->{address}->getAddress1(),'',$tempClaim->{insured}->[$payerLoop]->{address}->getCity(),$tempClaim->{insured}->[$payerLoop]->{address}->getState(),$tempClaim->{insured}->[$payerLoop]->{address}->getZipCode(),$tempClaim,'DA2:Insured Address');
	
		# Insured Telephone no.
	
		$self->checkValidTelephoneNo($tempClaim->{insured}->[$payerLoop]->{address}->getTelephoneNo(),$tempClaim->{insured}->[$payerLoop]->{address}->getState(),$tempClaim,'DA2:Insured Telephone No.');
	
		# Insured Employer name
		my @validForIndividual = ('A'..'Z','a'..'z','-',' ');
		$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{insured}->[$payerLoop]->getEmployerOrSchoolName,$tempClaim,'DA2:Insured Employer Name',@validForIndividual);
	
	}	
}


sub validateE
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	my $i;
	my @validTimeCodes = ('00','01','02','03','04','05','06','07','08','09',
						  '10','11','12','13','14','15','16','17','18','19',
						  '20','21','22','23','99');
	my @validSpecialProgramCodes = ('02','03','05','06','07','08','09','10', 
									'A', 'B', 'D', 'W', 'CA', 'CZ', 'C0', 'C9');						  
	my $tempProcedures; 					
	
	

#*******************************************************************************************	
# VALIDATIONS FOR EA0
#*******************************************************************************************	

	#Patient Control Number
	$self->isRequired($tempClaim->{careReceiver}->getAccountNo(),$tempClaim,'EA0:Patient Control No.');
	
	#Employment Related Indicator
	$self->isRequired($tempClaim->getConditionRelatedToEmployment(),$tempClaim,'EA0:Employment Related Indicator');
	
	if($tempClaim->getSourceOfPayment() ne 'C')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getConditionRelatedToEmployment(),$tempClaim,'EA0:Employment Related Indicator',('Y','N'));
	}	
	else
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->getConditionRelatedToEmployment(),$tempClaim,'EA0:Employment Related Indicator',('Y','N','U'));
	}
	
	
	#Accident Indicator
	#$self->isRequired($tempClaim->getConditionRelatedToAutoAccident(),$tempClaim,'EA0:Accident Indicator');
	#$self->checkValidValues(CONTAINS,'','',$tempClaim->getConditionRelatedToAutoAccident(),$tempClaim,'EA0:Accident Indicator',('A','O','N'));
		
	#Symptom Indicator
	if($tempClaim->{careReceiver}->getSex() eq 'F')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getSymptomIndicator(),$tempClaim,'EA0:Symptom Indicator',(0,1,2));
	}	
	else
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->getSymptomIndicator(),$tempClaim,'EA0:Symptom Indicator',(0,1));	
	}
	
	
	#Accident Symptom Date
	if(($tempClaim->getSymptomIndicator() =~ /[1,2]/) || ($tempClaim->getConditionRelatedToAutoAccident() ne ''))
	{
		$self->isRequired($tempClaim->{treatment}->getDateOfIllnessInjuryPregnancy(),$tempClaim,'EA0:Accident/Symptom Date');
		$self->checkValidDate($tempClaim->{treatment}->getDateOfIllnessInjuryPregnancy(),$tempClaim,'EA0:Accident/Symptom Date');
		$self->checkDate(GREATER,$tempClaim->{treatment}->getDateOfIllnessInjuryPregnancy(),$tempClaim,'EA0:Accident/Symptom Date', $tempClaim->{careReceiver}->getDateOfBirth());
		
		$tempProcedures = $tempClaim->{procedures};
		if ($#$tempProcedures > -1)
		{
			for $i (0..$#$tempProcedures)
			{	
				 
				$self->checkDate(LESS,$tempClaim->{treatment}->getDateOfIllnessInjuryPregnancy(),$tempClaim,'EA0:Accident/Symptom Date',$tempClaim->{procedures}->[$i]->getDateOfServiceFrom());
			}
        }				
	}
	
	#External cause of Accident
	if ($tempClaim->getConditionRelatedToAutoAccident() eq 'O')
	{
		$self->isRequired($tempClaim->getSymptomExternalCause(),$tempClaim,'EA0:External cause of Accident');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$tempClaim->getSymptomExternalCause(),$tempClaim,'EA0:External cause of Accident',('E'));
		$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->getSymptomExternalCause(),$tempClaim,'EA0:External cause of Accident',('.'));
	}
	
	#Responsibility Indicator
	if($tempClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/)
	{
		$self->isRequired($tempClaim->getResponsibilityIndicator(),$tempClaim,'EA0:Responsibility Indicator');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->getResponsibilityIndicator(),$tempClaim,'EA0:Responsibility Indicator',('Y','N'));
	}
	
	
	#Accident State
	if($tempClaim->getConditionRelatedToAutoAccident() eq 'A')
	{
		$self->isRequired($tempClaim->getConditionRelatedToAutoAccidentPlace(),$tempClaim,'EA0:Accident State');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getConditionRelatedToAutoAccidentPlace(),$tempClaim,'EA0:Accident State',App::Billing::Locale::USCodes::getStates());
	}	
	
	#Accident Hour
	if($tempClaim->getConditionRelatedToAutoAccident() =~ /['A','O']/)
	{
		$self->isRequired($tempClaim->getAccidentHour(),$tempClaim,'EA0:Accident Indicator');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getAccidentHour(),$tempClaim,'EA0:Accident Indicator',@validTimeCodes);
	}	
		
	#Release of information Indicator
	$self->isRequired($tempClaim->getInformationReleaseIndicator(),$tempClaim,'EA0:Release of information Indicator');
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getInformationReleaseIndicator(),$tempClaim,'EA0:Release of information Indicator',('Y','M','N'));
	
	#Release of information Date
	
		
	if($tempClaim->getInformationReleaseIndicator() =~ /['Y','M']/)
	{
		$self->isRequired($tempClaim->getInformationReleaseDate,$tempClaim,'EA0:Release of information Date');
 	    $self->checkValidDate($tempClaim->getInformationReleaseDate(),$tempClaim,'EA0:Release of information Date');
	
	}		
	
	
	#Disability Type
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->getDisabilityType(),$tempClaim,'EA0:Disability Type',(1..4));
	
	#Disability From and To Date
	if($tempClaim->getDisabilityType() =~ /[1,2]/)
	{
		$self->isRequired($tempClaim->{treatment}->getDatePatientUnableToWorkFrom(),$tempClaim,'EA0:Disability From Date');
		$self->isRequired($tempClaim->{treatment}->getDatePatientUnableToWorkTo(),$tempClaim,'EA0:Disability To Date');	
		$self->checkDate(LESS,$tempClaim->{treatment}->getDatePatientUnableToWorkFrom(),$tempClaim,'EA0:Disability Date',$tempClaim->{treatment}->getDatePatientUnableToWorkTo());
		$self->checkDate(GREATER,$tempClaim->{treatment}->getDatePatientUnableToWorkTo(),$tempClaim,'EA0:Disability Date',$tempClaim->{treatment}->getDatePatientUnableToWorkFrom());
	}	
	
	#Referring provider id number
	if($tempClaim->{treatment}->getReferingPhysicianIDIndicator() ne '')
	{
		$self->isRequired($tempClaim->{treatment}->getIDOfReferingPhysician(),$tempClaim,'EA0:Referring Provider ID Number');
		$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$tempClaim->{treatment}->getIDOfReferingPhysician(),$tempClaim,'EA0:Referring Provider ID Number',('A'..'Z',0..9,' '));
	}	
	
	
	#Referring provider id indicator
	if($tempClaim->{treatment}->getReferingPhysicianIDIndicator() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{treatment}->getReferingPhysicianIDIndicator(),$tempClaim,'EA0:Referring Provider ID Indicator',('L','U','T'));
	}
	
	#Referring Provider Last , First and Middle Initial
	$self->checkValidNames(INDIVIDUAL_NAME,$tempClaim->{treatment}->getRefProviderLastName(),$tempClaim->{treatment}->getRefProviderFirstName(),$tempClaim->{treatment}->getRefProviderMiName(),$tempClaim,'EA0:Referring Provider Name');
	if($tempClaim->{diagnosis}->[0] ne "")
	{
		$self->isRequired($tempClaim->{treatment}->getRefProviderLastName(),$tempClaim,'EA0:Referring Provider Last Name');
		$self->isRequired($tempClaim->{treatment}->getRefProviderFirstName(),$tempClaim,'EA0:Referring Provider First Name');
	}
		
	#Referring Provider State
	if (($tempClaim->{treatment}->getRefProviderLastName() ne '') || ($tempClaim->{treatment}->getRefProviderFirstName() ne ''))
	{
		$self->isRequired($tempClaim->{treatment}->getReferingPhysicianState(),$tempClaim,'EA0:Referring Provider State');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{treatment}->getReferingPhysicianState(),$tempClaim,'EA0:Referring Provider State',App::Billing::Locale::USCodes::getStates());
	}		
	
	#Admission Date-1 and Discharge Date-1
	if (($tempClaim->{treatment}->getHospitilizationDateFrom() ne '') || ($tempClaim->{treatment}->getHospitilizationDateTo() ne ''))
	{
		$self->checkValidDate($tempClaim->{treatment}->getHospitilizationDateFrom(),$tempClaim,'EA0:Admission Date-1');
		$self->checkValidDate($tempClaim->{treatment}->getHospitilizationDateTo(),$tempClaim,'EA0:Discharge Date-1');
		$self->checkDate(LESS,$tempClaim->{treatment}->getHospitilizationDateFrom(),$tempClaim,'EA0:Admission Date-1',$tempClaim->{treatment}->getHospitilizationDateTo());
		$self->checkDate(GREATER,$tempClaim->{treatment}->getHospitilizationDateTo(),$tempClaim,'EA0:Admission Date-1',$tempClaim->{treatment}->getHospitilizationDateFrom());
	}
	
	#Laboratory Indicator
	if($tempClaim->{treatment}->getOutsideLab() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{treatment}->getOutsideLab(),$tempClaim,'EA0:Laboratory Indicator',('Y','N'));
		if($tempClaim->getSourceOfPayment() eq 'C')
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{treatment}->getOutsideLab(),$tempClaim,'EA0:Laboratory Indicator',('Y'));
		}	
	}	
	
	#Laboratory Charges
	if($tempClaim->{treatment}->getOutsideLab() eq 'Y')
	{
		$self->isRequired($tempClaim->{treatment}->getOutsideLabCharges(),$tempClaim,'EA0:Laboratory Charges');
		$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',$tempClaim->{treatment}->getOutsideLabCharges(),$tempClaim,'EA0:Laboratory Charges',(0..9));
	}
	
	
	my @tempDiagnosis = ['','','',''];
	my $diagnosis = $tempClaim->{diagnosis};
	
		
	if ($#$diagnosis > 3)
	{
		$valMgr->addWarning($self->getId() . "  " .$tempClaim->getPayerId()."  ". $tempClaim->getId(),' 1006 ', ' EA0:Diagnosis Codes ' . ' Diagnosis codes above 4 will not be reported in Claim output' ,$self->{claim})
	}
	
	if ($#$diagnosis > -1)
	{
		for $i (0..$#$diagnosis)
		{
			$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] = $diagnosis->[$i]->getDiagnosis; 
			$tempDiagnosis[$diagnosis->[$i]->getDiagnosisPosition] =~ s/\.//;
		}		
	}

	
	
	# Primary, Secondary, Tertiary and Other Diagnosis Code
	#my $diagnosis0 = $tempClaim->{diagnosis}->[0]->getDiagnosis; 
	#my $diagnosis1 = $tempClaim->{diagnosis}->[1]->getDiagnosis;
	#my $diagnosis2 = $tempClaim->{diagnosis}->[2]->getDiagnosis;
	#my $diagnosis3 = $tempClaim->{diagnosis}->[3]->getDiagnosis;   
		
	#$diagnosis0 =~ s/\.//;
	#$diagnosis1 =~ s/\.//;
	#$diagnosis2 =~ s/\.//;
	#$diagnosis3 =~ s/\.//;
	
	
	if ((not($tempClaim->{payToProvider}->getSpecialityId() =~ /['045','059','069','087','095','051','052','053','054','063','071','072','073','074','075','088','N06']/)) ||
	    ($tempClaim->getSourceOfPayment() ne 'C'))
	{
		$self->isRequired(($tempClaim->{diagnosis}->[0] eq ""  ? "" : $tempClaim->{diagnosis}->[0]->getDiagnosis()),$tempClaim,'EA0:Primary Diagnosis Code');
		$self->checkLength(LESS,'','',$tempDiagnosis[0],3,$tempClaim,'EA0:Primary Diagnosis Code');
		$self->checkLength(GREATER,'','',$tempDiagnosis[0],5,$tempClaim,'EA0:Primary Diagnosis Code');		
	
		if($tempDiagnosis[1] ne '')
		{	
			$self->checkLength(LESS,'','',$tempDiagnosis[1],3,$tempClaim,'EA0:Secondary Diagnosis Code');
			$self->checkLength(GREATER,'','',$tempDiagnosis[1],5,$tempClaim,'EA0:Secondary Diagnosis Code');		
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '1','1',$tempDiagnosis[1],$tempClaim,'EA0:Secondary Diagnosis Code',('E'));
		}	

		if($tempDiagnosis[2] ne '')
		{
			$self->checkLength(LESS,'','',$tempDiagnosis[2],3,$tempClaim,'EA0:Tertiary Diagnosis Code');
			$self->checkLength(GREATER,'','',$tempDiagnosis[2],5,$tempClaim,'EA0:Tertiary Diagnosis Code');		
		}
		
		if($tempDiagnosis[3] ne '')
		{
			$self->checkLength(LESS,'','',$tempDiagnosis[3],3,$tempClaim,'EA0:Other Diagnosis Code');
			$self->checkLength(GREATER,'','',$tempDiagnosis[3],5,$tempClaim,'EA0:Other Diagnosis Code');		
		}
		
	}

	#Provider assignment indicator
	if($tempClaim->{payToProvider}->getAssignIndicator() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{payToProvider}->getAssignIndicator(),$tempClaim,'EA0:Provider Assignment Indicator',('A','N','B','P'));
	}
	if($tempClaim->getSourceOfPayment() ne 'C')
	{
		
		$self->isRequired($tempClaim->{payToProvider}->getAssignIndicator(),$tempClaim,'EA0:Provider assignment indicator');
	}			

	#Provider Signature Indicator
	if($tempClaim->{payToProvider}->getSignatureIndicator() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaim->{payToProvider}->getSignatureIndicator(),$tempClaim,'EA0:Provider Signature Indicator',('Y','N'));
	}
	
	#Provider Signature Date
	if($tempClaim->{payToProvider}->getSignatureIndicator() ne 'Y')
	{
		$self->isRequired($tempClaim->{payToProvider}->getSignatureDate(),$tempClaim,'EA0:Provider Signature Date');
		$tempProcedures = $tempClaim->{procedures};
		if ($#$tempProcedures > -1 )
		{
			for $i (0..$#$tempProcedures)
			{
				$self->checkDate(GREATER,$tempClaim->{payToProvider}->getSignatureDate(),$tempClaim,'EA0:Provider Signature Date', $tempClaim->{procedures}->[$i]->getDateOfServiceFrom());
			}
		}
	}		
	
	#Facility Laboratory Name
	if(($tempClaim->{treatment}->getOutsideLab() eq 'Y'))
	{
		$self->isRequired($tempClaim->{renderingOrganization}->getName(),$tempClaim,'EA0:Facility Laboratory Name');
	}	
		
	#Documentation Indicator
	if($tempClaim->{payToProvider}->getDocumentationIndicator() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{payToProvider}->getDocumentationIndicator(),$tempClaim,'EA0:Documentation Indicator',(1,2,3,4,5,6,9));
	}	
	
	#Type of Documentation
	if($tempClaim->{payToProvider}->getDocumentationIndicator() =~ /[1,2,3,4,5,6]/)
	{
		$self->isRequired($tempClaim->{payToProvider}->getDocumentationType(),$tempClaim,'EA0:Type of Documentation');
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{payToProvider}->getDocumentationType(),$tempClaim,'EA0:Type of Documentation',('A'..'J','Y','Z'));
	}			
	
	#Special Program Indicator
	if($tempClaim->getSpProgramIndicator() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getSpProgramIndicator(),$tempClaim,'EA0:Special Program Indicator',@validSpecialProgramCodes);
	}		
	
	#Resubmission Code
	if($tempClaim->{treatment}->getMedicaidResubmission() ne '')
	{
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{treatment}->getMedicaidResubmission(),$tempClaim,'EA0:Resubmission Code',('01'));
	}	
	
	# Date last seen
	if($tempClaim->{careReceiver}->getLastSeenDate() ne '')
	{
		$self->checkValidDate($tempClaim->{careReceiver}->getLastSeenDate(),$tempClaim,'EA0:Date Last Seen');
	}
	
	# Date Documentation Send
	if($tempClaim->{payToProvider}->getDocumentationIndicator() =~ /[1,2,4,6]/)
	{
		$self->isRequired($tempClaim->getdateDocSen(),$tempClaim,'EA0:Date Documentaion Sent');
		$self->checkValiDate($tempClaim->getdateDocSen(),$tempClaim,'EA0:Date Documentaion Sent');
	}			


#*******************************************************************************************	
# VALIDATIONS FOR EA1
#*******************************************************************************************	

	# checks for Facility Id
	if ($tempClaim->{treatment}->getOutsideLab() eq "Y" ) 
	{
		
		$self->isRequired($tempClaim->{renderingOrganization}->getId(),$tempClaim,'EA1:Facility ID');
	}

	# checks for Facility Address
	#if ($tempClaim->{procedures}->[0] ne "")
	my $tempProc = $tempClaim->{procedures};
	
	if ($#$tempProc > -1)
	{
		
		if (($tempClaim->{treatment}->getOutsideLab() eq 'Y' ) || ($tempClaim->{procedures}->[0]->getPlaceOfService() !~ /['11','12']/))
		{
						
			$self->isRequired($tempClaim->{renderingOrganization}->{address}->getAddress1(),$tempClaim,'EA1:Facility Address');
			$self->checkValidAddress($tempClaim->{renderingOrganization}->{address}->getAddress1(),
						 		$tempClaim->{renderingOrganization}->{address}->getAddress2(),
								$tempClaim->{renderingOrganization}->{address}->getCity(),
								$tempClaim->{renderingOrganization}->{address}->getState(),
								$tempClaim->{renderingOrganization}->{address}->getZipCode(),$tempClaim,'EA1:Facility Address');
		}
	 }
	 else
	 {
 		if (($tempClaim->{treatment}->getOutsideLab() eq "Y" ))
		{
			$self->isRequired($tempClaim->{renderingOrganization}->{address}->getAddress1(),$tempClaim,'EA1:Facility Address');
			$self->checkValidAddress($tempClaim->{renderingOrganization}->{address}->getAddress1(),
						 		$tempClaim->{renderingOrganization}->{address}->getAddress2(),
								$tempClaim->{renderingOrganization}->{address}->getCity(),
								$tempClaim->{renderingOrganization}->{address}->getState(),
								$tempClaim->{renderingOrganization}->{address}->getZipCode(),$tempClaim,'EA1:Facility Address');
		}
	
	 	
	 	
	 }


#*******************************************************************************************	
# VALIDATIONS FOR EA@
#*******************************************************************************************	


# Rendering Provider Name Qualifier
 if ($tempClaim->{renderingProvider}->getFederalTaxId() ne '')
 {
 	$self->isRequired($tempClaim->getQualifier(),$tempClaim,'EA@:Rendering Provider Name Qualifier');
 }
 if ($tempClaim->getQualifier() ne '')
 {
 	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getQualifier(),$tempClaim,'EA@:Rendering Provider Name Qualifier [O,L]',('O','L'));
 }
 
# Rendering Provider Organization or Last Name

 if ($tempClaim->getQualifier() eq 'O')
 {
 	$self->isRequired($tempClaim->{renderingOrganization}->getName(),$tempClaim,'EA@:Rendering Organization Name');
 }
 if ($tempClaim->getQualifier() eq 'L')
 {
 	$self->isRequired($tempClaim->{renderingProvider}->getLastName(),$tempClaim,'EA@:Rendering Provider Last Name');
 }
 
 
 if ($tempClaim->{renderingProvider}->getLastName() ne '')
 {
 	if ($tempClaim->getQualifier eq 'O')
 	{
 		$self->checkValidNames(ORGANIZATION_NAME,$tempClaim->{renderingOrganization}->getName(),'','',$tempClaim,'EA@:Organization Name');
	}
	elsif ($tempClaim->getQualifier eq 'L')
	{
 		$self->isRequired($tempClaim->{renderingProvider}->getFirstName(),$tempClaim,'EA@:Rendering Provider First Name');
 		$self->checkValidNames(INDIVIDUAL_NAME,$tempClaim->{renderingProvider}->getLastName(),$tempClaim->{renderingProvider}->getFirstName(),$tempClaim->{renderingProvider}->getMiddleInitial(),$tempClaim,'EA@:');
 		
	}
     
 }

}



sub validateF
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	

#*******************************************************************************************	
# VALIDATIONS FOR FAO
#*******************************************************************************************	

	my $i;
	my $procedures = $tempClaim->{procedures};
	my $currentProcedure;

	# checks for record type
	
	# checks for Sequence number
	
	# checks for Patient control number
	$self->isRequired($tempClaim->{careReceiver}->getAccountNo(),$tempClaim,'FA0:Patient Control No.');	
	
	
	# checks for Service From Date and Service To Date
	if ($#$procedures > -1 )
	{
		for $i (0..$#$procedures)
		{
		
			$currentProcedure = $procedures->[$i];
		
			$self->checkDate(LESS, $currentProcedure->getDateOfServiceFrom(), $tempClaim, 'FA0:Date of service from '); #ccyy/mm/dd Service Date from
			$self->checkDate(LESS, $currentProcedure->getDateOfServiceTo(), $tempClaim, 'FA0:Date of service to'); #ccyy/mm/dd Service Date To
			$self->checkDate(GREATER, $currentProcedure->getDateOfServiceFrom(), $tempClaim, 'FA0:Date of service', $tempClaim->{careReceiver}->getDateOfBirth()); #ccyy/mm/dd Service Date from
		
			if ($currentProcedure->getDateOfServiceFrom() ne '')
			{
				$self->checkDate(LESS, $currentProcedure->getDateOfServiceFrom(), $tempClaim, 'FA0:Date of service', $currentProcedure->getDateOfServiceTo()); #ccyy/mm/dd Service Date To
			
				# Place of service
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$currentProcedure->getPlaceOfService(),$tempClaim,'FA0:Place of service',(11,12,21..26,31..34,41,42,51..55)); 
			
				# type of service
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$currentProcedure->getTypeOfService(),$tempClaim,'FA0:Type of service',('01'..'21','99')); 
			
				# HCPCS Procedure Code
				if ($currentProcedure->getCPT() ne "") 
				{
					unless($currentProcedure->getModifier()) # HCPCS Modifier 1
					{
						$valMgr->addError($self->getId()."  ".$tempClaim->getPayerId()."  ".$tempClaim->getId(), ' 1000 ', ' FA0:Modifier is required ', $tempClaim);
					}
				
					# Line Charges
					unless($currentProcedure->getCharges()) 
					{
						$valMgr->addError($self->getId()."  ".$tempClaim->getPayerId()."  ".$tempClaim->getId(), ' 1000 ', ' FA0:Line charges is required ', $tempClaim);
					}

					if (not  (($tempClaim->getSourceOfPayment() eq 'F') &&  (not ($currentProcedure->getTypeOfService() eq '07'))))
					{
						# units of service
						$self->isRequired($currentProcedure->getDaysOrUnits(), $tempClaim, 'FA0:Units or Days is required'); 
						$self->checkLength(GREATER,'','', $currentProcedure->getDaysOrUnits(), 2,$tempClaim,'FA0:Days or units are not proper procedure') ; 
						$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS, '','',$currentProcedure->getDaysOrUnits(),$tempClaim,'FA0:Days or units are not proper for procedure',('.')); 
					}

				}
			
			}
		}
		
		# checks for Diagnosis Code Pointers
		$self->isRequired(($tempClaim->{'diagnosis'}->[0] eq "" ? "" : $tempClaim->{'diagnosis'}->[0]->getDiagnosis()),$tempClaim, 'FA0:Code pointer is  required');
		
		# checks for Anesthesia Oxygen Minutes
		$self->checkLength(GREATER,'','', $tempClaim->getAnesthesiaOxygenMinutes(), 3 ,$tempClaim,' FA0:AnesthesiaOxygenMinutes must be 3 digit number ') ;
		
		# checks for Emergency Indicator
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$currentProcedure->getEmergency(),$tempClaim,'FA0:Emergency should be Y or N',('Y','N'));
		
		# checks for COB Indicator
		if ($currentProcedure->getCOB() ne '')
		{
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim,$currentProcedure->getCOB(),$tempClaim,'FA0:COB Indicator',(0..9,'A'..'Z'));			
			if ($currentProcedure->getCOB() =~ /['A'..'Z']/)
			{
				$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$tempClaim,$currentProcedure->getCOB(),$tempClaim,'FA0:COB Indicator',(0..9));
			}	
			elsif($currentProcedure->getCOB() =~ /[0..9]/)
			{
				$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS, '','',$tempClaim,$currentProcedure->getCOB(),$tempClaim,'FA0:COB Indicator',('A'..'Z'));
			}
		}
		
		# checks for Disallowed Cost Containment	
		if ($currentProcedure->getDisallowedCostContainment() > $currentProcedure->getCharges())
		{
			$valMgr->addError($self->getId()."  ".$tempClaim->getPayerId()."  ".$tempClaim->getId(), ' 1000 ', ' FA0:DisallowedCostContainment must be less than Line charges ', $tempClaim);
		}
		if ($currentProcedure->getDisallowedOther() > $currentProcedure->getCharges())
		{
			$valMgr->addError($self->getId()."  ".$tempClaim->getPayerId()."  ".$tempClaim->getId(), ' 1000 ', ' FA0:getDisallowedOther must be less than Line charges ', $tempClaim);
		}
		
		# checks for Multiple Indicator
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{careReceiver}->getMultipleIndicator(),$tempClaim,'FA0:MultipleIndicator must be P,S or space',('P','S',' ','')); 
		
		# checks for Primary Paid amount
		
		$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '','',abs($tempClaim->getAmountPaid()),$tempClaim,'FA0:Amount must be numeric',(0..9)); 	
		
		# checks for Provider Speciality
		$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{payToProvider}->getSpecialityId(),$tempClaim,'FA0:Invalid Speciality Id',('079','003','005','078','006','035','081','028','007','030','093','046','008','010','001','002','038','009','040','082','083','044','011','094','085','090','070','039','013','086','014','036','015','016','018','017','019','020','012','004','021','022','037','076','023','025','024','084','026','027','029','092','032','066','031','091','033','099','034','077','089','042','043','068','064','062','067','065','080','050','041','097','048','072','071','074','075','073','087','059','049','095','069','055','056','057','058','045','051','052','053','054','063','060','088','061','N04','N06','N07','N02','N03','N05','N01','301','308','303','302','307','304','305','306'));  # Provider Speciality	
		
		# checks for HGB/HCT Date
		$self->checkValidDate($tempClaim->getHGBHCTDate(),$tempClaim,'FA0:HGBHCTDate must be date CCYYMMDD'); # HGB/HCT Date	
		
		# checks for Serum Creatine Date
		$self->checkValidDate($tempClaim->getSerumCreatineDate(),$tempClaim,'FA0:SerumCreatineDate must be date CCYYMMDD' . $tempClaim->getSerumCreatineDate()); #	Serum Creatine Date
	
	}
	
#*******************************************************************************************	
# VALIDATIONS FOR FA@
#******************************************************************************************	
	$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$tempClaim->{renderingProvider}->getFederalTaxId(),$tempClaim, 'FA@:Rendering Provider FederalTaxId must be numeric'   ,(0..9,'')); # federal tax id
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->getQualifier(),$tempClaim,'FA@:Rendering Provider qualifier must O or L',('O','L')) if defined $tempClaim->getQualifier(); # rendering provider name qualifier
	if ($tempClaim->getQualifier() =~ /['L']/)
	{
		my $qual = 
			{
				'L' => INDIVIDUAL_NAME,
				'O' => ORGANIZATION_NAME
			};
		
		$self->checkValidNames($qual->{$tempClaim->getQualifier()},$tempClaim->{renderingProvider}->getLastName(), $tempClaim->{renderingProvider}->getFirstName(), $tempClaim->{renderingProvider}->getMiddleInitial, $tempClaim,'FA@:Incorect rendering provider name');
	}
	
	if ($tempClaim->getQualifier() =~ /['L']/)
	{
		$self->isRequired($tempClaim->{renderingProvider}->getLastName(),$tempClaim,'FA@:Rendering Provider Lastname');
	}
	if ($tempClaim->getQualifier() =~ /['O']/)
	{
		$self->isRequired($tempClaim->{renderingOrganization}->getName(),$tempClaim,'FA@:Rendering Organization Name');
	}		
	
	# $self->isRequired($tempClaim->{renderingProvider}->getNetworkId(), $tempClaim, 'FA@:Rendering provider network id'); # rendering provider network id
	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$tempClaim->{renderingProvider}->getSpecialityId(),$tempClaim,'FA@:Invalid Speciality Id',('079','003','005','078','006','035','081','028','007','030','093','046','008','010','001','002','038','009','040','082','083','044','011','094','085','090','070','039','013','086','014','036','015','016','018','017','019','020','012','004','021','022','037','076','023','025','024','084','026','027','029','092','032','066','031','091','033','099','034','077','089','042','043','068','064','062','067','065','080','050','041','097','048','072','071','074','075','073','087','059','049','095','069','055','056','057','058','045','051','052','053','054','063','060','088','061','N04','N06','N07','N02','N03','N05','N01','301','308','303','302','307','304','305','306'));# rendering provider speciality code
	$self->checkValidAddress($tempClaim->{renderingProvider}->{address}->getAddress1(),'', $tempClaim->{renderingProvider}->{address}->getCity(), $tempClaim->{renderingProvider}->{address}->getState(), $tempClaim->{renderingProvider}->{address}->getZipCode(),$tempClaim,'FA@:Incorect rendering provider address')
	
}

sub validateX
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	my $tempProcedures = $tempClaim->{procedures};
	my ($patientAmountPaid, $lineCharges);
	my $i;
	
#*******************************************************************************************	
# VALIDATIONS FOR XA0
#*******************************************************************************************	
	
	#Patient Control Number
	$self->isRequired($tempClaim->{careReceiver}->getAccountNo(),$tempClaim,'XA0:Patient Control Number');
	
	#Patient Amount Paid
	if ($#$tempProcedures > -1)
	{
		for $i(0..$#$tempProcedures)
		{
			$lineCharges += $tempClaim->{procedures}->[$i]->getExtendedCost();
		}
	
	}
	
		$self->checkValue(EQUAL,abs($tempClaim->getTotalCharge()),abs($lineCharges),$tempClaim,'XA0:Total Charges must be equal to Line charges');
		$self->checkValue(GREATER,abs($tempClaim->getAmountPaid()),abs($lineCharges),$tempClaim,'XA0:Patient Amount paid must be less than or equal to line charges');
	
	# Payer amount paid
	 $self->checkValue(GREATER,abs($tempClaim->{payer}->getAmountPaid()),abs($lineCharges),$tempClaim,'XA0:Payer Amount paid must be less than or equal to line charges');
	
	
}	



sub validateY
{
	my ($self,$valMgr,$callSeq,$vFlags,$tempClaim) = @_;
	my $tempProcedures = $tempClaim->{procedures};
	my ($patientAmountPaid, $lineCharges);
	my $i;
	
#*******************************************************************************************	
# VALIDATIONS FOR YA0
#*******************************************************************************************	
	

	
}	

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
sub validate
{
	my ($self,$valMgr,$callSeq,$vFlags,$claimList) = @_;
	my $result = 0; # no error
	my ($payerId,$claim,$i);
	
	
	my $t0 = new Benchmark;
	 
    $self->{valMgr} = $valMgr;

	
	my $claims = $claimList->getClaim();


	foreach $i (0..$#$claims)
	{
   	
   		  $self->{claim} =  $claims->[$i];
   		
#   		  my $t0 = new Benchmark;
   				
		  $self->validateA($valMgr,$callSeq,$vFlags,$claims->[$i]);
#		   my $t1 = new Benchmark;
#		   my $td = timediff($t1, $t0);
#		   print  "validateA took:",timestr($td),"\n";
		   
		   
		  # my $t0 = new Benchmark;

    		$self->validateB($valMgr,$callSeq,$vFlags,$claims->[$i],$claims);
    		
		   # my $t1 = new Benchmark;
		   # my $td = timediff($t1, $t0);
		   # print  "validateB took:",timestr($td),"\n";

		# my $t0 = new Benchmark;
			
	    	$self->validateC($valMgr,$callSeq,$vFlags,$claims->[$i]);
	    	
		# my $t1 = new Benchmark;
		# my $td = timediff($t1, $t0);
		# print  "validateC took:",timestr($td),"\n";

	   # my $t0 = new Benchmark;
	    		
	    	$self->validateD($valMgr,$callSeq,$vFlags,$claims->[$i]);
	    	
	    	
		#my $t1 = new Benchmark;
		#my $td = timediff($t1, $t0);
		#print  "validateD took:",timestr($td),"\n";
		   
		   
			#my $t0 = new Benchmark;
       		
		    $self->validateE($valMgr,$callSeq,$vFlags,$claims->[$i]);
		    
   		   #my $t1 = new Benchmark;
		   #my $td = timediff($t1, $t0);
		   #print  "validateE took:",timestr($td),"\n";

		   #my $t0 = new Benchmark; 
       		
    		$self->validateF($valMgr,$callSeq,$vFlags,$claims->[$i]);
    		
		   #my $t1 = new Benchmark;
		   #my $td = timediff($t1, $t0);
		   #print  "validateF took:",timestr($td),"\n";


    	    # $self->validateG($valMgr,$callSeq,$vFlags,$claims->[$i]);
    		# $self->validateH($valMgr,$callSeq,$vFlags,$claims->[$i]);
    		
    		#my $t0 = new Benchmark;
       		
	    	$self->validateX($valMgr,$callSeq,$vFlags,$claims->[$i]);
	    	
		   #my $t1 = new Benchmark;
		   #my $td = timediff($t1, $t0);
		   #print  "validateX took:",timestr($td),"\n";

			#$t0 = new Benchmark;
       		
	    	$self->validateY($valMgr,$callSeq,$vFlags,$claims->[$i]);
	    	
		   #$t1 = new Benchmark;
		   #$td = timediff($t1, $t0);
		   #print  "validateY took:",timestr($td),"\n";


		    # $self->validateZ($valMgr,$callSeq,$vFlags,$claims->[$i]);
		
    }
    
 
   
   #my $t1 = new Benchmark;
   #my $td = timediff($t1, $t0);
   #print  "validation NSF took:",timestr($td),"\n"; 
   
   if ($valMgr->haveErrors() == 0)
    {   
    	
    	return	0;
	}		
	else
	{
		return 1;
	}
		
}


sub correctTelephoneNo
{
	my ($self,$telephoneNo) = @_;
	$telephoneNo =~ s/\(//g;
	$telephoneNo =~ s/\)//g;
	$telephoneNo =~ s/-//g;
	$telephoneNo =~  s/ //g;

	return $telephoneNo;
	
}


sub getId()
{
	my $self = shift;

	return "NSF_OUTPUT";
}

sub getName
{
	my $self = shift;

	return "NSF Output";
}

sub getCallSequences
{
	my $self =  shift;

	return 'Output';
}


@CHANGELOG =
( 
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/12/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Change careProvider hash to PayToProvider.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_REMOVE, '12/16/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Rendering Provider Flag check in BA0 has been removed, its value will be determined '.
	'by determining values of renderingProvider and payToProvider'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/16/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'An additional check of Relationship to Insured for Insured Last, First Name of DA0 has '.
	'been added,previously it only checked for value "01" now it will also check for "1"'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/16/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'An additional valid values 1 to 9 are added in Relationship to Insured of DA0 check '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_REMOVE, '12/16/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check for Accident Indicator in EA0 has been removed it will be determined on the ' .
	'basis of values of Auto Accident and Other Accident'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_REMOVE, '12/17/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check for valid values of Diagnosis Code Pointer in FA0 has been removed ' . 
	'and to make sure its presence by checking diagnosis codes because on its ' .
	'basis Diagnosis Code Pointers will be determined'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Now claim object is being passed in DA0: Assignment Benefit Indicator whose absence ',
	'was creating problem in calling "getPayerId"'],
	
	
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'All dates are now interperated from DD-MON-YY to CCYYMMDD'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Valid values of Tax Id Type in BA0 has changed from E,S,X to 0,1 and 2 in BA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/18/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'All Codes of Gender are now interprated from 0,1,2 to U,M,F in CA0, DA0 and EA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/20/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'All Codes of Employment Status are now interprated from Employment (Full-Time),Employment (Part-Time),Self-Employed,Retired to 1,2,4,5 CA0 and DA0' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'All changes in Codes of Employment Status, Codes of Gender, Tax Id Type and use of convertDateToCCYYMMDD have been removed, now on all formatted data will be provided by Claim object' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'App::Billing::Locale::USCodes class is now introduced and has replaced @validUSCodes with App::Billing::Locale::USCodes methog getStates ' . 
	'in EA0:Accident State and EA0:Referring Provider State ' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Function name is corrected from getinformationReleaseIndicator to getInformationReleaseDate in EA0:Release of information Date' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/30/1999', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check for valid telephone number for Service Provider has been added in BA1' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/01/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Function getDiagnosisPosition is used to determine Diagnosis Code value in EA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/01/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Now Locale::USCodes is being used as a package rather then a module'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/12/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check for Rendering Provider Network Id from FA@ has been removed, now it will be checked ' . 
	'in Envoy Payer Specific Edits '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/13/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check to see no. of Procedures have been implemented in CA0, EA0, EA1 and FA0 to skip procedures '.
	'check if no procedure exist'],				
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/10/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The abs() function is used in getAmountPaid value check in validateF() FA0 section to keep it from negavtive value'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/10/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'The abs() function is used in getAmountPaid(), getTotalCharge() and linecharges value check in validateX() XA0 section to keep it from negavtive value'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/12/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'A new parmeter has been added in checkValidValues method and its value could be either CHECK_EXACT_VALUES or CHECK_CHARACTERS'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/17/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check on getTPO() method value has been removed from validateB BA0 section. Now on only spaces will be printed on its place, ' .
	'as advised by Envoy in its 16-FEB-2000 e-mail to Mr. Yousuf'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/22/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Check of Medicare has been removed from Another Insurance Indicator in validateC method to make it mandatory'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '02/22/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Checks for EA@ has been added'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '02/24/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'Checks for Payer and Patient Amount Paid has been added in XA0'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '03/24/2000', 'AUF',
	'Billing Interface/Validating NSF Output',
	'A check of diagnosis code more than 4 is added in EA0 validation it will add warning by using method addWarning method of Driver']
	
);


1;

