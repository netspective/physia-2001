##############################################################################
package App::Billing::Output::Validate::THIN;
##############################################################################

use strict;
use vars qw(@ISA %PAYERSMAP);
use App::Billing::Claim;
use App::Billing::Claims;
use App::Billing::Validator;
use Benchmark;


@ISA = qw(App::Billing::Validator);

# All constants are imported from the following file
use App::Billing::Universal;


%PAYERSMAP =
(
	'F' =>
	[
		'Commercial Claims',
		sub 
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);		

			my $billingFacility = $claim->{payToOrganization};
			my $billingProvider = $claim->{payToProvider};
			my $serviceProvider = $claim->{renderingProvider};
			my $primaryPayerId =  $claim->{policy}->[0]->getPayerId();
			my $careReceiver = $claim->{careReceiver};		#Patient
			my $procedures = $claim->{procedures};
			
			my $taxTypeId = 'S'; # $billingProvider->getTaxTypeId()
			
			#-------------------------------------
			# Validations for AA0
			#-------------------------------------

			
			#-------------------------------------
			# Validations for BA0
			#-------------------------------------
				# Provider Tax ID
				$self->isRequired($billingProvider->getTaxId(),$claim,'BA0:Provider Tax Id');
				$self->checkLength(NOT_EQUAL,'','',$billingProvider->getTaxId(),9,$claim,'BA0:Provider Tax Id');
			
				#Provider Tax Id Type
				$self->isRequired($billingProvider->getTaxTypeId(),$claim,'BA0:Provider Tax Id Type');
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES , '','',$taxTypeId,$claim,'BA0:Provide Tax Id Type',('E','S','X'));

				#Provider UPIN Number
				if (($serviceProvider->getPIN() eq '') && (grep{$_ eq $primaryPayerId} ('HCPHM','HCPMC','19572')))
				{
					$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingProvider->getPIN(),'1','1',$claim,'BA0:Provider UPIN Number',('A'..'Z'));
					$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingProvider->getPIN(),'2','6',$claim,'BA0:Provider UPIN Number',(0..9));
					$self->checkLength(NOT_EQUAL,'','',$billingProvider->getPIN(),6,$claim,'BA0:Provider UPIN Number');
				}
			
				#Medicaid Provider Number
				if (($serviceProvider->getPIN() eq '') && (grep{$_ eq $primaryPayerId} ('26374','26375','MSC33')))
				{	
					$self->isRequired($billingProvider->getMedicaidId(),$claim,'BA0:Medicaid Provider Number');
					$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingProvider->getMedicaidId(),'','',$claim,'BA0:Medicaid Provider Number',('A'..'Z',0..9));
					$self->checkLength(NOT_EQUAL,'','',$billingProvider->getMedicaidId(),9,$claim,'BA0:Medicaid Provider Number');
				}

				#Blue Shield Provider Number
				if (($serviceProvider->getPIN() eq '') || ($primaryPayerId eq '35175'))
				{
					$self->isRequired($billingProvider->getBCBSId(),'','',$claim,'BA0:Blue Shield Provider Number');
					$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingProvider->getBCBSId(),'','',$claim,'BA0:Blue Shield Provider Number',(0..9));
					$self->checkLength(NOT_EQUAL,'','',$billingProvider->getBCBSId(),6,$claim,'BA0:Blue Shield Provider Number');
				}

###############---------------NEED CLARIFICATIOM---------------------------##########################			
# No method is provided to check Commercial Provider Number in BA0
###############---------------NEED CLARIFICATIOM---------------------------##########################			
				
				#Commercial Provider Number
				#Please also fill value in Batch::Claim::Record::NSF::THIN_F
				#if ((grep{$_ eq $primaryPayerId} ('75201')) && ($serviceProvider->getPIN() eq ''))
				#{
				#	#check for Required 
				#	#check for valid numeric, 7 numerics # can use checkLength function of validator.pm
				#	#In Commercial's format is is $Space, to be filled
				#}
				#if ((grep{$_ eq $primaryPayerId} ('19572')) && ($serviceProvider->getPIN() eq ''))
				#{
				#	#check for Required 
				#	#check for valid numeric, 4 numerics
				#	#In Commercial's format is is $Space, to be filled
				#}
				#if ((grep{$_ eq $primaryPayerId} ('94999')) && ($serviceProvider->getPIN() eq ''))
				#{
				#	#check for Required 
				#	#check for valid values , 9numeric + 2alpha + 1 numberic or 7 numeric
				#	#In Commercial's format is is $Space, to be filled
				#}

