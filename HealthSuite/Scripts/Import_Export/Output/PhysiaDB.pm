##############################################################################
package Output::PhysiaDB;
##############################################################################

use strict;
use DBI;
use DBI::StatementManager;
use App::Statements::External;
use Driver;
use base qw(Driver::Output::PhysiaDB);
use App::Universal;

my $mainOrgInternalId;
my $crUserId  = 'IMPORT_PHYSIA_T';
my $CHECKDIR=`pwd`;
chomp $CHECKDIR;

sub init
{
	my $self = shift;	
	my $args = $self->cmdLineArgs;	
	$crUserId = $args->{-createid} if ($args->{-createid});
		
}

sub open
{
	my $self=shift;
	my $args = $self->cmdLineArgs;	
	$self->SUPER::open();	
	
	###################################################
	#Save SQL to file if loadFile set
	###################################################
	if ($args->{-loadFile})
	{
		chomp $args->{-loadFile};
		$self->storeSql(); 
		my $sqlFile = File::Spec->catfile($CHECKDIR, $args->{-loadFile});
		$self->reportStatus("Opening $sqlFile \n");
		open (FILEHANDLE,">$sqlFile") || die "Unable to Open $sqlFile\n";	
	};
}

sub close
{
	my $self=shift;
	my $args = $self->cmdLineArgs;		
	$self->SUPER::close();	
	
	###################################################
	#Save SQL to file if loadFile set
	###################################################
	if ($args->{-loadFile})
	{
		print FILEHANDLE $self->getSql();
		close (FILEHANDLE);	
	}
}




sub loadInsuranceData
{
	my $self = shift;	
	my $org = shift;	
	my $prodCount=0;
	my $planCount=0;
	my $flags=0;	

	my $command='add';
	my $numProducts = $org->insuranceProduct_size;
	for(my $loop=0;$loop<=$numProducts;$loop++)
	{
		$prodCount++;
		my $insuranceProduct=$org->insuranceProduct($loop);		
		next unless $insuranceProduct;
		#if loadIndicator is skip then do not load this insurance Product
		if ($insuranceProduct->loadIndicator ne 'S')
		{
			my $insIntId = $self->schemaAction($flags,
				'Insurance',$command,
				cr_user_id => $crUserId,
				product_name => $insuranceProduct->productName,
				record_type => App::Universal::RECORDTYPE_INSURANCEPRODUCT,
				owner_org_id => $mainOrgInternalId, 
				ins_org_id => $org->id,
				ins_type => $insuranceProduct->productType,
			);				
			$insuranceProduct->id($insIntId);
			$self->schemaAction($flags,
				'Insurance_Address', $command,
				cr_user_id => $crUserId,
				parent_id => $insIntId,
				address_name => 'Billing',
				line1 => defined $insuranceProduct->billingAddress ? $insuranceProduct->billingAddress->addressLine1 : undef,
				line2 => defined $insuranceProduct->billingAddress ? $insuranceProduct->billingAddress->addressLine2 : undef,
				city =>  defined $insuranceProduct->billingAddress ?$insuranceProduct->billingAddress->city : undef,
				state => defined $insuranceProduct->billingAddress ? $insuranceProduct->billingAddress->state : undef,
				zip =>  defined $insuranceProduct->billingAddress ? $insuranceProduct->billingAddress->zipCode : undef,
			);

			$self->schemaAction($flags,
				'Insurance_Attribute', $command,
				cr_user_id => $crUserId,
				parent_id => $insIntId,
				item_name => 'Contact Method/Telephone/Primary',
				_debug => 0
			);
		}
		my $numPlans = $insuranceProduct->insurancePlan_size;
		for (my $inner_loop=0;$inner_loop<=$numPlans;$inner_loop++)
		{
			my $insurancePlan = $insuranceProduct->insurancePlan($inner_loop);		
			
			#if loadIndicator is skip then do not load this insurance plan
			next if $insurancePlan ->loadIndicator eq 'S';
			$planCount++;
			my $insIntId=$self->schemaAction($flags,
				'Insurance', $command,
				cr_user_id => $crUserId,
				parent_ins_id => $insuranceProduct->id,
				product_name => $insuranceProduct->productName,
				plan_name => $insurancePlan->planName,
				record_type => App::Universal::RECORDTYPE_INSURANCEPLAN,
				owner_org_id => $mainOrgInternalId, #main Org
				ins_org_id => $org->id, #insurance Org
				ins_type => $insuranceProduct->productType ,
			);	
			$insurancePlan->id($insIntId);
			$self->schemaAction($flags,
				'Insurance_Address', $command,
				cr_user_id => $crUserId,
				parent_id => $insurancePlan->id,
				address_name => 'Billing',
				line1 => defined $insurancePlan->billingAddress ? $insurancePlan->billingAddress->addressLine1 : undef,
				line2 => defined $insurancePlan->billingAddress ?  $insurancePlan->billingAddress->addressLine2 : undef,
				city => defined $insurancePlan->billingAddress ?  $insurancePlan->billingAddress->city : undef,
				state => defined $insurancePlan->billingAddress ?  $insurancePlan->billingAddress->state : undef,
				zip => defined $insurancePlan->billingAddress ?  $insurancePlan->billingAddress->zipCode : undef,
			);	
	
			$self->schemaAction($flags,
					'Insurance_Attribute', $command,
					cr_user_id => $crUserId,
					parent_id =>$insurancePlan->id,
					item_name => 'Contact Method/Telephone/Primary',
					value_type => App::Universal::ATTRTYPE_PHONE,
				);		
			$self->schemaAction($flags,
					'Insurance_Attribute', $command,
					cr_user_id => $crUserId,
					parent_id => $insurancePlan->id,
					item_name => 'Contact Method/Fax/Primary',
					value_type =>App::Universal::ATTRTYPE_FAX,
			);		
		};		
	};

	my $counts={planCount=>$planCount,productCount=>$prodCount};
	return $counts;
}

