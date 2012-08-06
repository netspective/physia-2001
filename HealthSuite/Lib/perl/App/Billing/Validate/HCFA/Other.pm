##############################################################################
package App::Billing::Validate::HCFA::Other;
##############################################################################

use strict;
use Carp;
use App::Billing::Validator;
use App::Billing::Validate::HCFA;


use vars qw(@ISA);
@ISA = qw(App::Billing::Validate::HCFA);
use constant VALITEMIDX_NAME => 0;
use constant VALITEMIDX_INSTANCE => 1;
use constant VALITEMIDX_ERRCODE => 2;
use constant VALITEMIDX_MESSAGE => 3;
use constant CONTAINS => 0;
use constant NOT_CONTAINS => 1;


sub new
{
	my ($type) = @_;
	my $self = new App::Billing::Validate::HCFA(@_);
	return bless $self, $type;
}




sub getId
{

	return 'VC06';
}

sub getName
{
	return 'Other Validator Class';
}

sub getCallSequences
{
	return 'Claim_Other';
}

sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $claim) = @_;



	if ($claim->{treatment}->getDateOfSameOrSimilarIllness eq "")
	{
		$self->checkGenericProperties($claim,$vFlags,$parent);


 		if ($claim->{insured}->[0]->getAnotherHealthBenefitPlan)
		{
			$self->checkSecondaryProperties($claim,$vFlags,$parent);
		}
		else
			{
				$self->checkPrimaryProperties($claim,$vFlags,$parent);
			}
	}
	else
		{

		$self->checkGenericBCBSProperties($claim,$vFlags,$parent);


 		if ($claim->{insured}->[0]->getAnotherHealthBenefitPlan)
		{
			$self->checkSecondaryBCBSProperties($claim,$vFlags,$parent);
		}
		else
			{
				$self->checkPrimaryBCBSProperties($claim,$vFlags,$parent);
			}
	}

#		here medicare specfic validation will be done.

}

sub checkGenericProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::Person::getSsn,$insured,100,'Missing insured Id'],
		[\&App::Billing::Claim::Person::getFirstName,$patient,101,'Missing patient first name'],
		[\&App::Billing::Claim::Person::getLastName,$patient,102,'Missing patient last name'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$patient,103,'Missing patient middle initial name'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$patient,125,'Missing patient date of birth'],
		[\&App::Billing::Claim::Person::getSex,$patient,105,'Missing patient sex'],
		[\&App::Billing::Claim::Person::getFirstName,$insured,101,'Missing insured first name'],
		[\&App::Billing::Claim::Person::getLastName,$insured,102,'Missing insured last name'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$insured,103,'Missing insured middle initial name'],
		[\&App::Billing::Claim::Patient::getRelationshipToInsured,$patient,104,'Missing patient insured relationship'],
		[\&App::Billing::Claim::Patient::getStatus,$patient,106,'Missing patient status'],
		[\&App::Billing::Claim::Person::getStudentStatus,$patient,107,'Missing patient student status'],
		[\&App::Billing::Claim::Person::getEmploymentStatus,$patient,108,'Missing patient employment ststus'],
