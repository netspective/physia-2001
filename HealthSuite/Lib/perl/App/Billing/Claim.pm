##############################################################################
package App::Billing::Claim;
##############################################################################

use strict;
use App::Billing::Claim::Person;
use App::Billing::Claim::Organization;
use App::Billing::Claim::Diagnosis;
use App::Billing::Claim::Procedure;
use App::Billing::Claim::Patient;
use App::Billing::Claim::Physician;
use App::Billing::Claim::Insured;
use App::Billing::Claim::Treatment;
# use App::Billing::Claim::TWCC73;
# use App::Billing::Claim::TWCC60;

use App::Billing::Universal;
use constant DATEFORMAT_USA => 1;

# use constant MEDICARE => '4';
# use constant MEDICAID => '5';

use enum qw(:BILLRECEIVERTYPE_ PERSON ORGANIZATION);

use constant PRIMARY => 0;
use constant SECONDARY => 1;
use constant TERTIARY => 2;
use constant QUATERNARY => 3;

use constant BILLSEQ_PRIMARY_PAYER => 1;
use constant BILLSEQ_SECONDARY_PAYER => 2;
use constant BILLSEQ_TERTIARY_PAYER => 3;
use constant BILLSEQ_QUATERNARY_PAYER => 4;


sub new
{
	my ($type, %params) = @_;

	$params{careReceiver} = undef;						# Patient

	$params{payToOrganization} = undef;				# Billing Facility
	$params{payToProvider} = undef;						# Billing Provider (Physician)
	$params{renderingOrganization} = undef;		# Service Facility
	$params{renderingProvider} = undef;				# Service Provider (Physician)
	$params{careProvider} = undef;						# ???

	$params{insured} = [];
	$params{treatment} = undef;
	$params{diagnosis} = [];
	$params{procedures} = [];
	$params{id} = undef;
	$params{errors} = [];
	$params{warnings} = [];
	$params{legalRepresentator} = undef;
	$params{payer} = undef;
	$params{otherItems} = [];
	$params{copayItems} = [];
	$params{adjItems} = [];
	$params{policy} = [];
	$params{coInsuranceItems} = [];
	$params{deductibleItems} = [];
	$params{voidItems} = [];
	$params{suppressedItems} = [];

	$params{twcc73} = undef;
	$params{twcc60} = undef;

	$params{programName} = undef;
	$params{acceptAssignment} = undef;
	$params{totalCharge} = undef;
	$params{totalChargePaid} = undef;
	$params{amountPaid} = undef;
	$params{conditionRelatedToEmployment} = undef;
	$params{conditionRelatedToAutoAccident} = undef;
	$params{conditionRelatedToOtherAccident} = undef;
	$params{conditionRelatedToAutoAccidentPlace} = undef;
	$params{payerId} = undef;
	$params{qualifier} = undef;
	$params{filingIndicator} = undef;
	$params{symptomIndicator} = undef;
	$params{symptomExternalCause} = undef;
	$params{informationReleaseIndicator} = undef;
	$params{informationReleaseDate} = undef;
	$params{disabilityType} = undef;
	$params{spProgramIndicator} = undef;
	$params{dateDocSent} = undef;
	$params{anesthesiaOxygenMinutes} = undef;
	$params{hgbHctDate} = undef;
	$params{serumCreatineDate} = undef;
	$params{sourceOfPayment} = undef;
	$params{remarks} = undef;
	$params{informationReleaseDate} = undef;
	$params{responsibilityIndicator} = undef;
	$params{accidentHour} = undef;
	$params{champusSponsorBranch} = undef;
	$params{champusSponsorGrade} = undef;
	$params{champusSponsorStatus} = undef;
	$params{insuranceCardEffectiveDate} = undef;
	$params{insuranceCardTerminationDate} = undef;
	$params{bcbsPlanCode} = undef;
	$params{invoiceHistoryItem} = undef;
	$params{status} = undef;
	$params{historyCount} = 0;
	$params{balance} = 0;
	$params{claimType} = 0;
	$params{billSeq} = 0;
	$params{transProviderId} = undef;
	$params{transProviderName} = undef;
	$params{totalInvoiceCharges} = undef;
	$params{flags} = undef;

	$params{invoiceType} = undef;
	$params{invoiceSubtype} = undef;
	$params{totalItems} = undef;
	$params{insType} = undef;
	$params{providerEMCId} = undef;
	$params{invoiceDate} = undef;

	$params{changedTreatingDoctor} = undef;

	return bless \%params, $type; #binding the param hash with class reference
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}