sub InsuranceData
{
	my $self = shift;	
	my $context = $self->context();
	my $collection = $self->dataModel();
	my $parentId=undef;
	my $ownerOrg=undef;
	my $orgCount=0;
	my $productCount=0;
	my $planCount=0;	
	my $totalProductCount=0;
	my $totalPlanCount=0;	

	
	#Get the information for the main org (this assumes there is only one main org)
	my $orgData = $collection->getFirstOrgOfType('InsuranceOrg');	
	while ($orgData)
	{
	
		#Load Main Org
		my $insName= $orgData->orgId;
		$mainOrgInternalId = $orgData->ownerOrg->id;
		$self->reportStatus("Loaing Insurance Data For $insName.......");	

		$orgCount++;		
		#Load All Insurance Product and Plan for this Org
		my $counts=$self->loadInsuranceData($orgData);
		$productCount=$counts->{'productCount'};
		$planCount=$counts->{'planCount'};				
		$totalProductCount += $productCount;
		$totalPlanCount +=$planCount;
		
		#Get Next Main Org
		$orgData = $collection->getNextOrgOfType('InsuranceOrg');
	}		
		$self->reportStatus("Finished Loading Insurance Product/Plan ......\n");	
		$self->reportStatus("Insurance Products Loaded			: $totalProductCount");   
		$self->reportStatus("Insurance Plans  	Loaded			: $totalPlanCount");	
		$self->reportStatus("-----------------------------------------\n");			
}




