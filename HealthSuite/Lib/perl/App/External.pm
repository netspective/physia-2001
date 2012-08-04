##############################################################################
package App::External;
##############################################################################

use strict;
use Exporter;
use Schema::API;
use App::Data::MDL::Module;
use App::Configuration;
use File::Spec;

sub initializeContext
{
	#
	# $args is expected to be a command-line arguments object of the form returned
	# by Getopt::Declare; %params can be any additional parameters required
	#
	my ($args, %params) = @_;
	my ($verbose, $debugLevel) = (exists $args->{'-verbose'} ? 1 : 0, exists $args->{'-debug'} ? $args->{'-debug'} : 0);
	
	my $page = new App::Data::MDL::Module();
	$page->{args} = $args;
	$page->{debugLevel} = $debugLevel;
	$page->{verbose} = $verbose || $debugLevel;
	$page->{schema} = undef;
	$page->{schemaFlags} = SCHEMAAPIFLAG_LOGSQL | SCHEMAAPIFLAG_EXECSQL;
	if($CONFDATA_SERVER->db_ConnectKey() && $CONFDATA_SERVER->file_SchemaDefn())
	{
		my $schemaFile = $args->{'-schema'} || $CONFDATA_SERVER->file_SchemaDefn();
		print STDOUT "Loading schema from $schemaFile\n" if $verbose || $debugLevel;
		$page->{schema} = new Schema::API(xmlFile => $schemaFile);

		my $connectKey = $args->{'-connectkey'} || $CONFDATA_SERVER->db_ConnectKey();
		print STDOUT "Connecting to $connectKey\n" if $verbose || $debugLevel;

		$page->{schema}->connectDB($connectKey);
		$page->{db} = $page->{schema}->{dbh};
		
		return $page;
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
}

sub runSQL
{
	my ($sqlFile, @params) = @_;
	$sqlFile = File::Spec->catfile($Main::BUILDIR, $sqlFile);
	my $logFile = $sqlFile . ".log";

	die "Missing required '$sqlFile'. Aborted.\n" unless (-f $sqlFile);
	system(qq{
		cd @{[ $CONFDATA_SERVER->path_SchemaSQL ]}
		(	echo "---------------------------------------"
			date
			echo "---------------------------------------"
		) >> $logFile
		$ENV{ORACLE_HOME}/bin/sqlplus -s $Main::sqlPlusKey <<-!!! >> $logFile 2>&1
			\@ $sqlFile @params
			exit;
		!!!
	});
}

sub connectDB
{
	my $page = new App::Data::MDL::Module();
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

		my $sqlPlusKey = $connectKey;
		$sqlPlusKey =~ s/dbi:Oracle://;

		return ($page, $sqlPlusKey);
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
}

1;