sub getEMCId
{
	my $self = shift;
	my @ids;
	$ids[MEDICARE]= $self->{payToOrganization}->getMedicareId();
	$ids[MEDICAID]= $self->{payToOrganization}->getMedicaidId();
	$ids[WORKERSCOMP]= $self->{payToOrganization}->getWorkersComp();
	$ids[RAILROAD]= $self->{payToOrganization}->getRailroadId();
	$ids[BCBS]= $self->{payToOrganization}->getBCBSId();
	my @payerCodes =(MEDICARE, MEDICAID, WORKERSCOMP, RAILROAD, BCBS);
	$self->{providerEMCId} =
		(
			(grep{$_ eq $self->{insType}} @payerCodes) ?
			(
				($ids[$self->{insType}] eq '') ?
				$self->{payToProvider}->getPIN() :
				$ids[$self->{insType}]
			) :
			$self->{payToProvider}->getPIN()
		);
	return $self->{providerEMCId};
}

sub setInvoiceDate
{
	my ($self, $value) = @_;
	$self->{invoiceDate} = $value;
}

sub getInvoiceDate
{
	my $self = shift;
	return $self->{invoiceDate};
}

sub setFlags
{
	my ($self, $value) = @_;
	$self->{flags} = $value;
}

sub getFlags
{
	my $self = shift;
	return $self->{flags};
}

sub setTWCC73
{
	my ($self, $value) = @_;
	$self->{twcc73} = $value;
}

sub getTWCC73
{
	my $self = shift;
	return $self->{twcc73};
}

sub setTWCC60
{
	my ($self, $value) = @_;
	$self->{twcc60} = $value;
}

sub getTWCC60
{
	my $self = shift;
	return $self->{twcc60};
}

sub setTransProviderId
{
	my ($self, $value) = @_;
	$self->{transProviderId} = $value;
}

sub getTransProviderId
{
	my $self = shift;
	return $self->{transProviderId};
}

sub setInsType
{
	my ($self, $value) = @_;
	$self->{insType} = $value;
}

sub getInsType
{
	my $self = shift;
	return $self->{insType};
}

sub setTransProviderName
{
	my ($self, $value) = @_;
	$self->{transProviderName} = $value;
}

sub getTransProviderName
{
	my $self = shift;
	return $self->{transProviderName};
}

sub setBalance

{
	my ($self, $value) = @_;
	$self->{balance} = $value;
}

sub getBalance
{
	my $self = shift;
	return $self->{balance};
}


sub setStatus
{
	my ($self, $value) = @_;
	$self->{status} = $value;
}

sub getStatus
{
	my $self = shift;
	return $self->{status};
}

sub setInvoiceHistoryDate
{
	my ($self, $value) = @_;
	$self->{invoiceHistoryItem}->[$self->{historyCount}][0] = $value;
}


sub setInvoiceHistoryAction
{
	my ($self, $value) = @_;
	$self->{invoiceHistoryItem}->[$self->{historyCount}][1] = $value;
}


sub setInvoiceHistoryBy
{
	my ($self, $value) = @_;
	$self->{invoiceHistoryItem}->[$self->{historyCount}][2] = $value;
}

sub setInvoiceHistoryComments
{
	my ($self, $value) = @_;
	$self->{invoiceHistoryItem}->[$self->{historyCount}][3] = $value;
	$self->{historyCount}++;
}

sub getHistory
{
	my $self = shift;
	if (defined $self->{invoiceHistoryItem})
	{
		return $self->{invoiceHistoryItem};
	}
	else
	{
		return [[]];
	}
}

sub setInvoiceHistoryItem
{
	my ($self, $value) = @_;
	my $tempArray = $self->{invoiceHistoryItem};
	push(@$tempArray,$value);
}

sub getInvoiceHistoryItem
{
	my ($self, $index) = @_;
	if (defined($index))
	{
		 return $self->{invoiceHistoryItem}->[$index];
	}
	else
	{
		return $self->{invoiceHistoryItem};
	}
}

sub getDiagnosis
{
	my ($self, $no) = @_;
	$no = 0 + $no;
	return $self->{diagnosis}->[$no];
}

