################################################################
package App::Billing::Input::DBI;
################################################################

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
use App::Billing::Claim::TWCC73;
use App::Billing::Claim::TWCC60;
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

use constant INVOICESTATUS_SUBMITTED => 4;
use constant INVOICESTATUS_APPEALED => 14;
use constant INVOICESTATUS_CLOSED => 15;
use constant INVOICESTATUS_VOID => 16;

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

use constant CONTACT_METHOD_TELEPHONE => 10;
use constant CONTACT_METHOD_FAX => 15;
use constant CONTACT_METHOD_BILLING => 25;

use constant ASSOCIATION_EMPLOYMENT_ALL => '(220,221,222,223,224,225,226)';
use constant ASSOCIATION_EMPLOYMENT_STUDENT => '(224)|(225)';
use constant AUTHORIZATION_PATIENT => 370;
use constant CERTIFICATION_LICENSE => 500;
use constant INSURANCE_PROVIDER_LICENSE => 550;
use constant PROFESSIONAL_LICENSE_NO => 510;
use constant PHYSICIAN_SPECIALTY => 540;
use constant FACILITY_GROUP_NUMBER => 600;

use constant PRIMARY => 0;
use constant SECONDARY => 1;
use constant TERTIARY => 2;
use constant QUATERNARY => 3;

#  Address Constants
use constant COLUMNINDEX_ADDRESSNAME => 0;
use constant COLUMNINDEX_ADDRESS1 => 1;
use constant COLUMNINDEX_ADDRESS2 => 2;
use constant COLUMNINDEX_CITY => 3;
use constant COLUMNINDEX_STATE => 4;
use constant COLUMNINDEX_ZIPCODE => 5;
use constant COLUMNINDEX_COUNTRY => 6;

#  Insurance Record Type Constants
use constant RECORDTYPE_CATEGORY => 0;
use constant RECORDTYPE_INSURANCE_PRODUCT => 1;
use constant RECORDTYPE_INSURANCE_PLAN => 2;
use constant RECORDTYPE_PERSONAL_COVERAGE => 3;

#  Bill Sequence Constants
use constant BILLSEQ_INACTIVE => 99;
use constant BILLSEQ_PRIMARY_PAYER => 1;
use constant BILLSEQ_SECONDARY_PAYER => 2;
use constant BILLSEQ_TERTIARY_PAYER => 3;
use constant BILLSEQ_QUATERNARY_PAYER => 4;
use constant BILLSEQ_WORKERSCOMP_PAYER => 5;

#  Bill Party Type Constants
use constant BILL_PARTY_TYPE_CLIENT => 0;
use constant BILL_PARTY_TYPE_PERSON => 1;
use constant BILL_PARTY_TYPE_ORGANIZATION => 2;
use constant BILL_PARTY_TYPE_INSURANCE => 3;

# Claim Type Constants
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
use constant CLAIM_TYPE_RAILROAD_MEDICARE => 15;

# Invoice Item Type Constants
use constant INVOICE_ITEM_OTHER => 0;
use constant INVOICE_ITEM_SERVICE => 1;
use constant INVOICE_ITEM_LAB => 2;
use constant INVOICE_ITEM_COPAY => 3;
use constant INVOICE_ITEM_COINSURANCE => 4;
use constant INVOICE_ITEM_ADJUST => 5;
use constant INVOICE_ITEM_DEDUCTABLE => 6;
use constant INVOICE_ITEM_VOID => 7;

# Bill Sequence Captions
use constant BILLSEQ_PRIMARY_CAPTION => 'Primary';
use constant BILLSEQ_SECONDARY_CAPTION => 'Secondary';
use constant BILLSEQ_TERTIARY_CAPTION => 'Tertiary';
use constant BILLSEQ_QUATERNARY_CAPTION => 'Quaternary';

# Default Place of Service for Items
use constant DEFAULT_PLACE_OF_SERIVCE => 11;


sub new
{
	my ($type) = shift;
	my $self = new App::Billing::Input::Driver(@_);
	return bless $self, $type;
}

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

sub getTargetInvoices
{
	my ($self, $submittedStatus) = @_;

	$submittedStatus = INVOICESTATUS_SUBMITTED if ($submittedStatus eq undef);

	my @row;
	my @allRecords;
	my $statment = "";
	my $i = 0;
	my $queryStatment;

	if($submittedStatus eq undef)
	{
		my $claimTypeSelf = CLAIM_TYPE_SELF;
		my $claimTypeThirdParty = CLAIM_TYPE_THIRD_PARTY;
		my $appealedStatus = INVOICESTATUS_APPEALED;

		$queryStatment = qq
		{
			select distinct invoice_id
			from invoice
			where invoice_status in ($submittedStatus, $appealedStatus)
			and invoice_subtype  <> $claimTypeSelf
			and invoice_subtype <> $claimTypeThirdParty
		};
	}
	else
	{
		$queryStatment = qq
		{
			select distinct invoice_id
			from invoice
			where invoice_status = $submittedStatus
		};
	}

	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	while(@row = $sth->fetchrow_array())
	{
		$allRecords[$i] = $row[0];
		$i++;
	}
	return \@allRecords;
}