sub loadOrgData
{
	my $self=shift;
	my $orgData=shift;
	my $flags=0;
	my $command='add';
	my $context = $self->context();	
	
	my $type = ref $orgData;
	my $orgId = $orgData->orgId;
	
	#If org should be skip the return
	return if $orgData->loadIndicator eq 'S';
	#!!!!!!!FIX THIS !!!!!!
	#Check if org_id is exists	
	
	unless ($orgId)
	{
		my $name = uc(substr($orgData->orgName,0,15));
		$name=~s/\W//g;
		$orgId=$name;
	}

	#Create Core Attributes
	my $mainOrg = $type eq 'App::DataModel::MainOrg' ? 1 : 0;
	my $parentOrg = $mainOrg ? undef :$orgData->parentOrg->id;
	my $ownerOrg = $mainOrg ? undef : $orgData->parentOrg->id;	
	unless($orgData->orgType)
	{
		if($type eq 'App::DataModel::InsuranceOrg')
		{
			$orgData->orgType('Insurance');
		};
	};
	
	my $orgIntId = $self->schemaAction(
			$flags,'Org', $command,
			cr_user_id => $crUserId,
			org_id => $orgId,
			name_primary =>$orgData->orgName,
			name_trade => $orgData->orgBusinessName,
			time_zone =>$orgData->timeZone,
			category=>$orgData->orgType,
			parent_org_id =>$parentOrg||undef,
			owner_org_id => $ownerOrg||undef,				
			);	
			
	#Store Internal ID and OrgID 			
	$orgData->id($orgIntId);	
	$orgData->orgId($orgId);

	#Update owner_org_id but only for main orgs
	$self->schemaAction(
				$flags,'Org', 'update',
				org_internal_id=>$orgIntId,
				owner_org_id=>$orgIntId					
				) if ($mainOrg);

	
	#Create Address record
	$self->schemaAction(
			$flags,'Org_Address', $command,
			parent_id => $orgData->id,
			address_name => 'Mailing',
			cr_user_id => $crUserId,
			line1 => $orgData->mailingAddress->addressLine1,
			line2 => $orgData->mailingAddress->addressLine2,
			city => $orgData->mailingAddress->city,
			state => $orgData->mailingAddress->state,
			zip => $orgData->mailingAddress->zipCode,
		); 	

	
	#Create Phone Record
	$self->schemaAction(
			$flags,'Org_Attribute', $command,
			cr_user_id => $crUserId,
			parent_id => $orgData->id,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $orgData->phone,
		) if $orgData->phone ;

	#Create fax Record
	$self->schemaAction(
			$flags,'Org_Attribute', $command,
			cr_user_id => $crUserId,
			parent_id => $orgData->id,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_FAX,
			value_text => $orgData->fax,
		) if $orgData->fax ;	
}
sub OrgData
{
	my $self = shift;	
	my $context = $self->context();
	my $collection = $self->dataModel();
	my $parentId=undef;
	my $ownerOrg=undef;
	my $mainCount=0;
	my $childCount=0;
	my $totalCount=0;

	
	#Get the information for the main org (this assumes there is only one main org)
	my $orgData = $collection->getFirstOrgOfType('MainOrg');	
	while ($orgData)
	{
	
		#Load Main Org
		$self->reportStatus("Loading Main Org Data.......");	
		$self->loadOrgData($orgData);
		$mainCount++;
		
		#Get the data for the childern of the Main Org
		my @childrenOrgs=$orgData->childrenOrgs();
		if(@childrenOrgs)
		{
			#load children Org Data
			$self->reportStatus("Loading Children Data.......");				
			foreach (@childrenOrgs)
			{
				$self->loadOrgData($_);
				$childCount++
			}	
		}
		$totalCount = $childCount+$mainCount;
		
		#Get Next Main Org
		$orgData = $collection->getNextOrgOfType('MainOrg');
	}		
		$self->reportStatus("Finished Loading Org Data.......\n");	
		$self->reportStatus("Main Org Loaded				: $mainCount");   
		$self->reportStatus("Childern Orgs Loaded			: $childCount");	
		$self->reportStatus("-----------------------------------------");		
		$self->reportStatus("Total Loaded				: $totalCount");		
		$self->reportStatus("-----------------------------------------\n");			
}

