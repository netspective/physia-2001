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
my $crUserId  = 'IMPORT_PHYSIAT';
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

sub loadOrgData
{
	my $self=shift;
	my $orgData=shift;
	my $flags=0;
	my $command='add';
	my $context = $self->context();	
	
	my $type = ref $orgData;
	my $orgId = $orgData->orgId;
	
	#!!!!!!!FIX THIS !!!!!!
	#Check if org_id is exists
	
	#If no orgId build one
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
			parent_id => $orgData->id,
			item_name => 'Primary',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $orgData->phone,
		) if $orgData->phone ;

	#Create fax Record
	$self->schemaAction(
			$flags,'Org_Attribute', $command,
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
			date_of_birth => $personData->dob,
			ssn => $personData->ssn,
			gender => $personData->gender,
		);	
		
	#Store Person ID
	$personData->id($personId);
	
	#Create Address record
	$self->schemaAction(
			$flags,'Person_Address', $command,			
			parent_id => $personId ,
			address_name => 'Home',
			#Add as Primary
			
			cr_user_id => $crUserId,	
			line1 => $personData->homeAddress->addressLine1,
			line2 => $personData->homeAddress->addressLine2,
			city => $personData->homeAddress->city,
			state => $personData->homeAddress->state,
			zip => $personData->homeAddress->zipCode,
		); 
		
	#Create Phone
	$self->schemaAction(
			$flags,'Person_Attribute', $command,
			cr_user_id => $crUserId,	
			parent_id => $personId,
			item_name => 'Home',
			value_type => App::Universal::ATTRTYPE_PHONE,
			value_text => $personData->homePhone,
		) if $personData->homePhone;	
	$self->schemaAction(
			$flags,'Person_Attribute', $command,
			cr_user_id => $crUserId,	
			parent_id => $personId,
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
				parent_id => $personId,
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
			parent_id => $personId,
			cr_user_id => $crUserId,
			parent_org_id => $mainOrgInternalId,
			item_name => 'Patient/Chart Number',
			value_type => 0,
			value_text => $personData->chartNumber,
		) if defined $personData->chartNumber;				
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

	
	#Load Org data 
	$self->OrgData();	
	
	#Load Person Data
	$self->PersonData();

	return $self->errors_size == 0 ? 1 : 0;	
}


1;

