#!/usr/bin/perl -I.

use strict;
use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use DBI::StatementManager;
use App::Statements::Scheduling;

use vars qw($page $sqlPlusKey);

&connectDB();

# You are now connected to the database and have
# access to a minimal $page object.
#
######## BEGIN UPGRADE SCRIPT #########

update_for_scheduling();


######## END UPGRADE SCRIPT #########

exit;

# Subroutines

sub update_for_scheduling
{
	my $count = $STMTMGR_SCHEDULING->getRowCount($page, STMTMGRFLAG_DYNAMICSQL,
		q{select count(*) from Transaction_Type where id = 8025}
	);

	unless ($count)
	{
		my $buildDir = `pwd`;
		chomp $buildDir;

		my $sqlFile = $buildDir . '/BUILD_0010_scheduling.sql';
		my $logFile = $buildDir . '/BUILD_0010_scheduling.log';
	
		die "Missing required '$sqlFile'.  Aborted.\n" unless (-f $sqlFile);
		
		system(qq{
			cd @{[ $CONFDATA_SERVER->path_SchemaSQL ]}
			echo "---------------------------------------" >> $logFile
			date >> $logFile
			echo "---------------------------------------" >> $logFile
			$ENV{ORACLE_HOME}/bin/sqlplus -s $sqlPlusKey < $sqlFile >> $logFile 2>&1
		});
		
		
		my $sqlFile = $buildDir . '/BUILD_0010_HCFA1500_Modifier_Code.sql';
		my $logFile = $buildDir . '/BUILD_0010_HCFA1500_Modifier_Code.log';
	
		die "Missing required '$sqlFile'.  Aborted.\n" unless (-f $sqlFile);
		
		system(qq{
			cd @{[ $CONFDATA_SERVER->path_SchemaSQL ]}
			echo "---------------------------------------" >> $logFile
			date >> $logFile
			echo "---------------------------------------" >> $logFile
			$ENV{ORACLE_HOME}/bin/sqlplus -s $sqlPlusKey < $sqlFile >> $logFile 2>&1
		});
	
	
	
		my $sqlFile = $buildDir . '/BUILD_0010_load_pre_post_code.sql';
		my $logFile = $buildDir . '/BUILD_0010_load_pre_post_code.log';
	
		die "Missing required '$sqlFile'.  Aborted.\n" unless (-f $sqlFile);
		
		system(qq{
			cd @{[ $CONFDATA_SERVER->path_SchemaSQL ]}
			echo "---------------------------------------" >> $logFile
			date >> $logFile
			echo "---------------------------------------" >> $logFile
			$ENV{ORACLE_HOME}/bin/sqlplus -s $sqlPlusKey < $sqlFile >> $logFile 2>&1
		});		
		
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


