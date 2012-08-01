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
use App::Data::HL7::Messages;
use Digest::MD5 qw(md5_hex);
use DBI::StatementManager;
use vars qw($STMTMGR_HL7);

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
	-efax						Process e-fax messages in the the directory specified by -path
								[required]
								[requires: -path || -file] 
								
	-hl7						Process HL7 messages in the files specified by -file
								[required]
								[requires: -file] 
								[mutex: -efax -hl7]

	-test						The data being processed should be done in test mode

	-patientid <id:s>			Force the patient id to this patient (person_id)
	-providerid <id:s>			Force the provider (physician) id to this provider (person_id)
	-orgid <id:i>				Force the organization id to this organization (org_internal_id)
	
	-force						Force processing of files even if they're already in the database
	-connectkey <key:s>			Use <key> as connect string instead of what's specified in App::Configuration
	-schema <file>				Use <file> as schema definition file instead of what's specified in App::Configuration
	
	-file <files>...			Process one or more files 
								Each item is treated as a parameter for File::DosGlob, 
								files not found are ignored unless -verbose is specified
	
	-verbose					Turn on verbose messages
	-debug <level:i>			Turn on debugging messages to <level>
	});
	
	print "Running in TEST mode.\n" if $args->{'-test'};
	print "Forcing Patient ID to '". $args->{'-patientid'} ."'.\n" if $args->{'-patientid'};
	print "Forcing Provider ID to '". $args->{'-providerid'} ."'.\n" if $args->{'-providerid'};
	print "Forcing Org Internal ID to '". $args->{'-orgid'} ."'.\n" if $args->{'-orgid'};
	
	processHL7($args) if $args->{'-hl7'};
	
	#my $dv = new Dumpvalue;
	#$dv->dumpValue($args);
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
# the HL7 processing functions
#

use constant DOCSPEC_HL7MESSAGE => 3000;
use constant DOCSRCTYPE_ORG => 200;

sub getHL7MsgSourceId
{
	my App::Data::HL7::Message $message = shift;
	
	if(my $app = $message->getSendingApp())
	{
		return 1000 if $app eq 'LCS';
		return 1020 if $app eq 'CERNER';
	}
	return 0;
}

sub initHL7Statements
{
	$STMTMGR_HL7 = new DBI::StatementManager(
		'getMainOrgInternalId' => qq{
				select org_internal_id 
				from org 
				where org_id = :1 and owner_org_id = org_internal_id
			},
		'documentExists' => qq{
				select doc_id 
				from document 
				where doc_message_digest = :1
			},
		'getPersonId' => qq{
				select person_id
				from person 
				where upper(name_last) = :1 and upper(name_first) = :2 and ssn = :3
			},
	);
}

sub convertStamp
{
	my $hl7Stamp = shift;
	return undef unless $hl7Stamp;
	my $stamp = UnixDate(ParseDate($hl7Stamp), '%f/%d/%Y %I:%M %p');
	return undef unless $stamp;
	#$stamp =~ s/^\s+//;
	#print "\n$stamp\n";	
	return $stamp;
}

