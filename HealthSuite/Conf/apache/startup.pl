#!/usr/bin/perl -w

BEGIN {
	use Apache ();
}

print "Entering startup.pl\n";
use strict;
use CGI ();
use CGI::Page ();
use DBI ();
use Apache::HealthSuite::PracticeManagement;
use Apache::Status;

DBI->install_driver('Oracle');
CGI->compile(':all');

print "Leaving startup.pl\n";

1;
