##############################################################################
# Define the most common data objects
##############################################################################

use strict;
use App::DataModel::Utilities;
use Class::Generate qw(class subclass);

class 'App::DataModel::Base' =>
{
	id =>{type=>'$',post=>q{$id = uc($id);}},
	sourceId=> '$',
	loadIndicator=>'$', #S = skip, D = delete , I = Insert , U = update 
	'&equalSourceId'=>q{return 0 unless  ($_[0] && $sourceId);  ($_[0] eq $sourceId) ? return 1 : return 0;},
};

subclass 'App::DataModel::Collection' =>
{
	people => 'App::DataModel::People',
	orgs => 'App::DataModel::Organizations',
	

	##################################################
	#Get Orgs and People by SourceID(should be unique)
	##################################################		
	'&findOrgBySourceID'=>q{
				&orgs->findBySourceID($_[0]);
	             	       },	             	      
	             	       
	'&findPersonBySourceID'=>q{&people->findBySourceID($_[0]);},

	
	##################################################
	#Get Orgs objects in collection
	##################################################	
	'&getFirstOrg'=>q{return &orgs->getFirst();},
	'&getNextOrg'=>q{return &orgs->getNext();},
	'&getFirstOrgOfType'=>q{return &orgs->getFirstOfType($_[0]);},			
	'&getNextOrgOfType'=>q{ return &orgs->getNextOfType($_[0]);},				

	
	##################################################
	#Get Person objects in collection
	##################################################	
	'&getFirstPersonOfType'=>q{return &people->getFirstOfType($_[0]);},			
	'&getNextPersonOfType'=>q{ return &people->getNextOfType($_[0]);},				
	
	
	
	##################################################
	#NOTE : Need to a new command to create people and org
	##################################################	
}, -parent => 'App::DataModel::Base';


##################################################
#Container for Orgs, People, Insurance, Etc
##################################################	
subclass 'App::DataModel::Entities'=>
{
	position=>'$',
	all=>'@App::DataModel::Base',	
	'&findBySourceID'=>q{	  	
				foreach  my $entity (&all)
				{
					return $entity if $entity->equalSourceId($_[0]);
				}
				return undef;
			   },
			   
	'&getNext'=>q	{	$position=-1 unless defined $position; 
				$position++;
				$position<=&all_size ? return $all[$position] : return undef;							
			},	
			
	'&getFirst'=>q{	$position=0; 
				$position<=&all_size ? return $all[$position] : return undef;
			},
			
	'&getFirstOfType'=>q{	
				$position=0;
				my $type = $_[0];		 			 
 				my $size = &all_size;
				while ($position<=$size)
				{
					my $objName = ref $all[$position];
					return $all[$position] if ($objName eq "App::DataModel::$type");
					$position++;
				}
				return undef
			       },	
			       
	'&getNextOfType'=>q{    $position=-1 unless defined $position; 
 				my $type = $_[0];		
 				my $size = &all_size;
				$position++; 				
				while ($position<=$size)
				{
					my $objName = ref $all[$position];
					return $all[$position] if ($objName eq "App::DataModel::$type");
					$position++;
				}
				return undef; 
			       },			       
			
}, -parent => 'App::DataModel::Base';	
	

subclass 'App::DataModel::People' =>
{

	##################################################
	#Add personnel
	##################################################	
	'&add_personnel' =>q{
				my $person=$_[0];
				my $org =$_[1];
				&add_all($person);	
				$org->add_personnel($person) if $org;					
			    },
}, -parent => 'App::DataModel::Entities';


subclass 'App::DataModel::Organizations' =>
{			
	##################################################
	#Add child org and links for parent and owner orgs
	##################################################	
	'&addChildOrg'=>q{
				my $org=$_[0];
				my $parentOrg =$_[1];
				my $ownerOrg=$_[2];				
				#Setup links to parentOrg and OwnerOrg
				#ParentOrg needs to be a main org
				$parentOrg->add_childrenOrgs($org) if $parentOrg;
				$org->parentOrg($parentOrg) if $parentOrg;
				$org->ownerOrg($ownerOrg) if $ownerOrg;
				&add_all($org) if $org;
			 },
	'&addInsuranceProduct'=>q{
				my $org=$_[0];
				my $insProd=$_[1];
				$org->add_insuranceProduct($insProd);
				$insProd->insOrg($org);
			},
}, -parent => 'App::DataModel::Entities';



#############################################################################
#People : Patient, Physician (Ref Doc), Nurse, Staff Member,Guarantor
#Insured
#############################################################################
subclass 'App::DataModel::Person' =>
{
	nameFirst => '$',
	nameLast => '$',
	nameMiddle => '$',
	nameSuffix=>'$',	
	dob => '$',
	ssn => '$',
	gender => '$',
	maritalStatus => '$',
	ethnicity=>'@',
	language=>'@',
	bloodType=>'$',
	homePhone=>'$',
	workPhone=>'$',
	cellPhone=>'$',
	alternatePhone=>'$', 
	pager=>'$',
	email=>'$',
	homeAddress=>'App::DataModel::Address',	
}, -parent => 'App::DataModel::Base';