sub loadPersonData
{
	my $self=shift;
	my $personData=shift;
	my $context = $self->context();
	my $collection = $self->dataModel();	
	my $flags=0;
	my $command='add';


	#Get Person Id		
	my $fName =$personData->nameFirst;
	my $mName = $personData->nameMiddle;
	my $lName = $personData->nameLast;	
	

	#If person should not be loaded then return
	return 1 if ($personData->loadIndicator eq 'S');

	#Get person ID
	my $personId = $STMTMGR_EXTERNAL->getSingleValue($context,STMTMGRFLAG_DYNAMICSQL,"select create_unique_person_id(:1,:2,:3) from dual",$fName,$mName,$lName);
	my $type = ref $personData;
	
	#create Core Person Record
	$self->schemaAction(
			$flags,'Person', $command,
			cr_user_id=>$crUserId,
			person_id => $personId ,
			name_first => $personData->nameFirst,
			name_middle => $personData->nameMiddle,
			name_last => $personData->nameLast,
			name_suffix =>$personData->nameSuffix,
			date_of_birth => $personData->dob,
			ssn => $personData->ssn,
			gender => $personData->gender,
		);	
		
	#Store Person ID
	$personData->id($personId);
	
	#Create Address record
	$self->schemaAction(
			$flags,'Person_Address', $command,			
			parent_id => $personData->id ,
			address_name => 'Home',
			cr_user_id => $crUserId,	
			line1 => $personData->homeAddress->addressLine1,
			line2 => $personData->homeAddress->addressLine2,
			city => $personData->homeAddress->city,
			state => $personData->homeAddress->state,
			zip => $personData->homeAddress->zipCode,
		)if $personData->homeAddress; 
		
	#Create Phone
	$self->schemaAction(
			$flags,'Person_Attribute', $command,
			cr_user_id => $crUserId,	
			parent_id => $personData->id,
			item_name => 'Home',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $personData->homePhone,
		) if $personData->homePhone;	
	$self->schemaAction(
			$flags,'Person_Attribute', $command,
			cr_user_id => $crUserId,	
			parent_id => $personData->id,
			item_name => 'Work',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $personData->workPhone,
		) if $personData->workPhone;	
				
	#Only for Patients
	if($type eq 'App::DataModel::Patient')
	{
	
		
		#Create Employment Record
		if($personData->employment)
		{
			my $orgData;
			$orgData = $personData->employment->org if  defined $personData->employment->org;
			my $orgInternalId = defined $orgData ? $orgData->id : undef;
			my $orgId = defined $orgData ? $orgData->orgId : undef;		
			my $status = $personData->employment->employmentStatus;
			$self->schemaAction(
				$flags,'Person_Attribute', 'add',
				parent_id => $personData->id,
				cr_user_id => $crUserId,				
				value_type => $status,
				value_int => $orgInternalId,
				value_text =>$orgId,
				value_textB => $personData->workPhone,
			) if (defined $orgInternalId || defined $orgId || defined $personData->workPhone);
		}
		
		#Create Chart Number Record
		$self->schemaAction(
			$flags,'Person_Attribute', $command,
			parent_id => $personData->id,
			cr_user_id => $crUserId,
			parent_org_id => $mainOrgInternalId,
			item_name => 'Patient/Chart Number',
			value_type => 0,
			value_text => $personData->chartNumber,
		) if defined $personData->chartNumber;	

		my $careProv = $personData->careProvider(0);
		$self->schemaAction($flags,
			'Person_Attribute',	$command,
			parent_id => $personData->id,
			value_type => App::Universal::ATTRTYPE_PROVIDER,
			value_text =>$careProv->id,
			value_int => 1,
			_debug => 0
		) if $careProv;

		my $size = $personData->insurance_size;				
		for (my $loop=0;$loop<=$size;$loop++)
		{
		
			
			#Coverage Record
			my $coverage = $personData->insurance($loop);			
			my $insuranceProduct = $coverage->insuranceProduct;
			my $insurancePlan = $coverage->insurancePlan;
			my $insOrg = $insuranceProduct->insOrg;

			my $id =  $insuranceProduct->id;
			#Create Insurance Coverage Record				
			my $insIntId = $self->schemaAction($flags,
				'Insurance', $command,
				cr_user_id => $crUserId,
				parent_ins_id			=> $insurancePlan ? $insurancePlan->id : $insuranceProduct->id,
				product_name			=> $insuranceProduct->productName,
				plan_name			=> $insurancePlan ? $insurancePlan->planName : undef,
				record_type			=> App::Universal::RECORDTYPE_PERSONALCOVERAGE,
				owner_person_id			=> $personData->id,
				ins_org_id			=> $insOrg->id,
				owner_org_id			=> $mainOrgInternalId,
				bill_sequence			=> $coverage->sequence,
				
				##
				##Change This Line Here
				ins_type			=> 2,#$insuranceProduct->productType,
				
				group_name			=> $coverage->groupName,
				group_number			=> $coverage->groupNumber,
				member_number			=> $coverage->memberNumber,
				rel_to_insured => App::Universal::INSURED_SELF, 
				coverage_begin_date		=> $coverage->coverageDate ? $coverage->coverageDate->beginDate : undef,
				coverage_end_date		=> $coverage->coverageDate ? $coverage->coverageDate->endDate : undef,				
				insured_id => $personData->id
				);	
			$coverage->id(	$insIntId);
		}
	}
	
}