###############---------------NEED CLARIFICATIOM---------------------------##########################			

# In BA0 we need to know that wether we will pick values from Organization or from Provider
# for time being we are using E in TaxTypeId, which represent Organization, so here we are deferring
# the checks for Provider and will only check validity for pay To Organization in BA0

###############---------------NEED CLARIFICATIOM---------------------------##########################			

				# Provider Organization Name
				if (grep{$_ eq $taxTypeId} ('E','X'))
				{
					#$self->isRequired($billingProvider->getName(),$claim,'BA0:Provider Organization Name');
					#$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingFacility->getName(),'1','1',$claim,'BA0:Provider Organization Name',('A'..'Z'));
					#$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingFacility->getName(),'2','33', $claim,'BA0:Provider Organization Name',('A'..'Z',0..9,'.',',','-','&'));
				}
				
				
				# Provider Last Name
				$self->isRequired(serviceProvider->getLastName(),$claim,'BA0:Provider Last Name');
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$serviceProvider->getLastName(),'1','2',$claim,'BA0:Provider Last Name',('A'..'Z','-'));
				$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,$serviceProvider->getLastName(),'1','3',$claim,'BA0:Provider Last Name',('MR ','JR '));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$serviceProvider->getLastName(),'3','',$claim,'BA0:Provider Last Name',('A'..'Z','-',' '));
				
				
				# Provider First Name
				$self->isRequired(serviceProvider->getFirstName(),$claim,'BA0:Provider First Name');
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$serviceProvider->getFirstName(),'1','2',$claim,'BA0:Provider First Name',('A'..'Z','-'));
				$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,$serviceProvider->getFirstName(),'1','3',$claim,'BA0:Provider First Name',('MR ','JR '));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$serviceProvider->getFirstName(),'3','',$claim,'BA0:Provider First Name',('A'..'Z','-',' '));

				$self->checkValidNames(INDIVIDUAL_NAME,serviceProvider->getLastName(),serviceProvider->getFirstName(),serviceProvider->getMiddleInitial(),$claim,'BA0:Provider Name');
						
				# Provider Specialty Code
				
	     		my @tempPSC = (1..46,48..95,97,99,('01'..'09'),(' 1',' 2',' 3',' 4',' 5',' 6',' 7',' 8',' 9',));

				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,$billingProvider->getSpecialityId(),'','',$claim,'BA0:Provider Specialty Code',@tempPSC);