sub getProcedure
{
	my ($self, $no) = @_;
	$no = 0 + $no ;
	return $self->{procedures}->[$no];
}


sub getOtherItems
{
	my ($self, $no) = @_;
	$no =  0 + $no ;
	return $self->{otherItems}->[$no];
}

sub getCopayItems
{
	my ($self, $no) = @_;
	$no =  0 + $no ;
	return $self->{copayItems}->[$no];
}

sub getAdjItems
{
	my ($self, $no) = @_;
	$no =  0 + $no ;
	return $self->{adjItems}->[$no];
}

sub getPolicy
{
	my ($self, $no) = @_;
	$no =  0 + $no ;
	return $self->{policy}->[$no];
}

sub getInsured
{
	my ($self, $no) = @_;
	$no = 0 + $no ;
	return $self->{insured}->[$no];
}

sub setBCBSPlanCode
{
	my($self, $value) = @_;
	$self->{bcbsPlanCode} = $value;
}

sub getBCBSPlanCode
{
	my $self = shift;
	return $self->{bcbsPlanCode};
}

sub setChampusSponsorBranch
{
	my($self, $value) = @_;
	$self->{champusSponsorBranch} = $value;
}

sub setConditionRelatedTo
{
	my($self, $value) = @_;
	$self->setConditionRelatedToEmployment( (uc($value) =~ /EMPLOYMENT/) ? 'Y' : 'N');
	$self->setConditionRelatedToAutoAccident((uc($value) =~ /AUTO ACCIDENT/) ? 'Y': 'N');
	$self->setConditionRelatedToOtherAccident((uc($value) =~ /OTHER ACCIDENT/) ? 'Y' : 'N');
}

sub getChampusSponsorBranch
{
	my $self = shift;
	return $self->{champusSponsorBranch};
}

sub setChampusSponsorGrade
{
	my($self, $value) = @_;
	$self->{champusSponsorGrade} = $value;
}

sub getChampusSponsorGrade
{
	my $self = shift;
	return $self->{champusSponsorGrade};
}

sub setChampusSponsorStatus
{
	my($self, $value) = @_;
	$self->{champusSponsorStatus} = $value;
}

sub getChampusSponsorStatus
{
	my $self = shift;
	return $self->{champusSponsorStatus};
}

sub setInsuranceCardEffectiveDate
{
	my($self, $value) = @_;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{insuranceCardEffectiveDate} = $value;
}

sub getInsuranceCardEffectiveDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{insuranceCardEffectiveDate}) : $self->{insuranceCardEffectiveDate};
}

sub setInsuranceCardTerminationDate
{
	my($self, $value) = @_;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{insuranceCardTerminationDate} = $value;
}

sub getInsuranceCardTerminationDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{insuranceCardTerminationDate}) : $self->{insuranceCardTerminationDate};
}

sub setPayer
{
	my($self, $value) = @_;
	$self->{payer} = $value;
}

sub getPayer
{
	my ($self) = @_;
	return $self->{payer};
}

sub setLegalRepresentator
{
	my($self, $value) = @_;
	$self->{legalRepresentator} = $value;
}

sub getLegalRepresentator
{
	my ($self) = @_;
	return $self->{legalRepresentator};
}

sub setAccidentHour
{
	my($self, $value) = @_;
	$self->{accidentHour} = $value;
}

sub getAccidentHour
{
	my ($self) = @_;
	return $self->{accidentHour};
}

sub setResponsibilityIndicator
{
	my($self, $value) = @_;
	$self->{responsibilityIndicator} = $value;
}

sub getResponsibilityIndicator
{
	my ($self) = @_;
	return $self->{responsibilityIndicator};
}

sub setSourceOfPayment
{
	my ($self, $value) = @_;
	$self->{sourceOfPayment} = $value;
}

sub getSourceOfPayment
{
	my ($self) = @_;
	return $self->{sourceOfPayment};
}

sub setRemarks
{
	my ($self, $value) = @_;
	$self->{remarks} = $value;
}

sub getRemarks
{
	my ($self) = @_;
	return $self->{remarks};
}

sub setAnesthesiaOxygenMinutes
{
	my ($self, $value) = @_;
	$self->{anesthesiaOxygenMinutes} = $value;
}

