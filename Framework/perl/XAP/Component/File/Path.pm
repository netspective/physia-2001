##############################################################################
package XAP::Component::File::Path;
##############################################################################

use strict;
use Exporter;
use Carp;

use CGI::Layout;
use Data::Publish;
use File::Spec;
use File::Basename;
use File::PathConvert;

use XAP::Component;
use XAP::Component::File;
use XAP::Component::Path;
use XAP::Component::File::Unknown;
use XAP::Component::Exception;

use base qw(XAP::Component::Path Exporter);
use fields qw(includeStack);
use vars qw(%SPECIAL_PATH_SUBCLASSES);

use constant PATHSUBCLASS_FNAME => 'Path.pm';
%SPECIAL_PATH_SUBCLASSES = ();

sub init
{
	my XAP::Component::File::Path $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{includeStack} = undef;
	$self;
}

sub pushIncludeStack
{
	my XAP::Component::File::Path $self = shift;
	my ($include) = @_;
	
	$include = File::PathConvert::rel2abs($include, $self->{includeStack} ? $self->{includeStack}->[-1] : $self->{srcFile});
	#$include = File::Spec->catfile($self->{includeStack} ? $self->{includeStack}->[-1] : $self->{srcFile}, $include);
	#print "push include '$include'\n";
	
	my $stack = $self->{includeStack} ? $self->{includeStack} : ($self->{includeStack} = []);
	push(@$stack, $include);
	return $include;
}

sub popIncludeStack
{
	my XAP::Component::File::Path $self = shift;
	#print "pop include\n";
	pop(@{$self->{includeStack}});
	$self->{includeStack} = undef unless scalar(@{$self->{includeStack}});
}

sub resolveFileName
{
	my XAP::Component::File::Path $self = shift;
	my ($entryName, $entryExtn) = @_;
	
	if($self->{includeStack})
	{
		return File::Spec->catfile($self->{includeStack}->[-1], "$entryName$entryExtn");
	}
	return File::Spec->catfile($self->{srcFile}, "$entryName$entryExtn");
}

sub addPath
{
	my XAP::Component::File::Path $self = shift;
	my ($entryName, %params) = @_;

	my $fsPath = $self->{includeStack} ? $self->{includeStack}->[-1] : $self->{srcFile};
	#print "adding path in '$fsPath'\n";
	#
	# check to see if the path has been subclassed for special consideration(s)
	#
	my $pathClassName = ref $self; # we should start out being whatever our parent is
	my $specialSubclassFName = File::Spec->catfile($fsPath, $entryName, PATHSUBCLASS_FNAME);
	if(-f $specialSubclassFName)
	{
		if(open(MODFILE, $specialSubclassFName))
		{
			while(<MODFILE>)
			{
				if (/^ *package +(\S+);/)
				{
					unless(exists $SPECIAL_PATH_SUBCLASSES{$1})
					{
						require $specialSubclassFName;
						$pathClassName = $1;
						$SPECIAL_PATH_SUBCLASSES{$1} = 1;
					}
					else
					{
						$self->addChildComponent(new XAP::Component::Exception(id => $entryName, message => "Path class '$1' has already been registered."), ADDCHILDCOMPFLAGS_DEFAULT, $entryName);
					}
					last;
				}
			}
			close(MODFILE);
		}
	}

	my $dirPath = File::Spec->catfile($fsPath, $entryName);
	#print "adding child dirPath '$dirPath'\n";

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime) = stat($dirPath);
	my XAP::Component::File::Path $childPath = $pathClassName->new(parent => $self, srcFile => $dirPath, srcFileStamp => $mtime, %params);
	$childPath->readEntries();
	unshift(@{$self->{childCompList}}, $childPath);
	$self->{childCompMap}->{$childPath->{id}} = $childPath;
	return $childPath;
}

sub clearEntries
{
	my XAP::Component::File::Path $self = shift;
	
	$self->{childCompList} = undef $self->{childCompList};
	$self->{childCompMap} = undef $self->{childCompMap};
}

sub readEntries
{
	my XAP::Component::File::Path $self = shift;

	my $entries = ($self->{childCompList} ? $self->{childCompList} : ($self->{childCompList} = []));
	my $eMap = ($self->{childCompMap} ? $self->{childCompMap} : ($self->{childCompMap} = {}));

	my $fsPath = $self->{includeStack} ? $self->{includeStack}->[-1] : $self->{srcFile};
	#print "reading entries in '$fsPath'\n";
	
	if(opendir(ACTIVEPATH, $fsPath))
	{
		my @dirs = ();
		my @files = ();
		grep
		{
			unless(m/^[_\.]/) # skip hidden files and subdirectories
			{
				if(-d File::Spec->catfile($fsPath, $_))	{
					push(@dirs, $_) unless $_ eq 'CVS';
				} else {
					push(@files, $_);
				}
			}
		} readdir(ACTIVEPATH);
		closedir(ACTIVEPATH);

		my $entryTypeClasses = \%XAP::Component::FileType::FILE_TYPE_MAP;

		#
		# first do a "pre-process" step to see if any of the files need to do anything special before
		# we add them to the list(s)
		#
		my $processFlags = XAP::Component::FileType::FILETYPEPROCESSFLAG_PREPROCESS();
		foreach my $file (sort @files)
		{
			#print "preprocess $file\n";
			next if $file eq PATHSUBCLASS_FNAME; # ignore Path.pm (which is handled in the directory section)
			my ($fileName, $filePath, $fileExtn) = fileparse($file, '\..*');
			if(my $fileEntryClass = exists $entryTypeClasses->{$fileExtn} ? $entryTypeClasses->{$fileExtn} : undef)
			{
				$fileEntryClass->processEntry($self, $processFlags, $fileName, $fileExtn);
			}
		}

		#
		# process the files first because there might be *.cml files that change the path data
		#
		$processFlags = 0;
		foreach my $file (sort @files)
		{
			#print "postprocess $file\n";
			next if $file eq PATHSUBCLASS_FNAME; # ignore Path.pm (which is handled in the directory section)
			my ($fileName, $filePath, $fileExtn) = fileparse($file, '\..*');
			if(my $fileEntryClass = exists $entryTypeClasses->{$fileExtn} ? $entryTypeClasses->{$fileExtn} : undef)
			{
				$fileEntryClass->processEntry($self, $processFlags, $fileName, $fileExtn);
			}
			else
			{
				$self->addChildComponent(new XAP::Component::File::Unknown(id => "$fileName$fileExtn", caption => $fileName, heading => $fileName), ADDCHILDCOMPFLAGS_DEFAULT, $fileName, $fileExtn);
			}
		}

		#
		# now process all the directories and subdirectories
		# (we do a reverse sort because we want directories to show at the top of the list)
		#
		foreach (reverse sort @dirs)
		{
			#print "dirprocess $_\n";
			my $caption = $_;
			$caption =~ s/_/ /g;
			
			$self->addPath($_, id => $_, caption => $caption, heading => $caption);
		}
	}
	else
	{
		die "Path '$fsPath' is not valid";
	}
}

1;