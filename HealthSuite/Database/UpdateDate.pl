#! /usr/bin/perl -w

# This script drops user and creates new DB user, import using export file from user DEMO01 and  
# update created user adding specified number of days.
#
#
# input parameters: number of days to move ( can be negative )
#                   export file name 
#                   DB user which was exported
#                   new DB user which will be created and imported
#                   password fro new DB user

my ($days, $expfile, $fromuser, $touser, $passwd) = @ARGV;

if ($#ARGV != 4) 
{
	print "Wrong number of arguments on command line";
	exit 1;
}


my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);

$year += 1900;
$mon++;

#$dt = sprintf "%4u%02u%02u%02u%02u%02u", $year, $mon, $mday, $hour, $min, $sec;


my $sqlexit;
my $expexit;


my @sqltext = ("whenever sqlerror exit sql.sqlcode;\n",
		"drop user $touser cascade;\n",
		"create user $touser identified by $passwd default tablespace TS_DATA temporary tablespace TEMP;\n",
		"grant webuser to $touser;\n",
		"grant unlimited tablespace to $touser;\n");

open SQLPLUS, "|sqlplus -s system/phtem\@sdedbs02";

print SQLPLUS @sqltext;

close SQLPLUS;

$sqlexit = $?;

print "sqlexit = $sqlexit\n";

if ($sqlexit != 0)
{
	print "Errors when creating user $touser\n";
	exit 1;
}



open IMP, "|imp system/phtem\@sdedbs02 file=$expfile fromuser=$fromuser touser=$touser log=expuser.log\n";

close IMP;

# need to add checking errors in export log file


my @sqltext1 = ("whenever sqlerror exit sql.sqlcode;\n",
		"exec changeDates($days);\n",
		"commit;\n");

open SQLPLUS, "|sqlplus -s $touser/$passwd\@sdedbs02";

print SQLPLUS @sqltext1;

close SQLPLUS;

my $sqlexit1 = $?;

print "sqlexit1 = $sqlexit1\n";

if ($sqlexit1 != 0)
{
	print "Errors when updating user $touser\n";
	exit 1;
}


exit 0;