###############---------------NEED CLARIFICATIOM---------------------------##########################			
# No method provided for state liscense number of provider BA0
###############---------------NEED CLARIFICATIOM---------------------------##########################			
				
				# State License Number
				if ($primaryPayerId eq 'TWCCP')
				{
					# Space in Format to be ask 
				}
				

			#-------------------------------------
			# Validations for BA1
			#-------------------------------------
			
						
			#Provider's Services Address 			 
			$self->checkValidAddress($serviceProvider->{address}->getAddress1(),
								     $serviceProvider->{address}->getAddress2(),
								     $serviceProvider->{address}->getCity(),
								     $serviceProvider->{address}->getState(),
								     $serviceProvider->{address}->getZipCode(), $claim,'BA1:Provider Services Address');

			# Progiver's Service Phone
			if ($billingProvider->{address}->getTelephoneNo() eq '')
			{
			    $self->isRquired($serviceProvider->{address}->getTelephoneNo(),$claim,'BA1:Provider Service Phone');
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$serviceProvider->{address}->getTelephoneNo(),'1','10',$claim,'BA1:Provider Service Phone',(0..9));
				$self->checkLength(NOT_EQUAL,'','',$serviceProvider->{address}->getTelephoneNo(),10,$claim,'BA1:Provider Service Phone');
			}
			
			
			#Provider's Pay-to Address
			$self->checkValidAddress($billingProvider->{address}->getAddress1(),
								$billingProvider->{address}->getAddress2(),
								$billingProvider->{address}->getCity(),
								$billingProvider->{address}->getState(),
								$billingProvider->{address}->getZipCode(), $claim,'BA1:Provider Pay-To Address');
			
			if ($billingProvider->{address}->getTelephoneNo() ne '')
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$billingProvider->{address}->getTelephoneNo(),'1','10',$claim,'BA1:Provider Pay-To Phone',(0..9));
				$self->checkLength(NOT_EQUAL,'','',$billingProvider->{address}->getTelephoneNo(),10,$claim,'BA1:Provider Pay-TO Phone');
			}
			

			#-------------------------------------
			# Validations for CA0
			#-------------------------------------

			my $careReceiverAddress = $careReceiver->{address};


			# Patient Control Number
			$self->isRequired($careReceiver->getAccountNo(),$claim,'CA0:Patient Control Number');
			$self->checkLength(LESS,'','',$careReceiver->getAccountNo(),1,$claim,'CA0:Patient Control Number');

			if ($primaryPayerId eq '71412')
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$careReceiver->getAccountNo(),'','',$claim,'CA0:Patient Control Number',('A'..'Z',0..9,'/','.','#','-',',',' '));
				$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,$careReceiver->getAccountNo(),'1','1',$claim,'CA0:Patient Control Number',(' '));
			}
			else
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$careReceiver->getAccountNo(),'','',$claim,'CA0:Patient Control Number',('A'..'Z',0..9));
			}
			
			# Patient Last Name
			$self->isRequired($careReceiver->getLastName(),$claim,'CA0:Patient Last Name');
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,$careReceiver->getLastName(),'1','3',$claim,'CA0:Patient Last Name',('MR ','JR '));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$careReceiver->getLastName(),'1','1',$claim,'CA0:Patient Last Name',('A'..'Z'));
			if ($primaryPayerId eq '71412')
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$careReceiver->getLastName(),'1','1',$claim,'CA0:Patient Last Name',('A'..'Z','-',' '));
			}
				
			# Patient First Name
			$self->isRequired($careReceiver->getFirstName(),$claim,'CA0:Patient First Name');
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,$careReceiver->getFirstName(),'1','3',$claim,'CA0:Patient First Name',('MR ','JR '));
			if ($primaryPayerId eq '71412')
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,$careReceiver->getFirstName(),'1','1',$claim,'CA0:Patient First Name',('A'..'Z','-',' '));
			}

							
			# Patient Date of Birth
			$self->isRequired($careReceiver->getDateOfBirth(),$claim,'CA0:Patient Date of Birth');
			$self->checkValidDate($careReceiver->getDateOfBirth(),$claim,'CA0:Patient Date of Birth must be CCYYMMDD'); 
			$self->checkDate(LESS+EQUAL, $careReceiver->getDateOfBirth(), $claim, 'CA0:Patient Date of Birth', $procedures->[0]->getDateOfServiceFrom());
		
			# Patient Sex Code 
			$self->isRequired($careReceiver->getSex(),$claim,'CA0:Patient Sex Code');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getSex(),$claim,'CA0:Patient sex must M or F',('M','F')); 
			
			# Patient address 1  patient address 2 patient city  patient state patient zip code
			$self->checkValidAddress($careReceiverAddress->getAddress1(),$careReceiverAddress->getAddress2(), $careReceiverAddress->getCity(), $careReceiverAddress->getState(), $careReceiverAddress->getZipCode(),$claim,'CA0:Patient Address'); 
			
			# Patient telephone number
			$self->checkValidTelephoneNo($careReceiverAddress->getTelephoneNo(),$careReceiverAddress->getState(),$claim,'CA0:Incorrect TelephoneNo');

			#Patient Maritial Status
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getStatus(),$claim,'CA0:Patient marital status must be S/M/D/U or Blank',('S', 'M', 'D', 'U', ' '));

			
			# Patient Student Status
			$self->isRequired($careReceiver->getStudentStatus(),$claim,'CA0:Patient Student Status');
			if ($primaryPayerId eq '71412')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getStudentStatus(),$claim,'CA0:Patient Student Status must be F/P/N or Space',('F', 'P', 'N'));
			}
			else
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getStudentStatus(),$claim,'CA0:Patient Student Status must be F/P/N or Space',('F', 'P', 'N',' '));
			}
			
			# Patient Employment Status
			if (grep{$_ eq $primaryPayerId} ('PAPER','TWCCP'))
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getEmploymentStatus(),$claim,'CA0:Patient employement status ',(1,2,4,5,6));
			}
			
			# Patient Date of Death
			if (grep{$_ eq $primaryPayerId} ('PAPER','TWCCP'))
			{
				if ($careReceiver->getDeathIndicator() eq 'D')
				{
					$self->isRequired($careReceiver->getDateOfDeath(), $claim, 'CA0:Date of death is required');
					$self->checkValidDate($careReceiver->getDateOfDeath(),$claim,'CA0:Patient Date of Death must be CCYYMMDD'); 
					$self->checkDate(GREATER + EQUAL, careReceiver->getDateOfDeath, $claim, 'CA0:Patient Date of Death must be greater then date of birth', $careReceiver->getDateOfBirth());
					$self->checkDate(GREATER + EQUAL, careReceiver->getDateOfDeath, $claim, 'CA0:Patient Date of Death must be greater then date of service to ', $procedures->[0]->getDateOfServiceTo());
				}
			}
			
			# Other Insurance Indicator
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getAnotherHealthBenefitPlan(), $claim, 'CA0:Other Insurance Indicator is required');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$claim->{insured}->[$claim->getClaimType()]->getAnotherHealthBenefitPlan(),$claim,'CA0:Other Insurance Indicator must be 1,2 or 3',(1,2,3));


			# Claim Editing Indicator
			# value fixed by "F" in batch::claim::header::thin1

			# Type of Claim Indicator
			# value fixed by $space in batch::claim::header::thin1

			# Origin Code
			# value is fixed by $space in batch::claim::header::thin1 

