###############################################################
package App::Billing::Input::DBI;
################################################################
# At present rendringProvider and pay to provider are same.
# by shams
use strict;
use Carp;
use DBI;

use App::Universal;
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
use App::Billing::Claim::Adjustment;
use App::Billing::Validator;
use App::Billing::Input::Validate::DBI;
use App::Billing::Validate::HCFA::Champus;
use App::Billing::Validate::HCFA::ChampVA;
use App::Billing::Validate::HCFA::Medicaid;
use App::Billing::Validate::HCFA::Medicare;
use App::Billing::Validate::HCFA::Other;
use App::Billing::Validate::HCFA::FECA;
# use App::Billing::Validate::HCFA::HCFA1500;

use vars qw(@ISA);
@ISA = qw(App::Billing::Input::Driver);
use Devel::ChangeLog;
use vars qw(@CHANGELOG);
use constant INVOICESTATUS_SUBMITTED => 4;
use constant INVOICESTATUS_CLOSED => 15;

use constant INVOICESTATUS_TRANSMITTED => 7;
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
use constant PRE_VOID => 16;
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

# Invoice item type constants
use constant INVOICE_ITEM_OTHER => 0;
use constant INVOICE_ITEM_SERVICE => 1;
use constant INVOICE_ITEM_LAB => 2;
use constant INVOICE_ITEM_COPAY => 3;
use constant INVOICE_ITEM_COINSURANCE => 4;
use constant INVOICE_ITEM_ADJUST => 5;
use constant INVOICE_ITEM_DEDUCTABLE => 6;
use constant INVOICE_ITEM_VOID => 7;

# Insurance sequence caption
use constant BILLSEQ_PRIMARY_CAPTION => 'Primary';
use constant BILLSEQ_SECONDARY_CAPTION => 'Secondary';
use constant BILLSEQ_TERTIARY_CAPTION => 'Tertiary';
use constant BILLSEQ_QUATERNARY_CAPTION => 'Quaternary';

# Default place of service for items
use constant DEFAULT_PLACE_OF_SERIVCE => 11;

use constant PROFESSIONAL_LICENSE_NO => 510;

sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Input::Driver(@_);
	return bless $self, $type;
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
	my $queryStatment = " select distinct INVOICE_ID from invoice where INVOICE_STATUS = $submittedStatus";
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

sub preStatusCheck
{
	my ($self, $claim, $attrDataFlag, $row) = @_;
	my $go = 0;

	$go = 1 if (($claim->getStatus() <=  PRE_STATUS) || (($claim->getInvoiceSubtype == CLAIM_TYPE_SELF) && ($claim->getStatus() ==  INVOICESTATUS_CLOSED)) || (($claim->getStatus() == PRE_VOID) && not($attrDataFlag & $row)));
# 	$go = 1 if (($claim->getStatus() >  INVOICESTATUS_SUBMITTED) && ($claim->getStatus() <  INVOICESTATUS_CLOSED));
	return $go
}


sub populateClaims
{
	my ($self, $claimList, %params) = @_;
	my $targetInvoices = [];
	my $i;
	my $currentClaim;
	my $populatedObjects;
	my $flag = 0;
	my @row;
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
		my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
		my $queryStatment = " select flags from invoice where INVOICE_id = $targetInvoices->[$i]";
		my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});

		$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
#		if (($claims->[$i]->getStatus() <=  PRE_STATUS) || (($claims->[$i]->getInvoiceSubtype == CLAIM_TYPE_SELF) && ($claims->[$i]->getStatus() ==  INVOICESTATUS_CLOSED)) || (($claims->[$i]->getStatus() == PRE_VOID) && not($attrDataFlag & $row[0])))
		if ( $self->preStatusCheck($claims->[$i], $attrDataFlag, $row[0]) ==1)
		{
			$self->assignInvoicePreSubmit($claims->[$i], $targetInvoices->[$i]);
		}
	}

	if($params{changeStatus} eq 1) {
		my $queryStatment = "update invoice set invoice_status = INVOICESTATUS_TRANSMITTED where INVOICE_STATUS = INVOICESTATUS_SUBMITTED";
		my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
		$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
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
	$self->assignPatientInfo($claim, $invoiceId);
	$self->assignPatientAddressInfo($claim, $invoiceId);
	$self->assignPatientInsurance($claim, $invoiceId);
	$self->assignPatientEmployment($claim, $invoiceId);
	$self->assignProviderInfo($claim, $invoiceId);
	$self->assignPaytoAndRendProviderInfo($claim, $invoiceId);
	$self->assignReferralPhysician($claim, $invoiceId);
	$self->assignServiceFacility($claim, $invoiceId);
	$self->assignServiceBilling($claim, $invoiceId);
	$self->assignPayerInfo($claim, $invoiceId);
}

