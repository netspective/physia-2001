#!/usr/bin/perl -w

BEGIN {
	use Apache ();
}

print "Entering startup.pl\n";
use strict;
use CGI;
use CGI::Page;
use Apache::HealthSuite::PracticeManagement;
print "Leaving startup.pl\n";

1;
