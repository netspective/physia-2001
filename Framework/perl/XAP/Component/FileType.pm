##############################################################################
package XAP::Component::FileType;
##############################################################################

use strict;
use Exporter;
use File::Spec;
use Date::Manip;
use XAP::Component;
use XAP::Component::Path;
use XAP::Component::File::Path;
use XAP::Component::File::HTML;
use XAP::Component::File::Text;

use base qw(XAP::Component Exporter);
#use fields qw();
use XAP::Component::Path;
use vars qw(@EXPORT %FILE_TYPE_MAP @PREFORMATTED @FORMATTED);

use enum qw(BITMASK:FILETYPEPROCESSFLAG_ PREPROCESS ISSELECTED);
@EXPORT = qw(FILETYPEPROCESSFLAG_ISSELECTED FILETYPEPROCESSFLAG_PREPROCESS);

%FILE_TYPE_MAP = ();
@PREFORMATTED = ('.txt', '.log');
@FORMATTED = ('.html');

use enum qw(BITMASK:NAVGENTFILEFLAG_ TRANSLATEUNDL TRANSLATEDATES);
use constant NAVGENTFILEFLAGS_DEFAULT => NAVGENTFILEFLAG_TRANSLATEUNDL | NAVGENTFILEFLAG_TRANSLATEDATES;

sub init
{
	my XAP::Component::FileType $self = shift;
	my %params = @_;

	$self->SUPER::init(@_, flags => NAVGENTFILEFLAGS_DEFAULT);

	my @extensions = $self->getExtensions();
	foreach (@extensions)
	{
		$FILE_TYPE_MAP{$_} = $self;
	}

	$self;
}

sub getExtensions
{
	# return an array of extensions that this entryType will manage
	return (@PREFORMATTED, @FORMATTED);
}

sub translateEntryName
{
	my XAP::Component::FileType $self = shift;
	my ($processFlags, $entryName) = @_;
	my $typeFlags = $self->{flags};

	if($typeFlags & NAVGENTFILEFLAG_TRANSLATEDATES)
	{
		$entryName =~ s/^(\d\d\d\d)\-(\d\d)\-(\d\d)\_(\d\d)\-(\d\d)/UnixDate("$2\/$3\/$1 $4:$5", '%F (%T)') || "Invalid Date"/e;
	}
	if($typeFlags & NAVGENTFILEFLAG_TRANSLATEUNDL)
	{
		$entryName =~ s/_/ /g;
	}

	return $entryName;
}

sub processEntry
{
	my XAP::Component::FileType $self = shift;
	my XAP::Component::File::Path $path = shift;
	my ($processFlags, $entryName, $entryExtn) = @_;
	
	return if $processFlags & FILETYPEPROCESSFLAG_PREPROCESS;

	my $fileName = $path->resolveFileName($entryName, $entryExtn);
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime) = stat($fileName);

	my $transEntryName = $self->translateEntryName($processFlags, $entryName);
	my %params = (id => $entryName, srcFile => $fileName, srcFileStamp => $mtime, caption => $transEntryName, heading => $transEntryName, fileName => $fileName, iconSel => $self->{iconSel}, icon => $self->{icon});
	my $component =
		(grep { $_ eq $entryExtn } @PREFORMATTED) ? (new XAP::Component::File::Text(%params)) : (new XAP::Component::File::HTML(%params));
	$path->addChildComponent($component, ADDCHILDCOMPFLAGS_DEFAULT, $entryName, $entryExtn);
}

#
# create a new instance, which will automatically be mapped in the
# %FILE_TYPE_MAP
#
new XAP::Component::FileType;

1;