###############---------------NEED CLARIFICATIOM---------------------------##########################			
# Billing provider id is required for payer REG06 in CA0
###############---------------NEED CLARIFICATIOM---------------------------##########################			

			# Billing Provider Number
			# value is fixed by $space in batch::claim::header::thin1 but it is required
			# in case of payer 'REG06' must be 9 numerics.
			
				
			#-------------------------------------
			# Validations for CB0
			#-------------------------------------

			my ($years,$months,$days);
			my $LegalRepresentator = $claim->{legalRepresentator};

			#Legal Representative Data
			if ($primaryPayerId eq 'REG06')
			{
				if ($self->getAge($careReceiver->getDateOfBirth(),$procedures->[0]->getDateOfServiceFrom(),\$years, \$months ,\$days) eq 1)
				{
					if($years < 18)
					{
						#Patient Control Number
						$self->isRequired($careReceiver->getAccountNo(), $claim, 'CB0:Patient Control Number is required');

						#Resp. Person Last Name
						$self->isRequired($LegalRepresentator->getLastName(), $claim, 'CB0:Resp. Person Last Name is required');
						$self->checkValidNames(INDIVIDUAL_NAME,$LegalRepresentator->getLastName(),$LegalRepresentator->getFirstName(),$LegalRepresentator->getMiddleInitial(),$claim,'CB0:Resp. Person Name');
					
						#Resp. Person Address1
						$self->isRequired($LegalRepresentator->getAddress1(), $claim, 'CB0:Resp. Person Address1 is required');
						$self->checkValidAddress($LegalRepresentator->getAddress1(),$LegalRepresentator->getAddress2(), $LegalRepresentator->getCity(), $LegalRepresentator->getState(), $LegalRepresentator->getZipCode(),$claim,'CB0:Resp. Person Address'); 
					}
				}
			}
		
			#-------------------------------------
			# Validations for D type Records
			#-------------------------------------
			
			# As we know that there will be maximum 3 payers, so we are hard coding the loop count
			for my $payerIndex (0..2)
			{
				
				my $tempPayer = $claim->{policy}->[$payerIndex];	# get current payer 
				my $tempClaimInsured = $claim->{insured}->[$payerIndex];
				
				
				# its not necessary that there are always be 3 payers, so in order to check
				# currently available payers we check their names, if they exist then it means
				# we can validate its data
				if($claim->{policy}->[$payerIndex]->{name} ne '')
				{
				
					#-------------------------------------
					# Validations for DA0 type Records
					#-------------------------------------
					
					# Sequence Number
					
					# Patient Control Number
					$self->isRequired($careReceiver->getAccountNo(), $claim, 'DA0:Patient Control Number');
										
					# Claim Filing Indicator
					$self->isRequired($claim->getFilingIndicator(), $claim, 'DA0:Claim Filing Indicator is required');
					$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$claim->getFilingIndicator(),$claim,'DA0:Claim Filing Indicator must be P or I',('P','I'));
					
					# Source of Payment
					if ($claim->getFilingIndicator() eq 'P')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$claim->getFilingIndicator(),$claim,'DA0:Source of Payment must be F',('F','H'));
					}

					# Insurance Type Code
					if (tempPayer->getPayerId() eq 'REG06')
					{
						$self->isRequired($tempClaimInsured->getTypeCode(), $claim,'DA0:Insurance Type Code is required');
###############---------------NEED CLARIFICATIOM---------------------------##########################			
# ask from afzal what is valid NSF Code
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					}
					
					#Payor Organization Identification
					if ($claim->getFilingIndicator() eq 'P')
					{
						$self->isRequired($tempPayer->getPayerId(), $claim,'DA0:Payer Organization Identification is required');
###############---------------NEED CLARIFICATIOM---------------------------##########################			
						#Ask for valid values from afzal, where is Appendix C
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					}
				
