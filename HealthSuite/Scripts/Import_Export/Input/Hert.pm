##############################################################################
package Input::Hert;
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

my %index = ();

sub init
{
	my $self = shift;
	#Create 2 connection sources
	$self->newSource('Semnet');
	$self->newSource('Physia');

	#Connect to Semnet datasource	
	$self->dbiConnectKey('Semnet',"dbi:Proxy:hostname=medina;port=3333;dsn=dbi:ODBC:PROMED_SAMPLE");	
	$self->statements('Semnet','org_data', 'select * from semnet_physician_orgs');
	$self->statements('Semnet','hertg_person_data', 'select * from semnet_person_hertg order by memname,hpcode');

	  
	
	#Connect to Physia DB
	$self->dbiConnectKey('Physia',"dbi:Oracle:SDEDBS03");
	$self->dbiUserName('Physia',"pro_new");
	$self->dbiPassword('Physia',"usuz1v4y");
	$self->statements('Physia','semnet_main_org',
	  "select org_internal_id from ORG where org_id='SEMNET' and parent_org_id is null");
	$self->statements('Physia','semnet_ins_orgs',
	  "select org_internal_id, org_id from ORG where parent_org_id=? and category='Insurance'");
	$self->statements('Physia','semnet_ins_org_products',
	  "select ins_internal_id,product_name from INSURANCE where ins_org_id=? and record_type=1");
	$self->statements('Physia','semnet_docs',
	  "select p.person_id pers_id, p.name_last lname from person p, person_org_category pog WHERE p.person_id = pog.person_id AND pog.org_internal_id = ? AND pog.category='Physician' ");
	  
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
	#print $org_internal_id . "<-ROW DAT \n";
	    	$semnetOrg = new App::DataModel::MainOrg(
    		id=>$org_internal_id,
  	    orgId=>'SEMNET',
  	    orgType=>'IPA',
  	    loadIndicator=>'S');
	#print "CREAT OBJECT REF->" . $semnetOrg . "\n";  	    
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
		#print "ROW DATA INSURANCE \n";
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
# This subroutine will pull Heritage patients and create patient records
#
sub populateHertgPatData
{
	my $self = shift;
	my $dataModel = $self->dataModel();	
	
	
	my $ins_org = $dataModel->findOrgBySourceID('HERITAGE');
	#Pull Heritage Pat Data 
	my $sth = $self->execute('Semnet', 'hertg_person_data');
	
	#Store Heritage Person Data into Object		
	my $count=0;
	my $rowRead=0;
	my $rowProcess=0;
	while (my $rowData = $sth->fetch()) 
	{		
		$count=0;	
		$rowRead++;
	

		#Store data from table into named vars
		my $name = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $memberID = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $sourceDob = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;	
		my $sex = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++;
		my $hpcode = defined $rowData->[$count] ?uc(App::Data::Manipulate::trim($rowData->[$count])) : '' ; $count++; 
		my $option = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $fromDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		my $toDate = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 		
		my $pcpName = defined $rowData->[$count] ?App::Data::Manipulate::trim($rowData->[$count]) : '' ; $count++; 
		
		my $ssn = substr($memberID,0,9);

		
		my $dob = formatDate($sourceDob); 
		my $begin = formatDate($fromDate); 				
		my $end = formatDate($toDate); 	
		$name =~/^([^\,]+), ([^\s]+)[\s]?(\w+)?/;		
		my $firstName = $2||'';
		my $lastName = $1||'';
		my $MI=$3 ? $3 : '';	
		#Check if First Name has a suffix
		$lastName =~/^([^\s]+)\s?(\w+)?/;
		$lastName = $1;
		my $suffix = $2 ||'';
		#print "[$lastName] [$firstName] [$MI] [$suffix]\n";				
		#next;

		$pcpName =~/^([^\,]+),([^\s]+)[\s]?(\w+)?/;
		my $pcpFirstName = $2;
		my $pcpLastName = $1;
		my $pcpMI=$3 ? $3 : '';		
		#Create Patient Data		
		if ($firstName eq '' || $lastName eq '')
		{
			print "ERROR : Invalid first [$firstName] or last [$lastName] name , member ID [$memberID] \n";
			next;
		}
		if ($pcpLastName eq '' || $pcpFirstName eq '')
		{
			print "ERROR : Invalid first [$pcpLastName] or last [$pcpFirstName] name , member ID [$memberID] \n";
			next;
		}		
		if ($pcpLastName eq "O'DWYER")
		{
			#print "Name Replace O'DWYER->ODWYER\n";
			$pcpLastName = 'ODWYER';
		}
		if ($pcpLastName eq "LAWSON  (76-0258915)")
		{
			#print "Name Replace LAWSON  (76-0258915)->LAWSON\n";
			$pcpLastName = 'LAWSON';
		}
		
		$rowProcess++;					
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


    # add person record
		my $person = new App::DataModel::Patient(
							nameFirst => $firstName,
							nameLast => $lastName,
							nameMiddle => $MI,
							ssn=>$ssn,
							gender=>$sex,
							dob=>$dob,	
							nameSuffix=>$suffix,
							);	
		my $key = $lastName . $firstName  .  $dob ;


		my $pcp = $dataModel->findPersonBySourceID($pcpLastName);								
		if (defined $pcp)
		{
			#print "$pcpLastName\n";
			$person->add_careProvider($pcp);
		}			

		my $personExists=0;
		#Check If person Already exists		    		
		if(my $list = $index{$key})
		{	
			$person = $list;	
			$personExists=1;
			print "$key EXISTS\n";
		}		
		else
		{
			$index{$key} = $person;
		}							
							

							
							
		#					
		# add PCP association - ???
		#	
		#
		# adding personal insurance coverage
		#
		
 		my $insProduct = $ins_org->findInsProductBySourceID($hpcode);
 		
		if (defined $ins_org)
		{
		       my $coverage = new App::DataModel::InsuranceCoverage(
				     	memberNumber=>$memberID,
				     	#groupNumber=>$groupNumber,
				     	coverageDate=>new App::DataModel::Duration(beginDate=>$begin, endDate=>$end)
				     	);	

				#Check if this insurance product coverage record already exists
				if($person->insurance)
				{
					my $replace;
					my $minStart="01/01/9999";
					my $maxEnd="01/01/1800";			
					my $loop;
					for ($loop=0;$loop <= $person->insurance_size; $loop++)
					{

						my $cov = $person->insurance($loop);
						$minStart = $cov->coverageDate->beginDate;
						$maxEnd = $cov->coverageDate->endDate;				
						my $startCov = $coverage->coverageDate->beginDate;
						my $endCov = $coverage->coverageDate->endDate;

						#print "startCov [$startCov ] endCov [$endCov] minStart [$minStart] maxEnd [$maxEnd] ENTER \n";
						my $flagStart = Date_Cmp($startCov,$minStart);
						if($flagStart<0)
						{
							$minStart = $startCov;
						}			
						$maxEnd = $endCov unless $endCov;
						my $flagEnd = Date_Cmp($endCov,$maxEnd);			
						if($flagEnd>0 && $maxEnd ne '')
						{
							$maxEnd = $endCov; 
						}				
						my $coverage = $person->insurance($loop);
						my $productName = $coverage->insuranceProduct->productName;
						if ($productName eq $insProduct->productName)
						{
							$replace=$coverage;
						}
						#print "startCov [$startCov ] endCov [$endCov] minStart [$minStart] maxEnd [$maxEnd] EXIT \n";						
					}
					#print "-------------$key------------DONE minStart [$minStart] maxEnd [$maxEnd] EXIT --------------------------\n";					
					if($replace)
					{
						#print "REPLACE  [$replace] $key -> $minStart $maxEnd\n";
						$replace->coverageDate->beginDate($minStart);
						$replace->coverageDate->endDate($maxEnd);
					}
					else
					{   			
						#print "SECONDARY $key\n";
						$person->link_insuranceCoverage($coverage,undef,$insProduct);       			
					}
				}
				else
				{
					$person->link_insuranceCoverage($coverage,undef,$insProduct);
				}				     


			  }				     	
    		my $mainOrg = $dataModel->getFirstOrgOfType('MainOrg');	
		$dataModel->people->add_personnel($person,$mainOrg) if(!$personExists);					  
	}

	print "Patients read from input		:	$rowRead\n";
	print "Patients loaded to model		: 	$rowProcess\n";
	
};   # end of populateHertgPatData

sub populateDataModel
{
	my $self = shift;

	my $dataModel = $self->dataModel();

	#Obtain Org data	
	print "***ENTERING DBData\n";
	$self->populateDBData();
	$self->populateHertgPatData();		
	#my $dumper = new Dumpvalue;
        #$dumper->dumpValue($dataModel);
	#exit;
	
	#return $self->errors_size == 0 ? 1 : 0;
};

1;