#Guarantor
subclass 'App::DataModel::Guarantor' =>
{
	relationship=>'$',
	relationshipName=>'$',	
}, -parent => 'App::DataModel::Person';


#Insured
subclass 'App::DataModel::Insured' =>
{
	relationship=>'$',
	relationshipName=>'$',
	insuredPersonEmployer=>'$',
}, -parent => 'App::DataModel::Person';


#Patient
subclass 'App::DataModel::Patient' =>
{
	accountNumber=>'$',
	chartNumber=>'$', 	
	driverLicenseNumber=>'$',
	driverLicenseState=>'$',
	miscNotes=>'$',	
	patientDeceased=>'$',
	deceasedDate=>'$',	
	employment=>'App::DataModel::Employment',	
	guarantor => 'App::DataModel::Guarantor',
	careProvider=>'@App::DataModel::Physician',
	careProviderSpecialty =>'$',
	insurance=>'@App::DataModel::InsuranceCoverage',
	'&link_insuranceCoverage' =>q{
				my $coverage=$_[0];
				my $plan=$_[1];
				my $product=$_[2];	
				if($coverage)
				{
					&add_insurance($coverage);
					my $ptr=&last_insurance;
					$ptr->insuranceProduct($product) if ($product);
					$ptr->insurancePlan($plan) if($plan);										
					if($plan)
					{
						$plan->add_insuranceCoverage($coverage);
					};
					if($product)
					{
						$product->add_insuranceCoverage($coverage);
					};
				};				
			     },	
	
}, -parent => 'App::DataModel::Person';

#Referring Doc
subclass 'App::DataModel::ReferringDoctor' =>
{
	
}, -parent => 'App::DataModel::Person';

#Associate
subclass 'App::DataModel::Associate' =>
{
	personType=>'@',
	jobTitle=>'$',
	jobCode=>'$',	
}, -parent => 'App::DataModel::Person';

#Physician
subclass 'App::DataModel::Physician' =>
{
	billIdType=>'$', 	#Perse, Envoy,etc
	billId=>'$',	 	#Doc ID for Perse,Envoy,etc
	billEffectiveDate=>'$',
	processLiveClaims=>'$',
	specialtyName=>'@',
	specialtySequence=>'@',
	affiliation=>'@App::DataModel::Certification',
	license=>'@App::DataModel::Certification',
	providerLicense=>'@App::DataModel::Certification',	
	boardCertification=>'@App::DataModel::Certification',
	stateLicense=>'App::DataModel::Certification',
}, -parent => 'App::DataModel::Associate';


#Nurse
subclass 'App::DataModel::Nurse' =>
{
	nursingLicense =>'App::DataModel::Certification',
	licenseCertification =>'@App::DataModel::Certification',
	associatedPhysician =>'@App::DataModel::Physician',		
}, -parent => 'App::DataModel::Associate';

#Staff Member
subclass 'App::DataModel::StaffMember' =>
{
	jobTitle=>'$',
	jobCode=>'$',
	employment=>'App::DataModel::Employment',	
	certification=>'@App::DataModel::Certification'
}, -parent => 'App::DataModel::Associate';


#############################################################################
#ORGS : Main Org, Departments, Associated Providers, Employers, Insurance Org,
#IPA, 
#############################################################################

#Org
subclass 'App::DataModel::Organization' =>
{
	orgId=>{type=>'$',post=>q{$orgId= uc($orgId);}},
	orgName=>'$',
	orgBusinessName=>'$',
	fiscalYear=>'$',
	hoursOperation=>'$',
	timeZone=>'$',
	phone=>'$',
	fax=>'$',
	mailingAddress=>'App::DataModel::Address',
	email=>'$',
	webSite=>'$',
	billingContact=>'$',
	billingPhone=>'$',
	parentOrg=>'App::DataModel::Organization',
	ownerOrg=>'App::DataModel::Organization',
	orgType=>'$',
	#assoicatedOrg=>'%',
}, -parent => 'App::DataModel::Base';


#MainOrg
subclass 'App::DataModel::MainOrg' =>
{
	ids=>'App::DataModel::IDNumbers',	
	childrenOrgs=>'@App::DataModel::Organization',
	personnel=>'@App::DataModel::Person',	
}, -parent => 'App::DataModel::Organization';


#DepartMent
subclass 'App::DataModel::Department' =>
{
	serviceInfo=>'App::DataModel::ServiceInformation',
}, -parent => 'App::DataModel::Organization';

#AssociatedProvider
subclass 'App::DataModel::AssociatedProvider' =>
{
	ids=>'App::DataModel::IDNumbers',
   	serviceInformation=>'App::DataModel::ServiceInformation',
}, -parent => 'App::DataModel::Organization';

