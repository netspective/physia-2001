#!/usr/bin/perl -I.

use strict;
use Date::Manip;
use Schema::API;
use App::Data::MDL::Module;
use FindBin qw($Bin);
use App::Universal;
use App::Configuration;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::External;
use vars qw($page $sqlPlusKey);
use Getopt::Declare;
use App::Data::Manipulate;

#This will work if record is fixed formatted
#if not will have to use reg exp
my %recordFormat=
(
H061Header =>
	{
		keyword=>[11,4],
		ackMsg=>[17,33],
		date=>[50,19],		
	},
H061TrackingNumber =>
	{
		keyword=>[20,26],
		trackNumber=>[47,20],		
	},
H061PractieData =>
	{
		keyword=>[1,80],				
		data=>[1,80],
	},
H061ColData=>
	{
		patientName=>[2,24],
		accountNumber=>[27,24],		
		charge=>[52,24],	
		keyword =>[2,24],
	},				
);	  

#my @statementId=();
my $trackNumber;
	my $args = new Getopt::Declare(q{
	[strict]

	-statment_id <id:s>		Only update records with statement id

	-verbose			Turn on verbose messages
	
	-file <id:s>			Name of file to process		
	});
	
&main();
sub main
{


	print "Process Statments with Statement ID : $args->{'-statment_id'} "if ($args->{'-statment_id'}); ;
	print "Verbose Mode  \n" if ($args->{'-verbose'});
	#print "Debug Mode   \n" if ($args->{'-debug'});
	unless ($args->{'-file'})
	{
		print "-file parameter is needed "; 
		exit;
	};
	
	my @reports = ();

	#Parse Report
	unless (parseFileH061($args->{'-file'},\@reports))
	{
	  print "Unable to Parse File $args->{'-file'}";
	  exit;
	} 


	#conenct to database
	connectDB();

	#Update Statement Tables
	updateStatement(\@reports);
	

	
}

#################################################################################
#
#SQL command to update Invoice_History ,Invoice and Statement Tables
#################################################################################
 sub updateStatement()
 {
 	my $destArray = shift;
 	print "Loading....\n";
 	foreach (@$destArray)
 	{
 		print "Load Patient ID : $_->{personId} \n Statement : $_->{statementId}\n" if ($args->{'-verbose'});

		my $msg = "Per-Se Acknowledged Receipt of Statement"; 
		
		my @rows;
		
		#Insert History Records into Invoice_History
		@rows = $STMTMGR_EXTERNAL->execute($page, STMTMGRFLAG_CACHE,
		'InsAckHistory',$msg,$_->{trackNumber}, $_->{statementId},$_->{personId});	 	  	
		print "Number Of History Records Created : $rows[1] \n" if ($args->{'-verbose'});
		
		#Change status of each invoice to awaiting bill payment
		@rows  = $STMTMGR_EXTERNAL->execute($page, STMTMGRFLAG_CACHE,
		'updateAckStatus', $_->{statementId},$_->{personId});	 	  	
		print "Number Of Invoice Status Record Updates : $rows[1] \n" if ($args->{'-verbose'});		
		
		
		#Change value in patient Statement
		@rows = $STMTMGR_EXTERNAL->execute($page, STMTMGRFLAG_CACHE,
		'updateAckStatement',  $_->{trackNumber},$_->{statementId},$_->{personId});	 	
		print "Number of Statement records updated : $rows[1] \n" if ($args->{'-verbose'});				
	}
 }
 


#################################################################################
#
#Parse H061 data from the file
#################################################################################
sub parseFileH061
{
	my $fileName = shift;
	my $destArray = shift;
	my $seqeuence = shift;
	

	open (FILEHANDLE,"<$fileName") or return 0;
	print" Opened $fileName \n";
	my $sequence = 1;
	my $pracData;
	my %result; 	
	my $date;
	while(<FILEHANDLE>)
	{	
	
		if ($sequence ==1)
		{
			%result = parseRecord($_,'H061Header');
			if (%result->{keyword} eq 'H061')
			{
				$sequence++;
			  	$date = %result->{date};
			  	
			};
		}
		elsif($sequence ==2)
		{
			%result = parseRecord($_,'H061TrackingNumber');
			if (%result->{keyword} eq 'STATEMENT TRACKING NUMBER:')
			{
				$sequence++;
			  	$trackNumber = %result->{trackNumber};;
			};
		}
		elsif($sequence ==3)
		{
			%result = parseRecord($_,'H061PractieData');
			if (%result->{keyword} ne '')
			{
				$sequence++;
			  	$pracData=%result->{data};
			};
		}		
		elsif($sequence ==4)
		{
			%result = parseRecord($_,'H061ColData');
			if (%result->{keyword} eq 'Patient Name')
			{
				$sequence++;
			};
		}
		elsif($sequence ==5)
		{
			%result = parseRecord($_,'H061ColData');
			if (%result->{keyword} eq '------------------------')
			{
				$sequence++;
			};
		}			
		elsif($sequence ==6)
		{
			%result = parseRecord($_,'H061ColData');
			if (%result->{keyword} ne '')
			{
			  	#Save Data Here
			  	my $accountNumber = %result->{accountNumber};
			  	$accountNumber =~ /(.*)\-(.*?)$/;
				my ($personId, $sId) = ($1, $2);
			  	push @$destArray,{personId=>$personId,
			  			  statementId =>$sId,
			  			  trackNumber =>$trackNumber,
			  			  date=>$date
			  			  };
			}
			else
			{
				$sequence++;
			};
		}			
	}
	return 1
}

#################################################################################
#
#Parse  fix position record
#################################################################################
sub parseRecord
{

	my $text = shift;
	my $parseFormat = shift;
	my %parsedData;
	my $key;
	my $value;
	
	foreach $key (keys %{$recordFormat{$parseFormat}})
	{
		my $start = $recordFormat{$parseFormat}{$key}->[0];
		my $len = $recordFormat{$parseFormat}{$key}->[1];
		if (length($text)<$start)
		{
			$start=0;
		}
		$parsedData{$key} =  App::Data::Manipulate::trim(substr($text,$start,$len));
	}
	return %parsedData;
}


#################################################################################
#
#Connect to the database
#################################################################################
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