###############---------------NEED CLARIFICATIOM---------------------------##########################			
# Please Check that position DA0-8 in THIN_D, it should be blank b/c it is not required
###############---------------NEED CLARIFICATIOM---------------------------##########################			
						
					# Payer Name
					if ($claim->getFilingIndicator() eq 'P')
					{
						$self->isRequired(tempPayer->getName(), $claim,'DA0:Payer Name is required');
						
						if (tempPayer->getPayerId() eq '71412')
						{
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '1','1',$tempPayer->getName(),$claim,'DA0:Payer Name first position must be A-Z',('A'..'Z'));
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempPayer->getName(),$claim,'DA0:Payer Name valid characters are A-Z,.,-,& and ,',('A'..'Z','.',',','-','&',' '));
						}
					}
									
				
					# Group Number
					$self->isRequired($tempClaimInsured->getPolicyGroupOrFECANo(), $claim,'DA0:Group Number is required');
					if (grep {$_ eq tempPayer->getPayerId()} ('HCPHM','HCPMC')) 
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '1','1',$tempClaimInsured->getPolicyGroupOrFECANo(),$claim,'DA0:Group Number, first position must be A,S,4',('A','S','4'));
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '2','5',$tempClaimInsured->getPolicyGroupOrFECANo(),$claim,'DA0:Group Number, position 2-5 must be numeric',(0..9));
						if (substr($tempClaimInsured->getPolicyGroupOrFECANo(),6,20) ne '') 
						{
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '6','20',$tempClaimInsured->getPolicyGroupOrFECANo(),$claim,'DA0:Group Number',('HK001'..'HK999','PS001'..'PS999','45M01'..'45M99'));
							
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#Third array is not running, what is the other way to define ... in above line
###############---------------NEED CLARIFICATIOM---------------------------##########################			
						}	
					}