sub getAnesthesiaOxygenMinutes
{
	my ($self) = @_;
	return $self->{anesthesiaOxygenMinutes};
}

sub setHGBHCTDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{hgbHctDate} = $value;
}

sub getHGBHCTDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{hgbHctDate}) : $self->{hgbHctDate};
}

sub setSerumCreatineDate
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{serumCreatineDate} = $value;
}

sub getSerumCreatineDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{serumCreatineDate}) : $self->{serumCreatineDate};
}

sub setQualifier
{
	my ($self, $value) = @_;
	$self->{qualifier} = $value;
}

sub getQualifier
{
	my ($self) = @_;
	return $self->{qualifier};
}

sub setRenderingProvider
{
	my ($self, $value) = @_;
	$self->{renderingProvider} = $value;
}

sub getRenderingProvider
{
	my ($self) = @_;
	return $self->{renderingProvider};
}

sub setCareProvider
{
	my ($self, $value) = @_;
	$self->{careProvider} = $value;
}

sub getCareProvider
{
	my ($self) = @_;
	return $self->{careProvider};
}

sub setRenderingOrganization
{
	my ($self, $value) = @_;
	$self->{renderingOrganization} = $value;
}

sub getRenderingOrganization
{
	my ($self) = @_;
	return $self->{renderingOrganization};
}

sub setdateDocSent
{
	my ($self,$value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{dateDocSent} = $value;
}

sub getdateDocSent
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{dateDocSent}) : $self->{dateDocSent};
}

sub setSpProgramIndicator
{
	my ($self, $value) = @_;
	$self->{SpProgramIndicator} = $value;
}

sub getSpProgramIndicator
{
	my ($self) = @_;
	return $self->{spProgramIndicator};
}

sub setDisabilityType
{
	my ($self, $value) = @_;
	$self->{disabilityType} = $value;
}

sub getDisabilityType
{
	my ($self) = @_;
	return $self->{disabilityType};
}

sub setInformationReleaseDate
{
	my ($self, $value) = @_;
	$value =~ s/ 00:00:00//;
	$value = $self->convertDateToCCYYMMDD($value);
	$self->{informationReleaseDate} = $value;
}

sub getInformationReleaseDate
{
	my ($self, $formatIndicator) = @_;
	return (DATEFORMAT_USA == $formatIndicator) ? $self->convertDateToMMDDYYYYFromCCYYMMDD($self->{informationReleaseDate}) : $self->{informationReleaseDate};
}

sub setInformationReleaseIndicator
{
	my ($self, $value) = @_;
	my $temp =
	{
		'0' => 'N',
		'1' => 'Y',
		'Yes' => 'Y',
		'No' => 'N',
	};
	$self->{informationReleaseIndicator} = $temp->{$value};
}

sub getInformationReleaseIndicator
{
	my ($self) = @_;
	return $self->{informationReleaseIndicator};
}

sub setSymptomExternalCause
{
	my ($self, $value) = @_;
	$self->{symptomExternalCause} = $value;
}

sub getSymptomExternalCause
{
	my ($self) = @_;
	return $self->{symptomExternalCause};
}

sub setSymptomIndicator
{
	my ($self, $value) = @_;
	$self->{symptomIndicator} = $value;
}

sub getSymptomIndicator
{
	my ($self) = @_;
	return $self->{symptomIndicator};
}

sub setFilingIndicator
{
	my ($self, $treat) = @_;
	$self->{filingIndicator} = $treat;
}

sub getFilingIndicator
{
	my ($self, $insSequence) = @_;
	#return $self->{filingIndicator};
	return $insSequence == 1 ? 'P' : 'I';
}

sub setAcceptAssignment
{
	my ($self, $treat) = @_;
	my $temp =
	{
		'0' => 'N',
		'NO' => 'N',
		'N' => 'N',
		'1'  => 'Y',
		'YES'  => 'Y',
		'Y'  => 'Y',
	};
	$self->{acceptAssignment} = $temp->{uc($treat)};
}

sub setTotalCharge
{
	my ($self, $treat) = @_;
	$self->{totalCharge} = $treat;
}

sub setTotalChargePaid
{
	my ($self, $value) = @_;
	$self->{totalChargePaid} = $value;
}

sub setTotalInvoiceCharges
{
	my ($self, $value) = @_;
	$self->{totalInvoiceCharges} = $value;
}

