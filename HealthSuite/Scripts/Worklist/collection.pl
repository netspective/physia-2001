#!/usr/bin/perl -w

use strict;
use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;
use DBI::StatementManager;
use App::Statements::BillingStatement;
use App::Page::Worklist::Collection;
use vars qw($page $sqlPlusKey);
use App::Statements::Worklist::WorklistCollection;
use Getopt::Declare;
use Date::Manip;
use Date::Calc qw(:all);

#FLAGS to define message type ,method, and destination
use enum qw(BITMASK:MESSAGE_ CONTACT_DBA CONTACT_SOFTWARE TYPE_WARNING TYPE_ERROR TYPE_INFORMATION EMAIL PAGER);

#Contact Groups
#Could store these value in file or database for easier update
#my @DBA = ('alex_hillman@physia.com');
#my @SOFTWARE =('robert_jenks@physia.com','thai_nuygen@phyisa.com','shahid_shah@phyisa.com','frank_major@physia.com');
my $DBA = q{alex_hillman@physia.com};
my $SOFTWARE =q{frank_major@hotmail.com};
my $CHECKDIR = `pwd`;


chomp $CHECKDIR;
&main();

sub main
{

	my $args = new Getopt::Declare(q{
	[strict]
	-org <id:s>			Internal Org ID to update worklist.  If blank update all orgs. -- Not implmented

	-person_id <id:s>		Person_Id to update worklist.  If blank update all person worklist -- Not implmented							

	-verbose			Turn on verbose messages

	-debug 				Turn on debugging messages 
	});
	
	print "Process Org with Internal ID : $args->{'-org'} \n" if $args->{'-org'};
	print "Process Worklist For Person ID : $args->{'-person_id'}\n " if  $args->{'-person_id'};	
	print "Verbose Mode  \n" if ($args->{'-verbose'});
	print "Debug Mode   \n" if ($args->{'-debug'});
	
	#conenct to database
	connectDB();
	
	#Update the collcetion worklist
	updateCollectionWorklist($args,MESSAGE_CONTACT_SOFTWARE);
}



# Subroutines
#update collector worklist with new records and new information for old records
sub updateCollectionWorklist
{
	my ($args,$flags) = @_;
	
	#Get all person_id to update 
	#UnixDate('today','%m/%d/%Y');
	my $time =  UnixDate('today','%H:%M:%S');
	
	#Print Times for debug and verbose mode
	print "START Time for Collector List : $time \n" if($args->{'-verbose'} || $args->{'-debug'} );
	my $data = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page, STMTMGRFLAG_NONE,'selAllCollectors');
	$time =  UnixDate('today','%H:%M:%S');
	print "START  Time for Update Collection Worklist : $time \n" if($args->{'-verbose'} || $args->{'-debug'} );	
	
	#loop through personid
	foreach (@$data)
	{
		print "Processing Person_ID [$_->{parent_id}] for Org [$_->{parent_org_id}]\n" if($args->{'-verbose'} || $args->{'-debug'} ) ;
		App::Page::Worklist::Collection::refreshInvoiceWorkList($page,$_->{parent_id},$_->{parent_org_id});
	}
	$time =  UnixDate('today','%H:%M:%S');
	print "END Time for Update Collection Worklist : $time \n" if($args->{'-verbose'} || $args->{'-debug'} );	

}

sub reportError
{
	my ($message,$flags) = @_;

	my $fromuser = getpwuid($>) || 'Collection Worklist';
	my $contact = '';
	$contact .= $SOFTWARE if $flags & MESSAGE_CONTACT_SOFTWARE;
	$contact .= $contact ? ",$DBA" : $DBA  if $flags & MESSAGE_CONTACT_DBA;
	print "$message\n";
	unless ($ENV{HS_NOERROREMAIL})
	{
		open SENDMAIL, '|/usr/sbin/sendmail -t';
		print SENDMAIL "to: $contact\n";
		print SENDMAIL "from: $fromuser\n";
		print SENDMAIL "subject: Collection Worklist Update Error\n";
		print SENDMAIL "content-type: text/plain\n";
		print SENDMAIL "\n";
		print SENDMAIL "Error updating Collection Worklist";
		close SENDMAIL;
	}	
}

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