sub processHL7
{
	my ($args, %params) = @_;

	initHL7Statements();
	
	my $files = createUniqueFilesList($args, %params);
	my $context = App::External::initializeContext($args, %params);
	my $verbose = $args->{'-verbose'} || 0;
	my App::Data::HL7::Messages $messages = new App::Data::HL7::Messages;	

	while(my ($file, $digest) = each (%$files))
	{
		print "Importing '$file' ($digest)\n" if $verbose;
		$messages->importFile($file);
	}
	
	my $defaultOrgId = $STMTMGR_HL7->getSingleValue($context, STMTMGRFLAGS_NONE, 'getMainOrgInternalId', DEFAULT_MAIN_ORG);
	print "Default main org_internal_id is $defaultOrgId (@{[ DEFAULT_MAIN_ORG() ]})\n" if $verbose;
	
	print "Imported " . ($messages->getMessagesCount()) . " messages\n" if $verbose;
	
	my $msgList = $messages->getMessagesList();
	foreach my $message (@$msgList)
	{
		my $msgString = $message->exportString();
		my $msgDigest = md5_hex($msgString);
		
		if($STMTMGR_HL7->recordExists($context, STMTMGRFLAGS_NONE, 'documentExists', $msgDigest))
		{
			print "Message '$msgDigest' already in the database, ignoring it.\n" if $verbose;
			next;
		}
		
		my $msgHeader = $message->getHeaderSegment();
		
		my $docId = $context->schemaAction(
				0, 'Document', 'add',
				doc_message_digest => $msgDigest,
				doc_header => $msgHeader->exportString(),
				doc_spec_type => DOCSPEC_HL7MESSAGE, 
				doc_spec_subtype => $message->getField('Message Type'),
				doc_source_type => DOCSRCTYPE_ORG, 
				doc_source_id => $message->getField('Sending Facility'),
				doc_source_system => $message->getField('Sending Application'),
				doc_name => $message->getCaption(),
				doc_content_small => $msgString,
			);
				
		print "Added document '$docId' @{[$message->getField('Message Type') ]}\n" if $verbose;
		
		foreach my $PID (@{$message->getAllSegments()})
		{
			next unless $PID->id() eq 'PID';

			my ($patientId, $providerId, $orgId) = ($args->{'-patientid'} || undef, $args->{'-providerid'} || undef, $args->{'-orgid'} || undef);
			unless($orgId)
			{
				my $recvFacility = $message->getField('Receiving Facility');
				unless($orgId = $STMTMGR_HL7->getSingleValue($context, STMTMGRFLAGS_NONE, 'getMainOrgInternalId', $recvFacility))
				{
					print "Receiving facility '$recvFacility' not known, using $defaultOrgId instead\n" if $verbose;
					$orgId = $defaultOrgId;
				}
			}
			
			unless($patientId)
			{
				my ($patientLN, $patientFN, $patientSSN) = ($PID->getField(6, 1), $PID->getField(6, 2), $PID->getField(6, 9));
				$patientSSN =~ s/^(\d\d\d)(\d\d)(\d\d\d\d)/$1\-$2\-$3/;
				$patientId = 
					$patientLN && $patientFN && $patientSSN ? 
						$STMTMGR_HL7->getSingleValue($context, STMTMGRFLAGS_NONE, 'getPersonId', uc($patientLN), uc($patientFN), $patientSSN) :
						undef;
				print "Patient '$patientLN', '$patientFN' SSN '$patientSSN' not found in the system\n" if $verbose && ! $patientId;
			}
			
			my $ORC = undef;
			foreach my $OBR (@{$PID->getChildren()})
			{
				$ORC = $OBR if $OBR->id() eq 'ORC';
				next unless $OBR->id() eq 'OBR';

				my $providerId = $args->{'-providerid'} || undef;
				unless($providerId)
				{
					my ($providerSegID, $providerLN, $providerFN) = ($OBR->getField(17, 1) || $ORC->getField(13, 1), $OBR->getField(17, 2) || $ORC->getField(13, 2), $OBR->getField(17, 3)  || $ORC->getField(13, 3));
					$providerId = 
						$providerSegID && $providerLN && $providerFN ? 
							$STMTMGR_HL7->getSingleValue($context, STMTMGRFLAGS_NONE, 'getProviderId', uc($providerSegID), uc($providerLN), $providerFN) :
							undef;
					print "Provider '$providerLN', '$providerFN' ID '$providerSegID' not found in the system\n" if $verbose && ! $patientId;
				}

				my $obsId = $context->schemaAction(
						0, 'Observation', 'add',
						parent_doc_id => $docId,
						obs_sequence => $OBR->getField(2),
						observee_id => $patientId || undef,
						observee_name => $PID->getField(6),
						observer_id => $providerId || undef,
						observer_name => $OBR->getField(17) || $ORC->getField(13),
						observer_org_id => $orgId,
						req_control_num => $OBR->getField(3, 1) || undef,
						prod_control_num => $OBR->getField(4, 1) || undef,
						battery_id => $OBR->getField(5, 1) || undef,
						battery_text => $OBR->getField(5, 2) || undef,
						specimen_collection_stamp => convertStamp($OBR->getField(8)) || undef,
						obs_report_stamp => convertStamp($OBR->getField(23)) || undef,
						obs_order_status => convertStamp($OBR->getField(26)) || undef,
						#_debug => 1,
					);

				print "Added observation '$obsId' @{[ $OBR->getField(5, 1) . ':' . $OBR->getField(5, 2) ]}\n" if $verbose;
				
				foreach my $OBX (@{$OBR->getChildren()})
				{
					next unless $OBX->id() eq 'OBX';
					
					my $resultNotes = '';
					if(my $children = $OBX->getChildren())
					{
						foreach my $NTE (@$children)
						{
							next unless $NTE->id() eq 'NTE';
							$resultNotes .= ($resultNotes ? "\n" : '') . $NTE->getField(4);
						}
					}
					
					my $resultType = $OBX->getField(3);
					my $resultValue = $OBX->getField(6);
					if($resultValue =~ m/^[\d\.]+$/)
					{
						$resultType = 'NM' if $resultType ne 'NM';
					}
					else
					{
						$resultType = 'ST' if $resultType eq 'NM';
					}
					
					my $resultId = $context->schemaAction(
							0, 'Observation_Result', 'add',
							parent_obs_id => $obsId,
							result_producer_id => $OBX->getField(16) || undef,
							result_sequence => $OBX->getField(2) || undef,
							result_obs_id => $OBX->getField(4, 1),
							result_obs_text => $OBX->getField(4, 2),
							result_obs_coding => $OBX->getField(4, 3) || undef,
							result_value_type => $resultType || undef,
							result_value_text => $resultValue,
							result_value_num => $resultType eq 'NM' ? $resultValue : undef,
							result_units_id => $OBX->getField(7, 1) || undef,
							result_units_text => $OBX->getField(7, 2) || undef,
							result_units_coding => $OBX->getField(7, 3) || undef,
							result_normal_range => $OBX->getField(8),
							result_abnormal_flags => $OBX->getField(9),
							result_abnormal_nature => $OBX->getField(11),
							result_order_status => $OBX->getField(12),
							result_notes => $resultNotes || undef,
							#_debug => 1,
						);
					print "Added observation result '$resultId' @{[ $OBX->getField(4, 1) . '/' . $OBX->getField(4, 2) . ' ' . $resultType . ':' . $OBX->getField(6) ]}\n" if $verbose;					
				}
			}
			
			$context->schemaAction(
					0, 'Document_Association', 'add',
					assoc_type => $patientId ? 1000 : 1010, # owned by person if we have one, otherwise org
					doc_id => $docId,
					person_id => $patientId || undef,
					org_internal_id => $orgId,
					assn_data_a => $PID->sequenceNumInMsg(),
				);
		}		
	}
	
	#my $segments = $messages->getSegments('MSH');
	#foreach my $segment (@$segments)
	#{
	#	print $segment->exportString() . "\n" . $segment->getChildCount() . " children \n";
	#}
}