sub setId
{
	my ($self, $value) = @_;
	$self->{id} = $value;
}

sub setAmountPaid
{
	my ($self, $treat) = @_;
	$self->{amountPaid} = $treat;
}

sub getAcceptAssignment
{
	my ($self) = @_;
	return $self->{acceptAssignment};
}

sub getTotalCharge
{
	my ($self) = @_;
	return $self->{totalCharge};
}

sub getTotalChargePaid
{
	my ($self) = @_;
	return $self->{totalChargePaid};
}

sub getTotalInvoiceCharges
{
	my ($self) = @_;
	return $self->{totalInvoiceCharges};
}

sub getAmountPaid
{
	my ($self) = @_;
	return $self->{amountPaid};
}

sub getId
{
	my ($self) = @_;
	return $self->{id};
}

sub setTreatment
{
	my ($self, $treat) = @_;
	$self->{treatment} = $treat;
}

sub getTreatment
{
	my $self = shift;
	return $self->{treatment};
}

sub setCareReceiver
{
	my ($self, $person) = @_;
	$self->{careReceiver} = $person;
}

sub getCareReceiver
{
	my $self = shift;
	return $self->{careReceiver};
}

sub setPayToProvider
{
	my ($self, $person) = @_;
	$self->{payToProvider} = $person;
}

sub setPayToOrganization
{
	my ($self, $value) = @_;
	$self->{payToOrganization} = $value;
}

sub getPayToProvider
{
	my $self = shift;
	return $self->{payToProvider};
}

sub getPayToOrganization
{
	my $self = shift;
	return $self->{payToOrganization};
}

sub addInsured
{
	my $self = shift;
	my $insuredListRef = $self->{insured};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Insured objects are allowed here'
			unless $_->isa('App::Billing::Claim::Insured');
		push(@{$insuredListRef}, $_);
	}
}

sub addDiagnosis
{
	my $self = shift;
	my $diagListRef = $self->{diagnosis};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Diagnosis objects are allowed here'
			unless $_->isa('App::Billing::Claim::Diagnosis');
		push(@{$diagListRef}, $_);
	}
}

