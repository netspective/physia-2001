##############################################################################
package Input::Promed;
##############################################################################

use strict;
use DBI;
use DBI::StatementManager;
use Driver;
use Dumpvalue;
use App::Data::Manipulate;
use App::Universal;

use base qw(Driver::Input);
use vars qw($STMTMGR);

sub init
{
	my $self = shift;
	#only need one connection string
	$self->newSource('Promed');
	my $source=$self->getSource('Promed');	
	$self->dbiConnectKey('Promed',"dbi:Proxy:hostname=medina;port=3333;dsn=dbi:ODBC:PROMED_SAMPLE");
	print $self->dbiConnectKey('Promed') . "\n";
	$self->statements('Promed','org_data', 'select * from mwadd');	
	$self->statements('Promed','phy_data', 'select * from mwphy');	
	$self->statements('Promed','pat_data', 'select * from mwpat');		
	$self->statements('Promed','prt_data', 'select * from mwpra where State = ?');	
	$self->statements('Promed','ins_data', 'select * from mwins');	
	$self->statements('Promed','refdoc_data', 'select * from mwrph');		
}


sub populateOrgData
{
	my $self = shift;
	my $source = $self->getSource('Promed');
	my $dbh = $source->dbh();
	my $dataModel = $self->dataModel();	
	
	#Pull Org Data 
	my $sth = $source->execute('org_data');
	
	#Store Org Data into Object		
	my $count=0;
	
	#Get Main Org
	my $mainOrg;
	$mainOrg = $dataModel->getFirstOrgOfType('MainOrg');
	while (my $rowData = $sth->fetch()) 
	{		

		$count=0;	
		#Store data from table into named vars
		my $code = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $orgName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;							
		my $phone=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$phone .=  defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $fax=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $contact=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $id=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $type=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra2=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		
		#Clean Fax and Phone Numbers
		$phone=~s/\(//g;		
		$phone=~s/\)/-/g;				
		$fax=~s/\(//g;	
		$fax=~s/\)/-/g;		
		
		#Create Org Data
		my $org;
		if ($type eq 'Employer' || $type eq 'Miscellaneous')
		{
			$org = new App::DataModel::Employer(sourceId=>$code,
							orgName=>$orgName, 
							orgBusinessName=>$orgName,
							phone=>$phone,
							fax=>$fax,
							orgType=>'Employer',
							billingContact=>$contact);							
		}
		elsif ($type eq 'Facility')
		{
			$org = new App::DataModel::Department(sourceId=>$code,
							orgName=>$orgName, 
							orgBusinessName=>$orgName,
							phone=>$phone,
							fax=>$fax,
							orgType=>'Facility/Site',
							billingContact=>$contact);							
		
		}
		#Create Address	
		$org->mailingAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));							
		#Create Links between child and parent orgs
		$dataModel->orgs->addChildOrg($org,$mainOrg,$mainOrg);
	};		
}

sub populatePrtData
{
	my $self = shift;
	my $dataModel = $self->dataModel();	
	#Pull Org Data 
	my $source=$self->getSource('Promed');	
	my $sth = $self->execute('Promed','prt_data',['FL']);
	#my $sth = $source->execute('prt_data',["FL"]);
	#Store Practice Data into Object	
	my $count=0;	
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		#Store data from table into named vars
		my $orgName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;							
		my $phone=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$phone .=  defined $rowData->[$count] ?" $rowData->[$count]" : '' ; $count++;
		my $fax= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$phone=~s/\(//g;		
		$phone=~s/\)/-/g;				
		$fax=~s/\(//g;	
		$fax=~s/\)/-/g;			
		my $practiceType= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $taxId= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $extra1= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra2= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		
		#Create Org Data
		my $org = new App::DataModel::MainOrg(
							orgName=>$orgName, 
							orgBusinessName=>$orgName,
							phone=>$phone,
							fax=>$fax,								
							orgType=>'Practice',
							);							
		#Create Address
		#Create Address	
		$org->mailingAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode));							
		#Create Id field												
		$org->ids(new App::DataModel::IDNumbers(taxId=>$taxId));		
		$dataModel->orgs->add_all($org);		
	};		
}