sub assignPatientInfo
{
	my ($self, $claim, $invoiceId) = @_;
	my $patient = $claim->getCareReceiver();
	my $queryStatment = "select name_last, name_middle, name_first, person_id, to_char(date_of_birth, \'dd-MON-yyyy\'), gender, marital_status, ssn, person_id from invoice, person where invoice_id = $invoiceId and person_id = invoice.client_id";
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
	$patient->setSsn($row[7]);
	$queryStatment = "select value_text,value_type,value_int from person_attribute where parent_id = \'$row[8]\' and value_type between 220 and 225";
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	if($row[2] ne "")
	{
		my $orgId = $row[2];
		$patient->setEmployerOrSchoolId($orgId);

		$queryStatment = "select org.org_id, org.name_primary, org.org_internal_id  from org where org.org_internal_id = $orgId" ;
		$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
		# do the execute statement
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();

		$patient->setEmployerOrSchoolName($row[1]);
		$queryStatment = $queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = $row[2] and address_name = \'Mailing\'";
		$self->populateAddress($patient->getEmployerAddress, $queryStatment);
	}
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
	my $colValueDate = 3;

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
			AUTHORIZATION_PATIENT . 'Signature Source' => [ $patient, [\&App::Billing::Claim::Patient::setSignature, \&App::Billing::Claim::Patient::setSignatureDate], [$colValTextB, $colValueDate] ],
			AUTHORIZATION_PATIENT . 'Information Release' => [ $claim, \&App::Billing::Claim::setInformationReleaseIndicator, $colValText]
		};
	$queryStatment = "select value_text,value_textb, value_type || item_name, value_date from person_attribute, invoice where invoice_id = $invoiceId and parent_id = invoice.client_id";
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


	if ($no ne "") # here populate only the current insurer for the bill
	{
		$queryStatment = "select bill_party_type from invoice_billing where invoice_id = $invoiceId and BILL_SEQUENCE = $no";
		$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
		# do the execute statement
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		if ($row[0] eq BILL_PARTY_TYPE_INSURANCE)
		{
			$queryStatment = "select nvl(PLAN_NAME, PRODUCT_NAME), ins.rel_to_insured, invoice_billing.BILL_SEQUENCE, ins.group_number,
									ins.insured_id, to_char(coverage_begin_date,\'dd-MON-yyyy\') , to_char(coverage_end_date, \'dd-MON-yyyy\'), GROUP_NAME,
									ins.ins_type, Ins.member_number
							from org, insurance ins, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .")" .
								" and invoice_billing.bill_ins_id = ins.ins_internal_id
								and ins.ins_org_id = org.org_Internal_id
								and invoice_billing.BILL_SEQUENCE = $no";
		}
		else
		{
			$queryStatment = "select nvl(PLAN_NAME, PRODUCT_NAME), ins.rel_to_insured, invoice_billing.BILL_SEQUENCE, ins.group_number,
									ins.guarantor_id, to_char(coverage_begin_date,\'dd-MON-yyyy\') , to_char(coverage_end_date, \'dd-MON-yyyy\'), GROUP_NAME,
									ins.ins_type, Ins.member_number
							from insurance ins, invoice_billing
							where invoice_billing.invoice_id = $invoiceId
								and invoice_billing.invoice_item_id is NULL
								and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .")" .
								" and invoice_billing.bill_ins_id = ins.ins_internal_id
								and invoice_billing.BILL_SEQUENCE = $no";
		}
		$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
		# do the execute statement
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		$patient->setRelationshipToInsured($row[1]);
		$insured = $claim->{insured}->[$claim->getClaimType];
		$insured->setInsurancePlanOrProgramName($row[0]);
		$insured->setRelationshipToPatient($row[1]);
		$insured->setPolicyGroupOrFECANo($row[3]);
		$insured->setId($row[4]);
		$insured->setEffectiveDate($row[5]);
		$insured->setTerminationDate($row[6]);
		$insured->setPolicyGroupName($row[7]);
		$insured->setBillSequence($row[2]);
		$insured->setMemberNumber($row[9]);
#		$claim->setInsType($row[8]);
	}
	if ($no ne "")
	{
		my @rowBilling;
		$queryStatment = "select bill_id, bill_party_type, BILL_SEQUENCE from invoice_billing where invoice_id = $invoiceId and BILL_SEQUENCE <> $no";
		my $sth1 = $self->{dbiCon}->prepare(qq{$queryStatment});
		# do the execute statement
		$sth1->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");

		while(@rowBilling = $sth1->fetchrow_array())
		{
			if ($rowBilling[1] eq BILL_PARTY_TYPE_INSURANCE)
			{
				$queryStatment = "select nvl(PLAN_NAME, PRODUCT_NAME), ins.rel_to_insured, invoice_billing.BILL_SEQUENCE, ins.group_number,
										ins.insured_id, to_char(coverage_begin_date,\'dd-MON-yyyy\') , to_char(coverage_end_date, \'dd-MON-yyyy\'), GROUP_NAME,
										ins.ins_type, Ins.member_number
								from org, insurance ins, invoice_billing
								where invoice_billing.invoice_id = $invoiceId
									and invoice_billing.bill_id = $rowBilling[0]
									and invoice_billing.invoice_item_id is NULL
									and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .")" .
									" and invoice_billing.bill_ins_id = ins.ins_internal_id
									and ins.ins_org_id = org.org_internal_id
									and invoice_billing.BILL_SEQUENCE = $rowBilling[2]";
			}
			else
			{
				$queryStatment = "select nvl(PLAN_NAME, PRODUCT_NAME), ins.rel_to_insured, invoice_billing.BILL_SEQUENCE, ins.group_number,
										ins.guarantor_id, to_char(coverage_begin_date,\'dd-MON-yyyy\') , to_char(coverage_end_date, \'dd-MON-yyyy\'), GROUP_NAME,
										ins.ins_type, Ins.member_number
								from insurance ins, invoice_billing
								where invoice_billing.invoice_id = $invoiceId
									and invoice_billing.bill_id = $rowBilling[0]
									and invoice_billing.invoice_item_id is NULL
									and invoice_billing.bill_party_type in (" . BILL_PARTY_TYPE_INSURANCE . "," . BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .")" .
									" and invoice_billing.bill_ins_id = ins.ins_internal_id
									and invoice_billing.BILL_SEQUENCE = $rowBilling[2]";
			}

			$sth = $self->{dbiCon}->prepare(qq{$queryStatment});
			# do the execute statement
			$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();
			$insured = $insureds[$billSeq->[$row[3]+0]];
			if ($insured ne "")
			{
				if ($no ne ($row[3]+ 0))
				# ($no ne ($row[3]+ 0)) other insureds of submit.
				{
					$insured->setInsurancePlanOrProgramName($row[0]);
					$insured->setPolicyGroupOrFECANo($row[1]);
					$insured->setRelationshipToPatient($row[2]);
					$insured->setBillSequence($row[3]);
					$insured->setId($row[4]);
					$insured->setEffectiveDate($row[5]);
					$insured->setTerminationDate($row[6]);
					$insured->setMemberNumber($row[7]);
				}
			}
		}
	}
	$self->assignInsuredInfo($claim, $invoiceId);
	$self->assignInsuredAddressInfo($claim, $invoiceId);

}

sub assignInsuredInfo
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
#			if ($insured ne $insureds->[$no1])
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
					$insured->setSsn($row[6]);
					$insured->setId($row[7]);

					if ($insured->getBillSequence() ne "")
					{
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

						$queryStatment = "select extra, employer_org_id
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
						my $orgInternalId = $row[1];
						$insured->setEmployerOrSchoolId($orgInternalId);

					}
					$queryStatment = "select value_text,value_type,value_int from person_attribute where parent_id = \'$insuredId\' and value_type between 220 and 225";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
						# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					if($row[2])
					{
#						my $orgInternalId = $row[2];
#						$insured->setEmployerOrSchoolId($orgInternalId);

#						$queryStatment = "select name_primary , org_id, org_internal_id  from org where org_internal_id = $orgInternalId";
						$queryStatment = "select name_primary , org_id, org_internal_id  from org where org_internal_id = $orgInternalId";
						$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
						# do the execute statement
						$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
						my @row1 = $sth->fetchrow_array();
						$insured->setEmployerOrSchoolName($row1[0]);
#						$queryStatment = $queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = \'$row[0]\' and address_name = \'Mailing\'";
#						$self->populateAddress($insured->getEmployerAddress(), $queryStatment);
						$insured->setEmploymentStatus($row[1]);
					}
				}
			}
		}
	}
}



