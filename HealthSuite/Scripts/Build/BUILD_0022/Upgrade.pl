#!/usr/bin/perl -I.

##############################################################################
package Main;
##############################################################################

use strict;
use App::Universal;
use App::Configuration;
use App::External;

use File::Spec;

use vars qw($page $sqlPlusKey $BUILDIR);

$BUILDIR = `pwd`;
chomp $BUILDIR;

($page, $sqlPlusKey) = App::External::connectDB();
# You are now connected to the database and have access to a minimal $page object.


######## BEGIN UPGRADE SCRIPT #########

system(qq{
	cd @{[ $CONFDATA_SERVER->path_Database ]}
	./GenerateSchema.pl
});

my $schemaName = uc($sqlPlusKey);
$schemaName =~ s/\/.*//;

App::External::runSQL('BUILD_0022_analyze_schema.sql', $schemaName);
App::External::runSQL('BUILD_0022_compile_invalid_and_disabled.sql');


######## END UPGRADE SCRIPT #########

exit;