#		[\&App::Billing::Claim::getConditionRelatedToEmployment,$claim,109,'Missing condition related to employment'],
#		[\&App::Billing::Claim::getconditionRelatedToAutoAccident,$claim,110,'Missing condition related to auto accident'],
#		[\&App::Billing::Claim::getConditionRelatedToOtherAccident,$claim,111,'Missing condition related to other accident'],
		[\&App::Billing::Claim::Insured::getPolicyGroupOrFECANo,$insured,104,'Missing plan or group'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$insured,125,'Missing insured date of birth'],
		[\&App::Billing::Claim::Person::getSex,$insured,126,'Missing insured sex'],
		[\&App::Billing::Claim::Insured::getEmployerOrSchoolName,$insured,112,'Missing employer or school name'],
		[\&App::Billing::Claim::Insured::getInsurancePlanOrProgramName,$insured,113,'Missing insurance plan or program name'],
		[\&App::Billing::Claim::Treatment::getDateOfIllnessInjuryPregnancy,$treatment,115,'Missing date of illness/injury/pregnancy'],
		[\&App::Billing::Claim::Treatment::getDateOfSameOrSimilarIllness,$treatment,127,'Missing date of similar illness'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateFrom,$treatment,117,'Missing hospitalization from date'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateTo,$treatment,118,'Missing hospitalization to date'],
		[\&App::Billing::Claim::Treatment::getOutsideLab,$treatment,119,'Missing outside lab indicator'],
		[\&App::Billing::Claim::Treatment::getPriorAuthorizationNo,$treatment,119,'Missing prior authorization number'],
		[\&App::Billing::Claim::Physician::getFederalTaxId,$physician,121,'Missing federal tax id'],
		[\&App::Billing::Claim::Physician::getName ,$physician ,123,'Bill receiver name missing ']
	];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);

	$self->checkAddress($physician->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($patient->{address},$vFlag,$claim,$parent);
	$self->checkAddress($insured->{address},$vFlag,$claim,$parent);

#		[\&App::Billing::Claim::Treatment::getOutsideLabCharges,$treatment,120,'Missing outside lab charges'],
#		[\&App::Billing::Claim::Treatment::getNameOfReferingPhysicianOrOther,$treatment,130],
#		[\&App::Billing::Claim::Treatment::getIdOfReferingPhysician,$treatment,116,'Missing id of referring physician'],

	$equalMap = [
		[\&App::Billing::Claim::getConditionRelatedToAutoAccidentPlace,$claim,124,'Condition related to auto accident place not required'],
		[\&App::Billing::Claim::Treatment::getMedicaidResubmission,$treatment,131,'Medicaid resubmission not required'],
		[\&App::Billing::Claim::Treatment::getResubmissionReference,$treatment,132,'Resubmission reference not required'],
	];
	$self->validateNotRequired($vFlag, $claim, $equalMap, $parent);
	$self->checkProcedures($vFlag, $claim, $parent);
}


sub checkSecondaryProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::getAcceptAssignment,$claim,122,'Missing accept assignment'],
		];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
}

sub checkPrimaryProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::getAmountPaid,$claim,101,'Missing paid amount']
		];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);

}


#################################################################################3
sub checkGenericBCBSProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});



	my $equalMap = [
		[\&App::Billing::Claim::Person::getId,$insured,100,'Missing insured Id'],
		[\&App::Billing::Claim::Person::getFirstName,$patient,101,'Missing patient first name'],
		[\&App::Billing::Claim::Person::getLastName,$patient,102,'Missing patient last name'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$patient,103,'Missing patient middle initial name'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$patient,125,'Missing patient date of birth'],
		[\&App::Billing::Claim::Person::getSex,$patient,105,'Missing patient sex'],
		[\&App::Billing::Claim::Person::getFirstName,$insured,101,'Missing insured first name'],
		[\&App::Billing::Claim::Person::getLastName,$insured,102,'Missing insured last name'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$insured,103,'Missing insured middle initial name'],
		[\&App::Billing::Claim::Patient::getRelationshipToInsured,$patient,104,'Missing patient insured relationship'],
		[\&App::Billing::Claim::Patient::getStatus,$patient,106,'Missing patient status'],
		[\&App::Billing::Claim::Person::getStudentStatus,$patient,107,'Missing patient student status'],
		[\&App::Billing::Claim::Person::getEmploymentStatus,$patient,108,'Missing patient employment ststus'],
#		[\&App::Billing::Claim::getConditionRelatedToEmployment,$claim,109,'Missing condition related to employment'],
#		[\&App::Billing::Claim::getconditionRelatedToAutoAccident,$claim,110,'Missing condition related to auto accident'],
#		[\&App::Billing::Claim::getConditionRelatedToOtherAccident,$claim,111,'Missing condition related to other accident'],
		[\&App::Billing::Claim::Insured::getPolicyGroupOrFECANo,$insured,104,'Missing plan or group'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$insured,125,'Missing insured date of birth'],
		[\&App::Billing::Claim::Person::getSex,$insured,126,'Missing insured sex'],
		[\&App::Billing::Claim::Insured::getEmployerOrSchoolName,$insured,112,'Missing employer or school name'],
		[\&App::Billing::Claim::Insured::getInsurancePlanOrProgramName,$insured,113,'Missing insurance plan or program name'],
		[\&App::Billing::Claim::Treatment::getDateOfIllnessInjuryPregnancy,$treatment,115,'Missing date of illness/injury/pregnancy'],
		[\&App::Billing::Claim::Treatment::getNameOfReferingPhysicianOrOther,$treatment,130,'Missing name of refering physician'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateFrom,$treatment,117,'Missing hospitalization from date'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateTo,$treatment,118,'Missing hospitalization to date'],
		[\&App::Billing::Claim::Treatment::getOutsideLab,$treatment,119,'Missing outside lab indicator'],
		[\&App::Billing::Claim::Treatment::getPriorAuthorizationNo,$treatment,119,'Missing prior authorization number'],
		[\&App::Billing::Claim::Physician::getFederalTaxId,$physician,121,'Missing federal tax id'],
		[\&App::Billing::Claim::Physician::getName, $physician,123,'Bill receiver name missing ']
	];


	$self->validateRequired($vFlag, $claim, $equalMap,$parent);


	$self->checkAddress($physician->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($patient->{address},$vFlag,$claim,$parent);
	$self->checkAddress($insured->{address},$vFlag,$claim,$parent);



#		[\&App::Billing::Claim::Treatment::getOutsideLabCharges,$treatment,120,'Missing outside lab charges'],

#		[\&App::Billing::Claim::Treatment::getIdOfReferingPhysician,$treatment,116,'Missing id of referring physician'],

	$equalMap = [
		[\&App::Billing::Claim::getConditionRelatedToAutoAccidentPlace,$claim,124,'Condition related to auto accident place not required'],
		[\&App::Billing::Claim::Treatment::getMedicaidResubmission,$treatment,131,'Medicaid resubmission not required'],
		[\&App::Billing::Claim::Treatment::getResubmissionReference,$treatment,132,'Resubmission reference not required'],
		[\&App::Billing::Claim::Treatment::getDateOfSameOrSimilarIllness,$treatment,127,'Date of similar illness not required'],
	];
	$self->validateNotRequired($vFlag, $claim, $equalMap, $parent);
	$self->checkProceduresBCBS($vFlag, $claim, $parent);
}


