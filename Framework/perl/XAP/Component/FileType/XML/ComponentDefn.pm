##############################################################################
package XAP::Component::FileType::XML::ComponentDefn;
##############################################################################

use strict;
use Exporter;
use XML::Parser;
use File::Spec;
use File::Basename;

#
# just "use" all of the modules, they will automatically register their respective XML tag handlers
# (if any new components are added, add them to this list)
#
use XAP::Component;
use XAP::Component::Path;
use XAP::Component::Exception;
use XAP::Component::File::Path;
use XAP::Component::Field;
use XAP::Component::Dialog;
use XAP::Component::Command::Query;
use XAP::Component::Menu;
use XAP::Component::Menu::Horizontal;
use XAP::Component::Menu::Vertical;
use XAP::Component::Menu::ComboBox;
use XAP::Component::Menu::Tabs;
use XAP::Component::Template;
use XAP::Component::Controller;

use XAP::Component::FileType::XML;
use base qw(XAP::Component::FileType::XML);

sub getExtensions
{
	# return an array of extensions that this entryType will manage
	return ('.cml');
}

sub processXML
{
	my XAP::Component::FileType::XML::ComponentDefn $self = shift;
	my XAP::Component::File::Path $path = shift;
	my ($fileName, $documentTree) = @_;

	if(my $content = $documentTree->[1])
	{
		my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
		for(my $child = 1; $child < $childCount; $child += 2)
		{
			my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
			next unless $chTag; # if $tag is 0, it's just characters

			my $chAttrs = $chContent->[0];
			if($chTag eq 'path')
			{
				$path->applyXML($chTag, $chContent);
			}
			elsif($chTag eq 'include')
			{
				if(my $includeFile = $chAttrs->{file})
				{
					$includeFile = $path->ResolveFileName($includeFile, '');
					my ($incParser, $incDocument);
					eval
					{
						$incParser = new XML::Parser(Style => 'Tree');
						$incDocument = $incParser->parsefile($includeFile);
						$self->processXML($path, $includeFile, $incDocument);
					};
					if($@)
					{
						$path->addError("Error parsing XML in include file '$includeFile': $@");
					}
					undef $incParser;
					undef $incDocument;
				}
				elsif(my $includePath = $chAttrs->{path})
				{
					$path->pushIncludeStack($includePath);
					$path->readEntries();
					$path->popIncludeStack();
				}
				else
				{
					die "file or path attributes required in <include> tag\n";
				}
			}
			elsif(my XAP::Component $component = XAP::Component->createClassFromXMLTag($chTag, $chContent, %$chAttrs, parent => $path, srcFile => $self->{srcFile}, srcFileStamp => $self->{srcFileStamp}))
			{
				$path->addChildComponent($component, ADDCHILDCOMPFLAGS_DEFAULT, $component->{id});
			}
			else
			{
				$path->addWarning("Unable to create component from tag '$chTag' in '$fileName' (did you do a USE on the module? is it registered?)");
			}
		}
	}
	else
	{
		$path->addError("No content found in document '$documentTree' of $fileName.");
	}
}

#
# create a new instance, which will automatically be mapped in the
# %FILE_TYPE_MAP in XAP::Component::FileType
#
new XAP::Component::FileType::XML::ComponentDefn;

1;