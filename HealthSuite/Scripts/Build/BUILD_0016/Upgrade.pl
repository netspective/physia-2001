#!/usr/bin/perl -I.

use strict;
use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;
use File::Spec;

use DBI::StatementManager;
use App::Statements::Scheduling;

use vars qw($page $sqlPlusKey);

my $BUILDIR = `pwd`;
chomp $BUILDIR;

&connectDB();

# You are now connected to the database and have
# access to a minimal $page object.
#
######## BEGIN UPGRADE SCRIPT #########

system(qq{
	cd @{[ $CONFDATA_SERVER->path_Database ]}
	./GenerateSchema.pl
});

runSQL('BUILD_0016_main_script.sql');
runSQL('BUILD_0016_load_documents_schema.sql');
runSQL('BUILD_0016_drop_duplicate_triggers.sql');
runSQL('BUILD_0016_only_in_production.sql');
runSQL('BUILD_0016_views_and_ref_cpt.sql');
runSQL('BUILD_0016_alter_table_monitoring.sql');
#runSQL('BUILD_0016_create_new_indexes.sql');
runSQL('BUILD_0016_compile_invalid_and_disabled.sql');

######## END UPGRADE SCRIPT #########

exit;

# Subroutines

sub runSQL
{
	my $sqlFile = shift;
	$sqlFile = File::Spec->catfile($BUILDIR, $sqlFile);
	my $logFile = $sqlFile . ".log";

	die "Missing required '$sqlFile'. Aborted.\n" unless (-f $sqlFile);
	system(qq{
		cd @{[ $CONFDATA_SERVER->path_SchemaSQL ]}
		(	echo "---------------------------------------"
			date
			echo "---------------------------------------"
		) >> $logFile
		$ENV{ORACLE_HOME}/bin/sqlplus -s $sqlPlusKey < $sqlFile >> $logFile 2>&1
	});
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