sub checkSecondaryBCBSProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::getAmountPaid,$claim,101,'Missing paid amount']
		];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
}

sub checkPrimaryBCBSProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::getAmountPaid,$claim,101,'Missing paid amount']
		];

	$self->validateNotRequired($vFlag, $claim, $equalMap, $parent);

}
##########################################################################

sub checkProceduresBCBS
{
	my ($self, $vFlag, $claim, $parent) = @_;
	my $procedures = $claim->{procedures};
	my $i;
	my @pos =(11..12,21..26,31..34,50..56,61,62,71,81,99);

	my $equalMap = [
		[\&App::Billing::Claim::Procedure::getDateOfServiceFrom,,136,'Missing dates of service'],
		[\&App::Billing::Claim::Procedure::getDateOfServiceTo,,137,'Missing dates of service'],
		[\&App::Billing::Claim::Procedure::getPlaceOfService,,138,'Missing place of service'],
		[\&App::Billing::Claim::Procedure::getCPT,,139,'Missing CPT'],
		[\&App::Billing::Claim::Procedure::getModifier,,140,'Missing modifier'],
		[\&App::Billing::Claim::Procedure::getDiagnosisCode,,141,,'Missing diagnosis code pointer'],
		[\&App::Billing::Claim::Procedure::getCharges,,142,'Mssing service charges'],
		[\&App::Billing::Claim::Procedure::getDaysOrUnits,,143,'Mssing days or units'],
		];

	my $equalMap1 = [
			 [\&App::Billing::Claim::Procedure::getFamilyPlan,,145,'Family plan not required'],
			 [\&App::Billing::Claim::Procedure::getCOB,,147,'Cob not required'],
	   		 [\&App::Billing::Claim::Procedure::getEmergency,,146,'Eemergency indicator not required'],
		];

	for $i (0..$#$procedures)
	{
		$equalMap->[0]->[1] = $procedures->[$i];
		$equalMap->[1]->[1] = $procedures->[$i];
		$equalMap->[2]->[1] = $procedures->[$i];
		$equalMap->[3]->[1] = $procedures->[$i];
		$equalMap->[4]->[1] = $procedures->[$i];
		$equalMap->[5]->[1] = $procedures->[$i];
		$equalMap->[6]->[1] = $procedures->[$i];
		$equalMap->[7]->[1] = $procedures->[$i];
#		$equalMap->[8]->[1] = $procedures->[$i];

		$self->validateRequired($vFlag, $claim, $equalMap, $parent);

		$equalMap1->[0]->[1] = $procedures->[$i];
		$equalMap1->[1]->[1] = $procedures->[$i];
		$equalMap1->[2]->[1] = $procedures->[$i];

		$self->validateNotRequired($vFlag, $claim, $equalMap1,$parent);
		$self->checkValidValues(0,'','',$procedures->[$i]->getPlaceOfService,$claim,'Place of service', @pos);
	}
}



1;
