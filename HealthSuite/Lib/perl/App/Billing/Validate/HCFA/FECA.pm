##############################################################################
package App::Billing::Validate::HCFA::FECA;
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

	return 'VC03';
}

sub getName
{
	return 'FECA Validator Class';
}

sub getCallSequences
{
	return 'Claim_FECA';
}

sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $claim) = @_;

	$self->checkGenericProperties($claim,$vFlags,$parent);
}

sub checkGenericProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careReceiver},$claim->{renderingProvider},
	   $claim->{treatment});

	my $equalMap = [
		[\&App::Billing::Claim::Person::getSsn,$insured,100,'Missing insured Id'],
		[\&App::Billing::Claim::Person::getFirstName,$patient,101,'Missing patient first name'],
		[\&App::Billing::Claim::Person::getLastName,$patient,102,'Missing patient last name'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$patient,103,'Missing patient middle initial name'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$patient,125,'Missing patient date of birth'],
		[\&App::Billing::Claim::Person::getSex,$patient,105,'Missing patient sex'],
		[\&App::Billing::Claim::Patient::getStatus,$patient,106,'Missing patient status'],
		[\&App::Billing::Claim::Person::getEmploymentStatus,$patient,108,'Missing patient employment ststus'],
		[\&App::Billing::Claim::getConditionRelatedToEmployment,$claim,109,'Missing condition related to employment'],
		[\&App::Billing::Claim::getConditionRelatedToAutoAccident,$patient,110,'Missing condition related to auto accident'],
		[\&App::Billing::Claim::getConditionRelatedToOtherAccident,$patient,111,'Missing condition related to other accident'],
		[\&App::Billing::Claim::Insured::getEmployerOrSchoolName,$insured,112,'Missing employer or school name'],
		[\&App::Billing::Claim::Insured::getInsurancePlanOrProgramName,$insured,113,'Missing insurance plan or program name'],
		[\&App::Billing::Claim::Treatment::getDateOfIllnessInjuryPregnancy,$treatment,115,'Missing date of illness/injury/pregnancy'],
		[\&App::Billing::Claim::Treatment::getDateOfSameOrSimilarIllness,$treatment,127,'Missing date of similar illness'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateFrom,$treatment,117,'Missing hospitalization from date'],
		[\&App::Billing::Claim::Treatment::getHospitilizationDateTo,$treatment,118,'Missing hospitalization to date'],
		[\&App::Billing::Claim::Treatment::getOutsideLab,$treatment,119,'Missing outside lab indicator'],
		[\&App::Billing::Claim::Treatment::getPriorAuthorizationNo,$treatment,119,'Missing prior authorization number'],
		[\&App::Billing::Claim::Physician::getFederalTaxId,$physician,121,'Missing federal tax id'],
		[\&App::Billing::Claim::Physician::getName ,$physician,123,'Bill receiver name missing ']
	];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
	$self->checkAddress($physician->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($patient->{address},$vFlag,$claim,$parent);

	if (uc($treatment->getOutsideLab()) eq 'Y')
		{
			$self->validateRequired($vFlag, $claim, [[\&App::Billing::Claim::Treatment::getOutsideLabCharges,$treatment,120,'Missing outside lab charges']],$parent);
		}
		if ($treatment->getNameOfReferingPhysicianOrOther ne "")
		{
			$self->validateRequired($vFlag, $claim, [[\&App::Billing::Claim::Treatment::getIDOfReferingPhysician,$treatment,116,'Missing id of referring physician']],$parent);
		}


	$equalMap = [
		[\&App::Billing::Claim::Person::getFirstName,$insured,101,'insured first name not required'],
		[\&App::Billing::Claim::Person::getLastName,$insured,102,'insured last name not required'],
		[\&App::Billing::Claim::Person::getMiddleInitial,$insured,103,'insured middle initial name not required'],
		[\&App::Billing::Claim::Patient::getRelationshipToInsured,$patient,104,'patient insured relationship not required'],
		[\&App::Billing::Claim::getConditionRelatedToAutoAccidentPlace,$patient,124,'Condition related to auto accident place not required'],
		[\&App::Billing::Claim::Insured::getPolicyGroupOrFECANo,$insured,104,'plan or group not required'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$insured,125,'insured date of birth not required'],
		[\&App::Billing::Claim::Treatment::getMedicaidResubmission,$treatment,131,'Medicaid resubmission not required'],
		[\&App::Billing::Claim::Treatment::getResubmissionReference,$treatment,132,'Resubmission reference not required'],
		[\&App::Billing::Claim::Person::getSex,$insured,126,'insured sex  not required'],
		[\&App::Billing::Claim::getAcceptAssignment,$claim,122,'accept assignment  not required'],
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

#	my $equalMap = [

#		];

#	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
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



1;

