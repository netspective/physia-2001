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
use Input::Promed;
use Output::PhysiaDB;
use App::DataModel::Base;
use Input::Semnet;

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
	-type <id:s>				Process data of the -type 
								[required]
	
	-test					The data being processed should be done in test mode

	-userid <id:s>				Force the user id to this person (person_id)
	-orgid <id:i>				Force the organization id to this organization (org_internal_id).  
						
	
	-createid <id:s>			Set cr_user_id to this value.  If not provided default to  IMPORT_PHYSIA

	-delta <level:i>			Run load as a delta process to <level>
						1: Run full delta performing insert update and deletes to DB
						2: Run delta process performing inserts and updates to DB  and 
						produce report for deletes
						3: Produce delta report do not alter DB
						
	-loadFile <id:s>			Run process and creates a load file [default is to load database]				
	
	-connectkey <key:s>			Use <key> as connect string instead of what's specified in App::Configuration
	-schema <file>				Use <file> as schema definition file instead of what's specified in 
						App::Configuration
	
	-file <files>...			Process one or more files. 
							Each item is treated as a parameter for File::DosGlob, 
							files not found are ignored unless -verbose is specified
	
	-verbose				Turn on verbose messages
	-debug <level:i>			Turn on debugging messages to <level>
	});
	
	print "Running in TEST mode.\n" if $args->{'-test'};
	print "Forcing User ID to '". $args->{'-userid'} ."'.\n" if $args->{'-userid'};
	print "Forcing Org Internal ID to '". $args->{'-orgid'} ."'.\n" if $args->{'-orgid'};
	print "Forcing Creation ID to' ". $args->{'-createid'} ."'.\n" if $args->{'-createid'};	
	
	if(exists $args->{'-type'})
	{
		my $dataType = $args->{'-type'};
		eval
		{
		
			
			my $method = \&{"process_" . $dataType};
			&$method($args);
		};
		if($@)
		{
			die "Unable to find data type manager: $dataType ($@)\n";
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

sub process_promed
{
	my ($args, %params) = @_;
	#my $files = createUniqueFilesList($args, %params);

	my $dataModel = new App::DataModel::Collection();

	##########################################################
	#These statements need to be in the new for Collection
	#
	$dataModel->orgs(new App::DataModel::Organizations());
	$dataModel->people(new App::DataModel::People());
	##########################################################
	my @params = (dataModel => $dataModel, cmdLineArgs => $args, attributes => \%params, verbose => $args->{'-verbose'} || 0);	
	my $input = new Input::Promed(@params);
	$input->init();
	$input->open();

	$input->populateDataModel();
	$input->close();

	my $output = new Output::PhysiaDB(@params);
	$output->init();
	$output->open();
	$output->transformDataModel();
	$output->close();
}

#
# Semnet processing function
#
sub process_semnet
{
	my ($args, %params) = @_;
	#my $files = createUniqueFilesList($args, %params);

	my $dataModel = new App::DataModel::Collection();

	##########################################################
	#These statements need to be in the new for Collection
	#
	$dataModel->orgs(new App::DataModel::Organizations());
	$dataModel->people(new App::DataModel::People());
	##########################################################
	my @params = (dataModel => $dataModel, cmdLineArgs => $args, attributes => \%params, verbose => $args->{'-verbose'} || 0);	
	my $input = new Input::Semnet(@params);
	$input->init();
	$input->open();
	$input->populateDataModel();
	$input->close();

	my $output = new Output::PhysiaDB(@params);
	$output->init();
	$output->open();
	$output->transformDataModel();				
	$output->close();
}




