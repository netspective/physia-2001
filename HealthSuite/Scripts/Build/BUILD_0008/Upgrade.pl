#!/usr/bin/perl -w

use strict;
use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use vars qw($page $sqlPlusKey);

&connectDB();

# You are now connected to the database and have
# access to a minimal $page object.
#
######## BEGIN UPGRADE SCRIPT #########





######## END UPGRADE SCRIPT #########

exit;

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
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
	
	$sqlPlusKey = $connectKey;
	$sqlPlusKey =~ s/dbi:Oracle://;
}