sub populatePhyData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	#Pull Org Data 
	my $sth = $self->execute('phy_data');
	
	#Get Main Org
	my $mainOrg;
	$mainOrg = $dataModel->getFirstOrgOfType('MainOrg');
	my $count=0;
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		#Store data from table into named vars
		my $code = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $firstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $middleName =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $credentials =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $state=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $zipCode =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $phone =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $fax =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $ssn =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $taxId =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $licenseNumber =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $signature=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicarePin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicaidPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $champusPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $blueCrossShieldPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $commercialPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $GroupPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $hmoPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $ppoPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicareGroupPin=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicaidGroupPin=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $bcbsGroupPIN =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $otherGroupPIN =	defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $emcID =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicarePartProvider =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $UPIN =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra1=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra2 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $specialty =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $securityLevel=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sbNumber=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sofDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		

		#Clean Fax and Phone Nubmers		
		$phone=~s/\(//g;		
		$phone=~s/\)/-/g;				
		$fax=~s/\(//g;	
		$fax=~s/\)/-/g;			
		my $person = new App::DataModel::Physician(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $middleName,
							ssn => $ssn,
							workPhone=>$phone,
							sourceId=>$code);
		#Create Address		
		$person->homeAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));
		$dataModel->people->add_personnel($person,$mainOrg);
	};		
}




sub populateRefDocData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	#Pull Org Data 
	my $sth = $self->execute('refdoc_data');
	
	#Get Main Org
	my $mainOrg;
	$mainOrg = $dataModel->getFirstOrgOfType('MainOrg');
	my $count=0;
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		#Store data from table into named vars
		my $code = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $firstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $middleName =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $credentials =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $state=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $zipCode =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $phone =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $fax =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $ssn =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $taxId =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $licenseNumber =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $signature=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicarePin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicaidPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $champusPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $blueCrossShieldPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $commercialPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $GroupPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $hmoPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $ppoPin =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicareGroupPin=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicaidGroupPin=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $bcbsGroupPIN =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $otherGroupPIN =	defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $emcID =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $medicarePartProvider =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $UPIN =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra1=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $extra2 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $specialty =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $securityLevel=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sbNumber=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sofDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;			
		$phone=~s/\(//g;		
		$phone=~s/\)/-/g;				
		$fax=~s/\(//g;	
		$fax=~s/\)/-/g;			
		
		my $person = new App::DataModel::ReferringDoctor(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $middleName,
							ssn => $ssn,
							workPhone=>$phone,
							sourceId=>$code);
		#Create Address		
		$person->homeAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));			
		$dataModel->people->add_personnel($person,$mainOrg);		
	};		
}






