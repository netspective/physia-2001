##############################################################################
package Input::Semnet;
##############################################################################

use strict;
use DBI;
use DBI::StatementManager;
use Driver;
use Dumpvalue;
use App::Data::Manipulate;
use Date::Manip;
use App::Universal;

use base qw(Driver::Input);
use vars qw($STMTMGR);

my $semnetOrg;


sub init
{
	my $self = shift;
	#Create 2 connection sources
	$self->newSource('Semnet');
	$self->newSource('Physia');

	#Connect to Semnet datasource	
	$self->dbiConnectKey('Semnet',"dbi:Proxy:hostname=medina;port=3333;dsn=dbi:ODBC:PROMED_SAMPLE");	
	$self->statements('Semnet','org_data', 'select * from semnet_physician_orgs');
	$self->statements('Semnet','hertg_person_data', 'select * from semnet_person_hertg');
	$self->statements('Semnet','hmoblue_person_data_se_senior', 'select * from semnet_person_hmoblue_se_senior');
	$self->statements('Semnet','hmoblue_person_data_se_comm', 'select * from semnet_person_hmoblue_se_comm');
	
	#Connect to Physia DB
	$self->dbiConnectKey('Physia',"dbi:Oracle:SDEDBS04");
	$self->dbiUserName('Physia',"pro_test");
	$self->dbiPassword('Physia',"pro");
	$self->statements('Physia','semnet_main_org',
	  "select org_internal_id from ORG where org_id='SEMNET' and parent_org_id is null");
	$self->statements('Physia','semnet_ins_orgs',
	  "select org_internal_id, org_id from ORG where parent_org_id=? and category='Insurance'");
	$self->statements('Physia','semnet_ins_org_products',
	  "select ins_internal_id,product_name from INSURANCE where ins_org_id=? and record_type=1");
	$self->statements('Physia','semnet_docs',
	  "select p.person_id pers_id, p.name_last lname from person p, person_org_category pog WHERE p.person_id = pog.person_id AND pog.org_internal_id = ?");
	  
}


#
# Date formatting for ODBC
#
sub formatDate
{
    return UnixDate(ParseDate(shift), '%m/%d/%Y');
}


#
# This subroutine will pull all existing data from the database - semnet main org, insurance orgs, product and plans
#
sub populateDBData
{
	my $self = shift;
	my $dataModel = $self->dataModel();	
	
	my $sth = $self->execute('Physia','semnet_main_org');

	my $count=0;	
	my $org_internal_id;	

	#Store Main Semnet Org
	while (my $rowData = $sth->fetchrow_hashref('NAME_uc')) 
	{				

  	 $org_internal_id= $rowData->{ORG_INTERNAL_ID};
	print $org_internal_id . "<-ROW DAT \n";
	    	$semnetOrg = new App::DataModel::MainOrg(
    		id=>$org_internal_id,
  	    orgId=>'SEMNET',
  	    orgType=>'IPA',
  	    loadIndicator=>'S');
	print "CREAT OBJECT REF->" . $semnetOrg . "\n";  	    
  };
  $dataModel->orgs->add_all($semnetOrg);

	
	#Get Docs for Semnet Org
	$sth = $self->execute('Physia','semnet_docs',$org_internal_id);
	while(my $docRowData = $sth->fetchrow_hashref('NAME_uc'))
	{
		my $personId = $docRowData->{PERS_ID};
		my $lastName = $docRowData->{LNAME};		
		my $person = new App::DataModel::Physician(
							id=>$personId,
							sourceId=>$lastName,
							loadIndicator=>'S');
							
		$dataModel->people->add_personnel($person,$semnetOrg);							
	};
	
	#Get insurance data
	$sth = $self->execute('Physia','semnet_ins_orgs',$org_internal_id);

	#Get Insurance Orgs and Insurance Products
		print "ROW DATA INSURANCE \n";
	while (my $rowData = $sth->fetchrow_hashref('NAME_uc')) 
	{	
		
		my $orgIntId = $rowData->{ORG_INTERNAL_ID};
		my $insorgId = $rowData->{ORG_ID};

  	#Create newd Insurance Org	
		my $ins_org = new App::DataModel::InsuranceOrg(
		          id=>$orgIntId,
		          sourceId=>$insorgId,
		          loadIndicator=>'S');
							
		#Create Links between child and parent orgs
		$dataModel->orgs->addChildOrg($ins_org,$semnetOrg,$semnetOrg);

	  my $sthp = $self->execute('Physia','semnet_ins_org_products', $orgIntId);
						
	  while (my $prodrowData = $sthp->fetchrow_hashref('NAME_uc')) 
	  {	
			 my $insIntId = $prodrowData->{INS_INTERNAL_ID};
			 my $productName = $prodrowData->{PRODUCT_NAME};			
			 my @name = split('_',$productName); 
			 my $shortProdName = $name[0];
			
     	 my $insProduct = new App::DataModel::InsuranceProduct(
				           sourceId=>$shortProdName,
            	     id=>$insIntId,
            	     productName=>$productName,
            	     loadIndicator=>'S');						
			
			#Link insurance Product to Org and Org to insurance product
			$dataModel->orgs->addInsuranceProduct($ins_org,$insProduct);				
	  }

  }
 }


