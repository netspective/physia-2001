################################################################
package App::Billing::Input::SuperBillDBI;
################################################################

use strict;
use Carp;
use DBI;

use App::Universal;
use App::Billing::SuperBill::SuperBills;
use App::Billing::SuperBill::SuperBill;
use App::Billing::SuperBill::SuperBillComponent;
use App::Billing::Claim::Person;
use App::Billing::Claim::Organization;
use App::Billing::Claim::Address;

sub new
{
	my ($type, %params) = @_;

	$params{UID} = undef;
	$params{PWD} = undef;
	$params{connectStr} = undef;
	$params{dbiCon} = undef;

	return bless \%params, $type;
}

sub connectDb
{
	my ($self, %params) = @_;

	$self->{UID} = $params{UID};
	$self->{PWD} = $params{PWD};
	$self->{conectStr} = $params{connectStr};

	my $user = $self->{UID};
	my $dsn = $self->{conectStr};
	my $password = $self->{PWD};

	# For Oracle 8
	$self->{dbiCon} = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 0 }) || die "Unable To Connect to Database... $dsn ";

}

sub populateSuperBill
{
	my ($self, $superBills, $orgInternalID, %params) = @_;

	$self->makeStatements;

	my $handle = $params{dbiHdl};

	if($handle)
	{
		$self->{dbiCon} = $handle;
	}
	else
	{
		$self->connectDb(%params);
	}

	$self->populateSuperBillAndPatient($superBills, $orgInternalID, %params);

	unless($handle)
	{
		$self->dbDisconnect;
	}

	return 1;
}

sub populateSuperBillAndPatient
{

	my ($self, $superBills, $orgInternalID, %params) = @_;

	my @row;

#	my $sthMain = $self->prepareStatement('selEvents');
#	$sthMain->execute($orgInternalID, $orgInternalID);

	my $rows = $params{fetchedRows};

	my $sthOrgTitle = $self->prepareStatement('orgInternalID');
	my $sthPerson = $self->prepareStatement('personInfo');
	my $sthAddress = $self->prepareStatement('addressInfo');
	my $sthContact = $self->prepareStatement('contactInfo');
	my $sthOrg = $self->prepareStatement('orgInfo');

	foreach my $rowMain (@$rows)
	{

		my $superBillID = $rowMain->{superbill_id};
		my $patientID = $rowMain->{patient};
		my $doctorID = $rowMain->{physician};
		my $orgID = $rowMain->{facility_id};


		my $superBill = new App::Billing::SuperBill::SuperBill;

		$sthOrgTitle->execute($orgInternalID);

		@row = $sthOrgTitle->fetchrow_array();

		$superBill->setOrgName($row[0]);
		$superBill->setTaxId($row[1]);

		my $patient = new App::Billing::Claim::Person;
		my $patientAddress = new App::Billing::Claim::Address;

		$sthPerson->execute($patientID);
		@row = $sthPerson->fetchrow_array();
		$patient->setLastName($row[0]);
		$patient->setMiddleInitial($row[1]);
		$patient->setFirstName($row[2]);
		$patient->setId($row[3]);
		$patient->setDateOfBirth($row[4]);
		$patient->setSex($row[5]);
		$patient->setStatus($row[6]);
		$patient->setSsn($row[7]);
		$patient->setName($row[8]);

		$sthAddress->execute($patientID);
		@row = $sthAddress->fetchrow_array();
		$patientAddress->setAddress1($row[0]);
		$patientAddress->setAddress2($row[1]);
		$patientAddress->setCity($row[2]);
		$patientAddress->setState($row[3]);
		$patientAddress->setZipCode($row[4]);
		$patientAddress->setCountry($row[5]);

		$sthContact->execute($patientID);
		@row = $sthContact->fetchrow_array();
		$patientAddress->setTelephoneNo($row[0]);

		$patient->setAddress($patientAddress);

		$superBill->setPatient($patient);

		my $doctor = new App::Billing::Claim::Person;

		$sthPerson->execute($doctorID);

		@row = $sthPerson->fetchrow_array();

		$doctor->setLastName($row[0]);
		$doctor->setMiddleInitial($row[1]);
		$doctor->setFirstName($row[2]);
		$doctor->setId($row[3]);
		$doctor->setDateOfBirth($row[4]);
		$doctor->setSex($row[5]);
		$doctor->setStatus($row[6]);
		$doctor->setSsn($row[7]);
		$doctor->setName($row[8]);

		$superBill->setDoctor($doctor);

		my $org = new App::Billing::Claim::Organization;

		$sthOrg->execute($orgID);

		@row = $sthOrg->fetchrow_array();

		$org->setId($row[0]);
		$org->setName($row[1]);

		$superBill->setLocation($org);

		$self->populateSuperBillComponent($superBill, $superBillID);

		$superBills->addSuperBill($superBill);
	}
}

