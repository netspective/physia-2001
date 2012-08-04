#!/usr/bin/perl -w

print "Entering startup.pl\n";

BEGIN {
    $ENV{ORACLE_HOME} = "/u01/app/oracle/product/11.2.0/dbhome_1";
    $ENV{ORACLE_SID} = "orcl";
    $ENV{HTTP_HOST} = "physia";
    $ENV{NLS_LANG} = ".WE8MSWIN1252";
    $ENV{LD_LIBRARY_PATH} =$ENV{ORACLE_HOME}."/lib";
    $ENV{HS_DEBUG} = 1;
    $ENV{PHYSIA_ROOT} = "/var/netphysia";

}

use strict;
use lib ("$ENV{PHYSIA_ROOT}/Framework/perl", "$ENV{PHYSIA_ROOT}/HealthSuite/Lib/perl"); 1;

#use CGI ();
#use CGI::Page ();
#use Apache2::compat;

use DBI ();
use Apache::HealthSuite::PracticeManagement;
use Apache2::Status;

DBI->install_driver('Oracle');
CGI->compile(':all');

print "Leaving startup.pl\n";

1;