#
# This subroutine will pull main Physician Practice orgs and create them as main orgs
# All patients should be visible by this orgs - using person_org_category
#
sub populateOrgData
{
	my $self = shift;
	#my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
	#Pull Org Data 
  my $sth = $self->execute('Semnet', 'org_data');

	#Store Org Data into Object		
	my $count=0;
	
	while (my $rowData = $sth->fetch()) 
	{		

		$count=0;	
		#Store data from table into named vars
		my $orgId = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $orgName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $phone=defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $line2 =defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;				
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;							
		
		#Create Org Data
		#Create All practices as main orgs		
		my $org = new App::DataModel::MainOrg(
			        orgId=>$orgId,
							orgName=>$orgName, 
							orgBusinessName=>$orgName,
							phone=>$phone,
							orgType=>'Practice');							
		
		#Create Address	
		$org->mailingAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode));
							
		$dataModel->orgs->add_all($org);
	}
	
}

	
#
# This subroutine will pull Heritage patients and create patient records
#
sub populateHertgPatData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
	#Pull Heritage Pat Data 
	my $sth = $self->execute('Semnet', 'hertg_person_data');
	
	#Store Heritage Person Data into Object		
	my $count=0;
	
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		#Store data from table into named vars
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $firstMIName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $memberID = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $sourceDob = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $sex = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $hpcode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $option = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $fromData = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $pcplastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $pcpfirstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		
		my $ssn = substr($memberID,1,9);
		
		my $dob = formatDate($sourceDob); 
		
		#Create Patient Data
		
		#Map gender to id value
		if($sex eq 'F')
		{
			$sex = App::Universal::GENDER_FEMALE;
		}
		elsif($sex eq 'M')
		{
			$sex = App::Universal::GENDER_MALE;	
		}
		else
		{
			$sex = App::Universal::GENDER_UNKNOWN;		
		}

    my ($firstName, $MI) = split (/ /, $firstMIName);   # require works, will not work for Mary Ann for example

    # add person record
		my $person = new App::DataModel::Patient(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $MI,
							ssn=>$ssn,
							gender=>$sex,
							dob=>$dob	
							);	
							
    my $mainOrg = $dataModel->getFirstOrgOfType('MainOrg');	
    while ($mainOrg)
    {
	  		$dataModel->people->add_personnel($person,$mainOrg);		
		    $mainOrg = $dataModel->getNextOrgOfType('MainOrg');
    }
							
							
		#					
		# add PCP association - ???
		#
		
		#
		# adding personal insurance coverage
		#

	}
	
};   # end of populateHertgPatData


sub populateHMOBlueSeSeniorPatData
{
	my $self = shift;
	#my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
  my $ins_org = $dataModel->findOrgBySourceID('HMOBLUE');
  
  #print "found insurance\n";
  
  my $insProduct = $ins_org->findInsProductBySourceID('SESENIOR');
  
  #print "BEFORE execute query\n";
  
	my $sth = $self->execute('Semnet', 'hmoblue_person_data_se_senior');
    
  #print "AFTER execute query\n";  
    
  my $count=0;
  my $recNum=0;
	
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;
	  $recNum++;
	  
	  my $pcpFullName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
	  my $memberID = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $firstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $MI = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $groupNumber = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sex = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $sourceDob = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $age = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$count+=13;
		my $fromDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $termDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $retro = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		

    #print "count=$count recNum=$recNum\n";

		my $dob = formatDate($sourceDob); 

		my $ssn = substr($memberID,1,9);
		
		my @pcpNames = split(' ', $pcpFullName);
		
		my $pcpLastName = $pcpNames[0];

		#Map gender to id value
		if($sex eq 'F')
		{
			$sex = App::Universal::GENDER_FEMALE;
		}
		elsif($sex eq 'M')
		{
			$sex = App::Universal::GENDER_MALE;	
		}
		else
		{
			$sex = App::Universal::GENDER_UNKNOWN;		
		}

    #print "person\n";
    
		my $person = new App::DataModel::Patient(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $MI,
							ssn => $ssn,
							gender=>$sex,
							dob=>$dob	
							);	
    #print "person address\n";

		$person->homeAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));
		
		#print "pcp association\n";
		
		# add PCP association 
		my $pcp = $dataModel->findPersonBySourceID($pcpLastName);
	  #print "pcp association done\n";
				
		if (defined $pcp)
		{
			$person->add_careProvider($pcp);
		}
		
		#print "insurance coverage\n";
		
		# add personal insurance coverage
		
		if (defined $ins_org)
		{
       my $coverage = new App::DataModel::InsuranceCoverage(
				     memberNumber=>$memberID,
				     groupNumber=>$groupNumber);
				     
       $person->link_insuranceCoverage($coverage,undef,$insProduct);
       
	  }

    #print "adding person to main orgs\n";

    # add person object to all semnet main orgs
    
    my $mainOrg = $dataModel->getFirstOrgOfType('MainOrg');	
    while ($mainOrg)
    {
	  		$dataModel->people->add_personnel($person,$mainOrg);		
				#process code here
		    $mainOrg = $dataModel->getNextOrgOfType('MainOrg');
    }
    
    #print "end of record\n";

	}
	
}



