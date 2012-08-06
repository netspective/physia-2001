##############################################################################
package App::Billing::Output::Validate::EnvoyPayer;
##############################################################################

use strict;
use vars qw(@ISA %PAYERSMAP);
use App::Billing::Claim;
use App::Billing::Claims;
use App::Billing::Validator;
use Benchmark;


@ISA = qw(App::Billing::Validator);

use constant PAYERINFOIDX_NAME         => 0;
use constant PAYERINFOIDX_VALIDATEFUNC => 1;
use constant GREATER => 7;
use constant LESS => 1;
use constant EQUAL => 2;
use constant NOT_EQUAL => 20;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;
use constant NOT_ALL => 3;
use constant CHECK_EXACT_VALUES => 50;
use constant CHECK_CHARACTERS => 60;


%PAYERSMAP =
(
	'95285' =>
	[
		'Admar',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @numbers = (0..9);
			my @selectiveNumbers = ('000000000','999999999','123456789');
			my @spaces = (' ');

			# check for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS, '1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@numbers);
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@selectiveNumbers);
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(' '));
		}
	],

	'35175' =>
	[
		'AdminaStarInc',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
	   		my @numbers = (0..9);
			my @selectiveNumbers = ('000000000','999999999','123456789');
	     	my @spaces = (' ');
			my @sourceOfPayment = ('H');

			# checks for Provider Blue Shield number
			$self->checkLength(LESS,'','',$claim->{payToProvider}->getBlueShieldId(),7,$claim,'Provider Blue Shield Number');
			$self->checkLength(GREATER,'','',$claim->{payToProvider}->getBlueShieldId(),12,$claim,'Provider Blue Shield Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number',('A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','7',$claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,,'8','12',$claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number',('A'..'Z',' '));
			#$self->checkValidValues(CONTAINS,'13','13',$claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number',(' '));

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment',('H'));

			# check for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@numbers);
			$self->checkValidValues(NOT_CONTAINS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@selectiveNumbers);

			# checks for Rendering Provider Tax ID
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax Id');

			# checks for Performing Provider ID
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',('A'..'Z',','));
			if( not( $claim->{renderingProvider}->getProviderId() =~ /[',']/))
			{
				$self->{valMgr}->addError($self->getId()."  ".$claim->getPayerId()."  ".$claim->getId(),' 3000 ', 'Performing Provider must contains comman (,) ',$self->{claim});
			}
		}
	],

	'60054' =>
	[
		'Aetna Life & Casualty',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			 # checks for Insured ID
			 $self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,"Insured Id");
			 $self->checkAlphanumeric(CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,"Insured Id");
		}
	],

	'52149' =>
	[
		'Alliance PPO Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),3,$claim,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),11,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));



		}
	],

	'22248' =>
	[
		'Amerihealth Mercy Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider ID Number
			$self->isRequired($claim->{payToProvider}->getId,$claim,'Provider Id');
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),13,$claim,'Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),13,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

		}
	],

	'74223' =>
	[
		'Benefit Planners',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			my @federalTaxId = ($claim->{payToProvider}->getTaxId());

			# check for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));
		}
	],

	'65358' =>
	[
		'Blue Cross/Blue Shield of Connecticut',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),13,$claim,'Provider Id');

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('G'));

		}
	],

	'00700' =>
	[
		'Blue Cross/Blue Shield of Connecticut',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),13,$claim,'Provider Id');

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('G'));

		}
	],

	'22099' =>
	[
		'Blue Cross/Blue Shield of New Jersey',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $i;
			my $tempProcedures;

			# checks for Patient Birth Date
			$self->isRequired($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for Patient Sex
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('U'));

			# checks for Patient Relation to Insured
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getRelationshipToPatient(),$claim,'Patient Relationship to Insured',('99'));

			# checks for Insured ID Number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',9);
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',12);

			if (length($claim->{insured}->[$claim->getClaimType()]->getSsn()) == 10)
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9,'N'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','10',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			}
			if (length($claim->{insured}->[$claim->getClaimType()]->getSsn()) == 11)
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','10',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',('A'..'Z'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'11','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			}
			my $val = substr($claim->{insured}->[$claim->getClaimType()]->getSsn(),0,1);

			if ((length($claim->{insured}->[$claim->getClaimType()]->getSsn()) == 12) && ($val =~ m/[0..9]/))
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','10',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'11','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',('A'..'Z'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'12','12',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			}
			if ((length($claim->{insured}->[$claim->getClaimType()]->getSsn()) == 12) && ($val =~ m/[A..Z]/))
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','3',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',('A'..'Z'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'4','12',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			}
			if (length($claim->{insured}->[$claim->getClaimType()]->getSsn()) == 9)
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9,'R'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			}

			# checks for Insured Last Name
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getLastName(),$claim,'Insured Last Name');

			# checks for Insured First Name
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getFirstName(),$claim,'Insured First Name');

			# checks for Insured Address-1
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->{address}->getAddress1(),$claim,'Insured Address-1');

			# checks for Insured City
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->{address}->getCity(),$claim,'Insured City');

			# checks Insured State
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->{address}->getState(),$claim,'Insured State');

			# checks for Insured Zip Code
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->{address}->getZipCode(),$claim,'Insured ZipCode');

			# checks for Symptom Indicator
			$self->isRequired($claim->getSymptomIndicator(),$claim,'Symptom Indicator');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSymptomIndicator(),$claim,'Symptom Indicator',('1','2'));

			# checks for Accident/Sysptom Date
			$self->isRequired($claim->{treatment}->getDateOfIllnessInjuryPregnancy(),$claim,'Accident/Symptom Date');
			$self->checkValidDate($claim->{treatment}->getDateOfIllnessInjuryPregnancy(),$claim,'Accident/Symptom Date');

			# checks for Admission Date-1
			$self->isRequired($claim->{treatment}->getHospitilizationDateFrom,$claim,'Admission Date-1');

			# checks for Discharge Date-1
			$self->isRequired($claim->{treatment}->getHospitilizationDateTo,$claim,'Discharge Date-1');

			# checks for Diagnosis Code 1
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$claim->{diagnosis}->[0]->getDiagnosis(),$claim,'Diagnosis 1',(0..9,'N'));

			# checks for Diagnosis Code 2
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{diagnosis}->[1]->getDiagnosis(),$claim,'Diagnosis 2',(0..9,'N'));

			# checks for Diagnosis Code 3
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{diagnosis}->[2]->getDiagnosis(),$claim,'Diagnosis 3',(0..9,'N'));

			# checks for Diagnosis Code 4
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{diagnosis}->[3]->getDiagnosis(),$claim,'Diagnosis 4',(0..9,'N'));

			# checks for Sequence Number
				# not necessay because it depends upon no. of procedures which are only four

			# checks for Type of Service
			$tempProcedures = $claim->{procedures};
			if ($#$tempProcedures > -1)
			{
				for $i (0..$#$tempProcedures)
				{
					$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{procedures}->[$i]->getTypeOfService(),$claim,'Type of Service',('B','F','I'));
				}
			}

		}
	],

	'47198' =>
	[
		'Blue Cross of California',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my ($i,$modifier1, $modifier2);
			my $tempProcedures;

			# checks for Patient Sex
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('U'));

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('G'));

			# checks for Patient Relation to Insured
 			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getRelationshipToPatient(),('99'));

			# checks for Insured ID Number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),8,$claim,'Insured Id');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),12,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insurd Id',(0..9,'A'..'Z'));
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'1','2',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('XE','XL'));

			if (substr($claim->{insured}->[$claim->getClaimType()]->getSsn(),0,1) eq 'R')
			{
				$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'2','2',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			}

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');

			# checks for Rendering Provider Zip Code/Service Zip Code
			$self->isRequired($claim->{renderingProvider}->getZipCode(),$claim,'Rendering Provider Zip Code');

			# checks for HCPCS procedure Code
			$tempProcedures = $claim->{procedures};

			if ($#$tempProcedures > -1)
			{
				for $i (0..$#$tempProcedures)
				{
					$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{procedures}->[$i]->getCPT(),$claim,'HCPCS Procedure Code',('99070'));
				}
			}

			# checks for HCPCS modifier
			$tempProcedures = $claim->{procedures};
			if($#$tempProcedures > -1)
			{
				for $i (0..$#$tempProcedures)
				{
					($modifier1, $modifier2) = split(/ /,$claim->{procedures}->[$i]->getModifier());
					if (($modifier1 ne '') || ($modifier2 ne ''))
					{
						$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$modifier1,$claim,'Modifier 1',('20','30'));
						$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$modifier2,$claim,'Modifier 2',('20','30'));
					}
				}
			 }



		}
	],

	'47199' =>
	[
		'Blue Cross of California: Encounters',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checsk for Patient Sex
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('U'));

			# Patient relation to Insured
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getRelationshipToPatient(),('99'));


		}
	],

	'94036' =>
	[
		'Blue Shield of California',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Blue Shield Number
			$self->isRequired($claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number');


			# checks for source of payment code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('G'));

		}
	],

	'74230' =>
	[
		'Boon Chapman Administrators',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Rendering Provider Name Qulifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

		}
	],


	'74232' =>
	[
		'Boon Chapman Administrators',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Rendering Provider Name Qulifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

		}
	],

	'62137' =>
	[
		'Buyers Healthcare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Rendering Provider Name Qulifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			if ($claim->getQualifier() eq 'L')
			{
				$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');
			}


		}
	],

	'43127' =>
	[
		'Care Partners',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider ID Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Id');
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),$claim,'Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),13,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));


		}
	],

	'37060' =>
	[
		'Caterpillar, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @federalTaxId = ($claim->{payToProvider}->getTaxId());


			# checks for Insured Id Number

			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));


		}
	],

	'34097' =>
	[
		'Central Reserve Life',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @federalTaxId = ($claim->{payToProvider}->getTaxId());

			# checks for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));

		}
	],

	'22083' =>
	[
		'Chubb Life Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID Number');

		}
	],

	'62308' =>
	[
		'CIGNA',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $procedures = $claim->{procedures};
		    my ($i,@serviceMonth);
		    my ($modifier1, $modifier2);
			my @groupValues = ('57800','70600','70601','70602','70605','70606','70607',
							   '70609','70610','70611','70612','70613','70614');
			my @numbers = (0..9);
			my @spaces = (' ');
			my @characters = ('1','2','3','4','5','6','7','8','9');
			my @modifierValues = ('P1','P2','P3','P4','P5','P6','22','23','32','51');
			my @insuredIdNumbers = ('987654321','111222333','011111111',
									'022222222','033333333','044444444',
									'055555555','066666666','077777777',
									'088888888','099999999');

			# checks for Group No.
			 $self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,1,5,$claim->{insured}->[$claim->getClaimType()]->getPolicyGroupOrFECANo,$claim,'Policy Group or FECA No',@groupValues);

			# checks for Insured ID Number
			 $self->checkValidValues(CONTAINS,CHECK_CHARACTERS,1,9,$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',@numbers);
			 #$self->checkValidValues(CONTAINS,10,17,$claim->{insured}->[$claim->getClaimType()]->getId(),$claim,'Insured Id',@spaces);
			 $self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',@characters);

			# check for Insured Last Name
			 $self->isRequired($claim->{insured}->[$claim->getClaimType()]->getLastName(),$claim,'Insured Last Name');

			# check for Insured First Name
			 $self->isRequired($claim->{insured}->[$claim->getClaimType()]->getFirstName(),$claim,'Insured First Name');

			# check for Accident State
			 $self->isRequired($claim->getConditionRelatedToAutoAccidentPlace,$claim,'Accident Place');

			# checks for Rendering Provider Tax ID
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax Id',(0..9));

			# checks for Rendering Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');
			if (uc($claim->{treatment}->getOutsideLab()) eq 'Y')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getQualifier(),$claim,'Rendering Provider Name Qualifier',('O'));
			}

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');


			# Rendering Provider/Service Address,City,State,ZipCode
			$self->isRequired($claim->{renderingProvider}->{address}->getAddress1(),$claim,'Rendering Provider Address1');
			$self->isRequired($claim->{renderingProvider}->{address}->getCity(),$claim,'Rendering Provider City');
			$self->isRequired($claim->{renderingProvider}->{address}->getState(),$claim,'Rendering Provider State');
			$self->isRequired($claim->{renderingProvider}->{address}->getZipCode(),$claim,'Rendering Provider ZipCode');


			# checks for Service From Date
			if($#$procedures > -1)
			{
				 for $i (0..$#$procedures)
				 {
				 	$self->checkDate(LESS,$claim->{procedures}->[$i]->getDateOfServiceFrom(),$claim,'Service Date From');
				 }

			# checks for Service To Date
				for $i (0..$#$procedures)
				 {
				 	@serviceMonth = (substr($claim->{procedures}->[$i]->getDateOfServiceFrom(),4,2));
				 	$self->checkDate(LESS,$claim->{procedures}->[$i]->getDateOfServiceTo(),$claim,'Service Date To');
				 	$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,5,6,$claim->{procedures}->[$i]->getDateOfServiceTo(), $claim, 'Service Date To', @serviceMonth);
				 }

			# checks for HCPCS Procedure Code
				for $i (0..$#$procedures)
				{
					($modifier1, $modifier2) = split(/ /,$claim->{procedures}->[$i]->getModifier());
					if (($modifier1 ne '') || ($modifier2 ne ''))
					{
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$modifier1,$claim,'Modifier 1',@modifierValues);
						$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$modifier2,$claim,'Modifier 2',@modifierValues);
					}
				}
  			}
			# checks for Anesthesia/Oxygen Minutes
			$self->isRequired($claim->getAnesthesiaOxygenMinutes(),$claim,'Anesthesia/Oxygen Minutes');

		}

	],

	'34172' =>
	[
		'Cleveland Health Network',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');
		}
	],

	'36094' =>
	[
		'CNA Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));


		}
	],

	'06105' =>
	[
		'Connecticare, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));

			# checks for Refering provider network id
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getNetworkId(),5,$claim,'Referring Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{payToProvider}->getNetworkId(),7,$claim,'Referring Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getNetworkId(),$claim,'Referring Provider Network Id',(0..9,'A'..'Z'));

			# checks for Consult/Surgery Date
				# not available

			# checks for Rendering Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');


		}
	],

	'04284' =>
	[
		'Consolidated Group Claims',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Group Number
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('A','B','G','H','K','N','Z'));
			if (substr($claim->{insured}->getPolicyGroupOrFECANo(),0,1) eq ['A','B','G','H','K'])
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','7',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9));
			}
			if (substr($claim->{insured}->getPolicyGroupOrFECANo(),0,1) eq ('N'))
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'2','2',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..3));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'3','6',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'7','7',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('A'..'Z'));
			}
			if (substr($claim->{insured}->getPolicyGroupOrFECANo(),0,1) eq ('Z'))
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'2','2',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..4,9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'3','6',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'7','7',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('A'..'Z'));
			}
		}
	],

	'48153' =>
	[
		'Coresource Repricing(TPO)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');
		}
	],

	'31111' =>
	[
		'Daymed',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider ID
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Id');
			$self->checkLength(LESS,$claim->{payToProvider}->getId(),6,$claim,'Provider Id');
			$self->checkLength(GREATER,$claim->{payToProvider}->getId(),7,$claim,'Provider Id');
			if (length($claim->{payToProvider}->getId()) == 6)
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','6',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));
			}
			if (length($claim->{payToProvider}->getId()) == 7)
			{
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','4',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'5','5',$claim->{payToProvider}->getId(),$claim,'Provider Id',('.'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'6','7',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));
			}

			# checks for Insured ID
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number');

			my @federalTaxId = ($claim->{payToProvider}->getTaxId());

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));

			### checking for only Social Security Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',(0..9));

		}
	],

	'73288' =>
	[
		'Employers Health',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

			# checks for Rendering Qualification Degree
			$self->isRequired($claim->{renderingProvider}->getQualification(),$claim,'Rendering Qualification Degree');


		}
	],

	'39026' =>
	[
		'Employers Insurance of Wausau',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

			# Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,' '));


		}
	],

	'62944' =>
	[
		'Equicor',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @groupNumbers = ('57800','70600','70601','70602',
								'70605','70606','70607','70609',
								'70610','70611','70612','70613','70614');
			my @insuredIdNumbers = ('987654321','111222333','011111111',
									'022222222','033333333','044444444',
									'055555555','066666666','077777777',
									'088888888','099999999');
			my @modifierValues = ('P1','P2','P3','P4','P5','P6','22','23','32','51');
			my ($i,$modifier1, $modifier2);
			my $procedures = $claim->{procedures};

			# checks for Group Number
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'1','5',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',@groupNumbers);

			# checks for Insured ID Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',@insuredIdNumbers);
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));

			# checks for Insured Last Name
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getLastName(),$claim,'Insured Last Name');
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getFirstName(),$claim,'Insured First Name');
			if ($claim->getConditionRelatedToOtherAccident() eq 'A')
			{
				$self->isRequired($claim->getConditionRelatedToAutoAccident(),$claim,'Accident State');
			}

			# checks for Rendering Provider Tax Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax Id');
			if ($claim->{treatment}->getOutsideLab() eq 'Y')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax Id',('O'));
			}


			# checks for Rendering Provider Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');
				if (uc($claim->{treatment}->getOutsideLab()) eq 'Y')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getQualifier(),$claim,'Rendering Provider Name Qualifier',('O'));
			}

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

			# Rendering Provider Address1
			$self->isRequired($claim->{renderingProvider}->{address}->getAddress1(),$claim,'Rendering Provider Address 1');

			# Rendering Provider City
			$self->isRequired($claim->{renderingProvider}->{address}->getCity(),$claim,'Rendering Provider City');

			# Rendering Provider State
			$self->isRequired($claim->{renderingProvider}->{address}->getState(),$claim,'Rendering Provider State');

			# Rendering Provider State
			$self->isRequired($claim->{renderingProvider}->{address}->getZipCode(),$claim,'Rendering Provider ZipCode');

			# checks for Service From Date
			if ($#$procedures > -1)
			{
				for $i (0..$#$procedures)
				{
					$self->checkDate(GREATER,$claim->{procedures}->[$i]->getDateOfServiceFrom(),$claim,'Service Date From');
				}
				# checks for Service To Date
				for $i (0..$#$procedures)
				{
					$self->checkDate(GREATER,$claim->{procedures}->[$i]->getDateOfServiceTo(),$claim,'Service Date To');
				}

				# checks for HCPCS Procedure Code
					# not necessary to implement

				# checks for HCPCS Modifiers
				for $i (0..$#$procedures)
				{
					if ($claim->{procedures}->[$i]->getTypeOfService == 7)
					{
						($modifier1, $modifier2) = split(/ /,$claim->{procedures}->[$i]->getModifier());
						if (($modifier1 ne '') || ($modifier2 ne ''))
						{
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$modifier1,$claim,'Modifier 1',@modifierValues);
							$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$modifier2,$claim,'Modifier 2',@modifierValues);
						}
					}
				}
			}

			# checks for Anesthesia/Oxygen Minutes
			$self->isRequired($claim->getAnesthesiaOxygenMinutes(),$claim,'Anesthesia/Oxygen Minutes');

		}
	],

	'69140' =>
	[
		'First Allmerica',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID',(0..9));

			my @federalTaxId = ($claim->{payToProvider}->getTaxId());

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));


		}
	],

	'59276' =>
	[
		'Florida 1st',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID',(0..9));

		}
	],

	'39065' =>
	[
		'Fortis/Time Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID',(' '));
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));

			# checks for Rendering Provider Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');



		}
	],

	'25169' =>
	[
		'Gateway Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Id');
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),7,$claim,'Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Id',(0..9,'A'..'Z'));

			# checks for Insured ID Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),6,$claim,'Insured ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID',(0..9));
		}
	],

	'63665' =>
	[
		'General American Life Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for HCPCS Procedure Code
				# no need to implement

		}
	],

	'80705' =>
	[
		'Great-West Life Assurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# check for Group Number
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('PSI'));

		}
	],

	'91051' =>
	[
		'Group Health Cooperative of Puget Sound (WA)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# check for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Id');

			# checks for Insured Id Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));

		}
	],

	'13551' =>
	[
		'Group Health, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),7,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));


		}
	],

	'64246' =>
	[
		'Guardian Life Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
		}
	],


	'75201' =>
	[
		'Harris Methodist Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));

			# checks for Rendering Provider Network Id
			$self->isRquired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),7,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));

		}
	],

	'04245' =>
	[
		'Harvard Community',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('0'));
			$self->checkAlpha(NOT_ALL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,"Insured Id");
			$self->checkAlphanumeric(CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,"Insured Id");
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),7,$claim,"Insured Id");
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),14,$claim,"Insured Id");
		}
	],

	'04271' =>
	[
		'Harvard Pilgrim',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured ID Number
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('0'));
			$self->checkAlpha(NOT_ALL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,"Insured Id");
			$self->checkAlphanumeric(CONTAINS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,"Insured Id");
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),7,$claim,"Insured Id");
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),14,$claim,"Insured Id");

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkAlpha(NOT_ALL,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkSameCharacter(NOT_CONTAINS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',('0'));

		}
	],

	'38224' =>
	[
		'Health Alliance Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->checkLength(LESS,'','',$claim->{payToProvider}->getId(),6,$claim,'Provider Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Number',(0..9,'A'..'Z'));
		}

	],

	'31081' =>
	[
		'Health First',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);


			# checks for Patient Sex
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('M','F'));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
		}
	],

	'55247' =>
	[
		'Health Insurance Plan of Greater New York',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),6,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),12,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','6',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'7','12',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z',' '));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'13','15',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(' '));

		}
	],

	'95568' =>
	[
		'Health Net - California (Ecounters)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# check for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');
			$self->checkLength(LESS,'','',$claim->{payToProvider}->getId(),3,$claim,'Provider Number');
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'1','3',$claim->{payToProvider}->getId(),$claim,'Provider Number',(' '));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Number',(0..9,'A'..'Z'));
		}
	],


	'94254' =>
	[
		'Health Plan of The Redwoods',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my ($i,@codeValidValues);

			for $i (1..39)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (2350..2377)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (4995..4999)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (5730..5752)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (8881..8888)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (90890..90898)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (99062..99065)
			{
				push(@codeValidValues,numToStr(5,0,$i));
			}
			for $i (0..9999)
			{
				push(@codeValidValues,'X'.numToStr(4,0,$i));
			}

			push(@codeValidValues,'05815');
			push(@codeValidValues,'09947');
			push(@codeValidValues,'90089');
			push(@codeValidValues,'97789');
			push(@codeValidValues,'99079');

			# checks for HCPCS Procedure Code
			if ($i > -1)
			{
				$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{procedures}->[$i]->getCPT(),$claim,'HCPCS Procedure Code',@codeValidValues);
			}
		}
	],


	'59140' =>
	[
		'Health Plan Services',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

			# Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');


		}
	],

	'90001' =>
	[
		'Healthcare Interchange, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $procedures = $claim->{procedures};

			# checks for Provider Blue Shield Number
			$self->isRequired($claim->{payToProvider}->getBlueShieldId(),$claim,'Provider Blue Shield Number');


			# checks for Other insurance indicator
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getAnotherHealthBenefitPlan(),$claim,'Other Insurance Indicator');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),6,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));

			# checks for Sequence Number
			 	# not necessary

			# checks for Service To Date
			my $i;
			if($#$procedures > -1)
			{
				for $i (0..$#$procedures)
				{
					if ($claim->{procedures}->[$i]->getDateOfServiceTo() ne '')
					{
						$self->isRequired($claim->{procedures}->[$i]->getDateOfServiceTo(),$claim,'Service Date From');
					}
				}
			}
		}
	],

	'71074' =>
	[
		'Healthsource Arkansas',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),5,$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),11,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

		}
	],

	'71075' =>
	[
		'Healthsource Arkansas (Medicare HMO)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');

		}
	],

	'58210' =>
	[
		'Healthsource Georgia',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],


	'35167' =>
	[
		'Healthsource Indiana',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');

		}
	],

	'61127' =>
	[
		'Healthsource Kentucky',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'02039' =>
	[
		'Healthsource New Hampshire(Medicare)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'16126' =>
	[
		'Healthsource New York',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'56147' =>
	[
		'Healthsource North Carolina',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'75255' =>
	[
		'Healthsource North Texas',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'31141' =>
	[
		'Healthsource Ohio',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),5,$claim,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),6,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','5',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'6','6',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',('A'..'Z'));


		}
	],

	'06119' =>
	[
		'Healthsource North Carolina',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'62129' =>
	[
		'Healthsource Tennessee',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'22336' =>
	[
		'Horizon Mercy',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),13,$claim,'Provider Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Provider Number',(0..9,'A'..'Z'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),13,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

		}
	],

	'61101' =>
	[
		'Humana Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for HCPCS procedure code
				# no need to check

			# checks for Performing Provider Id
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');


		}
	],

	'61125' =>
	[
		'Humana Military',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
		}
	],

	'31112' =>
	[
		'Inhealth, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# Rendering Provider Organization/Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'14168' =>
	[
		'Jardine Group Services',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Patient Date of Birth
			$self->isRequired($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date');
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date');
		}
	],

	'41099' =>
	[
		'John Alden Life Ins. Co.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));

		}
	],

	'95378' =>
	[
		'John Deere Healthcare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $procedures = $claim->{procedures};


			# checks for Insured Id number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),8,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','7',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'8','8',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('A'..'Z',0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),6,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

			# checks for Refering Provider ID Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Referring Provider Id');
			$self->checkLength(GREATER,'','',$claim->{payToProvider}->getId(),6,$claim,'Referring Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Referring Provider Id',(0..9,'A'..'Z'));


			# checks for Refering Provider ID Indicator
			$self->isRequired($claim->{payToProvider}->getIdIndicator(),$claim,'Rendering Provider ID Indicator');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getIdIndicator(),$claim,'Rendering Provider ID Indicator',('U'));

			# checks for Refering Provider Last Name
			my $i;
			if($#$procedures > -1)
			{
				for $i (0..$#$procedures)
				{
					if (($claim->{procedures}->[$i]->getPlaceOfService() != 11) &&
						 (($claim->{procedures}->[$i]->getTypeOfService() == 4)
												|| ($claim->{procedures}->[$i]->getTypeOfService() == 5)))
					{
						$self->isRequired($claim->{treatment}->getRefProviderLastName(),$claim,'Referring Provider ID Indicator');
						$self->isRequired($claim->{treatment}->getRefProviderFirstName(),$claim,'Referring Provider ID Indicator');
					}
				}
			}

		}
	],

	'37124' =>
	[
		'Kepple & Company',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @validGroupNumbers = ('10030','10040','10080','10110','10140',
									 '10200','10230','10250','10270','10280',
									 '10300','10300','10301','10302','10301',
									 '10330','10350','10600','30001','50001',
 									 '70001','80010','80021','90001');


			# checks for Group Number
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',@validGroupNumbers);

		}
	],

	'23284' =>
	[
		'Keystone Mercy Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider ID Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Referring Provider Id');
			$self->checkLength(EQUAL,$claim->{payToProvider}->getId(),13,$claim,'Referring Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Referring Provider Id',(0..9,'A'..'Z'));

			# checks for Rendering Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),13,$claim,'Rendering Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));


		}
	],

	'02030' =>
	[
		'Mathew Thornton Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('9'));


			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),2,$claim,'Rendering Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),7,$claim,'Rendering Network Id');


		}
	],


	'56162' =>
	[
		'Medcost, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');

		}
	],

	'87726' =>
	[
		'Medicare Part B: Travelers Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('C'));

		}
	],

	'65978' =>
	[
		'Metlife',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),5,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));

		}
	],

	'70491' =>
	[
		'Mutual Group (The)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');



		}
	],

	'71412' =>
	[
		'Mutual of Omaha',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id number
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'1','6',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('999999'));

		}
	],

	'66893' =>
	[
		'New England (The)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Group Number
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('PSI'));


		}
	],

	'66915' =>
	[
		'New York Life Insurance Co.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Group Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9,'A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','4',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'5','6',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9,' '));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'7','20',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(' '));

		}
	],


	'E3510' =>
	[
		'North American Medical Management',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Patient Sex
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('M','F'));

			# checks for Insured Id
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id');


		}
	],


	'91135' =>
	[
		'NYLCare Ehix Northwest',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66917' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66918' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66919' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66920' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66921' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66922' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66923' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66924' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66925' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'66926' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'91166' =>
	[
		'NYLCare Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getProviderId(),9,$claim,'Performing Provider ID');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID',(0..9,' '));

			# checks for Rendering Provider Name Qualifier
			$self->isRequired($claim->getQualifier(),$claim,'Rendering Provider Name Qualifier');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Organization Last Name');

		}
	],

	'95356' =>
	[
		'Oaktree Health Plan of Pennsylvania, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),9,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));



		}
	],

	'52151' =>
	[
		'Optimum Choice Inc. of Pennsylvania',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),3,$claim,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),11,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

		}
	],

	'52152' =>
	[
		'Optimum Choice of Carolinas Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),3,$claim,'Rendering Provider Network Id');
			$self->checkLength(GREATER,'','',$claim->{renderingProvider}->getNetworkId(),11,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));
		}
	],


	'06111' =>
	[
		'Oxford Health Plans',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),8,$claim,'Insured Id');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id');

			# checks for Rendering Provider Tax Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Rendering Provider Tax id');

			# checks for Rendering Provider Last Name
			$self->isRequired($claim->{renderingProvider}->getLastName(),$claim,'Rendering Provider Last Name');

			# checks for Rendering Provider First Name
			$self->isRequired($claim->{renderingProvider}->getFirstName(),$claim,'Rendering Provider First Name');

		}
	],

	'95959' =>
	[
		'Pacificare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id Number',(0..9));

		}
	],

	'61129' =>
	[
		'Passport Health Plan',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Id Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Referring Provider Id');
			$self->checkLength(EQUAL,$claim->{payToProvider}->getId(),13,$claim,'Referring Provider Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{payToProvider}->getId(),$claim,'Referring Provider Id',(0..9,'A'..'Z'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');

		}
	],

	'65018' =>
	[
		'PCA Health Plans of Florida',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),10,$claim,'Insured Id Number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','10',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'11','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id Number',(0..9,' '));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'12','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id Number',(' '));

			# checks for Rendering Provider Network Id
			my @medicareProviderId = $claim->{renderingProvider}->getMedicareId();

			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',@medicareProviderId);


			# checks for Diagnosis Code Pointer 1
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$self->getDiagnosisPtr($claim->{diagnosis}->[0]->getDiagnosis()),$claim,'Diagnosis Code Pointer 1',('0','5'));

			# checks for Performing Provider id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'62153' =>
	[
		'Phoenix Healthcare of Tennessee',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Patient Status
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getState(),$claim,'Patient State',('TN','MS'));

			# checks for Insured State
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getState(),$claim,'Patient State',('TN','MS'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');


		}
	],

	'67814' =>
	[
		'Phoenix Home Life',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Group Number
			$self->checkLength(LESS,'','',$claim->{insured}->getPolicyGroupOrFECANo(),6,$claim,'Group Number');
			$self->checkLength(GREATER,'','',$claim->{insured}->getPolicyGroupOrFECANo(),9,$claim,'Group Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',(0..9));

			# checks for Insured ID number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));


		}
	],

	'06108' =>
	[
		'Physicians Health Services',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured ID number
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number');
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',	$claim->{renderingProvider}->getNetworkId(),6,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9,'A'..'Z'));

		}
	],


	'16105' =>
	[
		'Prepaid Health Plans',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');


			# checks for Insured ID Number
			my @insuredValue = $claim->payerId();

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','5',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',@insuredValue);


		}
	],


	'68241' =>
	[
		'Prudential (The)',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my @values = ('AARP','A.A.R.P.','A A R P');

			# check for Payer Name
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payer}->getName(),$claim,'Program Name', @values);

			# check for Group Name
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getInsurancePlanOrProgramName(),$claim,'Program Name', @values);
		}
	],

	'22300' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'22310' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'22320' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],


	'22330' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'22340' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'22350' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'22360' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],

	'84117' =>
	[
		'Qual-Med',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for patient birth date
			$self->checkValidDate($claim->{careReceiver}->getDateOfBirth(),$claim,'Patient Date of Birth');

			# checks for  Insured Id number
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(NOT_CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));

			# checks for Performing Provider Id
			$self->isRequired($claim->{renderingProvider}->getProviderId(),$claim,'Performing Provider ID');

		}
	],


	'13310' =>
	[
		'Seabury & Smith',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(' '));


		}
	],

	'38253' =>
	[
		'Selectcare, Inc.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number');
			$self->checkLength(LESS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),9,$claim,'Insured Id number');
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(LESS,'','',$claim->{renderingProvider}->getNetworkId(),2,$claim,'Rendering Provider Network Id');

		}
	],

	'31053' =>
	[
		'State Farm Insurance',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->isRequired($claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number');
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'10','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',('03','04'));

		}
	],

	'87726' =>
	[
		'Travelers Insurance Co.',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# Insured ID Number
			if ($claim->getSourceOfPayment() eq 'F')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
				$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('000000000','999999999','123456789'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));
			}

			# HCPCS Procedure Code
				# no need to check
		}
	],

	'23222' =>
	[
		'U.S. Healthcare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $i;
			my $procedures = $claim->{procedures};

			# checks for Accident/Symptom Date
			$self->isRquired($claim->{treatment}->getDateOfIllnessInjuryPregnancy(),$claim,'Accident/Symptom Date');

			# checks for Admission Date-1
			$self->isRequired($claim->{treatment}->getHospitilizationDateFrom,$claim,'Admission Date-1');

			# checks for Rendering Provider Network ID
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');

			# checks for Place of Service
			if($#$procedures > -1)
			{
				for $i (0..$#$procedures)
				{
					$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{procedures}->[$i]->getPlaceOfService(),$claim,'Place of Service',('26'));
				}


				# checks for Line Charges


				# checks for Total Claim Charges

				# checks for Remarks
				for $i(0..$#$procedures)
				{
					if ($claim->{procedures}->[$i]->getCPT() =~ m/[99070,99071,92393]/)
					{
						$self->isRequired($claim->getRemarks(),$claim,'Remarks');
					}
				}

			}

			# checks for Batch Total Charges

			# checks for File Total Charges

		}
	],

	'52180' =>
	[
		'UMWA Health & Retirement Funds',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for insured id Number
			$self->checkLength(EQUAL,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),11,$claim,'Insured Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->getSsn,$claim,'Insured id',(0..9));

			my @federalTaxId = ($claim->{payToProvider}->getTaxId());

			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured ID Number',@federalTaxId);
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getTaxTypeId(),$claim,'Tax Type Id',('S'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),7,$claim,'Rendering Provider Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',(0..9));


		}
	],

	'80314' =>
	[
		'Unicare Major Accounts',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));


		}
	],

	'47195' =>
	[
		'Unicare of Texas',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);
			my $procedures = $claim->{procedures};


			# checks for Patient Sex
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{careReceiver}->getSex(),$claim,'Patient Sex',('U'));

			# checks for Source of Payment Code
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getSourceOfPayment(),$claim,'Source of Payment Code',('G'));


			# checks for Patient Relation to Insured
			$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{insured}->getRelationshipToPatient(),('99'));

			# checks for Insured ID Number
			if (substr($claim->{insured}->[$claim->getClaimType()]->getSsn(),0,1) eq 'X')
			{
				$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'2','2',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('D'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'3','3',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',('A'..'Z'));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'4','12',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));
				$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'13','17',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(' '));
			}

			# checks for HCPCS procedure code
			my $i;
			if ($#$procedures > -1)
			{
				for $i (0..$#$procedures)
				{
					$self->checkValidValues(NOT_CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{procedures}->[$i]->getCPT(),$claim,'HCPCS Procedure Code',('99070'));
				}
			}

		}
	],

	'59129' =>
	[
		'United Healthcare of Florida',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkLength(GREATER,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),10,$claim,'Insured Id Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'','',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id',(0..9));

		}
	],

	'74095' =>
	[
		'USAA',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Prior Authorization Number
			$self->isRequired($claim->{treatment}->getPriorAuthorizationNo(),$claim,'Prior Authorization Number');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','9',$claim->{treatment}->getPriorAuthorizationNo(),$claim,'Prior Authorization Number',(0..9));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'10','10',$claim->{treatment}->getPriorAuthorizationNo(),$claim,'Prior Authorization Number',('-'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'11','13',$claim->{treatment}->getPriorAuthorizationNo(),$claim,'Prior Authorization Number',(0..9));

			# checks for Accident Indicator
			$self->isRequired($claim->getConditionRelatedToOtherAccident(),$claim,'Accident Indicator');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->getConditionRelatedToOtherAccident(),$claim,'Accident Indicator',('A'));


		}
	],

	'36369' =>
	[
		'Utilimited',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			#checks for Group Number
			$self->isRequired($claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number');
			$self->checkLength(EQUAL,'','',$claim->{insured}->getPolicyGroupOrFECANo(),4,$claim,'Group Number');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$claim->{insured}->getPolicyGroupOrFECANo(),$claim,'Group Number',('U'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'1','1',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Provider Network Id',('S'));

		}
	],

	'22264' =>
	[
		'Vytra Healthcare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');

		}
	],

	'39151' =>
	[
		'WEA Insurance Group',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Speciality
			$self->checkValidValues(CONTAINS,CHECK_EXACT_VALUES,'','',$claim->{payToProvider}->getSpecialityId(),$claim,'Provider Speciality',('035'));

		}
	],

	'VN' =>
	[
		'Vivra Network Services',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Provider Number
			$self->isRequired($claim->{payToProvider}->getId(),$claim,'Provider Number');
			$self->checkLength(EQUAL,'','',$claim->{payToProvider}->getId(),6,$claim,'Provider Number');
			$self->checkLength(CONTAINS,'1','1',$claim->{payToProvider}->getId(),$claim,'Provider Number',('A'..'Z'));
			$self->checkLength(CONTAINS,'2','2',$claim->{payToProvider}->getId(),$claim,'Provider Number',(0..9,'A'..'Z'));
			$self->checkLength(CONTAINS,'3','6',$claim->{payToProvider}->getId(),$claim,'Provider Number',(0..9));


			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');
			$self->checkLength(EQUAL,'','',$claim->{renderingProvider}->getNetworkId(),6,$claim,'Rendering Network Id');
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','1',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id',('A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'2','2',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id',(0..9,'A'..'Z'));
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'3','6',$claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id',(0..9));

		}
	],

	'14164' =>
	[
		'Wellcare',
		sub
		{
			my ($self,$valMgr, $claim) = ($_[0],$_[1], $_[4]);

			# checks for Insured Id Number
			$self->checkValidValues(CONTAINS,CHECK_CHARACTERS,'1','11',$claim->{insured}->[$claim->getClaimType()]->getSsn(),$claim,'Insured Id number',('A'..'Z'));

			# checks for Rendering Provider Network Id
			$self->isRequired($claim->{renderingProvider}->getNetworkId(),$claim,'Rendering Network Id');

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


    if ($claim->getPayerId() =~ m/^VN/)
    {
    	$payerId = 'VN';
    }
    else
    {
    	$payerId = $claim->getPayerId();
    }


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

	return "ENVOYPAYER";
}

sub getName
{
	my $self = shift;

	return "Envoy Payer";
}


sub getCallSequences
{
	my $self =  shift;

	return 'Claim_Payer';
}




1;