###############---------------NEED CLARIFICATIOM---------------------------##########################			
#Please check THIN_D, fields (DA0-12,13,14, it is not required, but its value is set in the 
#format.
###############---------------NEED CLARIFICATIOM---------------------------##########################			
						
					# Assignment of Benefits Indicator
					$self->isRequired($tempPayer->getAcceptAssignment(), $claim,'DA0:Assignment of Benefits Indicator is required');
					$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempPayer->getAcceptAssignment(),$claim,'DA0:Assignment of Benefits Indicator must be Y or N',('Y','N'));

					# Patient Signature Source
					$self->isRequired($careReceiver->getSignature(), $claim,'DA0:Patient Signature Source is required');
					$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$careReceiver->getSignature(),$claim,'DA0:Patient Signature Source must be C,S,M,B or P',('C','S','M','B','P'));
				
					
					# Patient Relationship to Insured
					$self->isRequired($tempClaimInsured->getRelationshipToPatient(), $claim,'DA0:Patient Relationship to Insured is required');
					if (tempPayer->getPayerId() eq 'REG06')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getRelationshipToPatient(),$claim,'DA0:Patient Relationship to Insured must be from 01 to 19',('01','02','03','05','07','09','18'));
					}
					else
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getRelationshipToPatient(),$claim,'DA0:Patient Relationship to Insured must be from 01 to 19',('01'..'19'));
					}
					

					# Insured Identification Number
					$self->isRequired($tempClaimInsured->getMemberNumber(), $claim,'DA0:Insured Identification Number is required');

					if (($payerIndex eq 0) || $tempPayer->getSourceOfPayment() eq '')	#'F'
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',('A'..'Z',0..9));
						$self->checkLength(LESS,'','',$tempClaimInsured->getMemberNumber(),1,$claim,'DA0:Insured Identification Number');
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#						'Checkallcharshould not same (0,9)
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					}	
					if (tempPayer->getPayerId() eq '94999')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',('A'..'Z',0..9));
						if (length($tempClaimInsured->getMemberNumber()) ne 11)
						{
							$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),7,$claim,'DA0:Insured Identification Number');
						}
					}

					if (tempPayer->getPayerId() eq '88030')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
					}
					
					if (tempPayer->getPayerId() eq 'HCPHM')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
						$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),11,$claim,'DA0:Insured Identification Number');
					}
					
					if (grep {$_ eq tempPayer->getPayerId()} ('NTX11','TCC11')) 
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
						$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),9,$claim,'DA0:Insured Identification Number');
					}
					
					if (tempPayer->getPayerId() eq 'HCPMC')
					{
						if (grep {$_ eq substr($tempClaimInsured->getMemberNumber(),0,1)} (0..9))
						{
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '1','9',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '10','10',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',('A'..'Z'))
						}
						else
						{
							
							if (grep {$_ eq substr($tempClaimInsured->getMemberNumber(),0,1)} ('A','H'))
							{
								if (length($tempClaimInsured->getMemberNumber()) eq 7)	
								{
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '2','7',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
								else
								{
									$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),10,$claim,'DA0:Insured Identification Number');
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '2','10',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
							}

							if (grep {$_ eq substr($tempClaimInsured->getMemberNumber(),0,1)} ('CA','JA','MA','MH','PA','PD','PH','WA','WD','WH'))
							{
								if (length($tempClaimInsured->getMemberNumber()) eq 8)	
								{
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '3','8',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
								else
								{
									$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),11,$claim,'DA0:Insured Identification Number');
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '3','11',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
							}
								
							if (grep {$_ eq substr($tempClaimInsured->getMemberNumber(),0,1)} ('WCA','WCD','WCH'))
							{
								if (length($tempClaimInsured->getMemberNumber()) eq 9)	
								{
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '4','9',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
								else
								{
									$self->checkLength(NOT_EQUAL,'','',$tempClaimInsured->getMemberNumber(),12,$claim,'DA0:Insured Identification Number');
									$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '4','12',$tempClaimInsured->getMemberNumber(),$claim,'DA0:Insured Identification Number',(0..9));
								}
							}
						}
					}

							
					# Insured Last Name
					$self->isRequired($tempClaimInsured->getLastName(), $claim,'DA0:Insured Last Name is required');
					if (tempPayer->getPayerId() eq '71412')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '1','1',$tempClaimInsured->getLastName(),$claim,'DA0:Insured Last Name',('A'..'Z'));
						$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '1','3',$tempClaimInsured->getLastName(),$claim,'DA0:Insured Last Name',('JR ','MR '));
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getLastName(),$claim,'DA0:Insured Last Name',('A'..'Z','-',' '));
					}
					
					# Insured First Name
					$self->isRequired($tempClaimInsured->getFirstName(), $claim,'DA0:Insured First Name is required');
					if (tempPayer->getPayerId() eq '71412')
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '1','1',$tempClaimInsured->getFirstName(),$claim,'DA0:Insured Last Name',('A'..'Z'));
						$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES, '1','3',$tempClaimInsured->getFirstName(),$claim,'DA0:Insured Last Name',('JR ','MR '));
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getFirstName(),$claim,'DA0:Insured Last Name',('A'..'Z','-',' '));
					}

					# Insured Middle Initial
					$self->isRequired($tempClaimInsured->getMiddleInitial(), $claim,'DA0:Insured Middle Initial is required');

				
					# Insured Sex						
					$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$tempClaimInsured->getSex(),$claim,'DA0:Insured Sex',('M','F'));
					
					#Insured Date of Birth
					$self->checkValidDate(tempClaimInsured->getDateOfBirth(),$claim,'DA0:Insured Date of Birth must be CCYYMMDD'); 

	
					#-------------------------------------
					# Validations for DA1 type Records
					#-------------------------------------
			
					# Payer Address Line 1
					$self->checkValidAddress($tempPayer->{address}->getAddress1(),
										     $tempPayer->{address}->getAddress2(),
										     $tempPayer->{address}->getCity(),
										     $tempPayer->{address}->getState(),
										     $tempPayer->{address}->getZipCode(), $claim,'DA1:Payer Address');
					# Payer City
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempPayer->{address}->getCity(), $claim,'DA1:Payer City is required');
					}
					
					
					# Payer State
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempPayer->{address}->getState(), $claim,'DA1:Payer State is required');
					}
					
					# Payer Zip
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempPayer->{address}->getZipCode(), $claim,'DA1:Payer Zip is required');
					}
					

					#Payer Amount Paid
					if (tempPayer->getPayerId() eq 'REG06')
					{
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#						'what will i check in this colum, it is not required
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					}
					
					# Zero Payment Indicator					
					if (tempPayer->getPayerId() eq 'REG06')
					{
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#						'it is space in thin_d, it is also not required,
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					}
					

					#-------------------------------------
					# Validations for DA2 type Records
					#-------------------------------------

					# Insured Address Line 1
					refClaimInsuredAddress->getAddress1(),

					$self->checkValidAddress($tempClaimInsured->{address}->getAddress1(),
										     $tempClaimInsured->{address}->getAddress2(),
										     $tempClaimInsured->{address}->getCity(),
										     $tempClaimInsured->{address}->getState(),
										     $tempClaimInsured->{address}->getZipCode(), $claim,'DA2:Insured Address');


					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempClaimInsured->{address}->getAddress1(), $claim,'DA2:Insured Address1 is required');
					}
					

					#Insured City
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempClaimInsured->{address}->getCity(), $claim,'DA2:Insured City is required');
					}

					# Insured State
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempClaimInsured->{address}->getState(), $claim,'DA2:Insured State is required');
					}
					

					#Insured Zip
					if (grep {$_ eq tempPayer->getPayerId()} ('PAPER','TWCCP'))
					{
						$self->isRequired($tempClaimInsured->{address}->getZipCode(), $claim,'DA2:Insured Zip Code is required');
					}
					
					
					# Employer Identification Number
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#it is space in thin_d (da2) but here is a condition to check the valid values if it is present
###############---------------NEED CLARIFICATIOM---------------------------##########################			
					
				} # end of payer name checking
			
			} # end of payer loop
			
			
			#-------------------------------------
			# Validations for EA0 type Records
			#-------------------------------------

			my $tempClaimTreatment = $claim->{treatment};


			# Patient Control Number

			# Employment Related Indicator
			$self->isRequired($claim->getConditionRelatedToEmployment(),$claim,'EA0:Employment Related Indicator is required');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES, '','',$claim->getConditionRelatedToEmployment(),$claim,'EA0:Employment Related Indicator',('Y','N','U'));
			