sub loadPersonOrgCategory
{

	my $self=shift;
	my $personData=shift;
	my $org_internal_id=shift;
	my $context = $self->context();
	my $collection = $self->dataModel();	
	my $flags=0;
	my $command='add';
	#
	my $catType;	
	#Get Category Type Values
	if(ref $personData eq 'App::DataModel::Patient')
	{
		$catType="Patient";
	}
	elsif (ref $personData eq 'App::DataModel::Physician')
	{
		$catType="Physician";	
	}
	elsif (ref $personData eq 'App::DataModel::ReferringDoctor')
	{
		$catType='Referring-Doctor';
	}
	
	#person Catgeory
	my $id = $personData->id;
	return if $personData->loadIndicator eq 'S';
	$self->schemaAction(
				$flags, 'Person_Org_Category', $command,
				cr_user_id=>$crUserId,
				person_id => $personData->id ,
				org_internal_id => $mainOrgInternalId,
				category =>$catType,
				_debug => 0
				);	
}
sub PersonData
{
	my $self = shift;	
	my $context = $self->context();
	my $collection = $self->dataModel();
	my $patCount =0;
	my $docCount =0;	
	my $refDocCount =0;	
	my $catCount=0;
	my $totalCount=0;	
	#Get the information 
	my $personData = $collection->getFirstPersonOfType('Physician');	
	
	#Load Doc Data 	
	$self->reportStatus("Loading Physician Data.......");
	while($personData)
	{
		$self->loadPersonData($personData);
		$personData=$collection->getNextPersonOfType('Physician');	
		$docCount++;
	};

	
	#Get the information 
	$personData = $collection->getFirstPersonOfType('ReferringDoctor');	
	
	#Load Ref-Doc Data 
	$self->reportStatus("Loading Referring-Doctor Data.......");
	while($personData)
	{
		$self->loadPersonData($personData);
		$personData=$collection->getNextPersonOfType('ReferringDoctor');	
		$refDocCount++;
	}


	#Get the information 
	$personData = $collection->getFirstPersonOfType('Patient');	
	
	#Load patient Data 
	$self->reportStatus("Loading Patient Data.......");	
	while($personData)
	{
		$self->loadPersonData($personData);		
		$personData=$collection->getNextPersonOfType('Patient');	
		$patCount++;
	}	
	
	
	#Create the Person Org Category Records for all people loaded	
	my $orgData = $collection->getFirstOrgOfType('MainOrg');	
	while ($orgData)
	{
		$mainOrgInternalId=$orgData->id;	
		my @personnel= $orgData->personnel;
		if(@personnel)
		{
			$self->reportStatus("Loading Person Category Data.......");	
			foreach (@personnel)
			{
				$self->loadPersonOrgCategory($_);
				$catCount++;
			} 
		};	
		$orgData = $collection->getNextOrgOfType('MainOrg');		
	}
	
	$totalCount = $docCount+$patCount+$refDocCount;
	$self->reportStatus("Finished Loading Person Data.......\n");	
	$self->reportStatus("Physicians Loaded			: $docCount");   
	$self->reportStatus("Reffering-Doctors Loaded		: $refDocCount");	
	$self->reportStatus("Patients Loaded				: $patCount");	
	$self->reportStatus("-----------------------------------------");		
	$self->reportStatus("Total Loaded				: $totalCount");		
	$self->reportStatus("-----------------------------------------");			
	$self->reportStatus("Categories Created			: $catCount");			
}


sub transformDataModel
{
	my $self = shift;	

	#Turn Off auto-commit
	
	#Load Org data 
	$self->OrgData();	
	
	#Load Insurance Data
	$self->InsuranceData();
	
	#Load Person Data
	$self->PersonData();
	
	#if not errors commit-code

	return $self->errors_size == 0 ? 1 : 0;	
}


1;