#Employer
subclass 'App::DataModel::Employer' =>
{   	
}, -parent => 'App::DataModel::Organization';

#InsuranceOrg
subclass 'App::DataModel::InsuranceOrg' =>
{
	insuranceProduct=>'@App::DataModel::InsuranceProduct',
	'&findInsProductBySourceID'=>q{	  	
					foreach  my $entity (&insuranceProduct)
					{
						return $entity if $entity->equalSourceId($_[0]);
					}
					return undef;
			   	      },		
}, -parent => 'App::DataModel::Organization';

#IPA
subclass 'App::DataModel::IPA' =>
{	
}, -parent => 'App::DataModel::Organization';


#############################################################################
#Insurance : Insurance product,plans,coverage
#############################################################################

#Insurance Product
subclass 'App::DataModel::InsuranceProduct' =>
{
	productName=>'$',
	productType=>'$',
	FeeScheduleID=>'$',
	billingAddress=>'App::DataModel::Address',
	insurancePlan=>'@App::DataModel::InsurancePlan',
	insuranceCoverage=>'@App::DataModel::InsuranceCoverage',	
	insOrg=>'App::DataModel::InsuranceOrg',
   	phone=>'$',
   	fax=>'$',  
	remittance=>'App::DataModel::Remittance',
	'&findInsPlanBySourceID'=>q{	  	
					foreach  my $entity (&insurancePlan)
					{
						return $entity if $entity->equalSourceId($_[0]);
					}
					return undef;
			   	      },			
}, -parent => 'App::DataModel::Base';


#Insurance Plan
subclass 'App::DataModel::InsurancePlan' =>
{
	remittance=>'App::DataModel::Remittance',
   	planName=>'$',
	planDate=>'App::DataModel::Duration',
	insuranceCoverage=>'@App::DataModel::InsuranceCoverage',	
	insuranceProduct=>'App::DataModel::InsuranceProduct',
	officeCoPay=>'$',
	deductible=>'App::DataModel::Deductible',	
	billingAddress=>'App::DataModel::Address',
}, -parent => 'App::DataModel::Base';


#Insurance Coverage
subclass 'App::DataModel::InsuranceCoverage' =>
{
	planDate=>'App::DataModel::Duration',
	insuredPerson=>'App::DataModel::Insured',
	sequence=>'$',
	groupName=>'$',
	groupNumber=>'$',
	memberNumber=>'$',
	injuryDate=>'$',
	coverageDate=>'App::DataModel::Duration',
	deductible=>'App::DataModel::Deductible',
	insuranceProduct=>'App::DataModel::InsuranceProduct',
	insurancePlan=>'App::DataModel::InsurancePlan',	
	officeCoPay=>'$',		
}, -parent => 'App::DataModel::Base';

#############################################################################
#Misc Classes
#############################################################################
subclass 'App::DataModel::Deductible'=>
{
	individual=>'$',
	family=>'$',
	individualRemaining =>'$',
	familyRemaining =>'$',	
},-parent =>'App::DataModel::Base';

subclass 'App::DataModel::Duration'=>
{
	beginDate=>'$',
	endDate=>'$',
}, -parent =>'App::DataModel::Base';

subclass 'App::DataModel::Employment'=>
{
	employmentStatus=>'$',
	occupation=>'$',
	employmentPhoneNumber=>'$',	
	employeeID=>'$',
	employeeExpDate=>'$',	
	org=>'App::DataModel::Employer'
}, -parent =>'App::DataModel::Base';

subclass 'App::DataModel::Address'=>
{
	addressLine1=>'$',
	addressLine2=>'$',
	city=>'$',
	state=>'$',
	zipCode=>'$',		
}, -parent =>'App::DataModel::Base';

subclass 'App::DataModel::Certification'=>
{
	name=>'$',
	number=>'$',
	ExpDate=>'$',
	State=>'$',
	FacilityId=>'$'
}, -parent =>'App::DataModel::Base';


subclass 'App::DataModel::Remittance'=>
{
	remittanceType=>'$',
   	remittancePayerId=>'$',    
   	remitPayerName=>'$', 
}, -parent =>'App::DataModel::Base';

subclass 'App::DataModel::ServiceInformation'=>
{
	HCFAServicePlace=>'$',
	medicareGPCILocation=>'$',
	medicareFacilityPricing=>'$',	
}, -parent=>'App::DataModel::Base';

subclass 'App::DataModel::IDNumbers'=>
{
	taxId=>'$',
	employerId =>'$',       
   	stateId=>'$', 
   	medicaidId =>'$', 	
	workerCompId=>'$', 
	blueCrossBlueShieldId =>'$',       
   	medicareId =>'$',       
   	CLIAId =>'$',	
}, -parent=>'App::DataModel::Base';
1;