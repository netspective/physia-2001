#!/usr/bin/perl -w
#
# this script processes one or more types of documents; bringing them from
# external sources (like HL-7) into the Physia document management database
#

use strict;
use Getopt::Declare;
use App::External;
use File::Spec;
use Dumpvalue;
use Date::Manip;
use File::DosGlob 'glob';
use DBI::StatementManager;
use App::Data::Class::Collection;

use constant DEFAULT_MAIN_ORG => 'PHYSIA_ADMIN'; # use this main org if no matching main org is found

&main();

#
# the main processing routine; basically takes command-line arguments and dispatches
# them to the appropriate subroutines
#

sub main
{
	my $args = new Getopt::Declare(q{
	[strict]
	-type <id:s>				Process data of the -type in the directory specified by -path
								[required]
								[requires: -path || -file] 
	
	-test						The data being processed should be done in test mode

	-userid <id:s>				Force the user id to this person (person_id)
	-orgid <id:i>				Force the organization id to this organization (org_internal_id)
	
	-connectkey <key:s>			Use <key> as connect string instead of what's specified in App::Configuration
	-schema <file>				Use <file> as schema definition file instead of what's specified in App::Configuration
	
	-file <files>...			Process one or more files 
								Each item is treated as a parameter for File::DosGlob, 
								files not found are ignored unless -verbose is specified
	
	-verbose					Turn on verbose messages
	-debug <level:i>			Turn on debugging messages to <level>
	});
	
	print "Running in TEST mode.\n" if $args->{'-test'};
	print "Forcing User ID to '". $args->{'-userid'} ."'.\n" if $args->{'-userid'};
	print "Forcing Org Internal ID to '". $args->{'-orgid'} ."'.\n" if $args->{'-orgid'};
	
	if(exists $args->{'-type'})
	{
		my $dataType = $args->{'-type'};
		eval
		{
			my $method = &{"process_" . $dataType};
			&$method($args);
		};
		if($@)
		{
			die "Unable to find data type manager: $dataType\n";
		}
	}
}

sub createUniqueFilesList
{
	my ($args, %params) = @_;

	my $filesArg = $args->{'-file'} || undef;
	my $pathsArg = $args->{'-path'} || undef;
	my $verbose = $args->{'-verbose'} || 0;
	my %files = ();
	
	if($filesArg)
	{
		foreach(@$filesArg)
		{
			my @matchedFiles = glob($_);
			if(@matchedFiles)
			{
				foreach (@matchedFiles)
				{
					my $fileSpec = File::Spec->rel2abs($_);
					unless(exists $files{$fileSpec})
					{
						if(-f $fileSpec)
						{
							$files{$fileSpec} = md5_hex($fileSpec, (stat($fileSpec))[9]);
						}
						elsif($verbose)
						{
							print "[WARNING] File '$fileSpec' not found or is not a plain file.\n";
						}
					}
				}
			}
			elsif($verbose)
			{
				print "[WARNING] Filespec '$_' not found or is not a plain file.\n";
			}
		}
	}
	
	#
	# each key is now an absolute filename, value of each key is the digest (unique filename+date/time marker)
	#
	
	return \%files;
}

#
# medisoft processing functions
#

sub process_medisoft
{
	my ($args, %params) = @_;
	my $files = createUniqueFilesList($args, %params);
	my $context = App::External::initializeContext($args, %params);
	my $verbose = $args->{'-verbose'} || 0;

	my $collection = new App::Data::Class::Collection();
	# my $obtainer = new App::Data::Obtain::Medisoft;
	# create the collection
	# obtain the data
	# write the data
}



