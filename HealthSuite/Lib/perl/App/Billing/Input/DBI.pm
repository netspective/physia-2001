###############################################################
package App::Billing::Input::DBI;
################################################################
# At present rendringProvider and pay to provider are same.
use strict;
use Carp;
use DBI;
use App::Billing::Input::Driver;
use App::Billing::Claim;
use App::Billing::Claim::Person;
use App::Billing::Claim::Organization;
use App::Billing::Claim::Diagnosis;
use App::Billing::Claim::Procedure;
use App::Billing::Claim::Patient;
use App::Billing::Claim::Physician;
use App::Billing::Claim::Insured;
use App::Billing::Claim::Treatment;
use App::Billing::Claim::Address;
use App::Billing::Claim::Payer;
use App::Billing::Validator;
use App::Billing::Input::Validate::DBI;
use App::Billing::Validate::HCFA::Champus;
use App::Billing::Validate::HCFA::ChampVA;
use App::Billing::Validate::HCFA::Medicaid;
use App::Billing::Validate::HCFA::Medicare;
use App::Billing::Validate::HCFA::Other;
use App::Billing::Validate::HCFA::FECA;
use App::Billing::Validate::HCFA::HCFA1500;

use vars qw(@ISA);
@ISA = qw(App::Billing::Input::Driver);
use Devel::ChangeLog;

use vars qw(@CHANGELOG);

use constant INVOICESTATUS_SUBMITTED => 4;
# constant related with invoice attribute
use constant COLUMNINDEX_ATTRNAME => 1;
use constant COLUMNINDEX_VALUE_TEXT => 2;
use constant COLUMNINDEX_VALUE_TEXTB => 3;
use constant COLUMNINDEX_VALUE_INT => 4;
use constant COLUMNINDEX_VALUE_INTB => 5;
use constant COLUMNINDEX_VALUE_FLOAT => 6;
use constant COLUMNINDEX_VALUE_FLOATB => 7;
use constant COLUMNINDEX_VALUE_DATE => 8;
use constant COLUMNINDEX_VALUE_DATEEND => 9;
use constant COLUMNINDEX_VALUE_DATEA => 10;
use constant COLUMNINDEX_VALUE_DATEB => 11;
use constant COLUMNINDEX_VALUE_BLOCK => 12; # changed from COLUMNINDEX_VALUE_HTML
use constant PRE_STATUS => 3;
use constant CERTIFICATION_LICENSE => 500;
use constant PHYSICIAN_SPECIALTY => 540;
use constant CONTACT_METHOD_TELEPHONE => 10;
use constant ASSOCIATION_EMPLOYMENT_EMP => '(220,221,222,223,224,225,226)';
use constant ASSOCIATION_EMPLOYMENT_STUDENT => '(224)|(225)';
use constant AUTHORIZATION_PATIENT => 370;
use constant FACILITY_GROUP_NUMBER => 0;

use constant PRIMARY => 0;
use constant SECONDARY => 1;
use constant TERTIARY => 2;
use constant QUATERNARY => 3;

# use constant COLUMNINDEX_VALUE_HTML => 12;

#  Address constants
use constant COLUMNINDEX_ADDRESSNAME => 0;
use constant COLUMNINDEX_ADDRESS1 => 1;
use constant COLUMNINDEX_ADDRESS2 => 2;
use constant COLUMNINDEX_CITY => 3;
use constant COLUMNINDEX_STATE => 4;
use constant COLUMNINDEX_ZIPCODE => 5;
use constant COLUMNINDEX_COUNTRY => 6;


#  Insurance Record Type constants
use constant RECORDTYPE_CATEGORY => 0;
use constant RECORDTYPE_INSURANCE_PRODUCT => 1;
use constant RECORDTYPE_INSURANCE_PLAN => 2;
use constant RECORDTYPE_PERSONAL_COVERAGE => 3;


#  Bill Sequence constants
use constant BILLSEQ_INACTIVE => 99;
use constant BILLSEQ_PRIMARY_PAYER => 1;
use constant BILLSEQ_SECONDARY_PAYER => 2;
use constant BILLSEQ_TERTIARY_PAYER => 3;
use constant BILLSEQ_QUATERNARY_PAYER => 4;
use constant BILLSEQ_WORKERSCOMP_PAYER => 5;

#  Bill Party Type constants
use constant BILL_PARTY_TYPE_CLIENT => 0;
use constant BILL_PARTY_TYPE_INSURANCE => 3;
use constant BILL_PARTY_TYPE_PERSON => 1;
use constant BILL_PARTY_TYPE_ORGANIZATION => 2;

# Claim Type constants
use constant CLAIM_TYPE_SELF => 0;
use constant CLAIM_TYPE_INSURANCE => 1;
use constant CLAIM_TYPE_HMO_CAP => 2;
use constant CLAIM_TYPE_PPO => 3;
use constant CLAIM_TYPE_MEDICARE => 4;
use constant CLAIM_TYPE_MEDICAID => 5;
use constant CLAIM_TYPE_WORKCOMP => 6;
use constant CLAIM_TYPE_THIRD_PARTY => 7;
use constant CLAIM_TYPE_CHAMPUS => 8;
use constant CLAIM_TYPE_CHAMPVA => 9;
use constant CLAIM_TYPE_FECA_BLK_LUNG => 10;
use constant CLAIM_TYPE_BCBS => 11;
use constant CLAIM_TYPE_HMO_NONCAP => 12;


sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Input::Driver(@_);
	return bless $self,$type;
}

# Connect to the database.
sub connectDb
{
	my ($self, %params) = @_;

#	die 'DBI User Id is required' unless $params{UID};
#	die 'DBI connectStr is required' unless $params{PWD};
#	die 'DBI connectStr is required' unless $params{connectStr};

	$self->{'UID'} = $params{UID};
	$self->{'PWD'} = $params{PWD};
	$self->{'conectStr'} = $params{connectStr};

	my $user = $self->{'UID'};
	my $dsn = $self->{'conectStr'};
	my $password = $self->{'PWD'};

    # For Oracle 8
    $self->{dbiCon} = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 0 }) || die "Unable To Connect to Database... $dsn ";
}

# return the submitted invoices.
sub getTargetInvoices
{
	my ($self, $submittedStatus) = @_;
	my @row;
	my @allRecords;
	$submittedStatus = INVOICESTATUS_SUBMITTED if ($submittedStatus eq undef);
	my $statment = "";
	my $i;
	my $queryStatment = " select INVOICE_ID from invoice where INVOICE_STATUS = $submittedStatus ";
	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});

	$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	$i=0;
	while (@row = $sth->fetchrow_array())
	{
		$allRecords[$i] = $row[0];
		$i=$i+1;
	}
	return \@allRecords;
}

sub populateClaims
{
	my ($self, $claimList, %params) = @_;
	my $targetInvoices = [];
	my $i;
	my $currentClaim;
	my $populatedObjects;
	my $flag = 0;
	$self->{valMgr} = $params{valMgr};
	if ($params{dbiHdl} ne "")
	{
		$self->{dbiCon} = $params{dbiHdl};
	}
	else
	{
		$self->connectDb(%params);
	}

	if ($params{invoiceId} ne undef)
	{
		$targetInvoices->[0] = $params{invoiceId};
	} elsif (($params{invoiceIds} ne undef))
	{
		$targetInvoices = $params{invoiceIds} ;

	} else
	{
		$targetInvoices = $self->getTargetInvoices($params{invoiceStatus});
	}

	for $i (0..$#$targetInvoices)
	{
#	$objects[0] = $patient;
#	$objects[1] = $physian;
#	$objects[2] = $insured;
#	$objects[3] = $organization;
#	$objects[4] = $treatment;
#	$objects[5] = $claim;
		$populatedObjects = $self->assignInvoiceProperties($targetInvoices->[$i]);
		$currentClaim = $populatedObjects->[5];
		$self->populateTreatment($targetInvoices->[$i], $currentClaim, $populatedObjects->[4]);
		$self->populateItems($targetInvoices->[$i], $currentClaim);
		$self->setClaimProperties($targetInvoices->[$i], $currentClaim, $populatedObjects);
		$claimList->addClaim($currentClaim);
	}
	my $claims = $claimList->getClaim();
	for $i (0..$#$targetInvoices)
	{
		if ( $claims->[$i]->getStatus() <= PRE_STATUS)
		{
			$self->assignInvoicePreSubmit($claims->[$i],$targetInvoices->[$i]);
		}
	}

	if ($params{dbiHdl} eq "")
	{
		$self->dbDisconnect;
	}
	return 1;
}

sub assignInvoicePreSubmit
{
	my ($self, $claim, $invoiceId) = @_;

	$self->assignPatientInfo($claim,$invoiceId);
	$self->assignPatientAddressInfo($claim,$invoiceId);
	$self->assignPatientInsurance($claim,$invoiceId);
	$self->assignPatientEmployment($claim,$invoiceId);
	$self->assignProviderInfo($claim,$invoiceId);
	$self->assignPaytoAndRendProviderInfo($claim,$invoiceId);
	$self->assignReferralPhysician($claim,$invoiceId);
	$self->assignServiceFacility($claim,$invoiceId);
	$self->assignServiceBilling($claim,$invoiceId);
	$self->assignPayerInfo($claim,$invoiceId);
}

sub assignPatientInfo
{
	my ($self, $claim, $invoiceId) = @_;
	my $patient = $claim->getCareReceiver();
	my $queryStatment = "select name_last, name_middle, name_first, person_id, to_char(date_of_birth, \'dd-MON-yyyy\'), gender, marital_status from invoice, person where invoice_id = $invoiceId and person_id = invoice.client_id";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});

	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$patient->setLastName($row[0]);
	$patient->setMiddleInitial($row[1]);
	$patient->setFirstName($row[2]);
	$patient->setId($row[3]);
	$patient->setDateOfBirth($row[4]);
	$patient->setSex($row[5]);
	$patient->setStatus($row[6]);
}

