##############################################################################
package XAP::Component::FileType::XML;
##############################################################################

use strict;
use Exporter;
use XML::Parser;
use XAP::Component::Exception;
use XAP::Component::File::Path;
use XAP::Component::FileType;
use File::Spec;

use base qw(XAP::Component::FileType);

sub processXML
{
	#my XAP::Component::FileType::XML $self = shift;
	#my XAP::Component::Path $path = shift;
	#my $document = shift;

	# this needs to be overriden in a base class
}

sub processEntry
{
	my XAP::Component::FileType::XML $self = shift;
	my XAP::Component::File::Path $path = shift;
	my ($processFlags, $entryName, $entryExtn) = @_;

	return if $processFlags & FILETYPEPROCESSFLAG_PREPROCESS;

	my $fileName = $path->resolveFileName($entryName, $entryExtn);
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime) = stat($fileName);

	$self->{srcFile} = $fileName;
	$self->{srcFileStamp} = $mtime;

	my ($parser, $document);
	eval
	{
		$parser = new XML::Parser(Style => 'Tree');
		$document = $parser->parsefile($fileName);
	};

	unless($@)
	{
		$self->processXML($path, $fileName, $document);
	}
	else
	{
		$path->addError("Error parsing XML in '$fileName': $@");
	}
	undef $parser;
	undef $document;
}

1;