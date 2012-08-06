##############################################################################
package App::Billing::Validate::HCFA::Champus;
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
	my $self = shift;

	return 'VC01';
}

sub getName
{
	my $self = shift;

	return 'Other Validator Class';
}

sub getCallSequences
{
	my $self = shift;

	return 'Claim_Champus';
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
		[\&App::Billing::Claim::Patient::getStatus,$patient,106,'Missing patient marital status'],
		[\&App::Billing::Claim::Person::getStudentStatus,$patient,107,'Missing patient student status'],
		[\&App::Billing::Claim::Person::getEmploymentStatus,$patient,108,'Missing patient employment ststus'],
#		[\&App::Billing::Claim::getConditionRelatedToEmployment,$claim,109,'Missing condition related to employment'],
#		[\&App::Billing::Claim::getconditionRelatedToAutoAccident,$patient,110,'Missing condition related to auto accident'],
#		[\&App::Billing::Claim::getConditionRelatedToOtherAccident,$patient,111,'Missing condition related to other accident'],
		[\&App::Billing::Claim::Treatment::getDateOfIllnessInjuryPregnancy,$treatment,115,'Missing date of illness/injury/pregnancy'],
		[\&App::Billing::Claim::Treatment::getOutsideLab,$treatment,119,'Missing outside lab indicator'],
		[\&App::Billing::Claim::Treatment::getPriorAuthorizationNo,$treatment,119,'Missing prior authorization number'],
#		[\&App::Billing::Claim::Treatment::getOutsideLabCharges,$treatment,120,'Missing outside lab charges'],
		[\&App::Billing::Claim::Physician::getFederalTaxId,$physician,121,'Missing federal tax id'],
		[\&App::Billing::Claim::Physician::getName ,$physician,123,'Missing Renedering provider name']
	];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);

	$self->checkAddress($physician->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($patient->getAddress,$vFlag,$claim,$parent);
	$self->checkAddress($insured->{address},$vFlag,$claim,$parent);

#		[\&App::Billing::Claim::Treatment::getNameOfReferingPhysicianOrOther,$treatment,130],
#		[\&App::Billing::Claim::Treatment::getIdOfReferingPhysician,$treatment,116,'Missing id of referring physician'],

	$equalMap = [
			[\&App::Billing::Claim::getConditionRelatedToAutoAccidentPlace,$patient,124,'Condition related to auto accident place not required'],
			[\&App::Billing::Claim::Treatment::getMedicaidResubmission,$treatment,131,'Medicaid resubmission not required'],
			[\&App::Billing::Claim::Treatment::getResubmissionReference,$treatment,132,'Resubmission reference not required']
			];

	$self->validateNotRequired($vFlag, $claim, $equalMap, $parent);
	$self->checkProcedures($vFlag, $claim, $parent);
}


sub checkSecondaryProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careRecevier},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
			[\&App::Billing::Claim::Person::getDateOfBirth,$insured,125,'Missing insured date of birth'],
			[\&App::Billing::Claim::Person::getSex,$insured,126,' Missing isured sex'],
			[\&App::Billing::Claim::Insured::getPolicyGroupOrFECANo,$insured,104,'Missing policy/group number'],
			[\&App::Billing::Claim::Insured::getEmployerOrSchoolName,$insured,112,'Missing employer or school name'],
			[\&App::Billing::Claim::Insured::getInsurancePlanOrProgramName,$insured,113,'Missing insurance plan or program name'],
			[\&App::Billing::Claim::getAmountPaid,$insured,113,'Missing amount paid'],
			[\&App::Billing::Claim::getAcceptAssignment,$claim,122,'Missing accept assignment'],
			];

	$self->validateRequired($vFlag, $claim, $equalMap,$parent);
}

sub checkPrimaryProperties
{
	my ($self,$claim,$vFlag,$parent) = @_;
	my ($insured,$patient,$physician,$treatment) =
	   ($claim->{insured}->[0],$claim->{careRecevier},$claim->{renderingProvider}
	    ,$claim->{treatment});

	my $equalMap = [
			[\&App::Billing::Claim::getAmountPaid,$claim,101,'Missing paid amount']
			];

	$self->validateNotRequired($vFlag, $claim, $equalMap,$parent);

}


sub checkProcedures
{
	my ($self, $vFlag, $claim, $parent) = @_;
	my $procedures = $claim->{procedures};
	my $i;
	my @pos =(11,12,21..26,31..34,50..56,61,62,65,71,81,99);
	my @tos =(1..9,'A'..'F');

	my $equalMap = [
		[\&App::Billing::Claim::Procedure::getDateOfServiceFrom,,136,'Missing service dates'],
		[\&App::Billing::Claim::Procedure::getDateOfServiceTo,,137,'Missing service dates'],
		[\&App::Billing::Claim::Procedure::getPlaceOfService,,138,,'Missing place of service'],
		[\&App::Billing::Claim::Procedure::getCPT,,139,'Missing CPT code'],
		[\&App::Billing::Claim::Procedure::getModifier,,140,'Missing modifier'],
		[\&App::Billing::Claim::Procedure::getDiagnosisCode,,141,'Missing diagnosis pointer'],
		[\&App::Billing::Claim::Procedure::getCharges,,142,'Missing service charges'],
		[\&App::Billing::Claim::Procedure::getDaysOrUnits,,143,'Missing days of service'],
  		[\&App::Billing::Claim::Procedure::getEmergency,,146,'Missing emergency indicator']
		];

	my $equalMap1 = [
			 [\&App::Billing::Claim::Procedure::getFamilyPlan,,145,'FamilyPlan not required'],
			 [\&App::Billing::Claim::Procedure::getCOB,,147,'COB not required']
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
		$equalMap->[8]->[1] = $procedures->[$i];

		$self->validateNotRequired($vFlag, $claim, $equalMap, $parent);

		$equalMap1->[0]->[1] = $procedures->[$i];
		$equalMap1->[1]->[1] = $procedures->[$i];
		$equalMap1->[2]->[1] = $procedures->[$i];
		$equalMap1->[3]->[1] = $procedures->[$i];
		$self->validateNotRequired($vFlag, $claim, $equalMap1, $parent);
		$self->checkValidValues(CONTAINS,'','',$procedures->[$i]->getPlaceOfService,$claim,'Place of service', @pos);
		$self->checkValidValues(CONTAINS,'','',$procedures->[$i]->getTypeOfService,$claim,'Place of service',@tos);

	}
}



1;