# Accident Indicator
###############---------------NEED CLARIFICATIOM---------------------------##########################			
#it is already checked in thin_e, (EA0), and fixed in the variable $accidentIndicator
###############---------------NEED CLARIFICATIOM---------------------------##########################			

			# Symptom Indicator
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSymptomIndicator(),$claim,'EA0:Symptom Indicator values must be 0,1 or 2',(0..2));
			
			# Accident/Symptom Date	
###############---------------NEED CLARIFICATIOM---------------------------##########################			
# in below condition(2nd),there should be come A or O but because of i dont have any method to get
# A or O, it is set by condition in thin_e,please check
###############---------------NEED CLARIFICATIOM---------------------------##########################			
			if ((grep {$_ eq $claim->getSymptomIndicator()} ('1','2')) || ($claim->getConditionRelatedToAutoAccident() eq 'Y'))
			{
				$self->isRequired($tempClaimTreatment->getDateOfIllnessInjuryPregnancy(),$claim,'EA0:Accident/Symptom Date is required');
				$self->checkValidDate($tempClaimTreatment->getDateOfIllnessInjuryPregnancy(),$claim,'EA0:Accident/Symptom Date');
			}

			if (($claim->getSymptomIndicator() eq '0') && ($claim->getConditionRelatedToAutoAccident() eq 'N'))
			{
###############---------------NEED CLARIFICATIOM---------------------------##########################			
# how will i check blank
# here i have to check that field($tempClaimTreatment->getDateOfIllnessInjuryPregnancy())
# must be blank
###############---------------NEED CLARIFICATIOM---------------------------##########################			
			}


