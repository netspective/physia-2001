################################################################
package App::Billing::Input::SuperBillDBI;
################################################################

use strict;
use Carp;

use App::Billing::SuperBill::SuperBills;
use App::Billing::SuperBill::SuperBill;
use App::Billing::SuperBill::SuperBillComponent;

use App::Billing::Claim::Person;
use App::Billing::Claim::Organization;
use App::Billing::Claim::Address;

use DBI::StatementManager;
use App::Statements::Report::SuperBill;


sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}


sub populateSuperBill
{
	my ($self, $superBills, $page, %params) = @_;

	$self->populateSuperBillAndPatient($superBills, $page, %params);

	return 1;
}

sub populateSuperBillAndPatient
{

	my ($self, $superBills, $page, %params) = @_;

	my $startTime = $params{startTime};
	my $endTime = $params{endTime};
	my $physicianID = $params{physicianID};
	my $eventID = $params{eventID};
	my $superBillID = $params{superBillID};


	if($superBillID ne '')
	{

		my $orgInternalId = $params{orgInternalID};

		if($orgInternalId eq '')
		{
			$orgInternalId = $page->session('org_internal_id');
		}

		my $orgInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgInfo', $orgInternalId);

		my $superBill = new App::Billing::SuperBill::SuperBill;
		$superBill->setOrgName($orgInfo->{name_primary});
		$superBill->setTaxId($orgInfo->{tax_id});
		my $patient = new App::Billing::Claim::Person;
		my $patientAddress = new App::Billing::Claim::Address;
		$patient->setAddress($patientAddress);
		$superBill->setPatient($patient);
		my $doctor = new App::Billing::Claim::Person;
		$superBill->setDoctor($doctor);
		my $org = new App::Billing::Claim::Organization;
		$superBill->setLocation($org);
		$self->populateSuperBillComponent($superBill, $superBillID, $page);
		$superBills->addSuperBill($superBill);
	}
	else
	{
		my $offset = $page->session('GMT_DAYOFFSET');
		my $orgInternalId = $page->session('org_internal_id');

		my $allEvents;

		if(($startTime ne '') && ($endTime ne ''))
		{
			if($physicianID ne '')
			{
				$allEvents = $STMTMGR_REPORT_SUPERBILL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSBbyStartEndDatePhysician', $startTime, $endTime, $offset, $orgInternalId, $physicianID);
			}
			else
			{
				$allEvents = $STMTMGR_REPORT_SUPERBILL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSBbyStartEndDate', $startTime, $endTime, $offset, $orgInternalId);
			}
		}
		elsif($eventID ne '')
		{
			$allEvents = $STMTMGR_REPORT_SUPERBILL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSBbyEvents', $eventID, $offset, $orgInternalId);
		}
		else
		{
		}

		foreach my $rowMain (@$allEvents)
		{
			my $superBillID = $rowMain->{superbill_id};
			my $patientID = $rowMain->{patient};
			my $doctorID = $rowMain->{physician};
			my $orgID = $rowMain->{facility_id};

			my $superBill = new App::Billing::SuperBill::SuperBill;

			my $orgInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgInfo', $orgInternalId);
			$superBill->setOrgName($orgInfo->{name_primary});
			$superBill->setTaxId($orgInfo->{tax_id});

			$superBill->setDate($rowMain->{start_date});
			$superBill->setTime($rowMain->{start_time});

			# patient info

			my $patient = new App::Billing::Claim::Person;
			my $patientAddress = new App::Billing::Claim::Address;
			my $patientInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'personInfo', $patientID);
			$patient->setLastName($patientInfo->{name_last});
			$patient->setMiddleInitial($patientInfo->{name_middle});
			$patient->setFirstName($patientInfo->{name_last});
			$patient->setId($patientInfo->{patient_id});
			$patient->setDateOfBirth($patientInfo->{dob});
			$patient->setSex($patientInfo->{gender});
			$patient->setStatus($patientInfo->{marital_status});
			$patient->setSsn($patientInfo->{ssn});
			$patient->setName($patientInfo->{simple_name});
			my $patientAddressInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'personAddressInfo', $patientID);
			$patientAddress->setAddress1($patientAddressInfo->{line1});
			$patientAddress->setAddress2($patientAddressInfo->{line2});
			$patientAddress->setCity($patientAddressInfo->{city});
			$patientAddress->setState($patientAddressInfo->{state});
			$patientAddress->setZipCode($patientAddressInfo->{zip});
			$patientAddress->setCountry($patientAddressInfo->{country});
			my $patientContactInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'personContactInfo', $patientID);
			$patientAddress->setTelephoneNo($patientContactInfo->{phone});
			$patient->setAddress($patientAddress);
			$superBill->setPatient($patient);

			# doctor info

			my $doctor = new App::Billing::Claim::Person;
			my $doctorInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'personInfo', $doctorID);
			$doctor->setLastName($doctorInfo->{name_last});
			$doctor->setMiddleInitial($doctorInfo->{name_middle});
			$doctor->setFirstName($doctorInfo->{name_last});
			$doctor->setId($doctorInfo->{patient_id});
			$doctor->setDateOfBirth($doctorInfo->{dob});
			$doctor->setSex($doctorInfo->{gender});
			$doctor->setStatus($doctorInfo->{marital_status});
			$doctor->setSsn($doctorInfo->{ssn});
			$doctor->setName($doctorInfo->{simple_name});
			$superBill->setDoctor($doctor);

			# facility info

			my $org = new App::Billing::Claim::Organization;
			my $facilityInfo = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgInfo', $orgID);
			$org->setId($facilityInfo->{org_id});
			$org->setName($facilityInfo->{name_primary});
			$superBill->setLocation($org);

			$self->populateSuperBillComponent($superBill, $superBillID, $page);

			$superBills->addSuperBill($superBill);
		}
	}
}

sub populateSuperBillComponent
{
	my ($self, $superBill, $superBillID, $page) = @_;

	my $headerInfo = $STMTMGR_REPORT_SUPERBILL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'catalogEntryHeader', $superBillID);

	foreach my $row (@$headerInfo)
	{
		my $superBillComponent = new App::Billing::SuperBill::SuperBillComponent;

		my $header = $row->{entry_id};
		$superBillComponent->setHeader($row->{name});

		my $entryCount = $STMTMGR_REPORT_SUPERBILL->getRowAsHash($page, STMTMGRFLAG_NONE, 'catalogEntryCount', $superBillID, $header);
		$superBillComponent->setCount($entryCount->{entry_count});

		my $entries = $STMTMGR_REPORT_SUPERBILL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'catalogEntries', $superBillID, $header);
		foreach my $entry (@$entries)
		{
			$superBillComponent->addCpt($entry->{code});
			$superBillComponent->addDescription($entry->{name});
		}

		$superBill->addSuperBillComponent($superBillComponent)
	}

}

1;