#
# This subroutine will pull HMOBLUE Se_Comm patients and create patient records and insurance coverage
#
sub populateHMOBlueSeCommPatData
{
	my $self = shift;
	#my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
  my $ins_org = $dataModel->findOrgBySourceID('HMOBLUE');
  
  #print "found insurance\n";
  
  my $insProduct = $ins_org->findInsProductBySourceID('SECOMM');
  
  #print "BEFORE execute query\n";
  
	my $sth = $self->execute('Semnet', 'hmoblue_person_data_se_comm');
    
  #print "AFTER execute query\n";  
    
  my $count=0;
  my $recNum=0;
	
	while (my $rowData = $sth->fetch()) 
	{	

		$count=0;
	  $recNum++;
	  
	  my $pcpFullName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
	  my $memberID = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $firstName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $lastName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $MI = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $groupNumber = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $sex = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $sourceDob = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $age = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		
		my $line1 = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $city = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $zipCode = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $state = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		$count+=13;
		my $fromDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $termDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $retro = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;		

    #print "count=$count recNum=$recNum\n";

		my $dob = formatDate($sourceDob); 
		
		my $ssn = substr($memberID,1,9);
		
		my @pcpNames = split(' ', $pcpFullName);
		
		my $pcpLastName = $pcpNames[0];

		#Map gender to id value
		if($sex eq 'F')
		{
			$sex = App::Universal::GENDER_FEMALE;
		}
		elsif($sex eq 'M')
		{
			$sex = App::Universal::GENDER_MALE;	
		}
		else
		{
			$sex = App::Universal::GENDER_UNKNOWN;		
		}

    #print "person\n";
    
		my $person = new App::DataModel::Patient(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $MI,
							ssn => $ssn,
							gender=>$sex,
							dob=>$dob	
							);	
    #print "person address\n";

		$person->homeAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));
		
		#print "pcp association\n";
		
		# add PCP association 
		my $pcp = $dataModel->findPersonBySourceID($pcpLastName);
	  #print "pcp association done\n";
				
		if (defined $pcp)
		{
			$person->add_careProvider($pcp);
		}
		
		#print "insurance coverage\n";
		
		# add personal insurance coverage
		
		if (defined $ins_org)
		{
       my $coverage = new App::DataModel::InsuranceCoverage(
				     memberNumber=>$memberID,
				     groupNumber=>$groupNumber);
				     
       $person->link_insuranceCoverage($coverage,undef,$insProduct);
       
	  }

    #print "adding person to main orgs\n";

    # add person object to all semnet main orgs
    
    my $mainOrg = $dataModel->getFirstOrgOfType('MainOrg');	
    while ($mainOrg)
    {
	  		$dataModel->people->add_personnel($person,$mainOrg);		
				#process code here
		    $mainOrg = $dataModel->getNextOrgOfType('MainOrg');
    }
    
    #print "end of record\n";

	}
	
}


sub populateDataModel
{
	my $self = shift;

	my $dataModel = $self->dataModel();

	#Obtain Org data	
	print "***ENTERING DBData\n";
	$self->populateDBData();
	print "***EXITING DBData\n";
	print "***ENTERING ORGData\n";
	$self->populateOrgData();
	print "***EXITING ORGData\n";
	#$self->populateHertgPatData();		
	print "***ENTERING HMOBLUESEComm\n";
	$self->populateHMOBlueSeCommPatData();
	print "***EXITING HMOBLUESEComm\n";
	$self->populateHMOBlueSeSeniorPatData();
	my $dumper = new Dumpvalue;
        $dumper->dumpValue($dataModel);
	exit;
	
	#return $self->errors_size == 0 ? 1 : 0;
};

1;









