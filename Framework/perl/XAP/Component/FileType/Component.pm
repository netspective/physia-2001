##############################################################################
package XAP::Component::FileType::Component;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use XAP::Component::Path;
use XAP::Component::File::Path;
use XAP::Component::FileType;
use XAP::Component::Exception;
use base qw(XAP::Component::FileType Exporter);
use File::Spec;

sub getExtensions
{
	# return an array of extensions that this entryType will manage
	return ('.pm');
}

sub processEntry
{
	my XAP::Component::FileType::Component $self = shift;
	my XAP::Component::File::Path $path = shift;
	my ($processFlags, $entryName, $entryExtn) = @_;
	
	my XAP::Component $component = undef;
	my $fileName = $path->resolveFileName($entryName, $entryExtn);
	if(open(MODFILE, $fileName))
	{
		while(<MODFILE>)
		{
			if (/^ *package +(\S+);/)
			{
				no strict 'refs';
				require $fileName;
				
				unless($processFlags & FILETYPEPROCESSFLAG_PREPROCESS)
				{
					my $startupFlags = $1->getStartupFlags();					
					$component = $1->new(id => $entryName) if $startupFlags & COMPSTARTUPFLAG_AUTOCREATE;
					if($component && ! $component->isa('XAP::Component'))
					{
						$component = new XAP::Component::Exception(id => $entryName, message => "'$entryName' is an invalid component: it's a '@{[ ref $component ]}' and should be a 'XAP::Component'");
					}
				}
				last;
			}
		}
		close(MODFILE);
	}
	else
	{
		$component = new XAP::Component::Exception(id => $entryName, message => "Unable to open module '$fileName': $!");
	}

	$path->addChildComponent($component, ADDCHILDCOMPFLAGS_DEFAULT, $entryName, $entryExtn)
		if ($component && ! $processFlags & FILETYPEPROCESSFLAG_PREPROCESS);
}

#
# create a new instance, which will automatically be mapped in the
# %FILE_TYPE_MAP in XAP::Component::FileType
#
new XAP::Component::FileType::Component;

1;