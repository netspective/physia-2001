#!/usr/bin/perl

BEGIN {
	use Apache ();
	print "Entering startup.pl\n";
}

use strict;
use Apache::Constants;
use CGI;
use App::ResourceDirectory;
use Apache::HealthSuite::PracticeManagement;
use App::Configuration;
use Schema::API;
use App::Component::News;
#CGI->compile(':all');
preConnectDB();

print "Before ConnectDB\n";
sub preConnectDB {
	my $schemaFile = $CONFDATA_SERVER->file_SchemaDefn;
	my $dbConnectKey = $CONFDATA_SERVER->db_ConnectKey;
	my $schema = new Schema::API(xmlFile => $schemaFile);
	$schema->connectDB($dbConnectKey);
}
print "After ConnectDB\n";

print "Leaving startup.pl\n";
1;
