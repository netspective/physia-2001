#!/usr/bin/perl -w

use strict;
use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;
use DBI::StatementManager;
use App::Statements::BillingStatement;
use vars qw($page $sqlPlusKey);
use Term::ReadLine;
use Getopt::Declare;


my $fileName;
my @childList;
my @parentList;
my @parentAssnList;
my @childAssnList;
my $count=0;
my $CHECKDIR = `pwd`;
chomp $CHECKDIR;

&main ();
sub main
{

	my $args = new Getopt::Declare(q{
	[strict]

	-file <id:s>			Name of file to process		
	});

	#conenct to database
	connectDB();
	if ($args->{'-file'})
	{
		print "Reading Association from file $args->{-file} \n" if ($args->{'-file'});
		$fileName=$args->{'-file'};
		getFileAssn();		
	}
	else
	{
		getAssn();
	}
	verfiyAssn();
	createAssn();
}





#################################################
#
# You are now connected to the database and have
# access to a minimal $page object.
#
######## BEGIN SQL #########

#Get Assoication information



######## END SQL #########

sub getFileAssn()
{
	#read data from file
	#File format
	#Parent Org ID \t Parent Association \t Child Org ID \t Child association
	my $File = File::Spec->catfile($CHECKDIR, $fileName);
	open (FILEHANDLE,"<$File") or die "Unable to open file $File\n";
	print" Opening $File \n";
	while(<FILEHANDLE>)
	{	
		#skip line if it is a comment line
		next if $_=~m/^\#/;
		#split the record on tabs
		my @data = split "\t",$_;
		push(@parentList,$data[0]);
		push(@parentAssnList,$data[1]);
		push(@childList,$data[2]);			
		push(@childAssnList,$data[3]);
		$count++;
	}		
}

sub getAssn()
{
	
	my $sqlStmt=qq{Select '['||id||'] '||caption ||',' from org_association_type };
	my $value = $STMTMGR_STATEMENTS->getRowsAsArray($page, STMTMGRFLAG_DYNAMICSQL,$sqlStmt);	
	my $options='';
	my $childId;
	my $parentAssn;
	my $childAssn;
	my $parentId;	;
	foreach (@$value)
	{
	   $options.=$_->[0] . " " ;	
	}
	print "Enter Parent ORG ID\n"; 
	$parentId =<>;
	push(@parentList,$parentId);
	print "Enter Parent Association\n$options\n";		
	$parentAssn =<>;
	push(@parentAssnList,$parentAssn);
	print "Enter Child ORG ID\n";
	$childId =<>;	
	push(@childList,$childId);			
	print "Enter Child Association\n$options\n";				
	$childAssn =<>;	
	push(@childAssnList,$childAssn);
	$count++;
};


