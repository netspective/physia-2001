##############################################################################
package Input::Semnet;
##############################################################################

use strict;
use DBI;
use DBI::StatementManager;
use Driver;
use Dumpvalue;
use App::Data::Manipulate;
use App::Universal;

use base qw(Driver::Input::DBI);
use vars qw($STMTMGR);

sub init
{
	my $self = shift;
	$self->dbiConnectKey("dbi:Oracle:SDEDBS04");
	$self->dbiUserName("sde01");
	$self->dbiPassword("sde");
	$self->statements('org_data', 'select * from SEMNET_ORG');
}


sub populateOrgData
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();	
	
	#Pull Org Data 
	my $sth = $self->execute('org_data');
	
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
		my $org = new App::DataModel::MainOrg(	orgId=>$orgId,
							orgName=>$orgName, 
							orgBusinessName=>$orgName,
							phone=>$phone,
							orgType=>'Practice',);							
		
		#Create Address	
		$org->mailingAddress(new App::DataModel::Address(
							addressLine1=>$line1,
							addressLine2=>$line2,
							city=>$city,
							state=>$state,
							zipCode=>$zipCode,));							
		$dataModel->orgs->add_all($org);
	};		
}

sub populateDataModel
{
	my $self = shift;
	my $dbh = $self->dbh();
	my $dataModel = $self->dataModel();

	#Obtain Org data		
	$self->populateOrgData();		
	
	#my $dumper = new Dumpvalue;
        #$dumper->dumpValue($dataModel);
	#exit;
	
	return $self->errors_size == 0 ? 1 : 0;
}

1;