sub populatePatData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
	
	#Pull Org Data 
	my $sth = $self->execute('pat_data');
	
	#Get Main Org
	my $mainOrg;
	$mainOrg = $dataModel->getFirstOrgOfType('MainOrg');
	my $count=0;
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;
		#Store data from table into named vars
		my $chart = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $firstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $middleName =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $state=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $zipCode =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $phone =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $phone2 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $ssn =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $signature=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $patientType=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $patientId =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sex =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $dob =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $assignProv =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $country =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $dateLastPayement =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastPayement =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $balance =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $dateCreated =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $employementStatus=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $employer=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $employeeLocation=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $retirementDate =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $workPhone =	defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $workExtension =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sofDate =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $billingCode =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $patientIndicator=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
			
		#Correct Date Of Birth Format		
		if ($dob)
		{
			$dob=~m/(\d\d\d\d)\-(\d\d)\-(\d\d)/;
			$dob="$2/$3/$1";
		};
		

		$phone=~s/\(//g;		
		$phone=~s/\)/-/g;				
		$phone2=~s/\(//g;	
		$phone2=~s/\)/-/g;		
		$workPhone=~s/\(//g;		
		$workPhone=~s/\)/-/g;				
		
		#Map gender to id value
		if($sex eq 'Female')
		{
			$sex = App::Universal::GENDER_FEMALE;
		}
		elsif($sex eq 'Male')
		{
			$sex = App::Universal::GENDER_MALE;	
		}
		else
		{
			$sex = App::Universal::GENDER_UNKNOWN;		
		}
		
		my $person = new App::DataModel::Patient(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $middleName,
							ssn => $ssn,
							workPhone=>$workPhone,
							chartNumber=>$chart,
							homePhone=>$phone,
							alternatePhone=>$phone2,
							gender=>$sex,
							dob=>$dob,	
							sourceId=>$chart
							);	
		#map employment Status		
		if ($employementStatus eq 'Unknown ')
		{
			$employementStatus=App::Universal::ATTRTYPE_EMPLOYUNKNOWN
		}
		elsif ($employementStatus eq 'Not employed')		
		{
			$employementStatus=App::Universal::ATTRTYPE_UNEMPLOYED
		}
		elsif ($employementStatus eq 'Full time')		
		{
			$employementStatus=App::Universal::ATTRTYPE_EMPLOYEDFULL
		}
		elsif ($employementStatus eq 'Part Time')		
		{
			$employementStatus=App::Universal::ATTRTYPE_EMPLOYEDPART
		}
		else
		{
			$employementStatus=App::Universal::ATTRTYPE_EMPLOYUNKNOWN
		}
		
		
		#Create Employment Data	
		if ($employementStatus||$workPhone||$employer) 
		{
			my $employment;
			my $orgEmp ;
			$employment = new App::DataModel::Employment (
								employmentStatus=>$employementStatus,
								employmentPhoneNumber=>$workPhone,	
								employeeID=>$employer,
								); 
			#Get Empolyer org info if the Org has been added
			$orgEmp = $dataModel->findOrgBySourceID($employer) if $employer;	
			$employment->org($orgEmp) if $orgEmp;
			$person->employment($employment) if $employment;			
		}
		#Create Address			
		$person->homeAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));	
		$dataModel->people->add_personnel($person,$mainOrg);		
	};		
}



sub populateInsData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
	#Pull Org Data 
	my $sth = $self->execute('ins_data');
	
	#Store Practice Data into Object	
	my $count=0;	
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		#Store data from table into named vars
		my $code = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $insName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;							
		my $phone=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$phone .=  defined $rowData->[$count] ?" $rowData->[$count]" : '' ; $count++;
		my $fax= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $contact= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $practiceID= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $planName= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $type= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $procedureCodeSet= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $Diagnosis= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $Signature= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $delay2Bill= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $defaultBilling= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $EMCReceiver= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $EMCPayor= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $EMCSubID= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $EMCExtra1= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $EMCExtra2= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;						
		my $ETSCode= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;						
		my $defaultPayment= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;						
		my $defaultWriteOffCode= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;								
		my $defaultDec= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;										
		my $indicator= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;								
		my $printPINs= defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;												
		
		#Create Org Insurance Data will belong to		
		my $insProduct = new App::DataModel::InsuranceProduct(	sourceId=>$code,									
									productName=>$insName,
									productType=>$type,	
									phone=>$phone,
									fax=>$fax,
								     );
		my $insPlan = new App::DataModel::InsurancePlan(planName=>$planName,
								);								
		my $insCoverage = new App::DataModel::InsuranceCoverage(memberNumber=>$practiceID,
									);
		my $address = new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,);		
		$insProduct->billingAddress($address);		
		$insPlan->add_insuranceCoverage($insCoverage);				
		$insProduct->add_insurancePlan($insPlan);

		#Create and Insurance Org	
		my $org = new App::DataModel::InsuranceOrg(
							orgName=>$insName, 
							orgBusinessName=>$insName,
							phone=>$phone,
							fax=>$fax,								
							);
		$org->mailingAddress($address);	
		$org->add_insuranceProduct($insProduct);		
		$dataModel->orgs->add_all($org);	
	};		
}



sub populateDataModel
{
	my $self = shift;
	#my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();

	#Obtain Org data
	$self->populatePrtData();		
	#$self->populateOrgData();		
	#$self->populatePhyData();
	
	#$self->populateRefDocData();	
	#$self->populatePatData();
	#$self->populateInsData();		
	
	my $dumper = new Dumpvalue;
        $dumper->dumpValue($dataModel->orgs);
	exit;
	
	return $self->errors_size == 0 ? 1 : 0;
}

1;