sub createAssn()
{
	#Get result
	my $loop;
	for ($loop=0;$loop<$count;$loop++)
	{
		my $childId=$childList[$loop];
		my $parentAssn=$parentAssnList[$loop];
		my $childAssn=$childAssnList[$loop];
		my $parentId=$parentList[$loop];		
		my $insertParent = qq
			{
				INSERT INTO ORG_ASSOCIATION
				(cr_user_id,org_assn_status,org_assn_type,org_assn_sequence,assn_org_internal_id,org_internal_id)
				SELECT 'IMPORT_PHYSIA',0,$parentAssn,1,$parentId,$childId FROM dual
				WHERE NOT EXISTS
				(SELECT 1
				FROM ORG_ASSOCIATION
				WHERE  org_assn_status=0
				AND	org_assn_type=110
				AND assn_org_internal_id=$parentId
				AND org_internal_id=$childId
				)		
			};
		my $insertParentSelf = qq
			{
				INSERT INTO ORG_ASSOCIATION
				(cr_user_id,org_assn_status,org_assn_type,org_assn_sequence,assn_org_internal_id,org_internal_id)
				SELECT 'IMPORT_PHYSIA',0,1,1,$parentId,$parentId FROM DUAL
				WHERE NOT EXISTS
				(SELECT 1
				FROM ORG_ASSOCIATION
				WHERE  org_assn_status=0
				AND	org_assn_type=1
				AND assn_org_internal_id=$parentId
				AND org_internal_id=$parentId
				)		
			};	
		my $insertChild = qq
			{
				INSERT INTO ORG_ASSOCIATION
				(cr_user_id,org_assn_status,org_assn_type,org_assn_sequence,assn_org_internal_id,org_internal_id)
				SELECT 'IMPORT_PHYSIA',0,$childAssn,1,$childId,$parentId FROM DUAL
				WHERE NOT EXISTS
				(SELECT 1
				FROM ORG_ASSOCIATION
				WHERE  org_assn_status=0
				AND	org_assn_type=100
				AND assn_org_internal_id=$childId
				AND org_internal_id=$parentId
				)
			};	
		my $insertChildSelf = qq
			{
				INSERT INTO ORG_ASSOCIATION
				(cr_user_id,org_assn_status,org_assn_type,org_assn_sequence,assn_org_internal_id,org_internal_id)
				SELECT 'IMPORT_PHYSIA',0,1,1,$childId,$childId FROM DUAL
				WHERE NOT EXISTS
				(SELECT 1
				FROM ORG_ASSOCIATION
				WHERE  org_assn_status=0
				AND	org_assn_type=1
				AND assn_org_internal_id=$childId
				AND org_internal_id=$childId
				)		
			};	
		my @value =$STMTMGR_STATEMENTS->execute($page, STMTMGRFLAG_DYNAMICSQL,$insertParent);	
		print "Parent/Child Insert Result $value[1]\n";
		@value =$STMTMGR_STATEMENTS->execute($page, STMTMGRFLAG_DYNAMICSQL,$insertParentSelf);	
		print "Parent/Parent Insert Result $value[1]\n";	
		@value =$STMTMGR_STATEMENTS->execute($page, STMTMGRFLAG_DYNAMICSQL,$insertChild);	
		print "Child/Parent Insert Result $value[1]\n";	
		@value =$STMTMGR_STATEMENTS->execute($page, STMTMGRFLAG_DYNAMICSQL,$insertChildSelf);		
		print "Child/Child Insert Result $value[1]\n";			
	}
		

};


sub verfiyAssn()
{
	#Get result
	#Get result
	my $loop;
	for ($loop=0;$loop<$count;$loop++)
	{
		my $childId=$childList[$loop];
		my $parentAssn=$parentAssnList[$loop];
		my $childAssn=$childAssnList[$loop];
		my $parentId=$parentList[$loop];	
	
		my $sqlStmt = qq
		{
			SELECT  (SELECT caption FROM org_association_type where id = $parentAssn) as assn_type,org_internal_id assn,org_id FROM org where org_internal_id = $parentId
			union
			SELECT  (SELECT caption FROM org_association_type where id = $childAssn) as assn_type,org_internal_id assn ,org_id FROM org where org_internal_id = $childId	
		};
		my $value =$STMTMGR_STATEMENTS->getRowsAsArray($page, STMTMGRFLAG_DYNAMICSQL,$sqlStmt);	
		print "\n---------------------------------------------------------------------------------------------\n";
		foreach my $data (@$value)
		{		
			print "Org ID : $data->[2] \tOrg Internal ID : $data->[1] \tAssociation Type : $data->[0] \n";
		}
		print "\n---------------------------------------------------------------------------------------------\n";	
	}
	print "Correct [Y/[N]]\n";
	my $ans=uc(<>);
	chomp $ans;	
	if(uc($ans) ne 'Y')
	{
		print "User Exit\n";
		exit;
	}
};

# Subroutines
sub connectDB
{
	$page = new App::Data::MDL::Module();
	$page->{schema} = undef;
	$page->{schemaFlags} = SCHEMAAPIFLAG_LOGSQL | SCHEMAAPIFLAG_EXECSQL;
	if($CONFDATA_SERVER->db_ConnectKey() && $CONFDATA_SERVER->file_SchemaDefn())
	{
		my $schemaFile = $CONFDATA_SERVER->file_SchemaDefn();
		print STDOUT "Loading schema from $schemaFile\n";
		$page->{schema} = new Schema::API(xmlFile => $schemaFile);

		my $connectKey = $CONFDATA_SERVER->db_ConnectKey();
		print STDOUT "Connecting to $connectKey\n";

		$page->{schema}->connectDB($connectKey);
		$page->{db} = $page->{schema}->{dbh};
		
		$sqlPlusKey = $connectKey;
		$sqlPlusKey =~ s/dbi:Oracle://;
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
}