sub addOtherItems
{
	my $self = shift;
	my $diagListRef = $self->{otherItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addAdjItems
{
	my $self = shift;
	my $diagListRef = $self->{adjItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addVoidItems
{
	my $self = shift;
	my $diagListRef = $self->{voidItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addSuppressedItems
{
	my $self = shift;
	my $diagListRef = $self->{suppressedItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addPolicy
{
	my ($self, $payer) = @_;
	my $policyListRef = $self->{policy};
	die 'only App::Billing::Claim::Payer objects are allowed here'
	unless $payer->isa('App::Billing::Claim::Payer');
	push(@{$policyListRef}, $payer);
}

sub addCopayItems
{
	my $self = shift;
	my $diagListRef = $self->{copayItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
		unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addCoInsurance
{
	my $self = shift;
	my $diagListRef = $self->{coInsuranceItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addDeductible
{
	my $self = shift;
	my $diagListRef = $self->{deductibleItems};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub addProcedure
{
	my $self = shift;
	my $diagListRef = $self->{procedures};
	foreach (@_)
	{
		die 'only App::Billing::Claim::Procedure objects are allowed here'
			unless $_->isa('App::Billing::Claim::Procedure');
		push(@{$diagListRef}, $_);
	}
}

sub setProgramName
{
	my ($self,$value) = @_;
	$self->{programName} = $value;
}

sub getProgramName
{
	my ($self) = @_;
	return $self->{programName};
}

sub getConditionRelatedToEmployment
{
	my ($self) = @_;
	return $self->{conditionRelatedToEmployment};
}

sub getConditionRelatedToAutoAccident
{
	my ($self) = @_;
	return $self->{conditionRelatedToAutoAccident};
}

sub getConditionRelatedToOtherAccident
{
	my ($self) = @_;
	return $self->{conditionRelatedToOtherAccident};
}

sub getConditionRelatedToAutoAccidentPlace
{
	my ($self) = @_;
	return $self->{conditionRelatedToAutoAccidentPlace};
}

sub setConditionRelatedToEmployment
{
	my ($self,$value) = @_;
	my $temp =
	{
		'Y' => 'Y',
		'N' => 'N',
	};
	$self->{conditionRelatedToEmployment} = $temp->{$value};
}

sub getClaimType
{
	my ($self) = @_;

	my $billSeq = [];
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = PRIMARY;
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = SECONDARY;
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  TERTIARY;
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = QUATERNARY;
	return $billSeq->[$self->{claimType}] + 0;
}

sub getBillSeq
{
	my ($self) = @_;
	return $self->{billSeq} + 0;
}

sub setBillSeq
{
	my ($self,$value) = @_;
	$self->{billSeq} = $value + 1;
}

sub getInvoiceType
{
	my ($self) = @_;
	return $self->{invoiceType};
}

sub setInvoiceType
{
	my ($self,$value) = @_;
	$self->{invoiceType} = $value;
}

sub getInvoiceSubtype
{
	my ($self) = @_;
	return $self->{invoiceSubtype};
}

sub setInvoiceSubtype
{
	my ($self,$value) = @_;
	$self->{invoiceSubtype} = $value;
}

sub getTotalItems
{
	my ($self) = @_;
	return $self->{totalItems};
}

sub setTotalItems
{
	my ($self,$value) = @_;
	$self->{totalItems} = $value;
}

sub setClaimType
{
	my ($self,$value) = @_;
	$self->{claimType} = $value;
}

sub setConditionRelatedToAutoAccident
{
	my ($self,$value) = @_;
	my $temp =
	{
		'Y' => 'Y',
		'N' => 'N',
	};
	$self->{conditionRelatedToAutoAccident} = $temp->{$value};
}

sub setConditionRelatedToOtherAccident
{
	my ($self,$value) = @_;
	my $temp =
	{
		'Y' => 'Y',
		'N' => 'N',
	};
	$self->{conditionRelatedToOtherAccident} = $temp->{$value};
}

sub setConditionRelatedToAutoAccidentPlace
{
	my ($self,$value) = @_;
	$self->{conditionRelatedToAutoAccidentPlace} = $value;
}

sub claimProcessor
{
	my $self = shift;
	return 'Envoy';
}

sub getPayerId
{
	my $self = shift;
	return $self->{payerId};	# implementation will come later
}

sub setPayerId
{
	my ($self,$value) = @_;
	$self->{payerId} = $value;	# implementation will come later
}

sub addError
{
	my ($self, $facility, $id, $msg) = @_;
	my $info = [$facility, $id, $msg];
	push(@{$self->{errors}}, $info);
}

sub haveErrors
{
	my $self =shift;
	my $errs = $self->{errors};
	return $#$errs >= 0 ? 1 : 0;
}

sub getErrors
{
	my $self =shift;
	return $self->{errors};
}

sub getError
{
	my ($self, $errorIdx) = @_;
	my $info = $self->{errors}->[$errorIdx];
	return @$info if wantarray();
	return "$info->[0]-$info->[1]: $info->[2]";
}

sub addWarning
{
	my ($self, $facility, $id, $msg) = @_;
	my $info = [$facility, $id, $msg];
	push(@{$self->{warnings}}, $info);
}

sub haveWarnings
{
	return scalar($_[0]->{warnings}) > 0 ? 1 : 0;
}

sub getWarnings
{
	return $_[0]->{warnings};
}

sub getWarning
{
	my ($self, $warningIdx) = @_;
	my $info = $self->{warnings}->[$warningIdx];
	return @$info if wantarray();
	return "$info->[0]-$info->[1]: $info->[2]";
}

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence =
	{
		JAN => '01', FEB => '02', MAR => '03', APR => '04',
		MAY => '05', JUN => '06', JUL => '07', AUG => '08',
		SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
	};

	$date =~ s/-//g;
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
}

sub convertDateToMMDDYYYYFromCCYYMMDD
{
	my ($self, $date) = @_;
	if ($date ne "")
	{
		return substr($date,4,2) . '/' . substr($date,6,2) . '/' . substr($date,0,4) ;
	}
	else
	{
		return "";
	}
}

sub getChangedTreatingDoctor
{
	my $self = shift;
	return $self->{changedTreatingDoctor};
}

sub setChangedTreatingDoctor
{
	my ($self,$value) = @_;
	$self->{changedTreatingDoctor} = $value;
}

sub printVal
{
	my ($self) = @_;
	foreach my $key (keys(%$self))
	{
		print " patient $key = " . $self->{$key} . " \n";
	}
}

1;