sub assignInsuredAddressInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $insureds = $claim->{insured};
	my $insured;
	my $no = $claim->getClaimType();
	foreach $insured (@$insureds)
	{
#		if ($insured ne $insureds->[$no])
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

sub assignProviderInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $renderingProvider = $claim->getRenderingProvider();
	my $payToProvider = $claim->getPayToProvider();
	my $queryStatment = "select  name_last, name_middle,  name_first, person_id from person, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and person.person_id = trans.provider_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $orgId;
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$renderingProvider->setLastName($row[0]);
	$payToProvider->setLastName($row[0]);
	$renderingProvider->setMiddleInitial($row[1]);
	$payToProvider->setMiddleInitial($row[1]);
	$renderingProvider->setFirstName($row[2]);
	$payToProvider->setFirstName($row[2]);
	$renderingProvider->setId($row[3]);
	$payToProvider->setId($row[3]);
	my $pId = $row[3];
	my $renderingProviderAddress = $renderingProvider->getAddress();
	my $payToProviderProviderAddress = $payToProvider->getAddress();
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

	$payToProviderProviderAddress->setAddress1($row[0]);
	$payToProviderProviderAddress->setAddress2($row[1]);
	$payToProviderProviderAddress->setCity($row[2]);
	$payToProviderProviderAddress->setState($row[3]);
	$payToProviderProviderAddress->setZipCode($row[4]);
	$payToProviderProviderAddress->setCountry($row[5]);

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
	my @providers = ($renderingProvider, $payToProvider);
	my $provider;
	my $id;
	my @row;
	my $queryStatment;
	my $sth;
	foreach $provider(@providers)
	{
		$id = $renderingProvider->getId();
		my $providerAddress=$provider->getAddress();

		my $inputMap =
			{
				CERTIFICATION_LICENSE . 'Tax ID' => [ [$provider, $provider], [\&App::Billing::Claim::Physician::setFederalTaxId, \&App::Billing::Claim::Physician::setTaxTypeId], [$colValText, $colValTextB]],
				PHYSICIAN_SPECIALTY . 'Primary' => [ $provider,  \&App::Billing::Claim::Physician::setSpecialityId, $colValTextB],
				CERTIFICATION_LICENSE . 'UPIN' => [ $provider, \&App::Billing::Claim::Physician::setPIN, $colValText],
				CONTACT_METHOD_TELEPHONE . 'Work' => [ $providerAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValText],

			};
		# do the execute statement
		$queryStatment = "select value_text , value_textB, value_type || item_name  from person_attribute where parent_id = \'$id\' ";
		$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
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
	}
	$queryStatment = "select value_textB from person_attribute,invoice where parent_id = invoice.client_id and item_name = \'Provider Assignment\' and invoice.invoice_id = $invoiceId and value_type = " . AUTHORIZATION_PATIENT;
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$renderingProvider->setAssignIndicator($row[0]);
	$payToProvider->setAssignIndicator($row[0]);

	$queryStatment = "select value_text from person_attribute where parent_id = \'$id\' and value_type = " . PROFESSIONAL_LICENSE_NO;
	$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();
	$renderingProvider->setProfessionalLicenseNo($row[0]);
	$payToProvider->setProfessionalLicenseNo($row[0]);

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

sub populateAddress
{
	my ($self, $address, $queryStatment) = @_;

#	$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = $row[0] and address_name = \'Mailing\'";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$address->setAddress1($row[0]);
	$address->setAddress2($row[1]);
	$address->setCity($row[2]);
	$address->setState($row[3]);
	$address->setZipCode($row[4]);
	$address->setCountry($row[5]);
}


sub assignServiceFacility
{
	my ($self, $claim, $invoiceId) = @_;

	my $renderingOrganization = $claim->getRenderingOrganization();
	my $queryStatment = "select org.org_id, org.name_primary, org.org_Internal_id from org, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and org.org_internal_id = trans.service_facility_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$renderingOrganization->setId($row[0]);
	$renderingOrganization->setName($row[1]);
	if ($row[2] ne "")
	{
		my $renderingOrganizationAdress = $renderingOrganization->getAddress();
		$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = $row[2] and address_name = \'Mailing\'";
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
	}
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
	my $queryStatment = "select org.org_id, org.name_primary, org.org_internal_id  from org, transaction trans, invoice where invoice_id = $invoiceId and trans.trans_id = invoice.main_transaction and org.org_internal_id = trans.billing_facility_id ";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	my $orgId;
	my $orgInternalId;
	# do the execute statement
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();
	$orgId = $row[0];
	$orgInternalId = $row[2];
	$payToOrganization->setId($row[0]);
	$payToOrganization->setName($row[1]);
#	$payToOrganization->setFederalTaxId($row[2]);
	if($orgInternalId ne "")
	{

		$queryStatment = "select value_text from org_attribute where parent_id = $orgInternalId and value_type = " . FACILITY_GROUP_NUMBER;
		$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
#		$payToOrganization->setGRP($row[0]);
#		my $payToOrganizationAddress = new App::Billing::Claim::Address;
		my $payToOrganizationAddress = $payToOrganization->getAddress;
		$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = $orgInternalId and address_name = \'Mailing\'";
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

		$queryStatment = "select value_text from org_attribute where parent_id = $orgInternalId and value_type = " . CONTACT_METHOD_TELEPHONE . " and item_name = \'Primary\'";
		$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		$payToOrganizationAddress->setTelephoneNo($row[0]);
		$payToOrganization->setAddress($payToOrganizationAddress);
	}

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
				invoice_billing.bill_party_type, invoice_billing.BILL_INS_ID
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
				invoice_billing.bill_party_type, invoice_billing.BILL_INS_ID, nvl(insurance.PLAN_NAME, insurance.PRODUCT_NAME)
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
#			if ($seqNum ne $no)
			{
				$payerAddress = $payer->getAddress();
				$payer->setAmountPaid($row1[2]);
				$payer->setBillSequence($row1[1]);
				if ($row1[3] == BILL_PARTY_TYPE_INSURANCE )
				{
					$queryStatment = "select name_primary as payer_name, org_id as payer_id from org where org_Internal_id = $row1[0]";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payer->setInsurancePlanOrProgramName($row1[5]);
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

						$queryStatment = "select line1, line2, city, state, zip, country
							from insurance_address
							where parent_id = (select parent_ins_id
										from invoice_billing, insurance
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
				}
				elsif ($row1[3] == BILL_PARTY_TYPE_PERSON)
				{
					my $pid = $row1[0];

					$queryStatment = "select complete_name from person where person_id = \'$pid\'";
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payer->setId($pid);
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
					$queryStatment= "select value_text from person_attribute where parent_id = \'$pid\' and Item_name = \'Home\' and value_type = " . CONTACT_METHOD_TELEPHONE;
					$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
					# do the execute statement
					$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
					@row = $sth->fetchrow_array();
					$payerAddress->setTelephoneNo($row[0]);
				}
				elsif ($row1[3] == BILL_PARTY_TYPE_ORGANIZATION)
				{
					if ($row1[0])
					{
						$queryStatment = "select name_primary , org_id, org_internal_id  from org where  org_internal_id = $row1[0]";
						$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
						# do the execute statement
						$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
						@row = $sth->fetchrow_array();

						$payer->setId($row[1]);
						$payer->setName($row[0]);
						my $internalId = $row[2];
				 		$queryStatment = "select line1, line2, city, state, zip, country from org_address where parent_id = $row1[0] and address_name = \'Mailing\'";
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
						$queryStatment = "select value_text from org_attribute where parent_id = $row1[0] and Item_name = \'Contact Method/Telepone/Primary\'";
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
}

sub assignInvoiceProperties
{
	my ($self, $invoiceId) = @_;
	my $claim = new App::Billing::Claim;
	my $patient = new App::Billing::Claim::Patient;
	my $patientAddress = new App::Billing::Claim::Address;
	my $patientEmployerAddress = new App::Billing::Claim::Address;
	$patient->setEmployerAddress($patientEmployerAddress);
	my $insured = new App::Billing::Claim::Insured;
	my $insuredAddress = new App::Billing::Claim::Address;
	$insured->setAddress($insuredAddress);
	my $insured2 = new App::Billing::Claim::Insured;
	my $insured2Address = new App::Billing::Claim::Address;
	$insured2->setAddress($insured2Address);
	my $insured3 = new App::Billing::Claim::Insured;
	my $insured3Address = new App::Billing::Claim::Address;
	$insured3->setAddress($insured3Address);
	my $insured4 = new App::Billing::Claim::Insured;
	my $insured4Address = new App::Billing::Claim::Address;
	$insured4->setAddress($insured4Address);
	my $treatment = new App::Billing::Claim::Treatment;
	my $renderingProviderAddress = new App::Billing::Claim::Address;
	my $referringProviderAddress = new App::Billing::Claim::Address;
	my $referringOrganizationAddress = new App::Billing::Claim::Address;
	my $payToProviderAddress = new App::Billing::Claim::Address;
	my $payToOrganizationAddress = new App::Billing::Claim::Address;
	my $payToProvider = new App::Billing::Claim::Physician;
	my $payToOrganization = new App::Billing::Claim::Organization;
	my $renderingProvider = new App::Billing::Claim::Physician;
	my $renderingOrganization = new App::Billing::Claim::Organization;
	my $referringProvider = new App::Billing::Claim::Physician;
	my $referringOrganization = new App::Billing::Claim::Organization;
	my $legalRepresentator = new App::Billing::Claim::Person;
	my $payer = new App::Billing::Claim::Payer;
	my $payerAddress = new App::Billing::Claim::Address;
	$payer->setAddress($payerAddress);
	my $payer2 = new App::Billing::Claim::Payer;
	my $payer3 = new App::Billing::Claim::Payer;
	my $payer4 = new App::Billing::Claim::Payer;
	my $payer2Address = new App::Billing::Claim::Address;
	$payer2->setAddress($payer2Address);
	my $payer3Address = new App::Billing::Claim::Address;
	$payer3->setAddress($payer3Address);
	my $payer4Address = new App::Billing::Claim::Address;
	$payer4->setAddress($payer4Address);

	$payToProvider->setType("pay to");
	$renderingProvider->setType("rendering");
	$referringProvider->setType("refering");
	$payToOrganization->setType("pay to");
	$renderingOrganization->setType("rendering");
	$referringOrganization->setType("refering");
	$patient->setType("patient");
	$insured->setType("insured");
	$insured2->setType("insured");
	$insured3->setType("insured");
	$insured4->setType("insured");
	$payer->setType("payer");
	$payer2->setType("payer");
	$payer3->setType("payer");
	$payer4->setType("payer");
	$legalRepresentator->setType("legal representator");
	my @objects;
	my @row;

	my $inputMap =
	{
		'Patient/Name/Last' => [$patient, [\&App::Billing::Claim::Person::setLastName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Name/First' => [$patient, \&App::Billing::Claim::Person::setFirstName,  COLUMNINDEX_VALUE_TEXT],
		'Patient/Name/Middle' => [$patient, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/DOB' => [$patient, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Patient/Personal/DOD' => [$patient, \&App::Billing::Claim::Person::setDateOfDeath, COLUMNINDEX_VALUE_DATE],
		'Patient/Death/Indicator' => [$patient, \&App::Billing::Claim::Person::setDeathIndicator, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/Gender' => [$patient, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Patient/Contact/Home Phone' => [$patientAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/Marital Status' => [$patient, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Student/Status' => [$patient, \&App::Billing::Claim::Person::setStudentStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Employment/Status' => [$patient, \&App::Billing::Claim::Person::setEmploymentStatus, COLUMNINDEX_VALUE_TEXT],
		'Condition/Related To' => [$claim, [ \&App::Billing::Claim::setConditionRelatedTo, \&App::Billing::Claim::setConditionRelatedToAutoAccidentPlace ], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Signature' => [$patient,   \&App::Billing::Claim::Patient::setSignature,COLUMNINDEX_VALUE_TEXTB],
		'Patient/Illness/Dates' => [$treatment, [ \&App::Billing::Claim::Treatment::setDateOfIllnessInjuryPregnancy, \&App::Billing::Claim::Treatment::setDateOfSameOrSimilarIllness ], [COLUMNINDEX_VALUE_DATEEND,COLUMNINDEX_VALUE_DATE]],
		'Patient/Disability/Dates'  => [$treatment, [ \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkFrom, \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkTo ], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],
		'Ref Provider/Name/Last' =>[$treatment, [\&App::Billing::Claim::Treatment::setRefProviderLastName,\&App::Billing::Claim::Treatment::setId],[ COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Ref Provider/Name/First' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderFirstName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Name/Middle' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderMiName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Identification' => [$treatment, [\&App::Billing::Claim::Treatment::setIDOfReferingPhysician,\&App::Billing::Claim::Treatment::setReferingPhysicianState], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Ref Provider/ID Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setReferingPhysicianIDIndicator, COLUMNINDEX_VALUE_TEXT],
		'Patient/Hospitalization/Dates' => [$treatment,[\&App::Billing::Claim::Treatment::setHospitilizationDateFrom, \&App::Billing::Claim::Treatment::setHospitilizationDateTo], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],
		'Laboratory/Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLab, COLUMNINDEX_VALUE_TEXT],
		'Laboratory/Charges' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLabCharges, COLUMNINDEX_VALUE_TEXT],
		'Medicaid/Resubmission' => [$treatment, [ \&App::Billing::Claim::Treatment::setMedicaidResubmission, \&App::Billing::Claim::Treatment::setResubmissionReference], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Prior Authorization Number' => [$treatment, \&App::Billing::Claim::Treatment::setPriorAuthorizationNo, COLUMNINDEX_VALUE_TEXT],
		'Provider/Tax ID' => [[$payToProvider, $renderingProvider, $payToOrganization, $payToProvider, $renderingProvider, $payToOrganization ], [\&App::Billing::Claim::Physician::setFederalTaxId ,\&App::Billing::Claim::Physician::setFederalTaxId, \&App::Billing::Claim::Organization::setTaxId,\&App::Billing::Claim::Physician::setTaxTypeId, \&App::Billing::Claim::Physician::setTaxTypeId, \&App::Billing::Claim::Organization::setTaxTypeId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Control Number' => [$patient, \&App::Billing::Claim::Patient::setAccountNo, COLUMNINDEX_VALUE_TEXT],
		'Service Facility/Name' => [[$renderingOrganization, $renderingOrganization], [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Billing Facility/Name' =>[$payToOrganization, [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Billing Facility/Billing/CLIA' => [$payToOrganization, \&App::Billing::Claim::Organization::setCLIA, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Employer Number' => [$payToOrganization, \&App::Billing::Claim::Organization::setEmployerNumber, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Medicaid' => [$payToOrganization, \&App::Billing::Claim::Organization::setMedicaidId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Medicare' => [$payToOrganization, \&App::Billing::Claim::Organization::setMedicareId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/State' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setState, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Tax ID' => [$payToOrganization, \&App::Billing::Claim::Organization::setFederalTaxId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Workers Comp' => [$payToOrganization, \&App::Billing::Claim::Organization::setWorkersComp, COLUMNINDEX_VALUE_TEXT],
		'Provider/Organization/Type' => [$renderingOrganization, \&App::Billing::Claim::Organization::setOrganizationType, COLUMNINDEX_VALUE_TEXT],
		'Service Provider/Facility/Billing/Contact' => [[$renderingProvider, $renderingProviderAddress], [\&App::Billing::Claim::Physician::setContact, \&App::Billing::Claim::Address::setTelephoneNo],[COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Site ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSiteId,\&App::Billing::Claim::Physician::setSiteId],[ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Medicare' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setMedicareId, \&App::Billing::Claim::Physician::setMedicareId], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Medicaid' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setMedicaidId, \&App::Billing::Claim::Physician::setMedicaidId], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Champus' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setChampusId,\&App::Billing::Claim::Physician::setChampusId], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Workers Comp' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setWorkersComp,\&App::Billing::Claim::Physician::setChampusId], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Specialty' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSpecialityId,\&App::Billing::Claim::Physician::setSpecialityId], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB]],
		'TPO Participation/Indicator' => [$patient, \&App::Billing::Claim::Patient::setTPO, COLUMNINDEX_VALUE_TEXT],
		'Patient/Legal Rep/Indicator' => [ $patient, \&App::Billing::Claim::Patient::setlegalIndicator, COLUMNINDEX_VALUE_TEXT],
		'Multiple/Indicator' => [$patient, \&App::Billing::Claim::Patient::setMultipleIndicator, COLUMNINDEX_VALUE_TEXT],
		'Claim Filing/Indicator' => [$claim, \&App::Billing::Claim::setFilingIndicator, COLUMNINDEX_VALUE_TEXT],
		'HMO-PPO/ID' => [$insured, \&App::Billing::Claim::Insured::setHMOId, COLUMNINDEX_VALUE_TEXT],
		'Symptom/Indicator' => [ $claim, \&App::Billing::Claim::setSymptomIndicator, COLUMNINDEX_VALUE_TEXT],
		'Accident Hour' => [ $claim, \&App::Billing::Claim::setAccidentHour, COLUMNINDEX_VALUE_TEXT],
		'Responsibility Indicator' => [ $claim, \&App::Billing::Claim::setResponsibilityIndicator, COLUMNINDEX_VALUE_TEXT],
		'Symptom/Indicator/External Cause' => [	$claim, \&App::Billing::Claim::setSymptomExternalCause, COLUMNINDEX_VALUE_TEXT],
		'Information Release/Indicator' => [ $claim, [\&App::Billing::Claim::setInformationReleaseIndicator, \&App::Billing::Claim::setInformationReleaseDate], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_DATE]],
		'Disability/Type' => [ $claim, \&App::Billing::Claim::setDisabilityType, COLUMNINDEX_VALUE_TEXT],
		'Provider/Assign Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setAssignIndicator, \&App::Billing::Claim::Physician::setAssignIndicator],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Signature/Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSignatureIndicator,\&App::Billing::Claim::Physician::setSignatureIndicator], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Signature/Date' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSignatureDate,\&App::Billing::Claim::Physician::setSignatureDate], [ COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATE]],
		'Documentation/Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setDocumentationIndicator,\&App::Billing::Claim::Physician::setDocumentationIndicator], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Documentation/Type' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setDocumentationType,\&App::Billing::Claim::Physician::setDocumentationType], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Special Program/Indicator' => [$claim, \&App::Billing::Claim::setSpProgramIndicator, COLUMNINDEX_VALUE_TEXT],
		'Last Seen/Date' => [$patient, \&App::Billing::Claim::Patient::setLastSeenDate, COLUMNINDEX_VALUE_DATE],
		'Documentation/Date' => [$claim, \&App::Billing::Claim::setdateDocSent, COLUMNINDEX_VALUE_DATE],
		'Anesthesia-Oxygen/Minutes' => [$claim, \&App::Billing::Claim::setAnesthesiaOxygenMinutes, COLUMNINDEX_VALUE_TEXT],
		'HGB-HCT/Date' => [	$claim, \&App::Billing::Claim::setHGBHCTDate, COLUMNINDEX_VALUE_DATE],
		'Serum Creatine/Date' => [$claim, \&App::Billing::Claim::setSerumCreatineDate, COLUMNINDEX_VALUE_DATE],
#		'Rendering/Provider/Tax ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setFederalTaxId, COLUMNINDEX_VALUE_TEXT],
#		'Rendering/Provider/ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setProviderId, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name Qualifier' => [$claim, \&App::Billing::Claim::setQualifier, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Person::setId, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXTB,COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Name/First' => [[$renderingProvider,$payToProvider], [\&App::Billing::Claim::Person::setFirstName, \&App::Billing::Claim::Person::setFirstName],[ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Name/Last' => [[$renderingProvider,$payToProvider], [\&App::Billing::Claim::Person::setLastName, \&App::Billing::Claim::Person::setLastName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Name/Middle' => [[$renderingProvider,$payToProvider], [\&App::Billing::Claim::Person::setMiddleInitial, \&App::Billing::Claim::Person::setMiddleInitial], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Pay To Provider/Name/First' => [$payToProvider,\&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
#		'Pay To Provider/Name/Last' => [$payToProvider, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
#		'Pay To Provider/Name/Middle' => [$payToProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Pay To Provider/Specialty' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSpecialityId,\&App::Billing::Claim::Physician::setSpecialityId,], [COLUMNINDEX_VALUE_TEXTB,COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Network ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setNetworkId,\&App::Billing::Claim::Physician::setNetworkId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXT]],
		'Pay To Provider/Network ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setNetworkId,\&App::Billing::Claim::Physician::setNetworkId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Blue Shield ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setBlueShieldId,\&App::Billing::Claim::Physician::setBlueShieldId],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Qualification/Degree' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setQualification, \&App::Billing::Claim::Physician::setQualification],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/ID Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setIdIndicator,\&App::Billing::Claim::Physician::setIdIndicator],[ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Remarks' => [$claim, \&App::Billing::Claim::setRemarks, COLUMNINDEX_VALUE_TEXT],
		'Representator/Name/Last' => [$legalRepresentator, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,,COLUMNINDEX_VALUE_TEXTB]],
		'Representator/Name/First' => [$legalRepresentator, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Representator/Name/Middle' => [$legalRepresentator, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Invoice/History/Item' => [[$claim, $claim, $claim], [\&App::Billing::Claim::setInvoiceHistoryDate, \&App::Billing::Claim::setInvoiceHistoryAction, \&App::Billing::Claim::setInvoiceHistoryComments], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
#		'Pay To Org/Name' => [$payToOrganization, [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Pay To Org/Phone' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT ],
		'Provider/UPIN' => [[$renderingProvider, $payToProvider, $payToOrganization], [\&App::Billing::Claim::Physician::setPIN,\&App::Billing::Claim::Physician::setPIN,\&App::Billing::Claim::Organization::setUPin], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Service Provider/Facility/Billing/Group Number' => [ $payToOrganization, \&App::Billing::Claim::Physician::setGRP, COLUMNINDEX_VALUE_TEXT],
		'Submission Order' => [[$claim, $claim], [\&App::Billing::Claim::setClaimType, \&App::Billing::Claim::setBillSeq], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT]],
		'Assignment of Benefits' => [[$claim, $payer, $payer2, $payer3, $payer4], [\&App::Billing::Claim::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT]],
		'Pay To Org/Tax ID' => [$payToOrganization, \&App::Billing::Claim::Organization::setFederalTaxId, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Name' => [[$insured, $payer, $payer], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Payment Source' => [$payer, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Branch' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Grade' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Status' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Phone' => [$payerAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Patient-Insured/Relationship' => [$insured, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name'	=> [$insured, \&App::Billing::Claim::Person::setId, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/Last'	=> [$insured, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/First' => [$insured, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/Middle' => [$insured, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/Marital Status' => [$insured, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/Gender' => [$insured, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/DOB' => [$insured, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Member Number'  => [$insured, \&App::Billing::Claim::Insured::setMemberNumber , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/SSN'  => [$insured, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Contact/Home Phone' => [$insuredAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Employer/Name'	=> [$insured, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/School/Name'	=> [$insured, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Effective Dates' => [$insured, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Type' => [$insured, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Group Number' => [$insured, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/HMO-PPO/Indicator' => [$insured, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/BCBS/Plan Code' => [$insured, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/E-Remitter ID' => [$payer, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Name' => [[$insured2, $payer2, $payer2], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Payment Source' => [$payer2, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Branch' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Grade' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Status' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Phone' => [$payer2Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Patient-Insured/Relationship' => [$insured2, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Name'	=> [$insured2, \&App::Billing::Claim::Person::setId, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Name/Last'	=> [$insured2, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Name/First' => [$insured2, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Name/Middle' => [$insured2, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Personal/Marital Status' => [$insured2, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Personal/Gender' => [$insured2, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Personal/DOB' => [$insured2, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Member Number'  => [$insured2, \&App::Billing::Claim::Insured::setMemberNumber , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Personal/SSN'  => [$insured2, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Contact/Home Phone' => [$insured2Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Employer/Name'	=> [$insured2, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/School/Name'	=> [$insured2, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Effective Dates' => [$insured2, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Type' => [$insured2, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Group Number' => [$insured2, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/HMO-PPO/Indicator' => [$insured2, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/BCBS/Plan Code' => [$insured2, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/E-Remitter ID' => [$payer2, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Name' => [[$insured3, $payer3, $payer3], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Payment Source' => [$payer3, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Branch' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Grade' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Status' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Phone' => [$payer3Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Patient-Insured/Relationship' => [$insured3, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Name'	=> [$insured3, \&App::Billing::Claim::Person::setId, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Name/Last'	=> [$insured3, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Name/First' => [$insured3, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Name/Middle' => [$insured3, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Personal/Marital Status' => [$insured3, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Personal/Gender' => [$insured3, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Personal/DOB' => [$insured3, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Member Number'  => [$insured3, \&App::Billing::Claim::Insured::setMemberNumber , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Personal/SSN'  => [$insured3, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Contact/Home Phone' => [$insured3Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Employer/Name'	=> [$insured3, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/School/Name'	=> [$insured3, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Effective Dates' => [$insured3, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Type' => [$insured3, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Group Number' => [$insured3, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/HMO-PPO/Indicator' => [$insured3, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/BCBS/Plan Code' => [$insured3, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/E-Remitter ID' => [$payer3, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Name' => [[$insured4, $payer4, $payer4], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Payment Source' => [$payer4, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Branch' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Grade' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Status' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Phone' => [$payer4Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Patient-Insured/Relationship' => [$insured4, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Name'	=> [$insured4, \&App::Billing::Claim::Person::setId, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Name/Last'	=> [$insured4, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Name/First' => [$insured4, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Name/Middle' => [$insured4, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Personal/Marital Status' => [$insured4, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Personal/Gender' => [$insured4, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Personal/DOB' => [$insured4, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Member Number'  => [$insured4, \&App::Billing::Claim::Insured::setMemberNumber , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Personal/SSN'  => [$insured4, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Contact/Home Phone' => [$insured4Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Employer/Name'	=> [$insured4, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/School/Name'	=> [$insured4, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Effective Dates' => [$insured4, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Type' => [$insured4, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Group Number' => [$insured4, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/HMO-PPO/Indicator' => [$insured4, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/BCBS/Plan Code' => [$insured4, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/E-Remitter ID' => [$payer4, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Invoice/TWCC61/16' => [$treatment, [\&App::Billing::Claim::Treatment::setReturnToLimitedWorkAnticipatedDate, \&App::Billing::Claim::Treatment::setMaximumImprovementAnticipatedDate, \&App::Billing::Claim::Treatment::setReturnToFullTimeWorkAnticipatedDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEA, COLUMNINDEX_VALUE_DATEB]],
		'Invoice/TWCC61/17' => [$treatment, \&App::Billing::Claim::Treatment::setInjuryHistory, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/18' => [$treatment, \&App::Billing::Claim::Treatment::setPastMedicalHistory, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/19' => [$treatment, \&App::Billing::Claim::Treatment::setClinicalFindings, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/20' => [$treatment, \&App::Billing::Claim::Treatment::setLaboratoryTests, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/21' => [$treatment, \&App::Billing::Claim::Treatment::setTreatmentPlan, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/22' => [$treatment, [\&App::Billing::Claim::Treatment::setReferralInfo, \&App::Billing::Claim::Treatment::setReferralSelection], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC61/23' => [$treatment, \&App::Billing::Claim::Treatment::setMedications, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/24' => [$treatment, \&App::Billing::Claim::Treatment::setPrognosis, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/26' => [$treatment, \&App::Billing::Claim::Treatment::setDateMailedToEmployee, COLUMNINDEX_VALUE_DATE],
		'Invoice/TWCC61/27' => [$treatment, \&App::Billing::Claim::Treatment::setDateMailedToInsurance, COLUMNINDEX_VALUE_DATE],

		'Invoice/TWCC64/17' => [$treatment, [\&App::Billing::Claim::Treatment::setActivityType, \&App::Billing::Claim::Treatment::setActivityDate, \&App::Billing::Claim::Treatment::setReasonForReport], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC64/18' => [$treatment, \&App::Billing::Claim::Treatment::setChangeInCondition, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC64/23' => [$treatment, \&App::Billing::Claim::Treatment::setComplianceByEmployee, COLUMNINDEX_VALUE_TEXT],

		'Invoice/TWCC69/17' => [$treatment, [\&App::Billing::Claim::Treatment::setMaximumImprovementDate, \&App::Billing::Claim::Treatment::setMaximumImprovement], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC69/18' => [$treatment, \&App::Billing::Claim::Treatment::setImpairmentRating, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC69/19' => [$treatment, [\&App::Billing::Claim::Treatment::setDoctorType, \&App::Billing::Claim::Treatment::setExaminingDoctorType], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC69/22' => [$treatment, [\&App::Billing::Claim::Treatment::setMaximumImprovementAgreement, \&App::Billing::Claim::Treatment::setImpairmentRatingAgreement], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],

	};

	my $queryStatment = " select ITEM_ID, ITEM_NAME, VALUE_TEXT, VALUE_TEXTB, VALUE_INT, VALUE_INTB, VALUE_FLOAT, VALUE_FLOATB, to_char(VALUE_DATE, \'dd-MON-yyyy\'), to_char(VALUE_DATEEND, \'dd-MON-yyyy\'), to_char(VALUE_DATEA, \'dd-MON-yyyy\'), to_char(VALUE_DATEB, \'dd-MON-yyyy\') from invoice_attribute where parent_id = $invoiceId ";
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
		$claim->setSourceOfPayment($tp1->getSourceOfPayment);
##		$claim->setBCBSPlanCode($ti1->getBCBSPlanCode);
		$patient->setRelationshipToInsured($ti1->getRelationshipToPatient);
		$claim->setPayer($tp1);
	}
	else
	{
		$claim->setPayer($payer);
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
	$claim->setRenderingOrganization($renderingOrganization);
	$claim->setRenderingProvider($renderingProvider);
	$self->assignInvoiceAddresses($invoiceId, $claim,\@objects);
	$self->payersRemainingProperties([$payer, $payer2, $payer3, $payer4], $invoiceId, $claim);

	return \@objects;
}

sub payersRemainingProperties
{
	my ($self, $payers, $invoiceId, $claim) = @_;
	my $billSeq = [];
	my $queryStatment;
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = PRIMARY;
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = SECONDARY;
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  TERTIARY;
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = QUATERNARY;
	my @billPartyType = ('', 'Person', 'Org');
	$queryStatment = "select bill_sequence, bill_amount, bill_party_type from invoice_billing where
						    invoice_id = $invoiceId";
	my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
	$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	my @row;
	my $colValTxt = 1;
	my @row1;
	while(@row = $sth->fetchrow_array())
	{
		my $payer = $payers->[$billSeq->[$row[0]] + 0];
		if ($payer ne "")
		{
			$payer->setAmountPaid($row[1]);
			$payer =	$claim->{payer};
			my $inputMap = {
				'Third-Party/Person/Name' => [$payer, [\&App::Billing::Claim::Payer::setName, \&App::Billing::Claim::Payer::setId], [$colValTxt, $colValTxt + 1]],
				'Third-Party/Person/Phone' => [$payer->getAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValTxt],
				'Third-Party/Org/Name' => [$payer, [\&App::Billing::Claim::Payer::setName, \&App::Billing::Claim::Payer::setId], [$colValTxt, $colValTxt + 1]],
				'Third-Party/Org/Phone' => [$payer->getAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValTxt],
			};
			my $colAttr = 0;
			if ($row[2] =~ /1|2/)
			{
				$queryStatment = "select Item_name, value_text, value_textB from invoice_attribute where
							    parent_id = $invoiceId and item_name like \'Third-Party/$billPartyType[$row[2]]/%\'";
				my $sth1 = $self->{dbiCon}->prepare(qq {$queryStatment});
				$sth1->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
				while (@row1 = $sth1->fetchrow_array())
				{
					if(my $attrInfo = $inputMap->{$row1[$colAttr]})
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
										&$functionRef($objInst->[$methodNum], ($row1[$bindColumn->[$methodNum]]));
									}
								}
								else
								{
									for my $methodNum (0..$#$method)
									{
										my $functionRef = $method->[$methodNum];
										&$functionRef($objInst, ($row1[$bindColumn->[$methodNum]]));
									}
								}
							}
							else
							{
								&$method($objInst, ($row1[$bindColumn]));
							}
						}
					}
				}
			}
		}
	}
}

sub setproperRenderingProvider
{
	my ($self, $claim, $renderingProvider, $renderingOrganization) = @_;

#	my $renderingOrg = new App::Billing::Claim::Organization;
#	$renderingOrg->setId($renderingOrganization->getId);
#	$renderingOrg->setFederalTaxId($renderingProvider->getFederalTaxId);
#	$renderingOrg->setName($renderingOrganization->getName);
#	$renderingOrg->setSpecialityId($renderingProvider->getSpecialityId);
#	$claim->setRenderingOrganization($renderingOrg);
#	$claim->setRenderingOrganization($renderingOrganization);
#	$claim->setRenderingProvider($renderingProvider);
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
	my $queryStatment = "select  total_cost, INVOICE_STATUS, CLAIM_DIAGS, balance,
								Invoice.total_adjust, Invoice_subtype, client_id,
								invoice_type, total_items, Invoice_date
								from invoice where invoice_id = $invoiceId";
	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@tempRow = $sth->fetchrow_array();
	my $diagnosis;
	$tempRow[2] =~ s/ //g;
	my @diagnosisCodes = split (/,/, $tempRow[2]) ;
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
	$currentClaim->setTotalInvoiceCharges($tempRow[0]);
	$currentClaim->setStatus($tempRow[1]);
	$currentClaim->setBalance($tempRow[3]);
	$currentClaim->setAmountPaid($tempRow[4]);
	$currentClaim->setCareReceiver($patient);
	$currentClaim->setPayToProvider($payToProvider);
	$currentClaim->setPayToOrganization($payToOrganization);
	$currentClaim->setLegalRepresentator($legalRepresentator);
	$currentClaim->setProgramName($ins[$tempRow[5]]);
	$currentClaim->setInvoiceSubtype($tempRow[5]);
	$currentClaim->{renderingProvider}->setInsType($tempRow[5]);
	$currentClaim->{payToProvider}->setInsType($tempRow[5]);
	$currentClaim->setInsType($tempRow[5]);
	$currentClaim->setInvoiceType($tempRow[7]);
	$currentClaim->setTotalItems($tempRow[8]);
	$currentClaim->setInvoiceDate($tempRow[9]);
	$patient->setId($tempRow[6]);
	my $no = $currentClaim->getClaimType;
	my $insureds = [$insured, $insured2, $insured3, $insured4];
	$currentClaim->addInsured($insureds->[0]);
	$currentClaim->addInsured($insureds->[1]);
	$currentClaim->addInsured($insureds->[2]);
	$currentClaim->addInsured($insureds->[3]);
#	$self->assignPatientInsurance($currentClaim, $invoiceId);
	my $payers = [ $payer, $objects->[12], $objects->[13], $objects->[14]];
	$currentClaim->addPolicy($payers->[0]);
	$currentClaim->addPolicy($payers->[1]);
	$currentClaim->addPolicy($payers->[2]);
	$currentClaim->addPolicy($payers->[3]);
#	$self->assignPolicy($currentClaim, $invoiceId);
#	$currentClaim->setPayer($payer); now set in setInvoiceAttribute. 29apr2000.
#	$currentClaim->getTotalCharge();
#	$currentClaim->getStatus();
#	$currentClaim->getBalance();
	$self->assignTransProvider($currentClaim, $invoiceId);
	my $count;
	$self->setProperPayer($invoiceId, $currentClaim	);
	my $tempItems = $currentClaim->{procedures};
	my $tempDiagnosisCodes;
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{otherItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{adjItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$tempItems = $currentClaim->{copayItems};
	for($count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}
	$self->populateVisitDate($invoiceId, $currentClaim, $patient);
	$self->populateChangedTreatingDoctor($invoiceId, $currentClaim);
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
	$codes =~ s/ //g;
	my @diagCodes = split(/,/, $codes);
	for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
	{
		$ptr =  $ptr . " " .  $diagnosisMap->{$diagCodes[$diagnosisCount]};
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
				my $payerName = $payer->getName();

				#$queryStatment = "select  id from ref_epayer where name = \'$payerName\'";
				$queryStatment = "select a.value_text from invoice_attribute a, invoice i where i.invoice_id = $invoiceId and i.invoice_id = a.parent_id and item_name = 'Insurance/Primary/E-Remitter ID'";
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
			$currentClaim->setPayer($payer);
		}
#	$currentClaim->setPayer($payer);
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
	my @claimCharge;
	my $claimChargePaid=0;

	$itemMap[INVOICE_ITEM_OTHER] = \&App::Billing::Claim::addOtherItems;
	$itemMap[INVOICE_ITEM_SERVICE] = \&App::Billing::Claim::addProcedure;
	$itemMap[INVOICE_ITEM_LAB] = \&App::Billing::Claim::addProcedure;
	$itemMap[INVOICE_ITEM_COPAY] = \&App::Billing::Claim::addCopayItems;
	$itemMap[INVOICE_ITEM_ADJUST] = \&App::Billing::Claim::addAdjItems;
	$itemMap[INVOICE_ITEM_COINSURANCE] = \&App::Billing::Claim::addCoInsurance;
	$itemMap[INVOICE_ITEM_DEDUCTABLE] = \&App::Billing::Claim::addDeductible;
	$itemMap[INVOICE_ITEM_VOID] = \&App::Billing::Claim::addVoidItems;


 	#$queryStatment = "select data_date_a, data_date_b, data_num_a, data_num_b, code, modifier, unit_cost, quantity, data_text_a, REL_DIAGS, data_text_c, DATA_TEXT_B , item_id, extended_cost, balance, total_adjust, item_type from invoice_item where parent_id = $invoiceId ";

 	$queryStatment = qq{
		select to_char(service_begin_date, 'dd-MON-yyyy'),
			to_char(service_end_date, 'dd-MON-yyyy'),
			nvl(HCFA1500_Service_Place_Code.abbrev, } . DEFAULT_PLACE_OF_SERIVCE . qq{) as service_place,
			nvl(HCFA1500_Service_Type_Code.abbrev, }. '01' . qq{) as service_type, code, modifier,
			unit_cost, quantity, emergency, REL_DIAGS, reference, COMMENTS , item_id, extended_cost,
			balance, total_adjust, item_type, flags, invoice_item.caption, to_char(nvl(service_begin_date,
			cr_stamp), 'dd-MON-yyyy'), data_text_b, code_type
 		from HCFA1500_Service_Type_Code, HCFA1500_Service_Place_Code, invoice_item
 		where parent_id = $invoiceId
 			and HCFA1500_Service_Place_Code.id (+) = invoice_item.hcfa_service_place
 			and HCFA1500_Service_Type_Code.id (+)  = invoice_item.hcfa_service_type
 	};

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
		$procedureObject->setItemType($tempRow[16]);
		$procedureObject->setFlags($tempRow[17]);
		$procedureObject->setCaption($tempRow[18]);
		$procedureObject->setPaymentDate($tempRow[19]);
		$procedureObject->setItemStatus($tempRow[20]);
		$procedureObject->setCodeType($tempRow[21]);

		$self->populateAdjustments($procedureObject, $tempRow[12]);
		$functionRef = $itemMap[$tempRow[16]];
		if (($tempRow[16] == INVOICE_ITEM_LAB) && (uc($tempRow[20]) ne "VOID"))
		{
			$outsideLabCharges = $outsideLabCharges + $tempRow[13]
		}
		if (uc($tempRow[20]) ne "VOID")
		{
			$claimCharge[$tempRow[16]] = $claimCharge[$tempRow[16]] + $tempRow[13];
			$claimChargePaid = $claimChargePaid + $tempRow[15] if (($tempRow[16] == INVOICE_ITEM_SERVICE) ||($tempRow[16] == INVOICE_ITEM_LAB));

		}
		if ($functionRef ne "")
		{
			&$functionRef($currentClaim, $procedureObject) ;
		}
	}
	$currentClaim->{treatment}->setOutsideLab(($outsideLabCharges eq "") ? 'N' : 'Y');
	$currentClaim->{treatment}->setOutsideLabCharges($outsideLabCharges);
	$currentClaim->setTotalCharge($claimCharge[INVOICE_ITEM_LAB] + $claimCharge[INVOICE_ITEM_SERVICE]);
	$currentClaim->setTotalChargePaid($claimChargePaid);

}

sub populateAdjustments
{
	my ($self, $procedure, $ItemId) = @_;
	my @tempRow;
	my $adjustment;
	my	$queryStatment = "select adjustment_id, adjustment_type, adjustment_amount, bill_id, flags,
								payer_type, payer_id, parent_id, plan_allow, plan_paid, deductible, copay,
								to_char(submit_date, \'dd-MON-yyyy\'), to_char(pay_date, \'dd-MON-yyyy\'), pay_method, pay_ref, writeoff_code, writeoff_amount,
								adjust_codes, net_adjust, comments, data_text_a, parent_id
 										from invoice_item_Adjust
 										where parent_id = $ItemId ";

	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or  $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	while(@tempRow = $sth->fetchrow_array())
	{
		$adjustment = new App::Billing::Claim::Adjustment;
		$adjustment->setAdjsutId($tempRow[0]);
		$adjustment->setAdjustType($tempRow[1]);
		$adjustment->setAdjustAmt($tempRow[2]);
		$adjustment->setBillId($tempRow[3]);
		$adjustment->setFlags($tempRow[4]);
		$adjustment->setPayerType($tempRow[5]);
		$adjustment->setPayerId($tempRow[6]);
		$adjustment->setPlanAllow($tempRow[7]);
		$adjustment->setPlanPaid($tempRow[8]);
		$adjustment->setDeductible($tempRow[9]);
		$adjustment->setCopay($tempRow[10]);
		$adjustment->setSubmitDate($tempRow[11]);
		$adjustment->setPayDate($tempRow[12]);
		$adjustment->setPayType($tempRow[13]);
		$adjustment->setPayMethod($tempRow[14]);
		$adjustment->setPayRef($tempRow[15]);
		$adjustment->setWriteoffCode($tempRow[16]);
		$adjustment->setWriteoffAmt($tempRow[17]);
		$adjustment->setAdjustCodes($tempRow[18]);
		$adjustment->setNetAdjust($tempRow[19]);
		$adjustment->setComments($tempRow[20]);
		$adjustment->setAuthRef($tempRow[21]);
		$adjustment->setParentId($tempRow[22]);

		$procedure->addAdjustments($adjustment);
	}
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
#	$objects[10] = $insured2;
#	$objects[11] = $insured3;
#	$objects[12] = $payer2;
#	$objects[13] = $payer3;
#	$objects[14] = $payer4;
#	$objects[15] = $insured4;
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
	my $insured2Address = $objects->[10]->getAddress;
	my $payer2Address = $objects->[12]->getAddress;
	my $insured3Address = $objects->[11]->getAddress;
	my $payer3Address = $objects->[13]->getAddress;
	my $insured4Address = $objects->[15]->getAddress;
	my $payer4Address = $objects->[14]->getAddress;
	my $thirdPartyTypeAddress = $currentClaim->{payer}->getAddress;
	my @methods = (\&App::Billing::Claim::Address::setAddress1,\&App::Billing::Claim::Address::setAddress2,\&App::Billing::Claim::Address::setCity,\&App::Billing::Claim::Address::setState,\&App::Billing::Claim::Address::setZipCode,\&App::Billing::Claim::Address::setCountry);
	my @bindColumns = (COLUMNINDEX_ADDRESS1,COLUMNINDEX_ADDRESS2,COLUMNINDEX_CITY,COLUMNINDEX_STATE,COLUMNINDEX_ZIPCODE,COLUMNINDEX_COUNTRY);

	my $addessMap =
	{
		'Billing' => [$renderingProviderAddress],
	 	 BILLSEQ_PRIMARY_CAPTION . ' Insured' => [$insuredAddress],
		 BILLSEQ_SECONDARY_CAPTION . ' Insured' => [$insured2Address],
		 BILLSEQ_TERTIARY_CAPTION . ' Insured' => [$insured3Address],
		 BILLSEQ_QUATERNARY_CAPTION . ' Insured' => [$insured4Address],
		'Patient' => [$patientAddress],
		'Service' => [$renderingOrganizationAddress],
		'Pay To Org' => [$payToOrganizationAddress],
		'legalRepresentator' => [$legalRepresentatorAddress],
 		 BILLSEQ_PRIMARY_CAPTION . ' Insurance' => [$payerAddress],
 		 BILLSEQ_SECONDARY_CAPTION . ' Insurance' => [$payer2Address],
  		 BILLSEQ_TERTIARY_CAPTION . ' Insurance' => [$payer3Address],
 		 BILLSEQ_QUATERNARY_CAPTION . ' Insurance' => [$payer4Address],
 		 'Third-Party' => [$thirdPartyTypeAddress],
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
	$payToProvider->setAddress($renderingProviderAddress);
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
}

sub getId
{
	'IDBI'
}

sub populateVisitDate
{
	my ($self, $invoiceId, $currentClaim, $patient) = @_;
	my @tempRow;

	my $queryStatment = qq{
		select to_char(min(service_begin_date), 'mm/dd/yyyy')
 		from invoice_item
 		where parent_id = $invoiceId
 	 	};

	my $sth = $self->{dbiCon}->prepare(qq{$queryStatment});
	$sth->execute or  $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
	@tempRow = $sth->fetchrow_array();
	$patient->setVisitDate($tempRow[0]);

}

sub populateChangedTreatingDoctor
{
	my ($self, $invoiceId, $currentClaim) = @_;
	my $changedTreatingDoctor = new App::Billing::Claim::Physician;
	my $changedTreatingDoctorAddress = new App::Billing::Claim::Address;
	$changedTreatingDoctor->setType("changedTreatingDoctor");
	$changedTreatingDoctor->setAddress($changedTreatingDoctorAddress);
	$currentClaim->setChangedTreatingDoctor($changedTreatingDoctor);

	if ($currentClaim->{treatment}->{reasonForReport} == 3)
	{
		my $id = $currentClaim->{treatment}->{activityType};
		my $queryStatment = "select complete_name from person where person_id = \'$id\'";
		my $sth = $self->{dbiCon}->prepare(qq {$queryStatment});
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		my @row = $sth->fetchrow_array();
		$changedTreatingDoctor->setId($id);
		$changedTreatingDoctor->setName($row[0]);
		$queryStatment = "select line1, line2, city, state, zip, country from person_address where parent_id = \'$id\'";
		$self->populateAddress($changedTreatingDoctorAddress, $queryStatment);

		$queryStatment = "select value_text from person_attribute where parent_id = \'$id\' and value_type = " . PROFESSIONAL_LICENSE_NO;
		$sth = $self->{dbiCon}->prepare(qq {$queryStatment});
		$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		$changedTreatingDoctor->setProfessionalLicenseNo($row[0]);
	}
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
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/21/2000', 'SSI','Billing Interface/Input DBI','Insured Employment Status is populated from person attribute.value type '],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/28/2000', 'SSI','Billing Interface/Input DBI','rendering provider Id is set from value_textb of invoice_attribute with item_name provider/name'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '04/28/2000', 'SSI','Billing Interface/Input DBI','Patient ID is populated form invoice.client_id in both pre-submit and post-submit cases'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/05/2000', 'SSI','Billing Interface/Input DBI','GRP number is not populated in pre-submit'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/06/2000', 'SSI', 'Billing Interface/Input DBI','payment date property added which holds a payment date for copay and adjustment items'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/06/2000', 'SSI', 'Billing Interface/Input DBI','Patient-Insured is changed to Patient-Insured/Relationship'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/23/2000', 'SSI', 'Billing Interface/Input DBI','Pay to org tax id is now pulling form invoice_attribue in both pre and post submit cases. Pay To Org/Tax ID(item path)'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/24/2000', 'SY', 'Billing Interface/Input DBI','Change the query, to fetch the values of invoice_type, invoice_subtype and total_items'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/24/2000', 'SY', 'Billing Interface/Input DBI','New Invoice Status (void) Implmented.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '05/24/2000', 'SSI', 'Billing Interface/Input DBI','Payer name is being populated nvl(PRODUCT_NAME, PLAN_NAME) when bill_party_type =3 in invoice_billing.'],
	[CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '05/24/2000', 'SSI', 'Billing Interface/Input DBI','Claim->{totalCharge} will only provide the sum of amount of service and lab items'],
);

1;