sub assignPatientAddressInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $patient = $claim->getCareReceiver();
	my $patientAddress = $patient->getAddress();
	my $queryStatment = "select line1, line2, city, state, zip, country	from person_address, invoice where invoice_id = $invoiceId and parent_id = invoice.client_id and address_name = \'Home\'";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $colValText = 0 ;
	my $colValTextB = 1 ;
	my $colAttrnName = 2;
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$patientAddress->setAddress1($row[0]);
	$patientAddress->setAddress2($row[1]);
	$patientAddress->setCity($row[2]);
	$patientAddress->setState($row[3]);
	$patientAddress->setZipCode($row[4]);
	$patientAddress->setCountry($row[5]);
	my $inputMap =
		{
			CONTACT_METHOD_TELEPHONE . 'Home' => [ $patientAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValText],
			AUTHORIZATION_PATIENT . 'Signature Source' => [ $patient, \&App::Billing::Claim::Patient::setSignature, $colValTextB],
			AUTHORIZATION_PATIENT . 'Information Release' => [ $claim, \&App::Billing::Claim::setInformationReleaseIndicator, $colValText]
		};

	$queryStatment = "select value_text,value_textb, value_type || item_name from person_attribute, invoice where invoice_id = $invoiceId and parent_id = invoice.client_id";
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute()  or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while(@row = $sth->fetchrow_array())
	{
		if(my $attrInfo = $inputMap->{$row[$colAttrnName]})
		{
			my ($objInst, $method, $bindColumn) = @$attrInfo;
			if ($objInst ne "")
			{
				&$method($objInst, ($row[$bindColumn]));
			  }
		 }
	}
	$patient->setAddress($patientAddress);
	$claim->setCareReceiver($patient);
	$self->setProperPayer($invoiceId, $claim);
}

sub assignPatientInsurance
{
	my ($self, $claim, $invoiceId) = @_;
	my @insureds;
	my $patient = $claim->getCareReceiver();
	my $insured;
	my @row;
	my @ins;
	$ins[CLAIM_TYPE_SELF] = "OTHER";
	$ins[CLAIM_TYPE_INSURANCE] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_HMO_CAP] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_PPO] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_MEDICARE] = "MEDICARE";
	$ins[CLAIM_TYPE_MEDICAID] = "MEDICAID";
	$ins[CLAIM_TYPE_WORKCOMP] = "OTHER";
	$ins[CLAIM_TYPE_THIRD_PARTY] = "OTHER";
	$ins[CLAIM_TYPE_CHAMPUS] = "CHAMPUS";
	$ins[CLAIM_TYPE_CHAMPVA] = "CHAMPVA";
	$ins[CLAIM_TYPE_FECA_BLK_LUNG] = "FECA";
	$ins[CLAIM_TYPE_BCBS] = "OTHER";
	$ins[CLAIM_TYPE_HMO_NONCAP] = "GROUP HEALTH PLAN";

	$insureds[0] = $claim->{insured}->[0];
	$insureds[1] = $claim->{insured}->[1];
	$insureds[2] = $claim->{insured}->[2];
	$insureds[3] = $claim->{insured}->[3];

	my $no = $claim->getBillSeq();
	my $queryStatment;
	my $sth;
	my $billSeq = [];
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = PRIMARY;
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = SECONDARY;
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  TERTIARY;
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = QUATERNARY;

	if ($claim->getStatus() ne INVOICESTATUS_SUBMITTED)  # here populate only the current insurer for the bill
	{
		$queryStatment = "select org.name_primary, ins.rel_to_insured, invoice_billing.BILL_SEQUENCE, ins.group_number,
									ins.insured_id, to_char(coverage_begin_date,\'dd-MON-yyyy\') , to_char(coverage_end_date, \'dd-MON-yyyy\'), GROUP_NAME,
									ins.ins_type, Ins.member_number
							from org, insurance ins, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .")" .
								" and invoice_billing.bill_ins_id = ins.ins_internal_id
								and ins.ins_org_id = org.org_id
								and invoice_billing.BILL_SEQUENCE = $no";
		$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
		# do the execute statement
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
#		$claim->setProgramName($ins[$row[8]]);
		$patient->setRelationshipToInsured($row[1]);
		$insured = $claim->{insured}->[$claim->getClaimType];
		$insured->setInsurancePlanOrProgramName($row[0]);
		$insured->setRelationshipToInsured($row[1]);
		$insured->setPolicyGroupOrFECANo($row[3]);
		$insured->setId($row[4]);
		$insured->setEffectiveDate($row[5]);
		$insured->setTerminationDate($row[6]);
		$insured->setPolicyGroupName($row[7]);
		$insured->setBillSequence($row[2]);
		$insured->setSsn($row[9]);
	}

	$queryStatment = "select org.name_primary, ins.group_number, ins.rel_to_insured, Invoice_billing.bill_sequence,
					ins.insured_id, to_char(coverage_begin_date, \'dd-MON-yyyy\'), to_char(coverage_end_date,\'dd-MON-yyyy\'), ins.member_number
					from org, insurance ins, invoice_billing
					where invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION . ")" .
						" and invoice_billing.invoice_item_id is NULL
						and invoice_billing.bill_ins_id = ins.ins_internal_id
						and invoice_id = $invoiceId
						and ins.ins_org_id = org.org_id
						and Invoice_billing.bill_sequence in (" . BILLSEQ_PRIMARY_PAYER . "," . BILLSEQ_SECONDARY_PAYER .
						"," . BILLSEQ_TERTIARY_PAYER . "," . BILLSEQ_QUATERNARY_PAYER . ")
						and Invoice_billing.bill_sequence <> $no ";
	$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while (@row = $sth->fetchrow_array())
	{
		$insured = $insureds[$billSeq->[$row[3]+0]];
		if ($insured ne "")
		{
			if (($claim->getStatus() ne INVOICESTATUS_SUBMITTED) || ($no ne ($row[3]+ 0)))
			# ($no ne ($row[3]+ 0)) other insureds of submit.
			{
				$insured->setInsurancePlanOrProgramName($row[0]);
				$insured->setPolicyGroupOrFECANo($row[1]);
				$insured->setRelationshipToInsured($row[2]);
				$insured->setBillSequence($row[3]);
				$insured->setId($row[4]);
				$insured->setEffectiveDate($row[5]);
				$insured->setTerminationDate($row[6]);
				$insured->setSsn($row[7]);
			}
		}
	}
	$self->assignOtherInsuredInfo($claim,$invoiceId);
	$self->assignOtherInsuredAddressInfo($claim,$invoiceId);
}

sub assignOtherInsuredInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $insureds = $claim->{insured};
	my $insured;
	my $queryStatment;
	my $sth;
	my $no = $claim->getBillSeq();
	my $no1 = $claim->getClaimType();

	foreach $insured (@$insureds)
	{
		if ($insured ne "")
		{
			# ($no ne ($row[3]+ 0)) other insureds of submit. but all pre submit will b covered.
			if (($claim->getStatus() ne INVOICESTATUS_SUBMITTED) || ($insured ne $insureds->[$no1]))
			{
				my $insuredId = $insured->getId();
				if ($insuredId ne "")
				{
					$queryStatment = "select name_last, name_middle, name_first, to_char(date_of_birth, \'dd-MON-yyyy\'), gender,marital_status, ssn, person_id from  person where person.person_id = \'$insuredId\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					my @row = $sth->fetchrow_array();
					$insured->setLastName($row[0]);
					$insured->setMiddleInitial($row[1]);
					$insured->setFirstName($row[2]);
					$insured->setDateOfBirth($row[3]);
					$insured->setSex($row[4]);
					$insured->setStatus($row[5]);
#					$insured->setSsn($row[6]); this is now populated in patient insurance with ins.member_number
					$insured->setId($row[7]);

					$queryStatment = "select attr.value_text
							from insurance, insurance_attribute attr, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.bill_sequence = " . $insured->getBillSequence() .
								" and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION . ")" .
								" and invoice_billing.bill_ins_id = insurance.ins_internal_id
								and attr.parent_id = parent_ins_id
								and attr.item_name = \'HMO-PPO/Indicator\'";

					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$insured->setHMOIndicator($row[0]);

					$queryStatment = "select value_text from person_attribute where parent_id = \'$insuredId\' and value_type between 220 and 225";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
						# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$insured->setEmployerOrSchoolName($row[0]);
		
					$queryStatment = "select extra
							from insurance, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.bill_sequence = " . $insured->getBillSequence().
								" and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION . ")" .
								" and invoice_billing.bill_ins_id = insurance.ins_internal_id";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$insured->setTypeCode($row[0]);
				}
			}
		}
	}
}

sub assignOtherInsuredAddressInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $insureds = $claim->{insured};
	my $insured;
	my $no = $claim->getClaimType();
	foreach $insured (@$insureds)
	{
		if (($claim->getStatus() ne INVOICESTATUS_SUBMITTED) || ($insured ne $insureds->[$no]))
		{
			my $insuredAddress = $insured->getAddress();
			my $id = $insured->getId();
			my $queryStatment = "select line1, line2, city, state, zip, country from person_address where parent_id = \'$id\' and address_name = \'Home\'";
			my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
			# do the execute statement
			$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
			my @row = $sth->fetchrow_array();

			$insuredAddress->setAddress1($row[0]);
			$insuredAddress->setAddress2($row[1]);
			$insuredAddress->setCity($row[2]);
			$insuredAddress->setState($row[3]);
			$insuredAddress->setZipCode($row[4]);
			$insuredAddress->setCountry($row[5]);
			my $iid = $insured->getId();
			$queryStatment = "select value_text from person_attribute where parent_id = \'$iid\' and Item_name = \'Home\' and value_type = " . CONTACT_METHOD_TELEPHONE;
			$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
			# do the execute statement
			$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();
			$insuredAddress->setTelephoneNo($row[0]);
#			$insured->setAddress($insuredAddress);
		}
	}
}

# *************************************
sub assignPatientEmployment
{
	my ($self, $claim, $invoiceId) = @_;
	my @row;
	my $patient = $claim->getCareReceiver();
	my $queryStatment = "select pa.value_type from person_attribute pa , invoice where pa.value_type in " . ASSOCIATION_EMPLOYMENT_EMP . " and invoice_id = $invoiceId and invoice.client_id = pa.parent_id";
	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$patient->setEmploymentStatus($row[0]);
	my $a = ASSOCIATION_EMPLOYMENT_STUDENT;
	$patient->setStudentStatus($row[0] =~ /$a/ ? $row[0] : "");
}
# *************************************

sub assignProviderInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $renderingProvider = $claim->getRenderingProvider();
	my $queryStatment = "select  name_last, name_middle,  name_first, person_id from person, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and person.person_id = trans.provider_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $orgId;
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$renderingProvider->setLastName($row[0]);
	$renderingProvider->setMiddleInitial($row[1]);
	$renderingProvider->setFirstName($row[2]);
	$renderingProvider->setId($row[3]);
	my $pId = $row[3];
	my $renderingProviderAddress = $renderingProvider->getAddress();
	$queryStatment = "select line1, line2, city, state, zip, country	from person_address where parent_id = \'$pId\' and address_name = \'Home\'";
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$renderingProviderAddress->setAddress1($row[0]);
	$renderingProviderAddress->setAddress2($row[1]);
	$renderingProviderAddress->setCity($row[2]);
	$renderingProviderAddress->setState($row[3]);
	$renderingProviderAddress->setZipCode($row[4]);
	$renderingProviderAddress->setCountry($row[5]);
	$renderingProvider->setAddress($renderingProviderAddress);
   $claim->setRenderingProvider($renderingProvider);
}

