##############################################################################
package XAP::Component::FileType::Template;
##############################################################################

use strict;
use Exporter;
use XML::Parser;
use XAP::Component;
use XAP::Component::Template;
use XAP::Component::File::Path;
use XAP::Component::FileType;
use File::Spec;

use base qw(XAP::Component::FileType);

sub getExtensions
{
	# return an array of extensions that this entryType will manage
	return ('.tmpl');
}

sub processEntry
{
	my XAP::Component::FileType::Template $self = shift;
	my XAP::Component::File::Path $path = shift;
	my ($processFlags, $entryName, $entryExtn) = @_;
	
	return if $processFlags & FILETYPEPROCESSFLAG_PREPROCESS;

	my $fileName = $path->resolveFileName($entryName, $entryExtn);
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime) = stat($fileName);

	$self->{srcFile} = $fileName;
	$self->{srcFileStamp} = $mtime;

	my $transEntryName = $self->translateEntryName($processFlags, $entryName);
	my XAP::Component::Template $component = new XAP::Component::Template(id => $entryName, srcFile => $fileName, srcFileStamp => $mtime, caption => $transEntryName, heading => $transEntryName, fileName => $fileName, iconSel => $self->{iconSel}, icon => $self->{icon});
	$component->setFlag(COMPFLAG_URLADDRESSABLE);
	if(open(SRCFILE, $fileName))
	{
		my @contents = <SRCFILE>;
		close(SRCFILE);
		$component->{bodyTemplate} = join('', @contents);
	}
	else
	{
		$component->{bodyTemplate} = "Unable to obtain template from '$fileName': $!";
	}
	$path->addChildComponent($component, ADDCHILDCOMPFLAGS_DEFAULT, $entryName, $entryExtn);
}

#
# create a new instance, which will automatically be mapped in the
# %FILE_TYPE_MAP
#
new XAP::Component::FileType::Template;

1;