sub populateSuperBillComponent
{
	my ($self, $superBill, $superBillID) = @_;

	my $sth = $self->prepareStatement('catalogEntryHeader');
	my $sthCount = $self->prepareStatement('catalogEntryCount');
	my $sthComp = $self->prepareStatement('catalogEntries');


	$sth->execute($superBillID);
	while(my @row = $sth->fetchrow_array())
	{
		my $superBillComponent = new App::Billing::SuperBill::SuperBillComponent;

		$superBillComponent->setHeader($row[1]);

		$sthCount->execute($superBillID, $row[0]);
		my @rowCount = $sthCount->fetchrow_array();
		$superBillComponent->setCount($rowCount[0]);

		$sthComp->execute($superBillID, $row[0]);
		while(my @rowComp = $sthComp->fetchrow_array())
		{
			$superBillComponent->addCpt($rowComp[1]);
			$superBillComponent->addDescription($rowComp[2]);
		}

		$superBill->addSuperBillComponent($superBillComponent)
	}

}

sub dbDisconnect
{
	my $self = shift;
	$self->{dbiCon}->disconnect;
}

sub makeStatements
{
	my $self = shift;

	$self->{statements} =
	{
		'selEvents' => qq
		{
			select e.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id
			from event e, event_attribute ea
			where e.event_id = ea.parent_id
			and owner_id = ?
			and e.superbill_id is not null
			union
			select apt.superbill_id, ea.value_text as patient, ea.value_textb as physician, facility_id
			from event e, event_attribute ea, appt_type apt
			where e.event_id = ea.parent_id
			and owner_id = ?
			and e.superbill_id is null
			and e.appt_type = apt.appt_type_id
			and apt.superbill_id is not null
		},

		'orgInternalID' => qq
		{
			select name_primary, tax_id
			from org
			where org_internal_id = ?
		},

		'catalogEntryHeader' => qq
		{
			select entry_id, name
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id is null
			and entry_type = 0
			and status = 1
			and not name = 'main'
			order by entry_id
		},

		'catalogEntryCount' => qq
		{
			select count(*)
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id = ?
			and entry_type = 100
			and status = 1
		},

		'catalogEntries' => qq
		{
			select entry_id, code, name
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id = ?
			and entry_type = 100
			and status = 1
			order by entry_id
		},

		'personInfo' => qq
		{
			select
				name_last,
				name_middle,
				name_first,
				person_id,
				to_char(date_of_birth, 'DD-MON-YYYY'),
				gender,
				marital_status,
				ssn,
				simple_name
			from person
			where person_id = ?
		},

		'orgInfo' => qq
		{
			select org_id, name_primary
			from org
			where org_internal_id = ?
		},

		'addressInfo' => qq
		{
			select line1, line2, city, state, zip, country
			from person_address
			where parent_id = ?
			and address_name = 'Mailing'
		},

		'contactInfo' => qq
		{
			select value_text
			from person_attribute
			where parent_id = ?
			and item_name = 'Home'
			and value_type = 10
		},
	};
}

sub getStatement
{
	my ($self, $statementID) = @_;

	my $statements = $self->{statements};
	return $statements->{$statementID};
}

sub prepareStatement
{
	my ($self, $statementID) = @_;


	my $statements = $self->{statements};
	return $self->{dbiCon}->prepare($statements->{$statementID});
}


1;