sub assignPaytoAndRendProviderInfo
{
	my ($self, $claim, $invoiceId) = @_;
	my $colValText = 0;
	my $colValTextB = 1;
	my $colAttrnName = 2;
	my $renderingProvider = $claim->getRenderingProvider();
	my $payToProvider = $claim->getPayToProvider();
	my $id = $renderingProvider->getId();
	my @row;
	my $inputMap =
		{
			CERTIFICATION_LICENSE . 'Tax ID' => [ [$renderingProvider,  $renderingProvider, $payToProvider, $payToProvider], [\&App::Billing::Claim::Physician::setFederalTaxId, \&App::Billing::Claim::Physician::setTaxTypeId, \&App::Billing::Claim::Physician::setFederalTaxId, \&App::Billing::Claim::Physician::setTaxTypeId  ], [$colValText, $colValTextB, $colValText, $colValTextB]],
			PHYSICIAN_SPECIALTY . 'Primary' => [ [$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSpecialityId,\&App::Billing::Claim::Physician::setSpecialityId], [$colValTextB, $colValTextB]],
			CERTIFICATION_LICENSE . 'UPIN' => [ [$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setPIN,\&App::Billing::Claim::Physician::setPIN], [$colValText, $colValText]],
		};
	# do the execute statement
	my $queryStatment = "select value_text , value_textB, value_type || item_name  from person_attribute where parent_id = \'$id\' ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});

	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while(@row = $sth->fetchrow_array())
	{
		if(my $attrInfo = $inputMap->{$row[$colAttrnName]})
		{
			my ($objInst, $method, $bindColumn) = @$attrInfo;
			if ($objInst ne "")
			{
				if (ref $method eq 'ARRAY')
				{
					if (ref $objInst eq 'ARRAY')
					{
						for my $methodNum (0..$#$method)
						{
							my $functionRef = $method->[$methodNum];
							&$functionRef($objInst->[$methodNum], ($row[$bindColumn->[$methodNum]]));
						}
					}
					else
						{
							for my $methodNum (0..$#$method)
							{
								my $functionRef = $method->[$methodNum];
								&$functionRef($objInst, ($row[$bindColumn->[$methodNum]]));
							}
						}
				}
				else
					{
						&$method($objInst, ($row[$bindColumn]));
					}
			  }
		 }
	}
	$queryStatment = "select value_textB from person_attribute,invoice where parent_id = invoice.client_id and item_name = \'Provider Assignment\' and invoice.invoice_id = $invoiceId and value_type = " . AUTHORIZATION_PATIENT;
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$renderingProvider->setAssignIndicator($row[0]);
	$payToProvider->setAssignIndicator($row[0]);
	$claim->setRenderingProvider($renderingProvider);
	$claim->setPayToProvider($payToProvider);
}

sub assignReferralPhysician
{
	my ($self, $claim, $invoiceId) = @_;

	my $treatment = $claim->{treatment};
	my $queryStatment = "select name_first, name_last, name_middle, person_id from person, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and person.person_id = trans.data_text_a";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute()  or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$treatment->setRefProviderFirstName($row[0]);
	$treatment->setRefProviderLastName($row[1]);
	$treatment->setRefProviderMiName($row[2]);
	$treatment->setId($row[3]);
	$queryStatment = "select value_text from person_attribute where parent_id = \'$row[3]\' and item_name = \'UPIN\' and value_type = " . CERTIFICATION_LICENSE;
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$treatment->setIDOfReferingPhysician($row[0]);
}

sub assignServiceFacility
{
	my ($self, $claim, $invoiceId) = @_;
 
	my $renderingOrganization = $claim->getRenderingOrganization();
	my $queryStatment = "select org.org_id, org.name_primary from org, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and org.org_id = trans.service_facility_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$renderingOrganization->setId($row[0]);
	$renderingOrganization->setName($row[1]);
	
	my $renderingOrganizationAdress = $renderingOrganization->getAddress();
	$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = \'$row[0]\' and address_name = \'Mailing\'";
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$renderingOrganizationAdress->setAddress1($row[0]);
	$renderingOrganizationAdress->setAddress2($row[1]);
	$renderingOrganizationAdress->setCity($row[2]);
	$renderingOrganizationAdress->setState($row[3]);
	$renderingOrganizationAdress->setZipCode($row[4]);
	$renderingOrganizationAdress->setCountry($row[5]);
	$claim->setRenderingOrganization($renderingOrganization);
}

sub assignTransProvider
{
	my ($self, $claim, $invoiceId) = @_;

	my $queryStatment = " select person_id, Complete_name from person where person_id = 
											(select trans.provider_id from transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction)";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$claim->setTransProviderId($row[0]);
	$claim->setTransProviderName($row[1]);
}

sub assignServiceBilling
{
	my ($self, $claim, $invoiceId) = @_;
	my $payToOrganization = $claim->getPayToOrganization();
	my $queryStatment = "select org.org_id, org.name_primary, org.Tax_id from org, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and org.org_id = trans.billing_facility_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $orgId;
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$orgId = $row[0];
	$payToOrganization->setId($row[0]);
	$payToOrganization->setName($row[1]);
	$payToOrganization->setFederalTaxId($row[2]);
	$queryStatment = "select value_text from org_attribute, invoice where parent_id = \'$row[0]\' and value_type = " . FACILITY_GROUP_NUMBER;
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$payToOrganization->setGRP($row[0]);
	my $payToOrganizationAddress = new App::Billing::Claim::Address;
	$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = \'$orgId\' and address_name = \'Mailing\'";
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$payToOrganizationAddress->setAddress1($row[0]);
	$payToOrganizationAddress->setAddress2($row[1]);
	$payToOrganizationAddress->setCity($row[2]);
	$payToOrganizationAddress->setState($row[3]);
	$payToOrganizationAddress->setZipCode($row[4]);
	$payToOrganizationAddress->setCountry($row[5]);
	$payToOrganization->setAddress($payToOrganizationAddress);

	$claim->setPayToOrganization($payToOrganization);
}

sub assignPayerInfo
{
	my ($self, $claim, $invoiceId) = @_;

	$self->assignPolicy($claim, $invoiceId);
	$self->setProperPayer($invoiceId, $claim);
}

sub assignPolicy
{
	my ($self, $claim, $invoiceId) = @_;
	my $insOrgId;
	my $seqNum;
	my @row;
	my $payers = $claim->{policy};
	my $payer;
	my $payerAddress;
	my $no = $claim->getBillSeq();
	my $billSeq = [];
	my $queryStatment;
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = PRIMARY;
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = SECONDARY;
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  TERTIARY;
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = QUATERNARY;

	my $queryStatmentInvSubtype = "select invoice.invoice_subtype from invoice where invoice_id = $invoiceId";

	my $sthInvSubtype = $self->{dbiCon}->prepare(qq {$queryStatmentInvSubtype});
	$sthInvSubtype->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sthInvSubtype->fetchrow_array();
	my $invoiceSubtype = $row[0];

	if($invoiceSubtype == CLAIM_TYPE_THIRD_PARTY)
	{
		$queryStatment = "select invoice_billing.BILL_TO_ID, invoice_billing.bill_sequence, invoice_billing.bill_amount,
				invoice_billing.bill_party_type	
				from invoice_billing
				where invoice_billing.invoice_id = $invoiceId
					and invoice_billing.invoice_item_id is NULL
					and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION . ")" .
					"and invoice_billing.bill_sequence in (" . BILLSEQ_PRIMARY_PAYER . "," . BILLSEQ_SECONDARY_PAYER .
					"," . BILLSEQ_TERTIARY_PAYER . "," . BILLSEQ_QUATERNARY_PAYER .	")";
	}
	else
	{
		$queryStatment = "select invoice_billing.BILL_TO_ID, invoice_billing.bill_sequence, invoice_billing.bill_amount,
				invoice_billing.bill_party_type	
				from insurance, invoice_billing
				where invoice_billing.invoice_id = $invoiceId
					and invoice_billing.bill_ins_id = insurance.ins_internal_id
					and invoice_billing.invoice_item_id is NULL
					and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . ")" .
					"and invoice_billing.bill_sequence in (" . BILLSEQ_PRIMARY_PAYER . "," . BILLSEQ_SECONDARY_PAYER .
					"," . BILLSEQ_TERTIARY_PAYER . "," . BILLSEQ_QUATERNARY_PAYER .	")";
	}
	my $sth1 = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $sth;
	my @row1;
	my $recordType;
	my $colValText = 1;
	# do the execute statement
	$sth1->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while (@row1 = $sth1->fetchrow_array())
	{
		$seqNum = $row1[1] + 0;
		$payer = $payers->[$billSeq->[$seqNum]];
		if ($payer ne "")
		{
			if (($claim->getStatus() ne INVOICESTATUS_SUBMITTED) || ($seqNum ne $no))
			{
				$payerAddress = $payer->getAddress();
				$payer->setAmountPaid($row1[2]);
				$payer->setBillSequence($row1[1]);
				if ($row1[3] == BILL_PARTY_TYPE_INSURANCE ) 
				{
					$insOrgId = $row1[0];
					$queryStatment = "select name_primary as payer_name, org_id as payer_id from org where org_id = \'$insOrgId\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payer->setName($row[0]);
					$payer->setId($row[1]);
	
					my $inputMap =
					{
						'Champus Branch' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorBranch, $colValText],
						'Champus Grade' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorGrade, $colValText],
						'Champus Status' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorStatus, $colValText],
						'Contact Method/Telepone/Primary' => [$payerAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValText],
					};
					if ($payer->getBillSequence() ne "")
					{
						$queryStatment = "select item_name, ia.value_text
							from insurance ins, insurance_attribute ia, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.bill_party_type = " . BILL_PARTY_TYPE_INSURANCE .
								" and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_sequence = " . $payer->getBillSequence() .
								" and ins.ins_internal_id = invoice_billing.bill_ins_id
								and ia.parent_id = ins.parent_ins_id
								and (ia.item_name like \'Champus%\'
									or ia.item_name like \'Contact Method/Telephone%\')";

						$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
						# do the execute statement
						$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
						my $colAttrnName = 0;
						while(@row = $sth->fetchrow_array())
						{
							if(my $attrInfo = $inputMap->{$row[$colAttrnName]})
							{
								my ($objInst, $method, $bindColumn) = @$attrInfo;
								if ($objInst ne "")
								{
									if (ref $method eq 'ARRAY')
									{
										if (ref $objInst eq 'ARRAY')
										{
											for my $methodNum (0..$#$method)
											{
												my $functionRef = $method->[$methodNum];
												&$functionRef($objInst->[$methodNum], ($row[$bindColumn->[$methodNum]]));
											}
										}
										else
											{
												for my $methodNum (0..$#$method)
												{
													my $functionRef = $method->[$methodNum];
													&$functionRef($objInst, ($row[$bindColumn->[$methodNum]]));
												}	
											}
									}
									else
									{
										&$method($objInst, ($row[$bindColumn]));
									}
							  	}
						 	}
						}
					}
					$queryStatment = "select line1, line2, city, state, zip, country
							from insurance_address
							where parent_id = (select parent_ins_id
										from invoice_billing , insurance
										where invoice_id = $invoiceId
											and ins_internal_id = bill_ins_id
											and bill_party_type = " . BILL_PARTY_TYPE_INSURANCE .
											" and invoice_item_id is NULL
											and invoice_billing.bill_sequence = " . $payer->getBillSequence() . ")";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payerAddress->setAddress1($row[0]);
					$payerAddress->setAddress2($row[1]);
					$payerAddress->setCity($row[2]);
					$payerAddress->setState($row[3]);
					$payerAddress->setZipCode($row[4]);
					$payerAddress->setCountry($row[5]);
					$payer->setAddress($payerAddress);
				}
				elsif ($row1[3] == BILL_PARTY_TYPE_PERSON)
				{
					my $pid = $row1[0];
					
					$queryStatment = "select complete_name from person where person_id = \'$pid\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payer->setName($row[0]);

			 		$queryStatment = "select line1, line2, city, state, zip, country from person_address where parent_id = \'$pid\' and address_name = \'Home\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();

					$payerAddress->setAddress1($row[0]);
					$payerAddress->setAddress2($row[1]);
					$payerAddress->setCity($row[2]);
					$payerAddress->setState($row[3]);
					$payerAddress->setZipCode($row[4]);
					$payerAddress->setCountry($row[5]);
					$queryStatment = "select value_text from person_attribute where parent_id = \'$pid\' and Item_name = \'Home\' and value_type = " . CONTACT_METHOD_TELEPHONE;
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payerAddress->setTelephoneNo($row[0]);
				}
				elsif ($row1[3] == BILL_PARTY_TYPE_ORGANIZATION)
				{

					my $oid = $row1[0];
					$queryStatment = "select name_primary , org_id  from org where org_id = \'$oid\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
			
					$payer->setId($row[1]);
					$payer->setName($row[0]);
			 		$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = \'$oid\' and address_name = \'Mailing\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payerAddress->setAddress1($row[0]);
					$payerAddress->setAddress2($row[1]);
					$payerAddress->setCity($row[2]);
					$payerAddress->setState($row[3]);
					$payerAddress->setZipCode($row[4]);
					$payerAddress->setCountry($row[5]);
					$queryStatment = "select value_text from org_attribute where parent_id = \'$oid\' and Item_name = \'Contact Method/Telepone/Primary\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payerAddress->setTelephoneNo($row[0]);
				}
			}
		}
	}
}

sub assignInvoiceProperties
{
	my ($self,$invoiceId) = @_;
	my $patient = new App::Billing::Claim::Patient;
	my $insured = new App::Billing::Claim::Insured;
	my $insured2 = new App::Billing::Claim::Insured;
	$insured2->setAddress(new App::Billing::Claim::Address);
	my $insured3 = new App::Billing::Claim::Insured;
	$insured3->setAddress(new App::Billing::Claim::Address);
	my $insured4 = new App::Billing::Claim::Insured;
	$insured4->setAddress(new App::Billing::Claim::Address);
	my $treatment = new App::Billing::Claim::Treatment;
	my $claim = new App::Billing::Claim;
	my $patientAddress = new App::Billing::Claim::Address;
	my $renderingProviderAddress = new App::Billing::Claim::Address;
	my $referringProviderAddress = new App::Billing::Claim::Address;
	my $referringOrganizationAddress = new App::Billing::Claim::Address;
	my $payToProviderAddress = new App::Billing::Claim::Address;
	my $payToOrganizationAddress = new App::Billing::Claim::Address;
	my $insuredAddress = new App::Billing::Claim::Address;
	my $payToProvider = new App::Billing::Claim::Physician;
	my $payToOrganization = new App::Billing::Claim::Organization;
	my $renderingProvider = new App::Billing::Claim::Physician;
	my $renderingOrganization = new App::Billing::Claim::Organization;
	my $referringProvider = new App::Billing::Claim::Physician;
	my $referringOrganization = new App::Billing::Claim::Organization;
	my $legalRepresentator = new App::Billing::Claim::Person;
	my $payer = new App::Billing::Claim::Payer;
	my $payerAddress = new App::Billing::Claim::Address;
	my $payer2 = new App::Billing::Claim::Payer;
	my $payer3 = new App::Billing::Claim::Payer;
	my $payer4 = new App::Billing::Claim::Payer;
	$insured->setAddress($insuredAddress);
	$payer->setAddress($payerAddress);
	$payer2->setAddress(new App::Billing::Claim::Address);
	$payer3->setAddress(new App::Billing::Claim::Address);
	$payer4->setAddress(new App::Billing::Claim::Address);

	my @objects;
	my @row;

	my $inputMap =
	{
		'Insurance/Primary/Type' => [ [$claim, $insured], [\&App::Billing::Claim::setProgramName,\&App::Billing::Claim::Insured::setTypeCode], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insured/Personal/SSN'  => [$insured, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Patient/Name/Last' => [$patient, [\&App::Billing::Claim::Person::setLastName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Name/First' => [$patient, \&App::Billing::Claim::Person::setFirstName,  COLUMNINDEX_VALUE_TEXT],
		'Patient/Name/Middle' => [$patient, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/DOB' => [$patient, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Patient/Personal/DOD' => [$patient, \&App::Billing::Claim::Person::setDateOfDeath, COLUMNINDEX_VALUE_DATE],
		'Patient/Death/Indicator' => [$patient, \&App::Billing::Claim::Person::setDeathIndicator, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/Gender' => [$patient, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insured/Name/Last'	=> [$insured, [\&App::Billing::Claim::Person::setLastName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insured/Name/First' => [$insured, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insured/Name/Middle' => [$insured, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insured/Contact/Home Phone' => [$insuredAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Patient/Insured/Relationship' => [[$patient, $insured], [\&App::Billing::Claim::Patient::setRelationshipToInsured, \&App::Billing::Claim::Insured::setRelationshipToInsured], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Patient/Contact/Home Phone' => [$patientAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/Marital Status' => [$patient, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Student/Status' => [$patient, \&App::Billing::Claim::Person::setStudentStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Employment/Status' => [$patient, \&App::Billing::Claim::Person::setEmploymentStatus, COLUMNINDEX_VALUE_TEXT],
		'Condition/Related To' => [$claim, [ \&App::Billing::Claim::setConditionRelatedTo, \&App::Billing::Claim::setConditionRelatedToAutoAccidentPlace ], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/Primary/Group Number' => [$insured, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insured/Personal/DOB' => [$insured, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insured/Personal/Gender' => [$insured, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insured/Employer/Name'	=> [$insured, [ \&App::Billing::Claim::Insured::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insured/School/Name'	=> [$insured, [ \&App::Billing::Claim::Insured::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/Primary/Name' => [[$insured,$payer], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName,\&App::Billing::Claim::Payer::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Payer/Amount' => [$payer, \&App::Billing::Claim::Payer::setAmountPaid, COLUMNINDEX_VALUE_TEXT],
		'Insurance/Secondary/x' =>[$insured, \&App::Billing::Claim::Insured::setAnotherHealthBenefitPlan, COLUMNINDEX_VALUE_TEXT],
		'Patient/Signature' => [$patient,   \&App::Billing::Claim::Patient::setSignature,COLUMNINDEX_VALUE_TEXTB],
		'Patient/Illness/Dates' => [$treatment, [ \&App::Billing::Claim::Treatment::setDateOfIllnessInjuryPregnancy, \&App::Billing::Claim::Treatment::setDateOfSameOrSimilarIllness ], [COLUMNINDEX_VALUE_DATEEND,COLUMNINDEX_VALUE_DATE]],
		'Patient/Disability/Dates'  => [$treatment, [ \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkFrom, \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkTo ], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],
		'Ref Provider/Name/Last' =>[$treatment, [\&App::Billing::Claim::Treatment::setRefProviderLastName,\&App::Billing::Claim::Treatment::setId],[ COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Ref Provider/Name/First' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderFirstName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Name/Middle' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderMiName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Identification' => [$treatment, [\&App::Billing::Claim::Treatment::setIDOfReferingPhysician,\&App::Billing::Claim::Treatment::setReferingPhysicianState], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Ref Provider/ID Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setReferingPhysicianIDIndicator, COLUMNINDEX_VALUE_TEXT],
		'Patient/Hospitalization/Dates' => [$treatment,[ \&App::Billing::Claim::Treatment::setHospitilizationDateFrom, \&App::Billing::Claim::Treatment::setHospitilizationDateTo], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],
		'Laboratory/Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLab, COLUMNINDEX_VALUE_TEXT],
		'Laboratory/Charges' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLabCharges, COLUMNINDEX_VALUE_TEXT],
		'Medicaid/Resubmission' => [$treatment, [ \&App::Billing::Claim::Treatment::setMedicaidResubmission, \&App::Billing::Claim::Treatment::setResubmissionReference], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Prior Authorization Number' => [$treatment, \&App::Billing::Claim::Treatment::setPriorAuthorizationNo, COLUMNINDEX_VALUE_TEXT],
		'Provider/Tax ID' => [[$payToProvider, $renderingProvider, $payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setFederalTaxId ,\&App::Billing::Claim::Physician::setFederalTaxId,\&App::Billing::Claim::Physician::setTaxTypeId,\&App::Billing::Claim::Physician::setTaxTypeId ], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Control Number' => [$patient, \&App::Billing::Claim::Patient::setAccountNo, COLUMNINDEX_VALUE_TEXT],
		'Assignment of Benefits' => [[$claim, $payer], [\&App::Billing::Claim::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment], [COLUMNINDEX_VALUE_INT,COLUMNINDEX_VALUE_INT]],
		'BCBS/Plan Code' => [$claim, \&App::Billing::Claim::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Service Provider/Facility/Service' => [[$renderingOrganization, $renderingOrganization], [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Service Provider/Facility/Billing' =>[$payToOrganization, [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Organization/Type' => [$renderingOrganization, \&App::Billing::Claim::Organization::setOrganizationType, COLUMNINDEX_VALUE_TEXT],
		'Service Provider/Facility/Billing/Contact' => [[$renderingProvider, $renderingProviderAddress], [\&App::Billing::Claim::Physician::setContact,  \&App::Billing::Claim::Address::setTelephoneNo],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Site ID' => [$payToProvider, \&App::Billing::Claim::Physician::setSiteId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Medicare ID' => [	$payToProvider, \&App::Billing::Claim::Physician::setMedicareId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Medicaid ID' => [ $payToProvider, \&App::Billing::Claim::Physician::setMedicaidId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Champus ID' => [ $payToProvider, \&App::Billing::Claim::Physician::setChampusId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Specialty' => [ [$renderingProvider,$payToProvider], [\&App::Billing::Claim::Physician::setSpecialityId,\&App::Billing::Claim::Physician::setSpecialityId], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB]],
		'TPO Participation/Indicator' => [$patient, \&App::Billing::Claim::Patient::setTPO, COLUMNINDEX_VALUE_TEXT],
		'Patient/Legal Rep/Indicator' => [ $patient, \&App::Billing::Claim::Patient::setlegalIndicator, COLUMNINDEX_VALUE_TEXT],
		'Multiple/Indicator' => [$patient, \&App::Billing::Claim::Patient::setMultipleIndicator, COLUMNINDEX_VALUE_TEXT],
		'Claim Filing/Indicator' => [$claim, \&App::Billing::Claim::setFilingIndicator, COLUMNINDEX_VALUE_TEXT],
		'HMO-PPO/Indicator' => [$insured, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'HMO-PPO/ID' => [$insured, \&App::Billing::Claim::Insured::setHMOId, COLUMNINDEX_VALUE_TEXT],
		'Symptom/Indicator' => [ $claim, \&App::Billing::Claim::setSymptomIndicator, COLUMNINDEX_VALUE_TEXT],
		'Accident Hour' => [ $claim, \&App::Billing::Claim::setAccidentHour, COLUMNINDEX_VALUE_TEXT],
		'Responsibility Indicator' => [ $claim, \&App::Billing::Claim::setResponsibilityIndicator, COLUMNINDEX_VALUE_TEXT],
		'Symptom/Indicator/External Cause' => [	$claim, \&App::Billing::Claim::setSymptomExternalCause, COLUMNINDEX_VALUE_TEXT],
		'Information Release/Indicator' => [ $claim, [\&App::Billing::Claim::setInformationReleaseIndicator, \&App::Billing::Claim::setInformationReleaseDate], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_DATE]],
#		'Information/Release/Date' => [$claim, \&App::Billing::Claim::setInformationReleaseDate, COLUMNINDEX_VALUE_DATE],
		'Disability/Type' => [ $claim, \&App::Billing::Claim::setDisabilityType, COLUMNINDEX_VALUE_TEXT],
		'Provider/Assign Indicator' => [ $payToProvider, \&App::Billing::Claim::Physician::setAssignIndicator, COLUMNINDEX_VALUE_TEXT],
		'Provider/Signature/Indicator' => [ $payToProvider, \&App::Billing::Claim::Physician::setSignatureIndicator, COLUMNINDEX_VALUE_TEXT],
		'Provider/Signature/Date' => [ $payToProvider, \&App::Billing::Claim::Physician::setSignatureDate, COLUMNINDEX_VALUE_DATE],
		'Documentation/Indicator' => [ $payToProvider, \&App::Billing::Claim::Physician::setDocumentationIndicator, COLUMNINDEX_VALUE_TEXT],
		'Documentation/Type' => [ $payToProvider, \&App::Billing::Claim::Physician::setDocumentationType, COLUMNINDEX_VALUE_TEXT],
		'Special Program/Indicator' => [$claim, \&App::Billing::Claim::setSpProgramIndicator, COLUMNINDEX_VALUE_TEXT],
		'Last Seen/Date' => [$patient, \&App::Billing::Claim::Patient::setLastSeenDate, COLUMNINDEX_VALUE_DATE],
		'Documentation/Date' => [$claim, \&App::Billing::Claim::setdateDocSent, COLUMNINDEX_VALUE_DATE],
		'Anesthesia-Oxygen/Minutes' => [$claim, \&App::Billing::Claim::setAnesthesiaOxygenMinutes, COLUMNINDEX_VALUE_TEXT],
		'HGB-HCT/Date' => [	$claim, \&App::Billing::Claim::setHGBHCTDate, COLUMNINDEX_VALUE_DATE],
		'Serum Creatine/Date' => [$claim, \&App::Billing::Claim::setSerumCreatineDate, COLUMNINDEX_VALUE_DATE],
		'Rendering/Provider/Tax ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setFederalTaxId, COLUMNINDEX_VALUE_TEXT],
      'Rendering/Provider/ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setProviderId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name Qualifier' => [$claim, \&App::Billing::Claim::setQualifier, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name/First' => [$renderingProvider, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name/Last' => [$renderingProvider, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Name/Middle' => [$renderingProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Pay To Provider/Name/First' => [$payToProvider,\&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Pay To Provider/Name/Last' => [$payToProvider, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Pay To Provider/Name/Middle' => [$payToProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Pay To Provider/Specialty' => [$payToProvider, \&App::Billing::Claim::Physician::setSpecialityId, COLUMNINDEX_VALUE_TEXTB],
		'Provider/Network ID' => [ $renderingProvider, \&App::Billing::Claim::Physician::setNetworkId, COLUMNINDEX_VALUE_TEXT],
		'Pay To Provider/Network ID' => [ $payToProvider, \&App::Billing::Claim::Physician::setNetworkId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Blue Shield ID' => [ $payToProvider, \&App::Billing::Claim::Physician::setBlueShieldId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Qualification/Degree' => [ [$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setQualification, \&App::Billing::Claim::Physician::setQualification],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/ID Indicator' => [ $payToProvider, \&App::Billing::Claim::Physician::setIdIndicator, COLUMNINDEX_VALUE_TEXT],
		'Payment Source/Primary' => [ [$claim, $payer], [\&App::Billing::Claim::setSourceOfPayment, \&App::Billing::Claim::Payer::setSourceOfPayment], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Payment Source/Secondary' => [$payer2, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Payment Source/Tertiary' => [$payer3, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Payment Source/Quaternary' => [$payer4, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Remarks' => [$claim, \&App::Billing::Claim::setRemarks, COLUMNINDEX_VALUE_TEXT],
		'Representator/Name/Last' => [$legalRepresentator, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,,COLUMNINDEX_VALUE_TEXTB]],
		'Representator/Name/First' => [$legalRepresentator, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Representator/Name/Middle' => [$legalRepresentator, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance Card Effective Date' => [$claim, \&App::Billing::Claim::setInsuranceCardEffectiveDate, COLUMNINDEX_VALUE_DATE],
		'Insurance Card Termination Date' => [$claim, \&App::Billing::Claim::setInsuranceCardTerminationDate, COLUMNINDEX_VALUE_DATE],
		'Champus Sponsor Status' => [$claim, \&App::Billing::Claim::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Champus Sponsor Grade' => [$claim, \&App::Billing::Claim::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Champus Sponsor Branch' => [$claim, \&App::Billing::Claim::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Invoice/History/Item' => [[$claim, $claim, $claim], [\&App::Billing::Claim::setInvoiceHistoryDate, \&App::Billing::Claim::setInvoiceHistoryAction, \&App::Billing::Claim::setInvoiceHistoryComments], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Pay To Org/Name' => [$payToOrganization, [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Pay To Org/Phone' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT ],
		'Provider/UPIN' => [ [$renderingProvider,$payToProvider], [\&App::Billing::Claim::Physician::setPIN,\&App::Billing::Claim::Physician::setPIN], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Service Provider/Facility/Billing/Group Number' => [ $payToOrganization, \&App::Billing::Claim::Physician::setGRP, COLUMNINDEX_VALUE_TEXT],
		'Submission Order' => [[$claim, $claim, $payer, $insured], [\&App::Billing::Claim::setClaimType, \&App::Billing::Claim::setBillSeq, \&App::Billing::Claim::Payer::setBillSequence, \&App::Billing::Claim::Insured::setBillSequence], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT]],
		'Insurance/Primary/Effective Dates' => [$insured, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'BCBS Plan Code' => [$payer, \&App::Billing::Claim::Payer::setBcbsPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Champus Branch' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Champus Grade' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Champus Status' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
	};

	my $queryStatment = " select ITEM_ID, ITEM_NAME, VALUE_TEXT, VALUE_TEXTB, VALUE_INT, VALUE_INTB, VALUE_FLOAT, VALUE_FLOATB, to_char(VALUE_DATE, \'dd-MON-yyyy\'), to_char(VALUE_DATEEND, \'dd-MON-yyyy\'), to_char(VALUE_DATEA, \'dd-MON-yyyy\'), to_char(VALUE_DATEB, \'dd-MON-yyyy\'), VALUE_BLOCK from invoice_attribute where parent_id = $invoiceId ";
	my $sth = $self->{dbiCon}->prepare(qq { $queryStatment});

	# do the execute statement
	$sth->execute()  or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while(@row = $sth->fetchrow_array())
	{
		if(my $attrInfo = $inputMap->{$row[COLUMNINDEX_ATTRNAME]})
		{
			my ($objInst, $method, $bindColumn) = @$attrInfo;
			if ($objInst ne "")
			{

				if (ref $method eq 'ARRAY')
				{
					if (ref $objInst eq 'ARRAY')
					{
						for my $methodNum (0..$#$method)
						{
							my $functionRef = $method->[$methodNum];
							&$functionRef($objInst->[$methodNum], ($row[$bindColumn->[$methodNum]]));
						}
					}
					else
						{
							for my $methodNum (0..$#$method)
							{
								my $functionRef = $method->[$methodNum];
								&$functionRef($objInst, ($row[$bindColumn->[$methodNum]]));
							}
						}
				  }
					else
						{
						&$method($objInst, ($row[$bindColumn]));
						}
			  }
		 }
	}
	
	my $billSeq = [];
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = [\$payer, \$insured];
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = [\$payer2, \$insured2];
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  [\$payer3, \$insured3];
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = [\$payer4, \$insured4];

	my $currentPolicy = $billSeq->[$claim->getBillSeq()];
	if ($currentPolicy ne "")
	{
		my $tp1 = ${$currentPolicy->[0]};
		my $ti1 = ${$currentPolicy->[1]};

		${$currentPolicy->[0]} = $payer;
    	${$currentPolicy->[1]} = $insured;
		$payer = $tp1;
		$insured = $ti1;
	    $claim->setSourceOfPayment($tp1->getSourceOfPayment);
	    }
	$objects[0] = $patient;
	$objects[1] = $payToProvider;
	$objects[2] = $insured;
	$objects[3] = $renderingOrganization;
	$objects[4] = $treatment;
	$objects[5] = $claim;
	$objects[6] = $legalRepresentator;
	$objects[7] = $payer;
	$objects[8] = $payToOrganization;
	$objects[9] = $renderingProvider;
	$objects[10] = $insured2;
	$objects[11] = $insured3;
	$objects[12] = $payer2;
	$objects[13] = $payer3;
	$objects[14] = $payer4;
	$objects[15] = $insured4;

	$payToOrganization->setAddress($payToOrganizationAddress);
	$patient->setAddress($patientAddress);
	$payToProvider->setAddress($payToProviderAddress);
	$renderingProvider->setAddress($renderingProviderAddress);
	$self->setproperRenderingProvider($claim, $renderingProvider, $renderingOrganization);
	$self->assignInvoiceAddresses($invoiceId,$claim,\@objects);

	return \@objects;
}

sub setproperRenderingProvider
{
	my ($self, $claim, $renderingProvider, $renderingOrganization) = @_;

	my $renderingOrg = new App::Billing::Claim::Organization;
	$renderingOrg->setId($renderingOrganization->getId);
	$renderingOrg->setFederalTaxId($renderingProvider->getFederalTaxId);
	$renderingOrg->setName($renderingOrganization->getName);
	$renderingOrg->setSpecialityId($renderingProvider->getSpecialityId);
	$claim->setRenderingOrganization($renderingOrg);
	$claim->setRenderingProvider($renderingProvider);
}

sub setClaimProperties
{
	my ($self, $invoiceId, $currentClaim, $objects) = @_;
	my $patient = $objects->[0];
	my $payToProvider = $objects->[1];
	my $insured = $objects->[2];
	my $insured2 = $objects->[10];
	my $insured3 = $objects->[11];
	my $insured4 = $objects->[15];
	my $renderingOrganization = $objects->[3];
	my $treatmentObject	= $objects->[4];
	my $legalRepresentator = $objects->[6];
	my $payer = $objects->[7];
	my $payToOrganization = $objects->[8];
	my %atr;
	my @tempRow;
	my $diagcount;
	my $queryStatment = "select  total_cost, INVOICE_STATUS, CLAIM_DIAGS, balance, Invoice.total_adjust, Invoice_subtype from invoice where invoice_id = $invoiceId";
	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@tempRow = $sth->fetchrow_array();
	my $diagnosis;
	$tempRow[2] =~ s/ //g;
	
	my @diagnosisCodes = split (/,/,$tempRow[2]) ;
	my $diagCount;
	my @ins;
	$ins[CLAIM_TYPE_SELF] = "OTHER";
	$ins[CLAIM_TYPE_INSURANCE] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_HMO_CAP] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_PPO] = "GROUP HEALTH PLAN";
	$ins[CLAIM_TYPE_MEDICARE] = "MEDICARE";
	$ins[CLAIM_TYPE_MEDICAID] = "MEDICAID";
	$ins[CLAIM_TYPE_WORKCOMP] = "OTHER";
	$ins[CLAIM_TYPE_THIRD_PARTY] = "OTHER";
	$ins[CLAIM_TYPE_CHAMPUS] = "CHAMPUS";
	$ins[CLAIM_TYPE_CHAMPVA] = "CHAMPVA";
	$ins[CLAIM_TYPE_FECA_BLK_LUNG] = "FECA";
	$ins[CLAIM_TYPE_BCBS] = "OTHER";
	$ins[CLAIM_TYPE_HMO_NONCAP] = "GROUP HEALTH PLAN";

	for ($diagCount = 0 ;$diagCount <= $#diagnosisCodes;$diagCount++)
	{
		$diagnosis = new App::Billing::Claim::Diagnosis;
		$diagnosis->setDiagnosis($diagnosisCodes[$diagCount]);
		$diagnosis->setDiagnosisPosition($diagCount);
		$currentClaim->addDiagnosis($diagnosis);
	}
	$currentClaim->setId($invoiceId);
	$currentClaim->setTotalCharge($tempRow[0]);
	$currentClaim->setStatus($tempRow[1]);
	$currentClaim->setBalance($tempRow[3]);
	$currentClaim->setAmountPaid($tempRow[4]);
	$currentClaim->setCareReceiver($patient);
	$currentClaim->setPayToProvider($payToProvider);
	$currentClaim->setPayToOrganization($payToOrganization);
	$currentClaim->setLegalRepresentator($legalRepresentator);
	$currentClaim->setProgramName($ins[$tempRow[5]]);
	my $no = $currentClaim->getClaimType;
	my $insureds = [$insured, $insured2, $insured3, $insured4];
	$currentClaim->addInsured($insureds->[0]);
	$currentClaim->addInsured($insureds->[1]);
	$currentClaim->addInsured($insureds->[2]);
	$currentClaim->addInsured($insureds->[3]);
	$self->assignPatientInsurance($currentClaim, $invoiceId);
	my $payers = [ $payer, $objects->[12], $objects->[13], $objects->[14]];
	$currentClaim->addPolicy($payers->[0]); 
	$currentClaim->addPolicy($payers->[1]); 
	$currentClaim->addPolicy($payers->[2]); 
	$currentClaim->addPolicy($payers->[3]); 
	$self->assignPolicy($currentClaim,$invoiceId);
	$currentClaim->setPayer($payer);
	$currentClaim->getTotalCharge();
	$currentClaim->getStatus();
	$currentClaim->getBalance();
	$self->assignTransProvider($currentClaim, $invoiceId);
	my $count;
	$self->setProperPayer($invoiceId, $currentClaim	);
	my $tempItems = $currentClaim->{procedures};
	my $tempDiagnosisCodes;
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /,$tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{otherItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /,$tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{adjItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /,$tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{copayItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /,$tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}

}

sub diagnosisPtr
{
	my ($self, $currentClaim, $codes) = @_;
	my $diagnosisMap = {};
	my $ptr;
	my $diag = $currentClaim->{'diagnosis'};
	my $diagt;
	my $count = 0;
	foreach $diagt(@$diag)
	{
		if ($diagt ne "")
		{
			$diagnosisMap->{$currentClaim->{'diagnosis'}->[$count]->getDiagnosis()} = $count + 1;
			$count++;
		}
	}
	my @diagCodes = split(/,/,$codes);
	for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
	{
		$ptr = $diagnosisMap->{$diagCodes[$diagnosisCount]} . " " . $ptr;
	}
	return $ptr;
}

sub setProperPayer
{
	my ($self, $invoiceId,  $currentClaim) = @_;
	my $payer = $currentClaim->getPayer();
	my $patient = $currentClaim->getCareReceiver();
	my $payerAddress = $payer->getAddress();

	my	$queryStatment = "select  invoice_subtype from  Invoice where invoice.invoice_id = $invoiceId";
	my	$sth = $self->{dbiCon}->prepare(qq{$queryStatment});

	$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @tempRow = $sth->fetchrow_array();

	if ($tempRow[0] != CLAIM_TYPE_SELF)
		{
			my $payers = $currentClaim->{policy};
			my $payer;
			my $ins = 0;
			foreach $payer (@$payers)
			{
				my $payerName = $currentClaim->{insured}->[$ins]->getInsurancePlanOrProgramName();
				$queryStatment = "select  id from ref_envoy_payer where name = \'$payerName\'";
				$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
				$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
				@tempRow = $sth->fetchrow_array();
				$payer->setPayerId($tempRow[0]);
				if ($payers->[$currentClaim->getClaimType] eq  $currentClaim->{payer})
				{
					$currentClaim->setPayerId($tempRow[0]);
				}
#				$payer->setName($payerName);  # incase of 
			}
		}
		elsif($tempRow[0] == CLAIM_TYPE_SELF)
		{
			$currentClaim->setPayerId($patient->getId());
			my $temp = $patient->getId();
			$payer->setId($temp);
			$temp = $patient->getLastName() . " ";
			$temp = $temp . $patient->getFirstName() . " ";
			$temp = $temp . $patient->getMiddleInitial();
			$payer->setName($temp);
			my $patientAddress = $patient->getAddress();
			$payerAddress->setAddress1($patientAddress->getAddress1);
			$payerAddress->setAddress2($patientAddress->getAddress2);
			$payerAddress->setCity($patientAddress->getCity);
			$payerAddress->setState($patientAddress->getState);
			$payerAddress->setZipCode($patientAddress->getZipCode);
			$payerAddress->setCountry($patientAddress->getCountry);
			$payer->setAddress($payerAddress);
		}
	$currentClaim->setPayer($payer);
}

sub populateItems
{
	my ($self, $invoiceId, $currentClaim) = @_;
	my $items;
	my $procedureObject;
	my @tempRow;
	my $invoiceItems;
	my $joinedItems;
	my $queryStatment;
	my $sth;
	my $functionRef;
	my $outsideLabCharges;
	my @itemMap;
	$itemMap[0] = \&App::Billing::Claim::addOtherItems;
	$itemMap[1] = \&App::Billing::Claim::addProcedure;
	$itemMap[2] = \&App::Billing::Claim::addProcedure;
	$itemMap[3] = \&App::Billing::Claim::addCopayItems;
	$itemMap[4] = \&App::Billing::Claim::addAdjItems;

 	#$queryStatment = "select data_date_a, data_date_b, data_num_a, data_num_b, code, modifier, unit_cost, quantity, data_text_a, REL_DIAGS, data_text_c, DATA_TEXT_B , item_id, extended_cost, balance, total_adjust, item_type from invoice_item where parent_id = $invoiceId ";

 	$queryStatment = "select to_char(service_begin_date, \'dd-MON-yyyy\'), to_char(service_end_date, \'dd-MON-yyyy\'), hcfa_service_place, hcfa_service_type, code, modifier, unit_cost, quantity, emergency,
 												REL_DIAGS, reference, COMMENTS , item_id, extended_cost, balance, total_adjust, item_type
 										from invoice_item
 										where parent_id = $invoiceId ";

	$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or  $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while(@tempRow = $sth->fetchrow_array())
	{
		$procedureObject = new App::Billing::Claim::Procedure;
		$procedureObject->setDateOfServiceFrom(($tempRow[0]));
		$procedureObject->setDateOfServiceTo(($tempRow[1]));
		$procedureObject->setPlaceOfService(($tempRow[2]));
		$procedureObject->setTypeOfService(($tempRow[3]));
		$procedureObject->setCPT(($tempRow[4]));
		$procedureObject->setModifier(($tempRow[5]));
		$procedureObject->setCharges(($tempRow[6]));  # EXTENDED COST IS THE REAL CHARGE FOR A PROCEDURE
		$procedureObject->setDaysOrUnits(($tempRow[7]));
		$procedureObject->setEmergency(($tempRow[8]));
		$procedureObject->setReference(($tempRow[10]));
		$procedureObject->setDiagnosis($tempRow[9]);
		$procedureObject->setComments($tempRow[11]);
		$procedureObject->setItemId($tempRow[12]);
		$procedureObject->setExtendedCost($tempRow[13]);
		$procedureObject->setBalance($tempRow[14]);
		$procedureObject->setTotalAdjustments($tempRow[15]);
		$functionRef = $itemMap[$tempRow[16]];
		if ($tempRow[16] eq '2')
		{
			$outsideLabCharges = $outsideLabCharges + $tempRow[13]
			}
		if ( $functionRef ne "")
		{
			&$functionRef($currentClaim, $procedureObject) ;
		}
	}
	$currentClaim->{treatment}->setOutsideLab($outsideLabCharges eq "" ? 'N' : 'Y');
	$currentClaim->{treatment}->setOutsideLabCharges($outsideLabCharges);

}


sub populateTreatment
{
	my ($self, $invoiceId, $workingClaim, $treatmentObject) = @_;
	my $constStr;
	my @tempRow;

	$workingClaim->setTreatment($treatmentObject);
}


sub dbDisconnect
{
	my $self = shift;
	$self->{dbiCon}->disconnect;
}

sub assignInvoiceAddresses
{
	my ($self, $invoiceId, $currentClaim, $objects) = @_;
	my @row;
	my $queryStatment;
	my $sth;
#	$objects[0] = $patient;
#	$objects[1] = $payToProvider;
#	$objects[2] = $insured;
#	$objects[3] = $renderingorganization;
#	$objects[4] = $treatment;
#	$objects[6] = $legalRepresentator;
#	$objects[7] = $payer;
#	$objects[8] = $payToOrganization;
#	$objects[9] = $renderingProvider;

	my $patientAddress = $objects->[0]->getAddress;
	my $payToProviderAddress = $objects->[1]->getAddress;
	my $payToProvider = $objects->[1];
	my $insuredAddress = $objects->[2]->getAddress;
	my $legalRepresentator = $objects->[6];
	my $payerAddress = $objects->[7]->getAddress;
	my $renderingOrganization = $objects->[3];
	my $payToOrganization = $objects->[8];
	my $payToOrganizationAddress = $payToOrganization->getAddress();
	my $payer = $objects->[7];
	my $renderingProvider = $objects->[9];
	my $renderingOrganizationAddress = new App::Billing::Claim::Address;
	my $renderingProviderAddress = $renderingProvider->getAddress();
	my $legalRepresentatorAddress = new App::Billing::Claim::Address;

	my @methods = (\&App::Billing::Claim::Address::setAddress1,\&App::Billing::Claim::Address::setAddress2,\&App::Billing::Claim::Address::setCity,\&App::Billing::Claim::Address::setState,\&App::Billing::Claim::Address::setZipCode,\&App::Billing::Claim::Address::setCountry);
	my @bindColumns = (COLUMNINDEX_ADDRESS1,COLUMNINDEX_ADDRESS2,COLUMNINDEX_CITY,COLUMNINDEX_STATE,COLUMNINDEX_ZIPCODE,COLUMNINDEX_COUNTRY);
	my $addessMap =
	{
		'Billing' => [$renderingProviderAddress],
		'Insured' => [$insuredAddress],
		'Patient' => [$patientAddress],
		'Service' => [$renderingOrganizationAddress],
		'Pay To Org' => [$payToOrganizationAddress],
		'legalRepresentator' => [$legalRepresentatorAddress],
		'Insurance' => [$payerAddress],
	};

	$queryStatment = "select ADDRESS_NAME,line1,line2,city,state,zip,country from invoice_Address where parent_id = $invoiceId";
	$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");

	while(@row = $sth->fetchrow_array())
	{
		if(my $attrInfo = $addessMap->{$row[COLUMNINDEX_ADDRESSNAME]})
		{
			my ($objInst) = @$attrInfo;
			if ($objInst ne "")
			{
					for my $methodNum (0..$#methods)
					{
						my $functionRef = $methods[$methodNum];

						&$functionRef($objInst, ($row[$bindColumns[$methodNum]]));
					}
			  }
		 }
	}

	$legalRepresentator->setAddress($legalRepresentatorAddress);
	$payer->setAddress($payerAddress);
	$renderingProvider->setAddress($renderingProviderAddress);
	$currentClaim->{renderingOrganization}->setAddress($renderingOrganizationAddress);
	$payToProvider->setAddress($payToOrganizationAddress);
	$payToOrganization->setAddress($payToOrganizationAddress);

}

sub id
{
	my $self = shift;
	return 'DBI';
}

sub registerValidators
{
	 my ($self, $validators) = @_;

	$validators->register(new App::Billing::Input::Validate::DBI);
	$validators->register(new App::Billing::Validate::HCFA::Champus);
	$validators->register(new App::Billing::Validate::HCFA::ChampVA);
	$validators->register(new App::Billing::Validate::HCFA::Medicaid);
	$validators->register(new App::Billing::Validate::HCFA::Medicare);
	$validators->register(new App::Billing::Validate::HCFA::Other);
	$validators->register(new App::Billing::Validate::HCFA::FECA);
	$validators->register(new App::Billing::Validate::HCFA::HCFA1500);

}

sub getId
{
	'IDBI'
}

@CHANGELOG =
(
    # [FLAGS, DATE, ENGINEER, CATEGORY, NOTE]

	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/16/1999', 'SSI','Billing Interface/Input DBI','Accept assignment is picked form value_int of invoice attribute.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'SSI','Billing Interface/Input DBI','Rendering and pay to provider (tax id,tax idType) is picked from Provider/Tax ID with columns (value_text, value_textb) respectively.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/17/1999', 'SSI','Billing Interface/Input DBI',' Pay to provider name XXX is obtained from (Pay To Provider/Name/xxx).'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/17/1999', 'SSI','Billing Interface/Input DBI',' Pay to provider Specialty code is obtained from (Pay To Provider/Specialty) with column value_textb.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/17/1999', 'SSI','Billing Interface/Input DBI',' Rendering provider Specialty code is obtained from (Provider/Specialty) with column value_textb.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/17/1999', 'SSI','Billing Interface/Input DBI',' Patient account number is obtained from (Patient/Control Number) with column value_text.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/20/1999', 'SSI','Billing Interface/Input DBI',' Payer and its address is populated from new queries in presubmitted case.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/20/1999', 'SSI','Billing Interface/Input DBI',' Insured and its address is populated from new queries in presubmitted case.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/21/1999', 'SSI','Billing Interface/Input DBI',' InformationReleaseDate value is now set from value_date of Information/Release/indicator.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'SSI','Billing Interface/Input DBI',' Insurance Type Code value is now set from value_TextB of Insurance/Primary/Type.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'SSI','Billing Interface/Input DBI',' Provider/Assign Indicator has been renamed to Provider/Assign/Indicator.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/23/1999', 'SSI','Billing Interface/Input DBI',' Source of Payment has been renamed to Payment Source.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/23/1999', 'SSI','Billing Interface/Input DBI',' Pay To Organization/Name is the new attribute for pay to organization name.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/24/1999', 'SSI','Billing Interface/Input DBI',' Constants for column indexes of invoice_attribute and invoice_address are incremented by 1 due to addition of field CR_ORG_ID.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/24/1999', 'SSI','Billing Interface/Input DBI',' Ref Provider/State is now obtained from "Ref Provider/Identification" with column value_textB.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'SSI','Billing Interface/Input DBI','"Pay To Organization/Name" is renamed to  "Pay To Org/Name" in invoice_attribute.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'SSI','Billing Interface/Input DBI','Pay To Organization Id is obtained from value_textB of "Pay To Org/Name" in invoice_attribute.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'SSI','Billing Interface/Input DBI','"Pay To Organization Address" is copied to " Pay To  Provider Address" in invoice_Address.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'SSI','Billing Interface/Input DBI','"Provider/Specialty" is to both pay to provider and rendering provider in invoice_attribute.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/24/1999', 'SSI','Billing Interface/Input DBI','"Pay to Org/Telephone" is provided to pay to organization.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '12/28/1999', 'SSI','Billing Interface/Input DBI','Ids for status (pre submit, submit) are updated i.e. decremented by 1.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/01/2000', 'SSI','Billing Interface/Input DBI','Diagnosis object is created as required in setClaimProperties, also position for diagnosis is saved.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/03/2000', 'SSI','Billing Interface/Input DBI','DiagnosisCodePointer is set by DBI in setClaimProperties. if there as multiple diagnosis, pointers are space separated numbers.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/04/2000', 'SSI','Billing Interface/Input DBI','ItemMap in populateItem is conveted to array from hash.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/04/2000', 'SSI','Billing Interface/Input DBI','New quries for presubmit are implemented.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/05/2000', 'SSI','Billing Interface/Input DBI','New quries for insured and payer for presubmit mode are implemented.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/05/2000', 'SSI','Billing Interface/Input DBI','Pin number for rendering and pay to provider is implemented.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/11/2000', 'SSI','Billing Interface/Input DBI','New quries for pre-submit and post-submit are implemented.' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/13/2000', 'SSI','Billing Interface/Input DBI','Creation of empty Extra Procedure is removed.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/14/2000', 'SSI','Billing Interface/Input DBI','New quries for pre-submit and post-submit are implemented.' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/18/2000', 'SSI','Billing Interface/Input DBI','Item->reference is populated with Invoice_Item.data_text_c' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/18/2000', 'SSI','Billing Interface/Input DBI','Item->disallowedCostContenment and otherCost are not populated now' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/06/2000', 'SSI','Billing Interface/Input DBI','New changes implemented' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '02/24/2000', 'SSI','Billing Interface/Input DBI','Field AmountPaid in payer is populated by the value invoice_attribute.itemName = Payer/Amount ' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '03/20/2000', 'SSI','Billing Interface/Input DBI','New changes about person and organization attribute implemented.' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '03/22/2000', 'SSI','Billing Interface/Input DBI','New quries regarding payers address implemented.' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '03/28/2000', 'SSI','Billing Interface/Input DBI','New quries regarding source of payment implemented.' ],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/18/2000', 'SSI','Billing Interface/Input DBI','The multiple payer and insured object are populated according to Invoice_billing table.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/20/2000', 'SSI','Billing Interface/Input DBI','Signature  is now populated from value textB of person_attribute'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/20/2000', 'SSI','Billing Interface/Input DBI','Workers compensation plan is also included'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/21/2000', 'SSI','Billing Interface/Input DBI','complete_name is used in payer when bill party type is person'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/21/2000', 'SSI','Billing Interface/Input DBI','insured SSN is now populated from insurance.member_number '],

);

1;
