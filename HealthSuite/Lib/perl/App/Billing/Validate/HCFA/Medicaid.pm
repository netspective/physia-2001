##############################################################################
package App::Billing::Validate::HCFA::Medicaid;
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

	return 'VC04';
}

sub getName
{
	return 'Other Validator Class';
}

sub getCallSequences
{
	return 'Claim_Medicaid';
}

sub validate
{
	my ($self, $parent, $callSeq, $vFlags, $claim) = @_;

	$self->checkGenericProperties($claim,$vFlags,$parent);


 	if ($claim->{insured}->[0]->getAnotherHealthBenefitPlan)
	{
		$self->checkSecondaryProperties($claim,$vFlags,$parent);
	}
	else
	{
		$self->checkPrimaryProperties($claim,$vFlags,$parent);
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

		[\&App::Billing::Claim::Person::getDateOfBirth,$patient,125],
		[\&App::Billing::Claim::Person::getSex,$patient,105,'Missing insured sex'],
		[\&App::Billing::Claim::Treatment::getNameOfReferingPhysicianOrOther,$treatment,130],
		[\&App::Billing::Claim::Treatment::getIDOfReferingPhysician,$treatment,130],
		[\&App::Billing::Claim::Treatment::getOutsideLab,$treatment,119,'Missing outside lab indicator'],
		[\&App::Billing::Claim::Physician::getFederalTaxId,$physician,121,'Missing federal tax id'],
		[\&App::Billing::Claim::Patient::getAccountNo,$patient,121,'Missing patient Account number'],
		[\&App::Billing::Claim::getAcceptAssignment,$claim,122,'Missing accept assignment'],
		[\&App::Billing::Claim::getAmountPaid,$claim,101,'Missing paid amount'],
		[\&App::Billing::Claim::Physician::getName ,$physician,123,'']
	];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
	$self->checkAddress($physician->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($patient->{address},$vFlag,$claim,$parent);

	$equalMap = [
		[\&App::Billing::Claim::Person::getSsn,$insured,100,'Missing insured Id'],
		[\&App::Billing::Claim::Patient::getRelationshipToInsured,$patient,104,'Missing patient insured relationship'],
		[\&App::Billing::Claim::Patient::getStatus,$patient,106,'Missing patient Id'],
		[\&App::Billing::Claim::Person::getStudentStatus,$patient,107,'Missing patient student status'],
		[\&App::Billing::Claim::Person::getEmploymentStatus,$patient,108,'Missing patient employment ststus'],
		[\&App::Billing::Claim::Person::getDateOfBirth,$insured,125],
		[\&App::Billing::Claim::Person::getSex,$insured,126],
		[\&App::Billing::Claim::Insured::getEmployerOrSchoolName,$insured,112,'Missing employer or school name'],
		[\&App::Billing::Claim::Insured::getInsurancePlanOrProgramName,$insured,113,'Missing insurance plan or program name'],
		[\&App::Billing::Claim::Treatment::getDateOfIllnessInjuryPregnancy,$treatment,115,'Missing date of illness/injury/pregnancy'],
		[\&App::Billing::Claim::Treatment::getDateOfSameOrSimilarIllness,$treatment,127],
		[\&App::Billing::Claim::Treatment::getDatePatientUnableToWorkFrom,$treatment,128],
		[\&App::Billing::Claim::Treatment::getDatePatientUnableToWorkTo,$treatment,129],
		[\&App::Billing::Claim::Treatment::getMedicaidResubmission,$treatment,131],
		[\&App::Billing::Claim::Treatment::getResubmissionReference,$treatment,132],
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
			[\&App::Billing::Claim::Person::getFirstName,$insured,101,'Missing patient first name'],
			[\&App::Billing::Claim::Person::getLastName,$insured,102,'Missing patient last name'],
			[\&App::Billing::Claim::Person::getMiddleInitial,$insured,103,'Missing patient middle initial name'],
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
			[\&App::Billing::Claim::Person::getFirstName,$insured,101,'Missing patient first name'],
			[\&App::Billing::Claim::Person::getLastName,$insured,102,'Missing patient last name'],
			[\&App::Billing::Claim::Person::getMiddleInitial,$insured,103,'Missing patient middle initial name'],
			];
	$self->validateNotRequired($vFlag, $claim, $equalMap,$parent);

}



1;

