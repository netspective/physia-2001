################################################################
package App::Billing::Input::PrescriptionDBI;
################################################################

use strict;
use Carp;

use App::Billing::Prescription::Prescription;
use App::Billing::Prescription::Drug;
use App::Billing::Prescription::Drugs;

use App::Billing::Claim::Physician;
use App::Billing::Claim::Organization;
use App::Billing::Claim::Person;
use App::Billing::Claim::Address;

use DBI::StatementManager;
use App::Statements::Report::Prescription;


sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}


sub populatePrescription
{

	my ($self, $prescription, $page, $permed_id, %params) = @_;

	my $orgInternalId = $page->session('org_internal_id');

	my $rowData = $STMTMGR_REPORT_PRESCRIPTION->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selPrescriptionByID', $permed_id, $orgInternalId);

	foreach my $row (@$rowData)
	{
		my $patientID = $row->{parent_id};
		my $doctorID = $row->{approved_by};
		my $orgID = $row->{cr_org_internal_id};

		$prescription->setDate($row->{start_date});

		# patient info

		my $patient = new App::Billing::Claim::Patient;
		my $patientAddress = new App::Billing::Claim::Address;

		my $patientInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'personInfo', $patientID);
		$patient->setLastName($patientInfo->{name_last});
		$patient->setMiddleInitial($patientInfo->{name_middle});
		$patient->setFirstName($patientInfo->{name_last});
		$patient->setId($patientInfo->{patient_id});
		$patient->setDateOfBirth($patientInfo->{dob});
		$patient->setSex($patientInfo->{gender});
		$patient->setStatus($patientInfo->{marital_status});
		$patient->setSsn($patientInfo->{ssn});
		$patient->setName($patientInfo->{simple_name});

		my $patientAddressInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'personAddressInfo', $patientID);
		$patientAddress->setAddress1($patientAddressInfo->{line1});
		$patientAddress->setAddress2($patientAddressInfo->{line2});
		$patientAddress->setCity($patientAddressInfo->{city});
		$patientAddress->setState($patientAddressInfo->{state});
		$patientAddress->setZipCode($patientAddressInfo->{zip});
		$patientAddress->setCountry($patientAddressInfo->{country});

		my $patientContactInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'personContactInfo', $patientID);
		$patientAddress->setTelephoneNo($patientContactInfo->{phone});
		$patient->setAddress($patientAddress);

		$prescription->setPatient($patient);

		# doctor info

		my $doctor = new App::Billing::Claim::Physician;

		my $doctorInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'personInfo', $doctorID);
		$doctor->setLastName($doctorInfo->{name_last});
		$doctor->setMiddleInitial($doctorInfo->{name_middle});
		$doctor->setFirstName($doctorInfo->{name_last});
		$doctor->setId($doctorInfo->{patient_id});
		$doctor->setDateOfBirth($doctorInfo->{dob});
		$doctor->setSex($doctorInfo->{gender});
		$doctor->setStatus($doctorInfo->{marital_status});
		$doctor->setSsn($doctorInfo->{ssn});
		$doctor->setName($doctorInfo->{simple_name});

		my $doctorDEAInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'physicianDEA', $doctorID);
		$doctor->setDEA($doctorDEAInfo->{dea});

		$prescription->setPhysician($doctor);

		# facility info

		my $org = new App::Billing::Claim::Organization;
		my $orgAddress = new App::Billing::Claim::Address;

		my $facilityInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgInfo', $orgInternalId);
		$org->setId($facilityInfo->{org_id});
		$org->setName($facilityInfo->{name_primary});
		$org->setTaxId($facilityInfo->{tax_id});

		my $orgAddressInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgAddressInfo', $orgInternalId);
		$orgAddress->setAddress1($orgAddressInfo->{line1});
		$orgAddress->setAddress2($orgAddressInfo->{line2});
		$orgAddress->setCity($orgAddressInfo->{city});
		$orgAddress->setState($orgAddressInfo->{state});
		$orgAddress->setZipCode($orgAddressInfo->{zip});
		$orgAddress->setCountry($orgAddressInfo->{country});

		my $orgContactInfo = $STMTMGR_REPORT_PRESCRIPTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'orgContactInfo', $orgInternalId);
		$orgAddress->setTelephoneNo($orgContactInfo->{phone});

		$org->setAddress($orgAddress);
		$prescription->setPractice($org);

		my $drugs = new App::Billing::Prescription::Drugs;
		$self->populateDrugs($row, $drugs);

		$prescription->setDrug($drugs);
	}

	return 1;
}

sub populateDrugs
{
	my ($self, $row, $drugs) = @_;

	my $drug = new App::Billing::Prescription::Drug;

	$drug->setDrugName($row->{med_name});
	$drug->setDose($row->{dose});
	$drug->setDoseUnits($row->{dose_units});
	$drug->setQuantity($row->{quantity});
	$drug->setDuration($row->{duration});
	$drug->setDurationUnits($row->{duration_units});
	$drug->setNumRefills($row->{num_refills});
	$drug->setAllowSubstitution($row->{allow_substitutions});
	$drug->setAllowGeneric($row->{allow_generic});
	$drug->setLabel($row->{label});
	$drug->setLabelSpanish($row->{label_in_spanish});
	$drug->setSig($row->{sig});

	$drugs->addDrug($drug)

}

1;