sub preSubmitStatusCheck
{
	my ($self, $claim, $attrDataFlag, $row) = @_;
	my $go = 0;

	$go = 1 if(($claim->getStatus() < INVOICESTATUS_SUBMITTED) || (($claim->getInvoiceSubtype == CLAIM_TYPE_SELF) && ($claim->getStatus() ==  INVOICESTATUS_CLOSED)) || (($claim->getStatus() == INVOICESTATUS_VOID) && not($attrDataFlag & $row)));

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

	if($params{dbiHdl} ne "")
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
	}
	elsif (($params{invoiceIds} ne undef))
	{
		$targetInvoices = $params{invoiceIds} ;
	}
	else
	{
		$targetInvoices = $self->getTargetInvoices($params{invoiceStatus});
	}

	for $i (0..$#$targetInvoices)
	{
		$currentClaim = $self->assignInvoiceProperties($targetInvoices->[$i]);
		$self->populateItems($targetInvoices->[$i], $currentClaim);
		$self->setClaimProperties($targetInvoices->[$i], $currentClaim);
		$claimList->addClaim($currentClaim);
	}

	my $claims = $claimList->getClaim();
	for $i (0..$#$targetInvoices)
	{
		my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
		my $queryStatment = qq
		{
			select flags
			from invoice
			where invoice_id = $targetInvoices->[$i]
		};
		my $sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		if($self->preSubmitStatusCheck($claims->[$i], $attrDataFlag, $row[0]) == 1)
		{
			$self->assignInvoicePreSubmit($claims->[$i], $targetInvoices->[$i]);
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
	$self->assignPatientInfo($claim, $invoiceId);
	$self->assignPatientAttributes($claim, $invoiceId);
	$self->assignPatientInsurance($claim, $invoiceId);
	$self->assignProviderInfo($claim, $invoiceId);
	$self->assignPaytoAndRendProviderInfo($claim, $invoiceId);
	$self->assignReferralPhysician($claim, $invoiceId);
	$self->assignServiceFacility($claim, $invoiceId);
	$self->assignBillingFacility($claim, $invoiceId);
	$self->assignPaytoAndRendFacilityInfo($claim, $invoiceId);
	$self->assignPayerInfo($claim, $invoiceId);
}

sub assignPatientInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $patient = $claim->getCareReceiver();

	my $queryStatment = qq
	{
		select
			name_last,
			name_middle,
			name_first,
			person_id,
			to_char(date_of_birth, \'DD-MON-YYYY\'),
			gender,
			marital_status,
			ssn,
			complete_name
		from invoice, person
		where invoice_id = $invoiceId
		and person_id = invoice.client_id
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$patient->setLastName($row[0]);
	$patient->setMiddleInitial($row[1]);
	$patient->setFirstName($row[2]);
	$patient->setId($row[3]);
	$patient->setDateOfBirth($row[4]);
	$patient->setSex($row[5]);
	$patient->setStatus($row[6]);
	$patient->setSsn($row[7]);
	$patient->setName($row[8]);

	$self->populateAddress($patient->getAddress(), "person_address", $row[3], "Home");
	$self->populateContact($patient->getAddress(), "person_attribute", $row[3], "Home", CONTACT_METHOD_TELEPHONE);
	$queryStatment = qq
	{
		select value_text, value_type, value_int
		from person_attribute
		where parent_id = \'$row[3]\'
		and value_type in
	}
	. ASSOCIATION_EMPLOYMENT_ALL;

	$sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	@row = $sth->fetchrow_array();

	if($row[2] ne "")
	{
		$patient->setEmploymentStatus($row[0]);
		my $a = ASSOCIATION_EMPLOYMENT_STUDENT;
		$patient->setStudentStatus($row[0] =~ /$a/ ? $row[0] : "");

		my $orgId = $row[2];
		$queryStatment = qq
		{
			select org.org_id, org.name_primary
			from org
			where org.org_internal_id = $orgId
		};
		$sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();

		$patient->setEmployerOrSchoolId($row[0]);
		$patient->setEmployerOrSchoolName($row[1]);
		$self->populateAddress($patient->getEmployerAddress(), "org_address", $orgId, "Mailing");
		$self->populateContact($patient->getEmployerAddress(), "org_attribute", $orgId, "Primary", CONTACT_METHOD_TELEPHONE);
	}
}

sub assignPatientAttributes
{
	my ($self, $claim, $invoiceId) = @_;

	my $patient = $claim->getCareReceiver();
	my $patientId = $patient->getId();

	my $colValText = 0 ;
	my $colValTextB = 1 ;
	my $colAttrnName = 2;
	my $colValueDate = 3;

	my $inputMap =
	{
		AUTHORIZATION_PATIENT . 'Signature Source' => [ $patient, [\&App::Billing::Claim::Patient::setSignature, \&App::Billing::Claim::Patient::setSignatureDate], [$colValTextB, $colValueDate] ],
		AUTHORIZATION_PATIENT . 'Information Release' => [ $claim, \&App::Billing::Claim::setInformationReleaseIndicator, $colValText]
	};
	my @row;

	my $queryStatment = qq
	{
		select value_text, value_textb, value_type || item_name, value_date
		from person_attribute, invoice
		where invoice_id = $invoiceId
		and parent_id = \'$patientId\'
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

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
	$self->setProperPayer($invoiceId, $claim);
}

sub assignPatientInsurance
{
	my ($self, $claim, $invoiceId) = @_;

	my $patient = $claim->getCareReceiver();
	my $insureds = $claim->{insured};
	my $insured;

	my $no = 0;
	my $queryStatment;
	my $sth;
	my $sth1;
	my @row;
	my @row1;

	$queryStatment = qq
	{
		select bill_party_type, bill_sequence
		from invoice_billing
		where invoice_id = $invoiceId
		and bill_status is null
		and invoice_item_id is null
		order by bill_sequence
	};
	$sth1 = $self->{dbiCon}->prepare("$queryStatment");
	$sth1->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");



	while((@row1 = $sth1->fetchrow_array()) && ($no <= 3))
	{
		if($row1[0] eq BILL_PARTY_TYPE_INSURANCE)
		{
			$queryStatment = qq
			{
				select
					nvl(plan_name, product_name),
					ins.rel_to_insured,
					invoice_billing.bill_sequence,
					ins.group_number,
					ins.insured_id,
					to_char(coverage_begin_date, 'DD-MON-YYYY'),
					to_char(coverage_end_date, 'DD-MON-YYYY'),
					group_name,
					ins.member_number,
					ins.extra,
					ins.employer_org_id
				from insurance ins, invoice_billing
				where invoice_billing.invoice_id = $invoiceId
				and invoice_billing.invoice_item_id is null
				and invoice_billing.bill_party_type = @{[ BILL_PARTY_TYPE_INSURANCE ]}
				and invoice_billing.bill_ins_id = ins.ins_internal_id
				and invoice_billing.bill_sequence = $row1[1]
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

			@row = $sth->fetchrow_array();
			$insured = $insureds->[$no];
			$insured->setInsurancePlanOrProgramName($row[0]);
			$insured->setRelationshipToPatient($row[1]);
			$insured->setBillSequence($row[2]);
			$insured->setPolicyGroupOrFECANo($row[3]);
			$insured->setId($row[4]);
			$insured->setEffectiveDate($row[5]);
			$insured->setTerminationDate($row[6]);
			$insured->setPolicyGroupName($row[7]);
			$insured->setMemberNumber($row[8]);
			$insured->setTypeCode($row[9]);
			$insured->setEmployerOrSchoolId($row[10]);

			$self->populateAddress($insured->getAddress(), "person_address", $row[4], "Home");
			$self->populateContact($insured->getAddress(), "person_attribute", $row[4], "Home", CONTACT_METHOD_TELEPHONE);

			my $insuredId = $row[4];
			my $orgInternalId = $row[10];
			if ($orgInternalId ne "")
			{
				$queryStatment = qq
				{
					select name_primary, org_id
					from org
					where org_internal_id = $orgInternalId
				};
				$sth = $self->{dbiCon}->prepare("$queryStatment");
				$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

				@row = $sth->fetchrow_array();
				$insured->setEmployerOrSchoolName($row[0]);
				$insured->setEmployerOrSchoolName($row[1]);

				$self->populateAddress($insured->getEmployerAddress(), "org_address", $orgInternalId, "Mailing");
				$self->populateContact($insured->getEmployerAddress(), "org_attribute", $orgInternalId, "Primary", CONTACT_METHOD_TELEPHONE);

				$queryStatment = qq
				{
					select value_text, value_type, value_int
					from person_attribute
					where parent_id = '$insuredId'
					and value_type in @{[ ASSOCIATION_EMPLOYMENT_ALL ]}
				};

				$sth = $self->{dbiCon}->prepare("$queryStatment");
				$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
				@row = $sth->fetchrow_array();

				if($row[2] ne "")
				{
					$insured->setEmploymentStatus($row[0]);
					my $a = ASSOCIATION_EMPLOYMENT_STUDENT;
					$insured->setStudentStatus($row[0] =~ /$a/ ? $row[0] : "");
				}
	    }

			$queryStatment = qq
			{
				select
					name_last,
					name_middle,
					name_first,
					to_char(date_of_birth, 'DD-MON-YYYY'),
					gender,
					marital_status,
					ssn,
					complete_name
				from person
				where person.person_id = '$insuredId'
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

			@row = $sth->fetchrow_array();
			$insured->setLastName($row[0]);
			$insured->setMiddleInitial($row[1]);
			$insured->setFirstName($row[2]);
			$insured->setDateOfBirth($row[3]);
			$insured->setSex($row[4]);
			$insured->setStatus($row[5]);
			$insured->setSsn($row[6]);
			$insured->setName($row[7]);

			$queryStatment = qq
			{
				select attr.value_text
				from insurance, insurance_attribute attr, invoice_billing
				where invoice_billing.invoice_id = $invoiceId
				and invoice_billing.bill_sequence = @{[ $insured->getBillSequence() ]}
				and invoice_billing.invoice_item_id is null
				and invoice_billing.bill_party_type = @{[ BILL_PARTY_TYPE_INSURANCE ]}
				and invoice_billing.bill_ins_id = insurance.ins_internal_id
				and attr.parent_id = parent_ins_id
				and attr.item_name = 'HMO-PPO/Indicator'
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();
			$insured->setHMOIndicator($row[0]);

			$no++;
		}
		elsif(($row1[0] eq BILL_PARTY_TYPE_PERSON) || ($row1[0] eq BILL_PARTY_TYPE_ORGANIZATION))
		{
			$queryStatment = qq
			{
				select
					nvl(plan_name, product_name),
					ins.rel_to_guarantor,
					invoice_billing.bill_sequence,
					ins.group_number,
					ins.guarantor_id,
					to_char(coverage_begin_date, 'DD-MON-YYYY'),
					to_char(coverage_end_date, 'DD-MON-YYYY'),
					group_name,
					ins.member_number,
					ins.extra,
					ins.employer_org_id
				from insurance ins, invoice_billing
				where invoice_billing.invoice_id = $invoiceId
				and invoice_billing.invoice_item_id is null
				and invoice_billing.bill_ins_id = ins.ins_internal_id
				and invoice_billing.bill_sequence = $row1[1]
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

			@row = $sth->fetchrow_array();
			$insured = $insureds->[$no];
			$insured->setInsurancePlanOrProgramName(''); #$row[0]);
			$insured->setRelationshipToPatient($row[1]);
			$insured->setBillSequence($row[2]);
			$insured->setPolicyGroupOrFECANo(''); #$row[3]);
			$insured->setId($row[4]);
			$insured->setEffectiveDate($row[5]);
			$insured->setTerminationDate($row[6]);
			$insured->setPolicyGroupName($row[7]);
			$insured->setMemberNumber($row[8]);
			$insured->setTypeCode($row[9]);
			$insured->setEmployerOrSchoolId($row[10]);

			$insured->setLastName('');
			$insured->setMiddleInitial('');
			$insured->setFirstName('');
			$insured->setDateOfBirth('');
			$insured->setSex('');
			$insured->setStatus('');
			$insured->setSsn('');
			$insured->setName('');

			$self->populateAddress($insured->getAddress(), "person_address", $row[4], "NoWhere");
			$self->populateContact($insured->getAddress(), "person_attribute", $row[4], "NoWhere", CONTACT_METHOD_TELEPHONE);

			$no++;
		}
		else
		{
			$insured = $insureds->[$no];
			$insured->setInsurancePlanOrProgramName('');
			$insured->setRelationshipToPatient('');
			$insured->setBillSequence('');
			$insured->setPolicyGroupOrFECANo('');
			$insured->setId('');
			$insured->setEffectiveDate('');
			$insured->setTerminationDate('');
			$insured->setPolicyGroupName('');
			$insured->setMemberNumber('');
			$insured->setTypeCode('');
			$insured->setEmployerOrSchoolId('');

			$insured->setLastName('');
			$insured->setMiddleInitial('');
			$insured->setFirstName('');
			$insured->setDateOfBirth('');
			$insured->setSex('');
			$insured->setStatus('');
			$insured->setSsn('');
			$insured->setName('');
			$self->populateAddress($insured->getAddress(), "person_address", $row[4], "NoWhere");
			$self->populateContact($insured->getAddress(), "person_attribute", $row[4], "NoWhere", CONTACT_METHOD_TELEPHONE);
			$no++;
		}
	}
}

sub assignProviderInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $payToProvider = $claim->getPayToProvider();
	my $queryStatment = qq
	{
		select name_last, name_middle, name_first, person_id, complete_name
		from person, transaction trans, invoice
		where invoice_id = $invoiceId
		and trans.trans_id = invoice.main_transaction
		and person.person_id = trans.provider_id
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my @row = $sth->fetchrow_array();
	$payToProvider->setLastName($row[0]);
	$payToProvider->setMiddleInitial($row[1]);
	$payToProvider->setFirstName($row[2]);
	$payToProvider->setId($row[3]);
	$payToProvider->setName($row[4]);

	$self->populateAddress($payToProvider->getAddress(), "person_address", $row[3], "Home");
	$self->populateContact($payToProvider->getAddress(), "person_attribute", $row[3], "Home", CONTACT_METHOD_TELEPHONE);

	my $renderingProvider = $claim->getRenderingProvider();
	$queryStatment = qq
	{
		select name_last, name_middle, name_first, person_id, complete_name
		from person, transaction trans, invoice
		where invoice_id = $invoiceId
		and trans.trans_id = invoice.main_transaction
		and person.person_id = trans.care_provider_id
	};
	$sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	@row = $sth->fetchrow_array();
	$renderingProvider->setLastName($row[0]);
	$renderingProvider->setMiddleInitial($row[1]);
	$renderingProvider->setFirstName($row[2]);
	$renderingProvider->setId($row[3]);
	$renderingProvider->setName($row[4]);

	$self->populateAddress($renderingProvider->getAddress(), "person_address", $row[3], "Home");
	$self->populateContact($renderingProvider->getAddress(), "person_attribute", $row[3], "Home", CONTACT_METHOD_TELEPHONE);
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

	my @row;

	my $queryStatment = qq
	{
		select org_address.state
		from invoice, transaction, org_address
		where invoice.invoice_id = $invoiceId
		and invoice.main_transaction = transaction.trans_id
		and org_address.parent_id = transaction.service_facility_id
		and org_address.address_name = 'Mailing'
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my $state = uc($sth->fetchrow_array());


	foreach my $provider (@providers)
	{
		my $id = $provider->getId();
		my $r2;

		my $inputMap =
		{
			INSURANCE_PROVIDER_LICENSE . 'Tax ID' => [ $provider, [\&App::Billing::Claim::Physician::setTaxId, \&App::Billing::Claim::Physician::setTaxTypeId], [$colValText, $colValTextB]],
			INSURANCE_PROVIDER_LICENSE . 'UPIN' => [ $provider, \&App::Billing::Claim::Physician::setUPIN, $colValText],
			INSURANCE_PROVIDER_LICENSE . 'WC#' => [$provider, \&App::Billing::Claim::Physician::setWorkersComp, $colValText],
			INSURANCE_PROVIDER_LICENSE . 'Medicare' => [$provider, \&App::Billing::Claim::Physician::setMedicareId, $colValText],
			INSURANCE_PROVIDER_LICENSE . 'Medicaid' => [$provider, \&App::Billing::Claim::Physician::setMedicaidId, $colValText],
			CERTIFICATION_LICENSE . 'BCBS' => [$provider, \&App::Billing::Claim::Physician::setBlueShieldId, $colValText],
			INSURANCE_PROVIDER_LICENSE . 'Railroad Medicare' => [$provider, \&App::Billing::Claim::Physician::setRailroadId, $colValText],
			CERTIFICATION_LICENSE . 'EPSDT' => [$provider, \&App::Billing::Claim::Physician::setEPSDT, $colValText],
			INSURANCE_PROVIDER_LICENSE . 'Champus' => [$provider, \&App::Billing::Claim::Physician::setChampusId, $colValText],
			PHYSICIAN_SPECIALTY . 'Primary' => [ $provider,  \&App::Billing::Claim::Physician::setSpecialityId, $colValTextB],
			AUTHORIZATION_PATIENT . 'Provider Assignment' => [$provider, \&App::Billing::Claim::Physician::setAssignIndicator, $colValTextB],
			PROFESSIONAL_LICENSE_NO . $state => [$provider, \&App::Billing::Claim::Physician::setProfessionalLicenseNo, $colValText],
		};

		$queryStatment = qq
		{
			select value_text, value_textB, value_type || item_name
			from person_attribute
			where parent_id = '$id'
		};
		$sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

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
}

sub assignReferralPhysician
{
	my ($self, $claim, $invoiceId) = @_;

	my $treatment = $claim->{treatment};

	my $queryStatment = qq
	{
		select name_first, name_last, name_middle, person_id
		from person, transaction trans, invoice
		where invoice_id = $invoiceId
		and trans.trans_id = invoice.main_transaction
		and person.person_id = trans.data_text_a
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my @row = $sth->fetchrow_array();
	$treatment->setRefProviderFirstName($row[0]);
	$treatment->setRefProviderLastName($row[1]);
	$treatment->setRefProviderMiName($row[2]);

	$queryStatment = qq
	{
		select value_text
		from person_attribute
		where parent_id = \'$row[3]\'
		and item_name = 'UPIN'
		and value_type =
	}
	. CERTIFICATION_LICENSE;
	$sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	@row = $sth->fetchrow_array();
	$treatment->setIDOfReferingPhysician($row[0]);
}

sub assignServiceFacility
{
	my ($self, $claim, $invoiceId) = @_;

	my $renderingOrganization = $claim->getRenderingOrganization();

	my $queryStatment = qq
	{
		select org.org_id, org.name_primary, org.org_internal_id, org.tax_id
		from org, transaction trans, invoice
		where invoice_id = $invoiceId
		and trans.trans_id = invoice.main_transaction
		and org.org_internal_id = trans.service_facility_id
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$renderingOrganization->setId($row[0]);
	$renderingOrganization->setName($row[1]);
	$renderingOrganization->setInternalId($row[2]);
	$renderingOrganization->setTaxId($row[3]);
	$self->populateAddress($renderingOrganization->getAddress(), "org_address", $row[2], "Mailing");
	$self->populateContact($renderingOrganization->getAddress(), "org_attribute", $row[2], "Primary", CONTACT_METHOD_TELEPHONE);
}

sub assignBillingFacility
{
	my ($self, $claim, $invoiceId) = @_;

	my $payToOrganization = $claim->getPayToOrganization();

	my $queryStatment = qq
	{
		select org.org_id, org.name_primary, org.org_internal_id, org.tax_id
		from org, transaction trans, invoice
		where invoice_id = $invoiceId and
		trans.trans_id = invoice.main_transaction
		and org.org_internal_id = trans.billing_facility_id
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my @row = $sth->fetchrow_array();

	$payToOrganization->setId($row[0]);
	$payToOrganization->setName($row[1]);
	$payToOrganization->setInternalId($row[2]);
	$payToOrganization->setTaxId($row[3]);
	$self->populateAddress($payToOrganization->getAddress(), "org_address", $row[2], "Billing");
	$self->populateContact($payToOrganization->getAddress(), "org_attribute", $row[2], "Primary", CONTACT_METHOD_TELEPHONE);
}

sub assignPaytoAndRendFacilityInfo
{
	my ($self, $claim, $invoiceId) = @_;

	my $colValText = 0;
	my $colValTextB = 1;
	my $colAttrnName = 2;

	my $renderingProvider = $claim->getRenderingOrganization();
	my $payToProvider = $claim->getPayToOrganization();

	my @providers = ($renderingProvider, $payToProvider);

	my @row;
	my $queryStatment;
	my $sth;

	foreach my $provider (@providers)
	{
		my $id = $provider->getInternalId();

		my $inputMap =
		{
			FACILITY_GROUP_NUMBER . 'Medicare#' => [$provider, \&App::Billing::Claim::Organization::setMedicareId, $colValText],
			FACILITY_GROUP_NUMBER . 'Medicaid#' => [$provider, \&App::Billing::Claim::Organization::setMedicaidId, $colValText],
			FACILITY_GROUP_NUMBER . 'BCBS#' => [$provider, \&App::Billing::Claim::Organization::setBCBSId, $colValText],
			FACILITY_GROUP_NUMBER . 'Workers Comp#' => [$provider, \&App::Billing::Claim::Organization::setWorkersComp, $colValText],
			FACILITY_GROUP_NUMBER . 'Railroad Medicare#' => [$provider, \&App::Billing::Claim::Organization::setRailroadId, $colValText],
		};

		$queryStatment = qq
		{
			select value_text, value_textB, value_type || item_name
			from org_attribute
			where parent_id = $id
		};
		$sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

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
	my $payers = $claim->{policy};
	my $payer;
	my $payerAddress;
	my $no = 0;

	my $queryStatment;
	my $sth;
	my $sth_bill;
	my @row;
	my @row_bill;
	my $colValText = 1;

	my $queryStatmentInvoiceSubtype = qq
	{
		select invoice_subtype
		from invoice
		where invoice_id = $invoiceId
	};
	my $sthInvoiceSubtype = $self->{dbiCon}->prepare("$queryStatmentInvoiceSubtype");
	$sthInvoiceSubtype->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatmentInvoiceSubtype");
	my $invoiceSubtype = $sthInvoiceSubtype->fetchrow_array();

	if($invoiceSubtype == CLAIM_TYPE_THIRD_PARTY)
	{
		$queryStatment = qq
		{
			select
				ib.bill_to_id,
				ib.bill_sequence,
				ib.bill_amount,
				ib.bill_party_type,
				ib.bill_ins_id
			from invoice_billing ib
			where ib.invoice_id = $invoiceId
			and ib.invoice_item_id is null
			and ib.bill_status is null
			and ib.bill_party_type in (
		}
		. BILL_PARTY_TYPE_PERSON . "," . BILL_PARTY_TYPE_ORGANIZATION .
		qq
		{
			) order by ib.bill_sequence
		};
	}
	else
	{
		$queryStatment = qq
		{
			select
				ib.bill_to_id,
				ib.bill_sequence,
				ib.bill_amount,
				ib.bill_party_type,
				ib.bill_ins_id,
				nvl(i.plan_name, i.product_name),
				i.ins_internal_id,
				i.parent_ins_id
			from insurance i, invoice_billing ib
			where ib.invoice_id = $invoiceId
			and ib.bill_status is null
			and ib.bill_ins_id = i.ins_internal_id
			and ib.invoice_item_id is NULL
			and ib.bill_party_type =
		}
		. BILL_PARTY_TYPE_INSURANCE .
		qq
		{
 			order by ib.bill_sequence
		};
	}
	$sth_bill = $self->{dbiCon}->prepare("$queryStatment");
	$sth_bill->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	while(@row_bill = $sth_bill->fetchrow_array())
	{
		$payer = $payers->[$no];
		$no++;

		$payerAddress = $payer->getAddress();
		$payer->setAmountPaid($row_bill[2]);

		if($row_bill[3] == BILL_PARTY_TYPE_INSURANCE )
		{
			$queryStatment = qq
			{
				select name_primary, org_id
				from org
				where org_Internal_id = $row_bill[0]
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();

			$payer->setName($row[0]);
			$payer->setId($row[1]);

			$payer->setInsurancePlanOrProgramName($row_bill[5]);
			$self->populateAddress($payer->getAddress(), "insurance_address", $row_bill[7], "Billing");
			$self->populateContact($payer->getAddress(), "insurance_attribute", $row_bill[7], "Contact Method/Telephone/Primary", CONTACT_METHOD_TELEPHONE);

			my $inputMap =
			{
				'Champus Branch' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorBranch, $colValText],
				'Champus Grade' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorGrade, $colValText],
				'Champus Status' => [$payer, \&App::Billing::Claim::Payer::setChampusSponsorStatus, $colValText],
			};
			$queryStatment = qq
			{
				select item_name, ia.value_text
				from insurance ins, insurance_attribute ia, invoice_billing ib
				where ib.invoice_id = $invoiceId
				and ib.bill_party_type =
			}
			. BILL_PARTY_TYPE_INSURANCE .
			qq
			{
				and ib.invoice_item_id is null
				and ib.bill_sequence = $row_bill[1]
				and ins.ins_internal_id = ib.bill_ins_id
				and ia.parent_id = ins.parent_ins_id
				and ia.item_name like 'Champus%'
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
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
		elsif ($row_bill[3] == BILL_PARTY_TYPE_PERSON)
		{
			$queryStatment = qq
			{
				select complete_name
				from person
				where person_id = \'$row_bill[0]\'
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();

			$payer->setId($row_bill[0]);
			$payer->setName($row[0]);
			$self->populateAddress($payer->getAddress(), "person_address", $row_bill[0], "Home");
			$self->populateContact($payer->getAddress(), "person_attribute", $row_bill[0], "Home", CONTACT_METHOD_TELEPHONE);
		}
		elsif ($row_bill[3] == BILL_PARTY_TYPE_ORGANIZATION)
		{
			$queryStatment = qq
			{
				select name_primary, org_id
				from org
				where org_internal_id = $row_bill[0]
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute() or $self->{valMgr}->addError($self->getId(),100,"Unable to execute $queryStatment");
			@row = $sth->fetchrow_array();

			$payer->setId($row[1]);
			$payer->setName($row[0]);
			$self->populateAddress($payer->getAddress(), "org_address", $row_bill[0], "Mailing");
			$self->populateContact($payer->getAddress(), "org_attribute", $row_bill[0], "Primary", CONTACT_METHOD_TELEPHONE);
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
	$patient->setAddress($patientAddress);
	$patient->setEmployerAddress($patientEmployerAddress);
	$claim->setCareReceiver($patient);

	my $insured1 = new App::Billing::Claim::Insured;
	my $insured1Address = new App::Billing::Claim::Address;
	my $insured1EmployerAddress = new App::Billing::Claim::Address;
	$insured1->setAddress($insured1Address);
	$insured1->setEmployerAddress($insured1EmployerAddress);
	$claim->addInsured($insured1);

	my $insured2 = new App::Billing::Claim::Insured;
	my $insured2Address = new App::Billing::Claim::Address;
	my $insured2EmployerAddress = new App::Billing::Claim::Address;
	$insured2->setAddress($insured2Address);
	$insured2->setEmployerAddress($insured2EmployerAddress);
	$claim->addInsured($insured2);

	my $insured3 = new App::Billing::Claim::Insured;
	my $insured3Address = new App::Billing::Claim::Address;
	my $insured3EmployerAddress = new App::Billing::Claim::Address;
	$insured3->setAddress($insured3Address);
	$insured3->setEmployerAddress($insured3EmployerAddress);
	$claim->addInsured($insured3);

	my $insured4 = new App::Billing::Claim::Insured;
	my $insured4Address = new App::Billing::Claim::Address;
	my $insured4EmployerAddress = new App::Billing::Claim::Address;
	$insured4->setAddress($insured4Address);
	$insured4->setEmployerAddress($insured4EmployerAddress);
	$claim->addInsured($insured4);

	my $renderingProvider = new App::Billing::Claim::Physician;
	my $renderingProviderAddress = new App::Billing::Claim::Address;
	$renderingProvider->setAddress($renderingProviderAddress);
	$claim->setRenderingProvider($renderingProvider);

	my $payToProvider = new App::Billing::Claim::Physician;
	my $payToProviderAddress = new App::Billing::Claim::Address;
	$payToProvider->setAddress($payToProviderAddress);
	$claim->setPayToProvider($payToProvider);

	my $renderingOrganization = new App::Billing::Claim::Organization;
	my $renderingOrganizationAddress = new App::Billing::Claim::Address;
	$renderingOrganization->setAddress($renderingOrganizationAddress);
	$claim->setRenderingOrganization($renderingOrganization);

	my $payToOrganization = new App::Billing::Claim::Organization;
	my $payToOrganizationAddress = new App::Billing::Claim::Address;
	$payToOrganization->setAddress($payToOrganizationAddress);
	$claim->setPayToOrganization($payToOrganization);

	my $treatment = new App::Billing::Claim::Treatment;
	$claim->setTreatment($treatment);

	my $legalRepresentator = new App::Billing::Claim::Person;
	$claim->setLegalRepresentator($legalRepresentator);

	my $payer1 = new App::Billing::Claim::Payer;
	my $payer1Address = new App::Billing::Claim::Address;
	$payer1->setAddress($payer1Address);
	$claim->addPolicy($payer1);

	my $payer2 = new App::Billing::Claim::Payer;
	my $payer2Address = new App::Billing::Claim::Address;
	$payer2->setAddress($payer2Address);
	$claim->addPolicy($payer2);

	my $payer3 = new App::Billing::Claim::Payer;
	my $payer3Address = new App::Billing::Claim::Address;
	$payer3->setAddress($payer3Address);
	$claim->addPolicy($payer3);

	my $payer4 = new App::Billing::Claim::Payer;
	my $payer4Address = new App::Billing::Claim::Address;
	$payer4->setAddress($payer4Address);
	$claim->addPolicy($payer4);

	my $twcc73 = new App::Billing::Claim::TWCC73;
	$claim->setTWCC73($twcc73);

	my $twcc60 = new App::Billing::Claim::TWCC60;
	my $requestorAddress = new App::Billing::Claim::Address;
	$twcc60->setRequestorAddress($requestorAddress);
	my $respondentAddress = new App::Billing::Claim::Address;
	$twcc60->setRespondentAddress($respondentAddress);
	$claim->setTWCC60($twcc60);
	
	$payToProvider->setType("pay to");
	$renderingProvider->setType("rendering");
	$payToOrganization->setType("pay to");
	$renderingOrganization->setType("rendering");

	$patient->setType("patient");

	$insured1->setType("insured");
	$insured2->setType("insured");
	$insured3->setType("insured");
	$insured4->setType("insured");

	$payer1->setType("payer");
	$payer2->setType("payer");
	$payer3->setType("payer");
	$payer4->setType("payer");

	$legalRepresentator->setType("legal representator");

	my $inputMap =
	{
		'Patient/Name' => [$patient, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Patient/Name/Last' => [$patient, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Patient/Name/First' => [$patient, \&App::Billing::Claim::Person::setFirstName,  COLUMNINDEX_VALUE_TEXT],
		'Patient/Name/Middle' => [$patient, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/DOB' => [$patient, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Patient/Personal/Gender' => [$patient, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Patient/Contact/Home Phone' => [$patientAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Patient/Personal/Marital Status' => [$patient, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Student/Status' => [$patient, \&App::Billing::Claim::Person::setStudentStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Employment/Status' => [$patient, \&App::Billing::Claim::Person::setEmploymentStatus, COLUMNINDEX_VALUE_TEXT],
		'Patient/Signature' => [$patient, \&App::Billing::Claim::Patient::setSignature,COLUMNINDEX_VALUE_TEXTB],
		'Patient/Illness/Dates' => [$treatment, [ \&App::Billing::Claim::Treatment::setDateOfIllnessInjuryPregnancy, \&App::Billing::Claim::Treatment::setDateOfSameOrSimilarIllness ], [COLUMNINDEX_VALUE_DATEEND,COLUMNINDEX_VALUE_DATE]],
		'Patient/Disability/Dates'  => [$treatment, [ \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkFrom, \&App::Billing::Claim::Treatment::setDatePatientUnableToWorkTo ], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],
		'Patient/Control Number' => [$patient, \&App::Billing::Claim::Patient::setAccountNo, COLUMNINDEX_VALUE_TEXT],
		'Patient/Hospitalization/Dates' => [$treatment, [\&App::Billing::Claim::Treatment::setHospitilizationDateFrom, \&App::Billing::Claim::Treatment::setHospitilizationDateTo], [COLUMNINDEX_VALUE_DATE,COLUMNINDEX_VALUE_DATEEND]],

#		'Patient/Personal/DOD' => [$patient, \&App::Billing::Claim::Person::setDateOfDeath, COLUMNINDEX_VALUE_DATE],
#		'Patient/Death/Indicator' => [$patient, \&App::Billing::Claim::Person::setDeathIndicator, COLUMNINDEX_VALUE_TEXT],
#		'Patient/Legal Rep/Indicator' => [ $patient, \&App::Billing::Claim::Patient::setlegalIndicator, COLUMNINDEX_VALUE_TEXT],


		'Ref Provider/Name/Last' =>[$treatment, [\&App::Billing::Claim::Treatment::setRefProviderLastName,\&App::Billing::Claim::Treatment::setId],[ COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Ref Provider/Name/First' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderFirstName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Name/Middle' =>[$treatment, \&App::Billing::Claim::Treatment::setRefProviderMiName, COLUMNINDEX_VALUE_TEXT],
		'Ref Provider/Identification' => [$treatment, [\&App::Billing::Claim::Treatment::setIDOfReferingPhysician,\&App::Billing::Claim::Treatment::setReferingPhysicianState], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],

#		'Ref Provider/ID Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setReferingPhysicianIDIndicator, COLUMNINDEX_VALUE_TEXT],

#		'Service Provider/Facility/Billing/Contact' => [[$renderingProvider, $renderingProviderAddress], [\&App::Billing::Claim::Physician::setContact, \&App::Billing::Claim::Address::setTelephoneNo],[COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
#		'Service Provider/Facility/Billing/Group Number' => [ $payToOrganization, \&App::Billing::Claim::Physician::setGRP, COLUMNINDEX_VALUE_TEXT],

		'Provider/Tax ID' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setTaxId, \&App::Billing::Claim::Physician::setTaxId] , [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Medicare' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setMedicareId, \&App::Billing::Claim::Physician::setMedicareId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Medicaid' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setMedicaidId, \&App::Billing::Claim::Physician::setMedicaidId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Champus' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setChampusId, \&App::Billing::Claim::Physician::setChampusId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/BCBS' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setBlueShieldId, \&App::Billing::Claim::Physician::setBlueShieldId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/UPIN' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setUPIN, \&App::Billing::Claim::Physician::setUPIN], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Workers Comp' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setWorkersComp, \&App::Billing::Claim::Physician::setWorkersComp], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Railroad Medicare' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setRailroadId, \&App::Billing::Claim::Physician::setRailroadId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/EPSDT' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setEPSDT, \&App::Billing::Claim::Physician::setEPSDT], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Specialty' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setSpecialityId, \&App::Billing::Claim::Physician::setSpecialityId], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Assign Indicator' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setAssignIndicator, \&App::Billing::Claim::Physician::setAssignIndicator], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Provider/Signature/Date' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setSignatureDate, \&App::Billing::Claim::Physician::setSignatureDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATE]],
		'Provider/Name' => [$payToProvider, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Provider/Name/First' => [$payToProvider, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name/Last' => [$payToProvider, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Provider/Name/Middle' => [$payToProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],

#		'Service Provider/Tax ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setTaxId ,COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Medicare' => [$renderingProvider, \&App::Billing::Claim::Physician::setMedicareId, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Medicaid' => [$renderingProvider, \&App::Billing::Claim::Physician::setMedicaidId, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Champus' => [$renderingProvider, \&App::Billing::Claim::Physician::setChampusId, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/BCBS' => [$renderingProvider, \&App::Billing::Claim::Physician::setBlueShieldId, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/UPIN' => [$renderingProvider, \&App::Billing::Claim::Physician::setUPIN, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Workers Comp' => [$renderingProvider, \&App::Billing::Claim::Physician::setWorkersComp, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Railroad Medicare' => [$renderingProvider, \&App::Billing::Claim::Physician::setRailroadId, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/EPSDT' => [$renderingProvider, \&App::Billing::Claim::Physician::setEPSDT, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Specialty' => [$renderingProvider, \&App::Billing::Claim::Physician::setSpecialityId, COLUMNINDEX_VALUE_TEXTB],
#		'Service Provider/Assign Indicator' => [$renderingProvider, \&App::Billing::Claim::Physician::setAssignIndicator, COLUMNINDEX_VALUE_TEXT],
#		'Service Provider/Signature/Date' => [$renderingProvider, \&App::Billing::Claim::Physician::setSignatureDate, COLUMNINDEX_VALUE_DATE],
		'Service Provider/Name' => [$renderingProvider, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Service Provider/Name/First' => [$renderingProvider, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Service Provider/Name/Last' => [$renderingProvider, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Service Provider/Name/Middle' => [$renderingProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],

#		'Provider/Qualification/Degree' => [[$payToProvider, $renderingProvider], [\&App::Billing::Claim::Physician::setQualification, \&App::Billing::Claim::Physician::setQualification],[COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
#		'Provider/ID Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setIdIndicator,\&App::Billing::Claim::Physician::setIdIndicator],[ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Provider/Signature/Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSignatureIndicator,\&App::Billing::Claim::Physician::setSignatureIndicator], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Provider/Organization/Type' => [$renderingOrganization, \&App::Billing::Claim::Organization::setOrganizationType, COLUMNINDEX_VALUE_TEXT],
#		'Provider/Site ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSiteId,\&App::Billing::Claim::Physician::setSiteId],[ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Provider/Name Qualifier' => [$claim, \&App::Billing::Claim::setQualifier, COLUMNINDEX_VALUE_TEXT],
#		'Provider/Network ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setNetworkId,\&App::Billing::Claim::Physician::setNetworkId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXT]],

		'Service Facility/Name' => [$renderingOrganization, [\&App::Billing::Claim::Organization::setName, \&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],

#		'Pay To Org/Name' => [$payToOrganization, [\&App::Billing::Claim::Organization::setName,\&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
#		'Pay To Org/Phone' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT ],
#		'Pay To Org/Tax ID' => [$payToOrganization, \&App::Billing::Claim::Organization::setTaxId, COLUMNINDEX_VALUE_TEXT],

		'Billing Facility/Name' =>[$payToOrganization, [\&App::Billing::Claim::Organization::setName, \&App::Billing::Claim::Organization::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Billing Facility/Billing/CLIA' => [$payToOrganization, \&App::Billing::Claim::Organization::setCLIA, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Employer Number' => [$payToOrganization, \&App::Billing::Claim::Organization::setEmployerNumber, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Medicaid' => [$payToOrganization, \&App::Billing::Claim::Organization::setMedicaidId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Medicare' => [$payToOrganization, \&App::Billing::Claim::Organization::setMedicareId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/State' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setState, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Tax ID' => [$payToOrganization, \&App::Billing::Claim::Organization::setTaxId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Workers Comp' => [$payToOrganization, \&App::Billing::Claim::Organization::setWorkersComp, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/BCBS' => [$payToOrganization, \&App::Billing::Claim::Organization::setBCBSId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Railroad Medicare' => [$payToOrganization, \&App::Billing::Claim::Organization::setRailroadId, COLUMNINDEX_VALUE_TEXT],
		'Billing Facility/Phone' => [$payToOrganizationAddress, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],

		'Claim Filing/Indicator' => [$claim, \&App::Billing::Claim::setFilingIndicator, COLUMNINDEX_VALUE_TEXT],
		'Invoice/History/Item' => [$claim, [\&App::Billing::Claim::setInvoiceHistoryDate, \&App::Billing::Claim::setInvoiceHistoryAction, \&App::Billing::Claim::setInvoiceHistoryComments], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Submission Order' => [$claim, [\&App::Billing::Claim::setClaimType, \&App::Billing::Claim::setBillSeq], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT]],
		'Assignment of Benefits' => [[$claim, $payer1, $payer2, $payer3, $payer4], [\&App::Billing::Claim::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment, \&App::Billing::Claim::Payer::setAcceptAssignment], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INT]],
		'Condition/Related To' => [$claim, [ \&App::Billing::Claim::setConditionRelatedTo, \&App::Billing::Claim::setConditionRelatedToAutoAccidentPlace ], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
		'Prior Authorization Number' => [$treatment, \&App::Billing::Claim::Treatment::setPriorAuthorizationNo, COLUMNINDEX_VALUE_TEXT],
		'Information Release/Indicator' => [ $claim, [\&App::Billing::Claim::setInformationReleaseIndicator, \&App::Billing::Claim::setInformationReleaseDate], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_DATE]],

#		'TPO Participation/Indicator' => [$patient, \&App::Billing::Claim::Patient::setTPO, COLUMNINDEX_VALUE_TEXT],
#		'Multiple/Indicator' => [$patient, \&App::Billing::Claim::Patient::setMultipleIndicator, COLUMNINDEX_VALUE_TEXT],
#		'HMO-PPO/ID' => [$insured, \&App::Billing::Claim::Insured::setHMOId, COLUMNINDEX_VALUE_TEXT],
#		'Symptom/Indicator' => [ $claim, \&App::Billing::Claim::setSymptomIndicator, COLUMNINDEX_VALUE_TEXT],
#		'Accident Hour' => [ $claim, \&App::Billing::Claim::setAccidentHour, COLUMNINDEX_VALUE_TEXT],
#		'Responsibility Indicator' => [ $claim, \&App::Billing::Claim::setResponsibilityIndicator, COLUMNINDEX_VALUE_TEXT],
#		'Symptom/Indicator/External Cause' => [	$claim, \&App::Billing::Claim::setSymptomExternalCause, COLUMNINDEX_VALUE_TEXT],
#		'Disability/Type' => [ $claim, \&App::Billing::Claim::setDisabilityType, COLUMNINDEX_VALUE_TEXT],
#		'Special Program/Indicator' => [$claim, \&App::Billing::Claim::setSpProgramIndicator, COLUMNINDEX_VALUE_TEXT],
#		'Last Seen/Date' => [$patient, \&App::Billing::Claim::Patient::setLastSeenDate, COLUMNINDEX_VALUE_DATE],
#		'Anesthesia-Oxygen/Minutes' => [$claim, \&App::Billing::Claim::setAnesthesiaOxygenMinutes, COLUMNINDEX_VALUE_TEXT],
#		'HGB-HCT/Date' => [	$claim, \&App::Billing::Claim::setHGBHCTDate, COLUMNINDEX_VALUE_DATE],
#		'Serum Creatine/Date' => [$claim, \&App::Billing::Claim::setSerumCreatineDate, COLUMNINDEX_VALUE_DATE],
#		'Remarks' => [$claim, \&App::Billing::Claim::setRemarks, COLUMNINDEX_VALUE_TEXT],
#		'Medicaid/Resubmission' => [$treatment, [ \&App::Billing::Claim::Treatment::setMedicaidResubmission, \&App::Billing::Claim::Treatment::setResubmissionReference], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
#		'Laboratory/Indicator' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLab, COLUMNINDEX_VALUE_TEXT],
#		'Laboratory/Charges' => [$treatment, \&App::Billing::Claim::Treatment::setOutsideLabCharges, COLUMNINDEX_VALUE_TEXT],
#		'Documentation/Indicator' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setDocumentationIndicator,\&App::Billing::Claim::Physician::setDocumentationIndicator], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Documentation/Type' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setDocumentationType,\&App::Billing::Claim::Physician::setDocumentationType], [ COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
#		'Documentation/Date' => [$claim, \&App::Billing::Claim::setdateDocSent, COLUMNINDEX_VALUE_DATE],
#		'Representator/Name/Last' => [$legalRepresentator, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,,COLUMNINDEX_VALUE_TEXTB]],
#		'Representator/Name/First' => [$legalRepresentator, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
#		'Representator/Name/Middle' => [$legalRepresentator, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],

#		'Rendering/Provider/Tax ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setTaxId, COLUMNINDEX_VALUE_TEXT],
#		'Rendering/Provider/ID' => [$renderingProvider, \&App::Billing::Claim::Physician::setProviderId, COLUMNINDEX_VALUE_TEXT],
#		'Pay To Provider/Name/First' => [$payToProvider,\&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
#		'Pay To Provider/Name/Last' => [$payToProvider, [\&App::Billing::Claim::Person::setLastName,\&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT,COLUMNINDEX_VALUE_TEXTB]],
#		'Pay To Provider/Name/Middle' => [$payToProvider, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
#		'Pay To Provider/Specialty' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setSpecialityId,\&App::Billing::Claim::Physician::setSpecialityId,], [COLUMNINDEX_VALUE_TEXTB,COLUMNINDEX_VALUE_TEXTB]],
#		'Pay To Provider/Network ID' => [[$renderingProvider, $payToProvider], [\&App::Billing::Claim::Physician::setNetworkId,\&App::Billing::Claim::Physician::setNetworkId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],


		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Medigap' => [$insured1, \&App::Billing::Claim::Insured::setMedigapNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Name' => [[$insured1, $payer1, $payer1], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Payment Source' => [$payer1, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Branch' => [$payer1, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Grade' => [$payer1, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Champus Status' => [$payer1, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Phone' => [$payer1Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Patient-Insured/Relationship' => [$insured1, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_INT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name'	=> [$insured1, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/Last'	=> [$insured1, \&App::Billing::Claim::Person::setLastName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/First' => [$insured1, \&App::Billing::Claim::Person::setFirstName, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Name/Middle' => [$insured1, \&App::Billing::Claim::Person::setMiddleInitial, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/Marital Status' => [$insured1, \&App::Billing::Claim::Person::setStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/Gender' => [$insured1, \&App::Billing::Claim::Person::setSex, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/DOB' => [$insured1, \&App::Billing::Claim::Person::setDateOfBirth, COLUMNINDEX_VALUE_DATE],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Member Number'  => [$insured1, \&App::Billing::Claim::Insured::setMemberNumber , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Personal/SSN'  => [$insured1, \&App::Billing::Claim::Person::setSsn , COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Contact/Home Phone' => [$insured1Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/Employer/Name'	=> [$insured1, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
#		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Insured/School/Name'	=> [$insured, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Effective Dates' => [$insured1, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Type' => [$insured1, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/Group Number' => [$insured1, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/HMO-PPO/Indicator' => [$insured1, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/BCBS/Plan Code' => [$insured1, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
#		'Insurance/' . BILLSEQ_PRIMARY_CAPTION . '/E-Remitter ID' => [$payer1, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Medigap' => [$insured2, \&App::Billing::Claim::Insured::setMedigapNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Name' => [[$insured2, $payer2, $payer2], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Payment Source' => [$payer2, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Branch' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Grade' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Champus Status' => [$payer2, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Phone' => [$payer2Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Patient-Insured/Relationship' => [$insured2, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_INT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/Name'	=> [$insured2, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
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
#		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Insured/School/Name'	=> [$insured2, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Effective Dates' => [$insured2, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Type' => [$insured2, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/Group Number' => [$insured2, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/HMO-PPO/Indicator' => [$insured2, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/BCBS/Plan Code' => [$insured2, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
#		'Insurance/' . BILLSEQ_SECONDARY_CAPTION . '/E-Remitter ID' => [$payer2, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Medigap' => [$insured3, \&App::Billing::Claim::Insured::setMedigapNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Name' => [[$insured3, $payer3, $payer3], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Payment Source' => [$payer3, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Branch' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Grade' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Champus Status' => [$payer3, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Phone' => [$payer3Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Patient-Insured/Relationship' => [$insured3, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_INT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/Name'	=> [$insured3, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
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
#		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Insured/School/Name'	=> [$insured3, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Effective Dates' => [$insured3, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Type' => [$insured3, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/Group Number' => [$insured3, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/HMO-PPO/Indicator' => [$insured3, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/BCBS/Plan Code' => [$insured3, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
#		'Insurance/' . BILLSEQ_TERTIARY_CAPTION . '/E-Remitter ID' => [$payer3, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Medigap' => [$insured4, \&App::Billing::Claim::Insured::setMedigapNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Name' => [[$insured4, $payer4, $payer4], [\&App::Billing::Claim::Insured::setInsurancePlanOrProgramName, \&App::Billing::Claim::Payer::setId, \&App::Billing::Claim::Payer::setName], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Payment Source' => [$payer4, \&App::Billing::Claim::Payer::setSourceOfPayment, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Branch' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorBranch, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Grade' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorGrade, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Champus Status' => [$payer4, \&App::Billing::Claim::Payer::setChampusSponsorStatus, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Phone' => [$payer4Address, \&App::Billing::Claim::Address::setTelephoneNo, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Patient-Insured/Relationship' => [$insured4, \&App::Billing::Claim::Insured::setRelationshipToPatient, COLUMNINDEX_VALUE_INT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/Name'	=> [$insured4, [\&App::Billing::Claim::Person::setName, \&App::Billing::Claim::Person::setId], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
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
#		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Insured/School/Name'	=> [$insured4, [\&App::Billing::Claim::Person::setEmployerOrSchoolName, \&App::Billing::Claim::Person::setEmploymentStatus], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Effective Dates' => [$insured4, [\&App::Billing::Claim::Insured::setEffectiveDate, \&App::Billing::Claim::Insured::setTerminationDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEEND]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Type' => [$insured4, \&App::Billing::Claim::Insured::setTypeCode, COLUMNINDEX_VALUE_TEXTB],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/Group Number' => [$insured4, [\&App::Billing::Claim::Insured::setPolicyGroupOrFECANo, \&App::Billing::Claim::Insured::setPolicyGroupName, \&App::Billing::Claim::Insured::setInsurancePlanOrProgramName], [COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/HMO-PPO/Indicator' => [$insured4, \&App::Billing::Claim::Insured::setHMOIndicator, COLUMNINDEX_VALUE_TEXT],
		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/BCBS/Plan Code' => [$insured4, \&App::Billing::Claim::Insured::setBCBSPlanCode, COLUMNINDEX_VALUE_TEXT],
#		'Insurance/' . BILLSEQ_QUATERNARY_CAPTION . '/E-Remitter ID' => [$payer4, \&App::Billing::Claim::Payer::setPayerId, COLUMNINDEX_VALUE_TEXT],

		'Invoice/TWCC61/16' => [$treatment, [\&App::Billing::Claim::Treatment::setReturnToLimitedWorkAnticipatedDate, \&App::Billing::Claim::Treatment::setMaximumImprovementAnticipatedDate, \&App::Billing::Claim::Treatment::setReturnToFullTimeWorkAnticipatedDate], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEA, COLUMNINDEX_VALUE_DATEB]],
		'Invoice/TWCC61/17' => [$treatment, \&App::Billing::Claim::Treatment::setInjuryHistory, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/18' => [$treatment, \&App::Billing::Claim::Treatment::setPastMedicalHistory, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/19' => [$treatment, \&App::Billing::Claim::Treatment::setClinicalFindings, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/20' => [$treatment, \&App::Billing::Claim::Treatment::setLaboratoryTests, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/21' => [$treatment, \&App::Billing::Claim::Treatment::setTreatmentPlan, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/22' => [$treatment, [\&App::Billing::Claim::Treatment::setReferralInfo61, \&App::Billing::Claim::Treatment::setReferralSelection], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC61/23' => [$treatment, \&App::Billing::Claim::Treatment::setMedications61, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/24' => [$treatment, \&App::Billing::Claim::Treatment::setPrognosis, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC61/26' => [$treatment, \&App::Billing::Claim::Treatment::setDateMailedToEmployee, COLUMNINDEX_VALUE_DATE],
		'Invoice/TWCC61/27' => [$treatment, \&App::Billing::Claim::Treatment::setDateMailedToInsurance, COLUMNINDEX_VALUE_DATE],

		'Invoice/TWCC64/17' => [$treatment, [\&App::Billing::Claim::Treatment::setActivityType, \&App::Billing::Claim::Treatment::setActivityDate, \&App::Billing::Claim::Treatment::setReasonForReport], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC64/18' => [$treatment, \&App::Billing::Claim::Treatment::setChangeInCondition, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC64/20' => [$treatment, \&App::Billing::Claim::Treatment::setReferralInfo64, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC64/21' => [$treatment, \&App::Billing::Claim::Treatment::setMedications64, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC64/23' => [$treatment, \&App::Billing::Claim::Treatment::setComplianceByEmployee, COLUMNINDEX_VALUE_TEXT],

		'Invoice/TWCC69/17' => [$treatment, [\&App::Billing::Claim::Treatment::setMaximumImprovementDate, \&App::Billing::Claim::Treatment::setMaximumImprovement], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC69/18' => [$treatment, \&App::Billing::Claim::Treatment::setImpairmentRating, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC69/19' => [$treatment, [\&App::Billing::Claim::Treatment::setDoctorType, \&App::Billing::Claim::Treatment::setExaminingDoctorType], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC69/22' => [$treatment, [\&App::Billing::Claim::Treatment::setMaximumImprovementAgreement, \&App::Billing::Claim::Treatment::setImpairmentRatingAgreement], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],

		'Invoice/TWCC73/4'   => [$twcc73,  \&App::Billing::Claim::TWCC73::setInjuryDescription, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC73/13'  => [$twcc73, [\&App::Billing::Claim::TWCC73::setMedicalCondition, \&App::Billing::Claim::TWCC73::setReturnToWorkDate, \&App::Billing::Claim::TWCC73::setReturnToWorkFromDate, \&App::Billing::Claim::TWCC73::setReturnToWorkToDate], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_DATEA, COLUMNINDEX_VALUE_DATEB]],
		'Invoice/TWCC73/14a' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsStanding, \&App::Billing::Claim::TWCC73::setPostureRestrictionsStandingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14b' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsSitting, \&App::Billing::Claim::TWCC73::setPostureRestrictionsSittingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14c' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsKneeling, \&App::Billing::Claim::TWCC73::setPostureRestrictionsKneelingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14d' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsBending, \&App::Billing::Claim::TWCC73::setPostureRestrictionsBendingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14e' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsPushing, \&App::Billing::Claim::TWCC73::setPostureRestrictionsPushingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14f' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsTwisting, \&App::Billing::Claim::TWCC73::setPostureRestrictionsTwistingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/14g' => [$twcc73, [\&App::Billing::Claim::TWCC73::setPostureRestrictionsOtherText, \&App::Billing::Claim::TWCC73::setPostureRestrictionsOther, \&App::Billing::Claim::TWCC73::setPostureRestrictionsOtherOther], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/15'  => [$twcc73, [\&App::Billing::Claim::TWCC73::setSpecificRestrictions, \&App::Billing::Claim::TWCC73::setSpecificRestrictionsOther], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC73/16'  => [$twcc73,  \&App::Billing::Claim::TWCC73::setOtherRestrictions, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC73/17a' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsWalking, \&App::Billing::Claim::TWCC73::setMotionRestrictionsWalkingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17b' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsClimbing, \&App::Billing::Claim::TWCC73::setMotionRestrictionsClimbingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17c' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsGrasping, \&App::Billing::Claim::TWCC73::setMotionRestrictionsGraspingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17d' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsWrist, \&App::Billing::Claim::TWCC73::setMotionRestrictionsWristOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17e' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsReaching, \&App::Billing::Claim::TWCC73::setMotionRestrictionsReachingOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17f' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsOverhead, \&App::Billing::Claim::TWCC73::setMotionRestrictionsOverheadOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17g' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsKeyboard, \&App::Billing::Claim::TWCC73::setMotionRestrictionsKeyboardOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/17h' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMotionRestrictionsOtherText, \&App::Billing::Claim::TWCC73::setMotionRestrictionsOther, \&App::Billing::Claim::TWCC73::setMotionRestrictionsOtherOther], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/18'  => [$twcc73, [\&App::Billing::Claim::TWCC73::setLiftRestrictions, \&App::Billing::Claim::TWCC73::setLiftRestrictionsHours, \&App::Billing::Claim::TWCC73::setLiftRestrictionsWeight, \&App::Billing::Claim::TWCC73::setLiftRestrictionsOther], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXT]],
		'Invoice/TWCC73/19a' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsMaxHours, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19b' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMiscRestrictionsSitBreaks, \&App::Billing::Claim::TWCC73::setMiscRestrictionsSitBreaksPer], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_TEXT]],
		'Invoice/TWCC73/19c' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsWearSplint, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19d' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsCrutches, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19e' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsNoDriving, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19f' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsDriveAutoTrans, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19g' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMiscRestrictionsNoWork, \&App::Billing::Claim::TWCC73::setMiscRestrictionsHoursPerDay, \&App::Billing::Claim::TWCC73::setMiscRestrictionsTemp, \&App::Billing::Claim::TWCC73::setMiscRestrictionsHeight], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB, COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC73/19h' => [$twcc73, [\&App::Billing::Claim::TWCC73::setMiscRestrictionsMustKeep, \&App::Billing::Claim::TWCC73::setMiscRestrictionsElevated, \&App::Billing::Claim::TWCC73::setMiscRestrictionsCleanDry], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC73/19i' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsNoSkinContact, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC73/19j' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsDressing, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/19k' => [$twcc73,  \&App::Billing::Claim::TWCC73::setMiscRestrictionsNoRunning, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/20'  => [$twcc73, [\&App::Billing::Claim::TWCC73::setMedicationRestrictionsMustTake, \&App::Billing::Claim::TWCC73::setMedicationRestrictionsAdvised, \&App::Billing::Claim::TWCC73::setMedicationRestrictionsDrowsy], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB, COLUMNINDEX_VALUE_INT]],
		'Invoice/TWCC73/21'  => [$twcc73,  \&App::Billing::Claim::TWCC73::setWorkInjuryDiagnosisInfo, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC73/22a' => [$twcc73, [\&App::Billing::Claim::TWCC73::setFollowupServiceEvaluationDate, \&App::Billing::Claim::TWCC73::setFollowupServiceEvaluationTime], [COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXT]],
		'Invoice/TWCC73/22b' => [$twcc73, [\&App::Billing::Claim::TWCC73::setFollowupServiceConsultWith, \&App::Billing::Claim::TWCC73::setFollowupServiceConsultDate, \&App::Billing::Claim::TWCC73::setFollowupServiceConsultTime], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC73/22c' => [$twcc73, [\&App::Billing::Claim::TWCC73::setFollowupServicePhysMedWeeks, \&App::Billing::Claim::TWCC73::setFollowupServicePhysMedWeeksPer, \&App::Billing::Claim::TWCC73::setFollowupServicePhysMedDate, \&App::Billing::Claim::TWCC73::setFollowupServicePhysMedTime], [COLUMNINDEX_VALUE_INTB, COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXT]],
		'Invoice/TWCC73/22d' => [$twcc73, [\&App::Billing::Claim::TWCC73::setFollowupServiceSpecialStudies, \&App::Billing::Claim::TWCC73::setFollowupServiceSpecialStudiesDate, \&App::Billing::Claim::TWCC73::setFollowupServiceSpecialStudiesTime], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_DATE, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC73/22e' => [$twcc73,  \&App::Billing::Claim::TWCC73::setFollowupServiceNone, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/23'  => [$twcc73,  \&App::Billing::Claim::TWCC73::setVisitType, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC73/24'  => [$twcc73,  \&App::Billing::Claim::TWCC73::setDoctorRole, COLUMNINDEX_VALUE_INT],

		'Invoice/TWCC60/1' => [$twcc60, [\&App::Billing::Claim::TWCC60::setRequestorType, \&App::Billing::Claim::TWCC60::setDisputeType], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC60/2' => [$twcc60, \&App::Billing::Claim::TWCC60::setRequestorName, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC60/3' => [$requestorAddress, [\&App::Billing::Claim::Address::setAddress1, \&App::Billing::Claim::Address::setCity], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/4' => [[$twcc60, $requestorAddress], [\&App::Billing::Claim::TWCC60::setRequestorContactName, \&App::Billing::Claim::Address::setTelephoneNo], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/5' => [$requestorAddress, [\&App::Billing::Claim::Address::setFaxNo, \&App::Billing::Claim::Address::setEmailAddress], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/6' => [$twcc60, [\&App::Billing::Claim::TWCC60::setRequestorFEIN, \&App::Billing::Claim::TWCC60::setRequestorLicenseNo], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/22' => [$twcc60, [\&App::Billing::Claim::TWCC60::setNoticeOfDenial, \&App::Billing::Claim::TWCC60::setNoticeOfDispute], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_INTB]],
		'Invoice/TWCC60/23' => [$twcc60, \&App::Billing::Claim::TWCC60::setRespondentType, COLUMNINDEX_VALUE_INT],
		'Invoice/TWCC60/24' => [$twcc60, \&App::Billing::Claim::TWCC60::setRespondentName, COLUMNINDEX_VALUE_TEXT],
		'Invoice/TWCC60/25' => [$respondentAddress, [\&App::Billing::Claim::Address::setAddress1, \&App::Billing::Claim::Address::setCity], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/26' => [[$twcc60, $respondentAddress], [\&App::Billing::Claim::TWCC60::setRespondentContactName, \&App::Billing::Claim::Address::setTelephoneNo], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/27' => [$respondentAddress, [\&App::Billing::Claim::Address::setFaxNo, \&App::Billing::Claim::Address::setEmailAddress], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/28' => [$twcc60, [\&App::Billing::Claim::TWCC60::setRespondentFEIN, \&App::Billing::Claim::TWCC60::setRespondentLicenseNo], [COLUMNINDEX_VALUE_TEXT, COLUMNINDEX_VALUE_TEXTB]],
		'Invoice/TWCC60/29' => [$twcc60, [\&App::Billing::Claim::TWCC60::setIssueResolved, \&App::Billing::Claim::TWCC60::setIssueResolvedDesc], [COLUMNINDEX_VALUE_INT, COLUMNINDEX_VALUE_TEXT]],
	};

	my $queryStatment = qq
	{
		select
			ITEM_ID,
			ITEM_NAME,
			VALUE_TEXT,
			VALUE_TEXTB,
			VALUE_INT,
			VALUE_INTB,
			VALUE_FLOAT,
			VALUE_FLOATB,
			to_char(VALUE_DATE, \'DD-MON-YYYY\'),
			to_char(VALUE_DATEEND, \'DD-MON-YYYY\'),
			to_char(VALUE_DATEA, \'DD-MON-YYYY\'),
			to_char(VALUE_DATEB, \'DD-MON-YYYY\')
		from invoice_attribute
		where parent_id = $invoiceId
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	while(my @row = $sth->fetchrow_array())
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

	$claim->setBillSeq(0);
	$claim->setClaimType(0);
	$claim->setSourceOfPayment($payer1->getSourceOfPayment);
	$claim->setPayer($payer1);


	#get all invoice_billing records for a claim

	my @payers = ($payer1, $payer2, $payer3, $payer4);
	my $payerCount = -1;
#	my $billingId = (invoice.billing_id)
	$queryStatment = qq
	{
		select *
		from invoice_billing
		where invoice_id = $invoiceId
		and invoice_item_id is null
		order by bill_sequence
	};
	my $sthPayer = $self->{dbiCon}->prepare("$queryStatment");
	$sthPayer->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	#loop through payers

	while(my $payer = $sthPayer->fetchrow_hashref())
	{
		$payerCount++;
		next if $payer->{BILL_STATUS} eq 'inactive';

		if($payer->{BILL_PARTY_TYPE} == 3)
		{
			my $remitPayerId;
			my $queryStatment = qq
			{
				select *
				from insurance
				where ins_internal_id = $payer->{BILL_INS_ID}
			};
			my $sth1 = $self->{dbiCon}->prepare("$queryStatment");
			$sth1->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			my $personInsurance = $sth1->fetchrow_hashref();

			$queryStatment = qq
			{
				select *
				from insurance
				where ins_internal_id = $personInsurance->{PARENT_INS_ID}
			};
			my $sth2 = $self->{dbiCon}->prepare("$queryStatment");
			$sth2->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			my $personInsurancePlanOrProd = $sth2->fetchrow_hashref();

			$remitPayerId = $personInsurancePlanOrProd->{REMIT_PAYER_ID};
			unless($remitPayerId)
			{
				my $personInsuranceProduct = undef;
				if($personInsurancePlanOrProd->{RECORD_TYPE} == 2)
				{
					$queryStatment = qq
					{
						select *
						from insurance
						where ins_internal_id = $personInsurancePlanOrProd->{PARENT_INS_ID}
					};
					my $sth3 = $self->{dbiCon}->prepare("$queryStatment");
					$sth3->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
					my $personInsuranceProduct = $sth3->fetchrow_hashref();
					$remitPayerId = $personInsuranceProduct->{REMIT_PAYER_ID};
				}
			}
			$payers[$payerCount]->setPayerId($remitPayerId);

		}
	}

	$self->assignInvoiceAddresses($invoiceId, $claim);
	$self->payersRemainingProperties([$payer1, $payer2, $payer3, $payer4], $invoiceId, $claim);
	$self->assignProviderLicenses($invoiceId, $claim);

	return $claim;
}

sub assignProviderLicenses
{
	my ($self, $invoiceId, $claim) = @_;

	my $serviceProvider = $claim->getRenderingProvider();
	my $serviceProviderAddress = $serviceProvider->getAddress();
	my $state = uc($serviceProviderAddress->getState());

	my $queryStatment = qq
	{
		select value_text
		from invoice_attribute
		where parent_id = $invoiceId
		and item_name = 'Service Provider/State License'
		and value_textb = '$state'
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my @row = $sth->fetchrow_array();
	$serviceProvider->setProfessionalLicenseNo($row[0]);
}

sub payersRemainingProperties
{
	my ($self, $payers, $invoiceId, $claim) = @_;

	my $billSeq = [];
	$billSeq->[BILLSEQ_PRIMARY_PAYER] = PRIMARY;
	$billSeq->[BILLSEQ_SECONDARY_PAYER] = SECONDARY;
	$billSeq->[BILLSEQ_TERTIARY_PAYER] =  TERTIARY;
	$billSeq->[BILLSEQ_QUATERNARY_PAYER] = QUATERNARY;

	my @billPartyType = ('', 'Person', 'Org');

	my $queryStatment = qq
	{
		select bill_sequence, bill_amount, bill_party_type
		from invoice_billing where
		invoice_id = $invoiceId
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");


	while(my @row = $sth->fetchrow_array())
	{
		my $payer = $payers->[$billSeq->[$row[0]] + 0];
		if($payer ne "")
		{
			my $colValTxt = 1;

			$payer->setAmountPaid($row[1]);
			$payer =	$claim->{payer};
			my $inputMap =
			{
				'Third-Party/Person/Name' => [$payer, [\&App::Billing::Claim::Payer::setName, \&App::Billing::Claim::Payer::setId], [$colValTxt, $colValTxt + 1]],
				'Third-Party/Person/Phone' => [$payer->getAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValTxt],
				'Third-Party/Org/Name' => [$payer, [\&App::Billing::Claim::Payer::setName, \&App::Billing::Claim::Payer::setId], [$colValTxt, $colValTxt + 1]],
				'Third-Party/Org/Phone' => [$payer->getAddress, \&App::Billing::Claim::Address::setTelephoneNo, $colValTxt],
			};

			my $colAttr = 0;
			if($row[2] =~ /1|2/)
			{
				$queryStatment = qq
				{
					select item_name, value_text, value_textB
					from invoice_attribute
					where parent_id = $invoiceId
					and item_name like \'Third-Party/$billPartyType[$row[2]]/%\'
				};
				my $sth1 = $self->{dbiCon}->prepare("$queryStatment");
				$sth1->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
				while(my @row1 = $sth1->fetchrow_array())
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
	$self->setPayerInsuranceType($invoiceId, $payers);
}

sub setPayerInsuranceType()
{
	my ($self, $invoiceId, $payers) = @_;

	my $queryStatment = qq
	{
		select insurance.ins_type
		from invoice_billing, insurance
		where invoice_id = $invoiceId
		and ins_internal_id = bill_ins_id
		and bill_status is null
		order by invoice_billing.bill_sequence
	};
	my $sth1 = $self->{dbiCon}->prepare("$queryStatment");
	$sth1->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my $payerCount = 0;

	while (my @row = $sth1->fetchrow_array())
	{
		$payers->[$payerCount++]->setInsType($row[0]);
	}
}

sub setClaimProperties
{
	my ($self, $invoiceId, $currentClaim) = @_;

	my $patient = $currentClaim->getCareReceiver();

	my $payToProvider = $currentClaim->getPayToProvider();
	my $payToOrganization = $currentClaim->getPayToOrganization();
	my $renderingProvider = $currentClaim->getRenderingProvider();
	my $renderingOrganization = $currentClaim->getRenderingOrganization();

	my $insured1 = $currentClaim->getInsured(0);
	my $insured2 = $currentClaim->getInsured(1);
	my $insured3 = $currentClaim->getInsured(2);
	my $insured4 = $currentClaim->getInsured(3);

	my $treatmentObject	= $currentClaim->getTreatment();
	my $legalRepresentator = $currentClaim->getLegalRepresentator();

	my $payer = $currentClaim->getPayer();

	my $queryStatment = qq
	{
		select
			total_cost,
			invoice_status,
			claim_diags,
			balance,
			total_adjust,
			invoice_subtype,
			client_id,
			invoice_type,
			total_items,
			invoice_date
		from invoice
		where invoice_id = $invoiceId
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my @tempRow = $sth->fetchrow_array();

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
	$ins[CLAIM_TYPE_RAILROAD_MEDICARE] = "OTHER";

	$tempRow[2] =~ s/ //g;
	my @diagnosisCodes = split (/,/, $tempRow[2]);
	my $diagnosis;

	for (my $diagCount = 0; $diagCount <= $#diagnosisCodes; $diagCount++)
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
	$currentClaim->setProgramName($ins[$tempRow[5]]);
	$currentClaim->setInvoiceSubtype($tempRow[5]);
	$currentClaim->setInsType($tempRow[5]);
	$currentClaim->setInvoiceType($tempRow[7]);
	$currentClaim->setTotalItems($tempRow[8]);
	$currentClaim->setInvoiceDate($tempRow[9]);

	$payToProvider->setInsType($tempRow[5]);
	$payToOrganization->setInsType($tempRow[5]);
	$renderingProvider->setInsType($tempRow[5]);
	$renderingOrganization->setInsType($tempRow[5]);

	$patient->setId($tempRow[6]);

	$self->setProperPayer($invoiceId, $currentClaim);

	my $tempDiagnosisCodes;
	my $tempItems = $currentClaim->{procedures};
	for(my $count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}

	$tempItems = $currentClaim->{otherItems};
	for(my $count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}

	$tempItems = $currentClaim->{adjItems};
	for(my $count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}

	$tempItems = $currentClaim->{copayItems};
	for(my $count = 0;$count <= $#$tempItems; $count++)
	{
		$tempDiagnosisCodes = $self->diagnosisPtr($currentClaim, $tempItems->[$count]->getDiagnosis);
		my @tempDiagnosisCodes1 = split(/ /, $tempDiagnosisCodes);
		$tempItems->[$count]->setDiagnosisCodePointer(\@tempDiagnosisCodes1);
	}

	$self->populateVisitDate($invoiceId, $currentClaim, $patient);
	$self->populateChangedTreatingDoctor($invoiceId, $currentClaim);

	if($ins[$tempRow[5]] == 'MEDICARE')
	{
		my $queryStatment = qq
		{
			select distinct invoice_id from invoice, invoice_item
			where invoice_id = $invoiceId
			and invoice_id = invoice_item.parent_id
			and code in (select epsdt from ref_epsdt)
		};
		my $sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		my @tempRow = $sth->fetchrow_array();

		if($tempRow[0] ne '')
		{
			$payToProvider->setInsType('99');
			$renderingProvider->setInsType('99');
		}
	}
}

sub diagnosisPtr
{
	my ($self, $currentClaim, $codes) = @_;

	my $diags = $currentClaim->{'diagnosis'};
	my $diagnosisMap = {};

	my $count = 0;

	foreach my $diag (@$diags)
	{
		if($diag ne "")
		{
			$diagnosisMap->{$currentClaim->{'diagnosis'}->[$count]->getDiagnosis()} = $count + 1;
			$count++;
		}
	}

	$codes =~ s/ //g;
	my @diagCodes = split(/,/, $codes);
	my $ptr;

	for (my $diagnosisCount = 0; $diagnosisCount <= $#diagCodes; $diagnosisCount++)
	{
		$ptr =  $ptr . " " .  $diagnosisMap->{$diagCodes[$diagnosisCount]};
	}
	return $ptr;
}

sub setProperPayer
{
	my ($self, $invoiceId, $currentClaim) = @_;

	my $payer = $currentClaim->getPayer();
	my $patient = $currentClaim->getCareReceiver();
	my $payerAddress = $payer->getAddress();

	my $queryStatment = qq
	{
		select invoice_subtype
		from invoice
		where invoice_id = $invoiceId
	};
	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
	my @tempRow = $sth->fetchrow_array();

	if($tempRow[0] != CLAIM_TYPE_SELF)
	{
		my $payers = $currentClaim->{policy};
		my $ins = 0;
		foreach my $payer (@$payers)
		{
			my $payerName = $payer->getName();

			$queryStatment = qq
			{
				select a.value_text
				from invoice_attribute a, invoice i
				where i.invoice_id = $invoiceId
				and i.invoice_id = a.parent_id
				and a.item_name = 'Insurance/Primary/E-Remitter ID'
			};
			$sth = $self->{dbiCon}->prepare("$queryStatment");
			$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
			@tempRow = $sth->fetchrow_array();

#			$payer->setPayerId($tempRow[0]);
			if ($payers->[$currentClaim->getClaimType] eq  $currentClaim->{payer})
			{
				$currentClaim->setPayerId($tempRow[0]);
			}
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
}

sub populateItems
{
	my ($self, $invoiceId, $currentClaim) = @_;

	my @itemMap;
	$itemMap[INVOICE_ITEM_OTHER] = \&App::Billing::Claim::addOtherItems;
	$itemMap[INVOICE_ITEM_SERVICE] = \&App::Billing::Claim::addProcedure;
	$itemMap[INVOICE_ITEM_LAB] = \&App::Billing::Claim::addProcedure;
	$itemMap[INVOICE_ITEM_COPAY] = \&App::Billing::Claim::addCopayItems;
	$itemMap[INVOICE_ITEM_ADJUST] = \&App::Billing::Claim::addAdjItems;
	$itemMap[INVOICE_ITEM_COINSURANCE] = \&App::Billing::Claim::addCoInsurance;
	$itemMap[INVOICE_ITEM_DEDUCTABLE] = \&App::Billing::Claim::addDeductible;
	$itemMap[INVOICE_ITEM_VOID] = \&App::Billing::Claim::addVoidItems;

 	my $queryStatment = qq
 	{
		select
			to_char(service_begin_date, 'DD-MON-YYYY'),
			to_char(service_end_date, 'DD-MON-YYYY'),
			nvl(HCFA1500_Service_Place_Code.abbrev,
	}
			. DEFAULT_PLACE_OF_SERIVCE .
	qq{
			) as service_place,
			nvl(HCFA1500_Service_Type_Code.abbrev,
	}
			. '01' .
	qq{
			) as service_type,
			code,
			modifier,
			unit_cost,
			quantity,
			emergency,
			rel_diags,
			reference,
			comments,
			item_id,
			extended_cost,
			balance,
			total_adjust,
			item_type,
			flags,
			invoice_item.caption,
			to_char(nvl(service_begin_date,	cr_stamp), 'DD-MON-YYYY'),
			data_text_b,
			code_type,
			data_num_b
 		from HCFA1500_Service_Type_Code, HCFA1500_Service_Place_Code, invoice_item
 		where parent_id = $invoiceId
		and invoice_item.hcfa_service_place = HCFA1500_Service_Place_Code.id (+)
		and invoice_item.hcfa_service_type = HCFA1500_Service_Type_Code.id (+)
 	};

	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or  $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my $procedureObject;
	my @claimCharge;
	my $claimChargePaid = 0;
	my $outsideLabCharges = 0;

	while(my @tempRow = $sth->fetchrow_array())
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
		$procedureObject->setDiagnosis($tempRow[9]);
		$procedureObject->setReference(($tempRow[10]));
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

		my $functionRef;


		if($tempRow[22] == 1)
		{
			$functionRef = \&App::Billing::Claim::addSuppressedItems;
		}
		else
		{
			$functionRef = $itemMap[$tempRow[16]];
		}
		if (($tempRow[16] == INVOICE_ITEM_LAB) && (uc($tempRow[20]) ne "VOID") && ($tempRow[22] != 1))
		{
			$outsideLabCharges = $outsideLabCharges + $tempRow[13]
		}
		if((uc($tempRow[20]) ne "VOID") && ($tempRow[22] != 1))
		{
			$claimCharge[$tempRow[16]] = $claimCharge[$tempRow[16]] + $tempRow[13];
			$claimChargePaid = $claimChargePaid + $tempRow[15] if (($tempRow[16] == INVOICE_ITEM_SERVICE) ||($tempRow[16] == INVOICE_ITEM_LAB));

		}
		if ($functionRef ne "")
		{
			&$functionRef($currentClaim, $procedureObject) ;
		}
	}

	$currentClaim->{treatment}->setOutsideLab(($outsideLabCharges == 0) ? 'N' : 'Y');
	$currentClaim->{treatment}->setOutsideLabCharges(($outsideLabCharges == 0) ? undef : $outsideLabCharges);
	$currentClaim->setTotalCharge($claimCharge[INVOICE_ITEM_LAB] + $claimCharge[INVOICE_ITEM_SERVICE]);
	$currentClaim->setTotalChargePaid($claimChargePaid);
}

sub populateAdjustments
{
	my ($self, $procedure, $ItemId) = @_;

	my $queryStatment = qq
	{
		select
			adjustment_id,
			adjustment_type,
			adjustment_amount,
			bill_id,
			flags,
			payer_type,
			payer_id,
			parent_id,
			plan_allow,
			plan_paid,
			deductible,
			copay,
			to_char(submit_date, 'DD-MON-YYYY'),
			to_char(pay_date, 'DD-MON-YYYY'),
			pay_method,
			pay_ref,
			writeoff_code,
			writeoff_amount,
			adjust_codes,
			net_adjust,
			comments,
			data_text_a,
			parent_id
		from invoice_item_adjust
		where parent_id = $ItemId
	};

	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or  $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	my $adjustment;

	while(my @tempRow = $sth->fetchrow_array())
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

sub dbDisconnect
{
	my $self = shift;
	$self->{dbiCon}->disconnect;
}

sub assignInvoiceAddresses
{
	my ($self, $invoiceId, $currentClaim) = @_;

	my @row;
	my $queryStatment;
	my $sth;

	my $patient = $currentClaim->getCareReceiver();
	my $insured1 = $currentClaim->getInsured(0);
	my $insured2 = $currentClaim->getInsured(1);
	my $insured3 = $currentClaim->getInsured(2);
	my $insured4 = $currentClaim->getInsured(3);

	my $payToProvider = $currentClaim->getPayToProvider();
	my $payToOrganization = $currentClaim->getPayToOrganization();
	my $renderingProvider = $currentClaim->getRenderingProvider();
	my $renderingOrganization = $currentClaim->getRenderingOrganization();

	my $legalRepresentator = $currentClaim->getLegalRepresentator();

	my $payer1 = $currentClaim->getPolicy(0);
	my $payer2 = $currentClaim->getPolicy(1);
	my $payer3 = $currentClaim->getPolicy(2);
	my $payer4 = $currentClaim->getPolicy(3);

	my $patientAddress = $patient->getAddress();

	my $payer1Address = $payer1->getAddress();
	my $payer2Address = $payer2->getAddress();
	my $payer3Address = $payer3->getAddress();
	my $payer4Address = $payer4->getAddress();

	my $insured1Address = $insured1->getAddress();
	my $insured2Address = $insured2->getAddress();
	my $insured3Address = $insured3->getAddress();
	my $insured4Address = $insured4->getAddress();
	my $insured1EmployerAddress = $insured1->getEmployerAddress();
	my $insured2EmployerAddress = $insured2->getEmployerAddress();
	my $insured3EmployerAddress = $insured3->getEmployerAddress();
	my $insured4EmployerAddress = $insured4->getEmployerAddress();

	my $payToProviderAddress = $payToProvider->getAddress;
	my $payToOrganizationAddress = $payToOrganization->getAddress();
	my $renderingProviderAddress = $renderingProvider->getAddress();
	my $renderingOrganizationAddress = $renderingOrganization->getAddress();

	my $legalRepresentatorAddress = $legalRepresentator->getAddress();

	my $thirdPartyTypeAddress = $currentClaim->{payer}->getAddress();

	my @methods = (
		\&App::Billing::Claim::Address::setAddress1,
		\&App::Billing::Claim::Address::setAddress2,
		\&App::Billing::Claim::Address::setCity,
		\&App::Billing::Claim::Address::setState,
		\&App::Billing::Claim::Address::setZipCode,
		\&App::Billing::Claim::Address::setCountry
	);
	my @bindColumns = (
		COLUMNINDEX_ADDRESS1,
		COLUMNINDEX_ADDRESS2,
		COLUMNINDEX_CITY,
		COLUMNINDEX_STATE,
		COLUMNINDEX_ZIPCODE,
		COLUMNINDEX_COUNTRY
	);

	my $addessMap =
	{
		BILLSEQ_PRIMARY_CAPTION . ' Insured' => [$insured1Address],
		BILLSEQ_SECONDARY_CAPTION . ' Insured' => [$insured2Address],
		BILLSEQ_TERTIARY_CAPTION . ' Insured' => [$insured3Address],
		BILLSEQ_QUATERNARY_CAPTION . ' Insured' => [$insured4Address],
		BILLSEQ_PRIMARY_CAPTION . ' Insured Employer' => [$insured1EmployerAddress],
		BILLSEQ_SECONDARY_CAPTION . ' Insured Employer' => [$insured2EmployerAddress],
		BILLSEQ_TERTIARY_CAPTION . ' Insured Employer' => [$insured3EmployerAddress],
		BILLSEQ_QUATERNARY_CAPTION . ' Insured Employer' => [$insured4EmployerAddress],

		BILLSEQ_PRIMARY_CAPTION . ' Insurance' => [$payer1Address],
		BILLSEQ_SECONDARY_CAPTION . ' Insurance' => [$payer2Address],
		BILLSEQ_TERTIARY_CAPTION . ' Insurance' => [$payer3Address],
		BILLSEQ_QUATERNARY_CAPTION . ' Insurance' => [$payer4Address],

		'Patient' => [$patientAddress],

		'Billing' => [$payToProviderAddress, $payToOrganizationAddress],
		'Service' => [$renderingProviderAddress, $renderingOrganizationAddress],

		'Legal Representator' => [$legalRepresentatorAddress],
		'Third-Party' => [$thirdPartyTypeAddress],
	};

	$queryStatment = qq
	{
		select
			address_name,
			line1,
			line2,
			city,
			state,
			zip,
			country
		from invoice_address
		where parent_id = $invoiceId
	};
	$sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");

	while(@row = $sth->fetchrow_array())
	{
		if(my $attrInfo = $addessMap->{$row[COLUMNINDEX_ADDRESSNAME]})
		{
			foreach my $objInst (@$attrInfo)
			{
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
	}
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

	my $queryStatment = qq
	{
		select to_char(min(service_begin_date), 'mm/dd/yyyy')
		from invoice_item
		where parent_id = $invoiceId
	};

	my $sth = $self->{dbiCon}->prepare("$queryStatment");
	$sth->execute or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
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

	if($currentClaim->{treatment}->{reasonForReport} == 3)
	{
		my $id = $currentClaim->{treatment}->{activityType};
		my $queryStatment = qq
		{
			select complete_name
			from person
			where person_id = \'$id\'
		};
		my $sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		my @row = $sth->fetchrow_array();

		$changedTreatingDoctor->setId($id);
		$changedTreatingDoctor->setName($row[0]);

		$self->populateAddress($changedTreatingDoctor->getAddress, "person_address", $id, "Mailing");

		$queryStatment = qq
		{
			select value_text
			from person_attribute
			where parent_id = \'$id\'
			and value_type =
		}
		. PROFESSIONAL_LICENSE_NO;
		$sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		@row = $sth->fetchrow_array();
		$changedTreatingDoctor->setProfessionalLicenseNo($row[0]);
	}
}

sub populateAddress
{
	my ($self, $address, $addressTable, $parentId, $addressName) = @_;

	if($addressTable ne '')
	{
		my $queryStatment = qq
		{
			select line1, line2, city, state, zip, country
			from $addressTable
			where parent_id = \'$parentId\'
			and address_name = \'$addressName\'
		};
		my $sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		my @row = $sth->fetchrow_array();

		$address->setAddress1($row[0]);
		$address->setAddress2($row[1]);
		$address->setCity($row[2]);
		$address->setState($row[3]);
		$address->setZipCode($row[4]);
		$address->setCountry($row[5]);
	}
}

sub populateContact
{
	my ($self, $address, $attributeTable, $parentId, $phoneLocation, $contactType) = @_;

	if($attributeTable ne '')
	{
		my $queryStatment = qq
		{
			select value_text
			from $attributeTable
			where parent_id = \'$parentId\'
			and item_name = \'$phoneLocation\'
			and value_type = \'$contactType\'
		};
		my $sth = $self->{dbiCon}->prepare("$queryStatment");
		$sth->execute() or $self->{valMgr}->addError($self->getId(), 100, "Unable to execute $queryStatment");
		my @row = $sth->fetchrow_array();

		$address->setTelephoneNo($row[0]);
	}
}

1;