###############---------------NEED CLARIFICATIOM---------------------------##########################			
# external cause of accident
# it should be blank in thin_e's commercial 8th postiion
# also 9,10,11 position should be blank in thin_e, commercial
# must be blank
###############---------------NEED CLARIFICATIOM---------------------------##########################			
			
			
			# Release of Information Indicator
			if ($primaryPayerId eq 'REG06')
			{
				$self->isRequired($claim->getInformationReleaseIndicator(),$claim,'EA0:Release of Information Indicator is required');
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getInformationReleaseIndicator(),$claim,'EA0:Release of Information Indicator must be Y,M or N',('Y','M','N'));
			}
			
			# Release of Information Date
			
###############---------------NEED CLARIFICATIOM---------------------------##########################			
# same similar symptom indicator
# it should be blank 15th position (or may not blank bcz the following field 16 is the
# date of the above indicator
# in thin_e of commercail 
###############---------------NEED CLARIFICATIOM---------------------------##########################			

			
			# Same or Similar Symptom Date
			if ($tempClaimTreatment->getDateOfSameOrSimilarIllness() ne '')
			{
				$self->checkValidDate($tempClaimTreatment->getDateOfSameOrSimilarIllness(),$claim,'EA0:Same or Similar Symptom Date');
			}
			
			# Referring Provider
			
			
			

			
			
		} # end of function
	],

	'C' =>
	[
		'Medicare Claims',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);			

			# validation for DA0
				   	
		#	my $payerCount = $claim->getClaimType();
		
			for my $payerLoop(0..3)
			
			{
				# Payer Organization ID
				if ($payerLoop > 0)
				{
					if($claim->{policy}->[$payerLoop - 1]->getName() eq 'Medicare')
					{
						$self->isRequired($claim->{insured}->[0]->getMedigapNo(), $claim,'DA0:Payer Organization ID(Medigap number)');
					}
				}	
				
				
				#Insured ID Number
				if ($payerLoop > 0)
				{
					if($claim->{policy}->[$payerLoop - 1]->getName() eq 'Medicare')
					{
						$self->isRequired($claim->{insured}->[0]->getSsn(),$claim,'DA0:Insured ID(For Medigap)');					
					}
				}
				
			}	
			
		}		
	]


);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
sub validate
{
	my ($self,$valMgr,$callSeq,$vFlags,$claim) = @_;
	my $result = 0; # no error
	my $payerId;

	$self->{claim} = $claim;
    $self->{valMgr} = $valMgr;
	 
#	 my $t0 = new Benchmark;

	 $payerId = $claim->getProgramName();
    
#    if ($primaryPayerId =~ m/^VN/)
#    {
#    	$payerId = 'VN';
#    }
#    else
#    {
#    	$payerId = $primaryPayerId;
#    }
    
    
#	if(my $payerInfo = $PAYERSMAP{$payerId})
#	{
#		$result = &{$payerInfo->[PAYERINFOIDX_VALIDATEFUNC]}($self,$valMgr,$callSeq,$vFlags,$claim);
#	}

	if(my $payerInfo = $PAYERSMAP{$payerId})
	{
		$result = &{$payerInfo->[PAYERINFOIDX_VALIDATEFUNC]}($self,$valMgr,$callSeq,$vFlags,$claim);
	}

	
#	 my $t1 = new Benchmark;
#     my $td = timediff($t1, $t0);
#	print  "Envoy NSF took:",timestr($td),"\n";

	
	return	$result;
}


sub getId()
{
	my $self = shift;

	return "THIN_NSF";
}

sub getName
{
	my $self = shift;

	return "THIN";
}


sub getCallSequences
{
	my $self =  shift;

	return 'THIN';
}



1;

