##############################################################################
package XAP::Component;
##############################################################################

use strict;
use Exporter;
use Text::Template;
use XML::Parser;
use base qw(Exporter);
use fields qw(
		id name parent flags heading caption url
		childCompList childCompMap icon iconSel iconPage translateURLParams errors warnings
		srcFile srcFileStamp sessType sessTimeOutSecs sessLoginCompId
		pageTemplate templateProcessor
		);
use Date::Manip;
use vars qw(@EXPORT $ROOT_COMPONENT %COMPONENT_FACTORY %SINGLETONS);

use constant ICONGRAPHIC_SELARROW	=> '/resources/icons/arrow-double-cyan.gif';
use constant ICONGRAPHIC_PAGE		=> '/resources/icons/report-yellow.gif';

use constant CUSTOMMETHODNAME_PAGEPREINIT => 'customPreInitPage';
use constant CUSTOMMETHODNAME_PAGEINIT => 'customInitPage';

@EXPORT = qw(%COMPONENT_MAP_URL
	COMPFLAGS_DEFAULT COMPFLAG_VIRTUALCHILDREN COMPFLAG_URLADDRESSABLE COMPFLAG_PRINTERRORS COMPFLAG_LASTFLAGID
	FINDCOMPURLFLAGS_DEFAULT FINDCOMPURLFLAG_SHOWERROR FINDCOMPURLFLAG_SHOWSEARCH $ROOT_COMPONENT
	TRANSURLPARAMFLAGS_DEFAULT TRANSURLPARAMFLAG_REQUIRED
	ADDCHILDCOMPFLAGS_DEFAULT
	COMPSTARTUPFLAG_AUTOCREATE
	COMPSTARTUPFLAGS_DEFAULT
	getTreeAsXMLText getTagTextOnly convertAttrsToHashRef
	);

use enum qw(BITMASK:COMPSTARTUPFLAG_ AUTOCREATE);
use enum qw(BITMASK:COMPFLAG_ VIRTUALCHILDREN URLADDRESSABLE PRINTERRORS LASTFLAGID);
use enum qw(BITMASK:FINDCOMPURLFLAG_ SHOWERROR SHOWSEARCH SOURCECHANGE);
use enum qw(BITMASK:TRANSURLPARAMFLAG_ REQUIRED);

use constant COMPFLAGS_DEFAULT => COMPFLAG_URLADDRESSABLE;
use constant COMPSTARTUPFLAGS_DEFAULT => COMPSTARTUPFLAG_AUTOCREATE;
use constant FINDCOMPURLFLAGS_DEFAULT => 0;
use constant TRANSURLPARAMFLAGS_DEFAULT => 0;
use constant ADDCHILDCOMPFLAGS_DEFAULT => 0;

use constant SESSIONTYPE_NONE      => 0; # no session information will be tracked
use constant SESSIONTYPE_ANONYMOUS => 1; # session will be tracked, but no person is identified
use constant SESSIONTYPE_PERSON    => 2; # session tracked for a single, named user

$ROOT_COMPONENT = undef;
%COMPONENT_FACTORY = ();
%SINGLETONS = ();

#
# STATIC class method returns flags to process on startup only
#
sub getStartupFlags
{
	return COMPSTARTUPFLAGS_DEFAULT;
}

#
# STATIC class method returns 1 if this should be a SINGLETON component (only one will exist)
# or 0 if many of the same component can exist
#
sub isSingleton
{
	return 0;
}

sub new
{
	my $class = shift;
	
	my $isSingleton = $class->isSingleton();
	return $SINGLETONS{$class} if $isSingleton && exists $SINGLETONS{$class};
	
	no strict 'refs';
        my XAP::Component $self = fields::new($class);
	use strict 'refs';
	$self->init(@_);
	$SINGLETONS{$class} = $self if $isSingleton;
	
	$self;
}

sub init
{
	my XAP::Component $self = shift;
	my %params = @_;
	
	$self->{parent} = exists $params{parent} ? $params{parent} : undef;
	$self->{id} = exists $params{id} ? $params{id} : ref $self;
	$self->{name} = exists $params{name} ? $params{name} : undef;
	$self->{flags} = exists $params{flags} ? $params{flags} : COMPFLAGS_DEFAULT;
	$self->{childCompList} = exists $params{childCompList} ? $params{childCompList} : undef;
	$self->{childCompMap} = exists $params{childCompMap} ? $params{childCompMap} : undef;
	$self->{heading} = exists $params{heading} ? $params{heading} : '';
	$self->{caption} = exists $params{caption} ? $params{caption} : '';
	$self->{url} = exists $params{url} ? $params{url} : undef;
	$self->{icon} = exists $params{icon} ? $params{icon} : ICONGRAPHIC_PAGE;
	$self->{iconSel} = exists $params{iconSel} ? $params{iconSel} : ICONGRAPHIC_SELARROW;
	$self->{iconPage} = exists $params{iconPage} ? $params{iconPage} : '';
	$self->{translateURLParams} = exists $params{translateURLParams} ? $params{translateURLParams} : undef;
	$self->{warnings} = exists $params{warnings} ? $params{warnings} : undef;
	$self->{errors} = exists $params{errors} ? $params{errors} : undef;
	$self->{srcFile} = exists $params{srcFile} ? $params{srcFile} : undef;
	$self->{srcFileStamp} = exists $params{srcFileStamp} ? $params{srcFileStamp} : undef;
	$self->{pageTemplate} = exists $params{pageTemplate} ? $params{pageTemplate} : undef;
	$self->{templateProcessor} = exists $params{templateProcessor} ? $params{templateProcessor} : undef;
	$self->{sessType} = exists $params{sessType} ? $params{sessType} : SESSIONTYPE_NONE;
	$self->{sessTimeOutSecs} = exists $params{sessTimeOutSecs} ? $params{sessTimeOutSecs} : 1800;
	$self->{sessLoginCompId} = exists $params{sessLoginCompId} ? $params{sessLoginCompId} : '.../loginDialog';

	$self;
}


use vars qw($CALL_NUM);
$CALL_NUM = 0;

sub registerXMLTagClass # STATIC METHOD
{
	my $class = shift;
	my ($tag, $componentClass, %defaultParams) = @_;

	$CALL_NUM++;
	if(ref $componentClass eq 'ARRAY')
	{
		#
		# if the class name is dependent upon both a tag and a tag's attribute, then we store
		# the attrName that it depends upon and a hash with the multiple attr values
		#
		my ($attrName, $attrClassMap) = @$componentClass;
		if(my $classInfo = $COMPONENT_FACTORY{$tag})
		{
			my ($componentClass, $defaultParams) = @$classInfo;
			my $classMap = $componentClass->[1];
			foreach (keys %$attrClassMap)
			{
				$classMap->{$_} = $attrClassMap->{$_};
				#print "$CALL_NUM: registering <$tag>/$attrName=$_ as '$classMap->{$_}' (params: @{[ join(', ', keys %defaultParams) || 'none' ]})\n";
			}
		}
		else
		{
			foreach (keys %$attrClassMap)
			{
				#print "$CALL_NUM: registering <$tag>/$attrName=$_ as '$attrClassMap->{$_}' (params: @{[ join(', ', keys %defaultParams) || 'none' ]})\n";
			}
			$COMPONENT_FACTORY{$tag} = [$componentClass, (%defaultParams ? \%defaultParams : undef)];
		}
	}
	else
	{
		$COMPONENT_FACTORY{$tag} = [$componentClass, (%defaultParams ? \%defaultParams : undef)];
		#print "$CALL_NUM: registering <$tag> as '$componentClass' (params: @{[ join(', ', keys %defaultParams) || 'none' ]})\n";
	}
}

sub createClassFromXMLTag # STATIC METHOD
{
	my $class = shift;
	my ($tag, $content, %params) = @_;

	#print "looking for class for tag <$tag>...";
	if(my $classInfo = $COMPONENT_FACTORY{$tag})
	{
		my ($componentClass, $defaultParams) = @$classInfo;

		# a reference to a hash means we check tag attributes to find appropriate class name
		if(ref $componentClass eq 'ARRAY')
		{
			my ($attrName, $attrClassMap) = @$componentClass;
			#print "looking for key '$attrName'...";
			if(my $classKey = $content->[0]->{$attrName})
			{
				#print "($classKey: @{[ join(', ', keys %$attrClassMap) ||  'none' ]}) ";
				$componentClass = exists $attrClassMap->{$classKey} ? $attrClassMap->{$classKey} : undef;
			}
			else
			{
				$componentClass = undef;
			}
		}

		if($componentClass)
		{
			#print "found '$componentClass'.\n";
			foreach (keys %$defaultParams)
			{
				$params{$_} = $defaultParams->{$_} unless exists $params{$_};
			}

			my $instance = $componentClass->new(%params);
			$instance->applyXML($tag, $content);
			return $instance;
		}
	}
	#print "not found.\n";
	return undef;
}

sub getTreeAsXMLText # UTILITY FUNCTION, exported above (doesn't belong to class, it's just a function)
{
	my $content = shift;
	my $xml = '';

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		if($chTag)
		{
			my ($chAttrsRef, @chAttrsText) = ($chContent->[0]);
			foreach (sort keys %$chAttrsRef)
			{
				push (@chAttrsText, qq{$_="$chAttrsRef->{$_}"});
			}

			$xml .= "<$chTag" . (@chAttrsText ? (' ' . join(' ', @chAttrsText)) : '') . ">\n" .
					getTreeAsXMLText($chContent) . "\n" .
					"</$chTag>\n";
		}
		else
		{
			$xml .= $chContent . "\n";
		}
	}

	return $xml;
}

sub getTagTextOnly # UTILITY FUNCTION, exported above (doesn't belong to class, it's just a function)
{
	my ($content) = @_;

	my $text = '';
	my $childCount = scalar(@$content);
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		$text .= $content->[$child+1] unless $content->[$child];
	}
	return $text;
}

sub convertXMLTokenToPerlVarName
{
	# convert tokens the form xxx-yyyy-zzz (XML style) to xxxYyyZzz (perl style)
	#
	my $token = shift;
	$token =~ s/\-([a-z])/\u$1/g;
	return $token;
}

sub convertAttrsToHashRef
{
	my $attrs = shift;
	my $hash = {};

	# convert tokens the form xxx-yyyy-zzz (XML style) to xxxYyyZzz (perl style)
	#		
	my ($key, $value);
	while(($key, $value) = each %$attrs)
	{
		$key =~ s/\-([a-z])/\u$1/g;
		$hash->{$key} = $value;
	}
	
	return $hash;
}

sub getPublishDefnFromXML
{
	my XAP::Component $self = shift;
	my ($tag, $content, $mode) = @_;

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	
	my $publishDefn = convertAttrsToHashRef($attrs);
	$publishDefn->{columnDefn} = [];
	
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag;

		my $chAttrs = $chContent->[0];
		if($chTag eq 'column')
		{
			my $columnDefn = convertAttrsToHashRef($chAttrs);
			push(@{$publishDefn->{columnDefn}}, $columnDefn);

			if(my $selType = $chAttrs->{'data-fmt-select'})
			{
				my $isArray = $selType eq 'array';
				my $dataFmt = ($columnDefn->{dataFmt} = ($isArray ? [] : {}));
				my $gChildCount = scalar(@$chContent);
				for(my $gChild = 1; $gChild < $gChildCount; $gChild += 2)
				{
					my ($gChTag, $gChContent) = ($chContent->[$gChild], $chContent->[$gChild+1]);
					if($gChTag && $gChTag eq 'data-fmt')
					{
						my ($value, $fmt) = ($gChContent->[0]->{value}, $gChContent->[0]->{fmt});
						if($isArray) { $dataFmt->[$value] = $fmt; } else { $dataFmt->{$value} = $fmt }
					}
				}			
			}
		}
		elsif($chTag =~ m/(frame|select|std\-icons|banner)/)
		{
			$publishDefn->{convertXMLTokenToPerlVarName($chTag)} = convertAttrsToHashRef($chAttrs);
			
			if($chTag eq 'banner')
			{
				my @actionRows = ();
				my $bannerContent = '';
				my $gChildCount = scalar(@$chContent);
				for(my $gChild = 1; $gChild < $gChildCount; $gChild += 2)
				{
					my ($gChTag, $gChContent) = ($chContent->[$gChild], $chContent->[$gChild+1]);
					if($gChTag && $gChTag eq 'action-row')
					{
						push(@actionRows, convertAttrsToHashRef($gChContent->[0]));
						#print "found action-row @{[ join(', ', keys %{$actionRows[-1]}) ]}\n";
					}
					else
					{
						$bannerContent .= $gChContent if $gChTag == 0;
					}
				}
				
				# remove all leading, trailing, and multiple white space
				$bannerContent =~ s/(^\s+|\s{2+}|\s+$)//g;
				$publishDefn->{banner}->{content} = $bannerContent if $bannerContent;
				$publishDefn->{banner}->{actionRows} = \@actionRows if @actionRows;
			}
		}
	}
	
	$publishDefn->{frame}->{heading} = $self->{heading} || $self->{caption} unless exists $publishDefn->{frame} && $publishDefn->{frame}->{heading};
	$publishDefn->{style} = $mode if $mode && ! exists $publishDefn->{style};
	return $publishDefn;
}

sub applyTemplates
{
	my XAP::Component $self = shift;
	my ($tag, $content) = @_;

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	
	my $child = 1;
	while($child < $childCount)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		unless($chTag) # if $tag is 0, it's just characters
		{
			$child += 2;
			next;
		}

		if($chTag eq 'apply-template')
		{
			my $chAttrs = $chContent->[0];
			#print "applying template: '$chAttrs->{id}' in '@{[ $self->getPathAsStr() ]}'\n";
			if(my $template = $self->getComponent($chAttrs->{id}))
			{
				my $source = $template->{bodyTemplate};
				$source =~ s/\#attributes.([A-Za-z0-9\-]+)\#/exists $chAttrs->{$1} ? $chAttrs->{$1} : ''/ge;
				#print "***************\n$source***************\n\n";
				unless($chAttrs->{style} && $chAttrs->{style} eq 'text')
				{
					my ($parser, $fragment);
					eval
					{
						$source = "<template>$source</template>";
						$parser = new XML::Parser(Style => 'Tree');
						$fragment = $parser->parse($source)->[1]; # use the contents, skip <template>
						shift @$fragment; # skip the processing of the attributes for <template> tag

						# remove the current apply-template tag and content and replace with 
						# all the children in the actual template
						splice(@$content, $child, 2, @$fragment);
					};
					if($@)
					{
						die "XML parsing error in template '@{[$template->getPathAsStr()]}': $@\n$source\n";
					}
				}
				else
				{
					# replace the current tag (apply-template) with the contents of the template
					$content->[$child] = 0;
					$content->[$child+1] = $source;
				}
				
				# make sure we don't skip any elements (go back over the current element to recurse)
				$child -= 2;						
			}
			else
			{
				die "Template '$chAttrs->{id}' not found in '@{[ $self->getPathAsStr() ]}'\n";
			}
		}
		
		$child += 2;
	}
}

sub applyXML
{
	my XAP::Component $self = shift;
	my ($tag, $content) = @_;

	# first see if any templates need to be replaced
	$self->applyTemplates($tag, $content);

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);		
	$self->{parent}->addChildSynonym($self, $attrs->{synonym}) if $attrs->{synonym} && $self->{parent};
	
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag; # if $tag is 0, it's just characters

		my $chAttrs = $chContent->[0];
		if($chTag eq 'page-template')
		{
			$self->{pageTemplate} = getTagTextOnly($chContent);
		}
		elsif($chTag eq 'synonym')
		{
			$self->{parent}->addChildSynonym($self, $chAttrs->{id}) if $self->{parent};
		}
		elsif($chTag eq 'session')
		{
			if(my $type = $chAttrs->{type})
			{
				$self->{sessType} =
					($type eq 'anonymous' ? SESSIONTYPE_ANONYMOUS() :
						($type eq 'none' ? SESSIONTYPE_NONE() : SESSIONTYPE_PERSON()));
			}
			if(my $timeOut = $chAttrs->{'time-out'})
			{
				$self->{sessTimeOutSecs} = $timeOut;
			}
			#print "$self->{sessType} : $self->{sessTimeOutSecs}\n";
		}
	}

	$self;
}

sub getChildById
{
	my XAP::Component $self = shift;
	my ($page, $entryName) = @_;
	return exists $self->{childCompMap}->{$entryName} ? $self->{childCompMap}->{$entryName} : undef;
}

sub getSiblingCount
{
	my XAP::Component $self = shift;
	return $self->{parent} && $self->{parent}->{childCompList} ? scalar(@{$self->{parent}->{childCompList}}) : 0;
}

sub addChildComponent
{
	my XAP::Component $self = shift;
	my XAP::Component $component = shift;
	my ($entryFlags, $entryName, $entryExtn) = @_;

	unless($component && $component->isa('XAP::Component'))
	{
		$component = new XAP::Component::Exception(id => $entryName, message => "Invalid component '$component'", heading => "Invalid component '$component");
	}

	$component->{parent} = $self;

	$self->{childCompMap}->{$component->{id}} = $component;
	push(@{$self->{childCompList}}, $component);
}

sub addChildSynonym
{
	my XAP::Component $self = shift;
	my XAP::Component $component = shift;
	my $synonym = shift;
	
	$self->{childCompMap}->{$synonym} = $component;
}

sub sourceChanged
{
	my XAP::Component $self = shift;

	if(my $sourceFile = $self->{srcFile})
	{
		# has the source been deleted?
		return 1 unless -e $sourceFile;

		# check the date/time now
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime) = stat($sourceFile);
		return 1 if $self->{srcFileStamp} && ($mtime ne $self->{srcFileStamp});
	}
	return 0;
}

sub findChildPath
{
	my XAP::Component $self = shift;

	my XAP::Component $activeComp = $self;
	my $lastPathItem = scalar(@_)-1;
	for(my $i = 0; $i <= $lastPathItem; $i++)
	{
		$activeComp = $activeComp->{childCompMap}->{$_[$i]};
		return $activeComp if $i == $lastPathItem;
		last unless $activeComp && $activeComp->{childCompList} && @{$activeComp->{childCompList}};
	}
	return undef;
}

sub getComponent
{
	my XAP::Component $self = shift;
	my ($pathSpec, $page, $flags) = (shift, shift, shift);

	my @pathItems = split(/\//, $pathSpec);
	my $startWith = shift @pathItems;
	my XAP::Component $found = undef;
	
	if(! $startWith) # absolute path  (started with /)
	{
		$found = $ROOT_COMPONENT->findChildPath($startWith, @pathItems);
	}
	elsif(scalar(@pathItems) == 0) # simple id, look for a sibling
	{
		$found = $self->{parent}->findChildPath($startWith) if $self->{parent};
	}
	elsif($startWith eq '...') # we're doing an inheritance search (first starting with us)
	{
		my XAP::Component $path = $self;
		my $lookForId = shift @pathItems;
		while($path)
		{
			last if $found = (exists $path->{childCompMap}->{$lookForId} ? $path->{childCompMap}->{$lookForId} : undef);
			$path = $path->{parent};
		}
	}
	elsif($startWith eq '..')  # we're doing a parent search (start with our parent's parent)
	{
		$found = $self->{parent}->{parent}->findChildPath(@pathItems) if $self->{parent} && $self->{parent}->{parent};
	}
	else  # we're doing a child search
	{
		push(@pathItems, $startWith) unless $startWith eq '.';
		$found = $self->{parent}->findChildPath($startWith) if $self->{parent};
	}

	$page->addComponent($found) if $found && $page;
	return $found;
}

sub getComponentHtml
{
	my XAP::Component $self = shift;
	my ($pathSpec, $page, $flags) = (shift, shift, shift);

	my XAP::Component $found = $self->getComponent($pathSpec, $page, $flags);
	#$page->addDebugStmt("Processing component '$found->{id} @{[ $found->getPathAsStr() ]}");
	return $found ? $found->getBodyHtml($page, $flags, @_) : "component '$pathSpec' not found in $self->{id}";
}

# --- URL-map functions ------------------------------------------------------

sub findComponentForURL # STATIC METHOD
{
	my ($self, $url, $page, $searchFlags) = @_;
	
	# store the url for later usage by other components
	$page->{page_urlFull} = $url;

	my $paramStartIndex = index($url, '?');
	$url = substr($url, 0, $paramStartIndex) if $paramStartIndex >= 0;
	$page->{page_urlPathOnly} = $url;

	# when doing searching, we do not want a leading slash
	$url = substr($url, 1) if substr($url, 0, 1) eq '/';

	my @pathItems = split(/\//, $url);
	my XAP::Component $activeComp = $self;
	@pathItems = $activeComp->eatURLPathItems($page, @pathItems) if $activeComp->{translateURLParams};

	my $id;
	if(@pathItems)
	{
		if($activeComp->{flags} & COMPFLAG_VIRTUALCHILDREN)
		{
			$page->setVirtualChildPath(@pathItems);
			return $activeComp;
		}
		
		while ($id = shift @pathItems)
		{
			last unless exists $activeComp->{childCompMap}->{$id};
			$activeComp = $activeComp->{childCompMap}->{$id};
			@pathItems = $activeComp->eatURLPathItems($page, @pathItems) if $activeComp->{translateURLParams};
			return $activeComp unless @pathItems; # if we've exhausted the pathItems and we have a component, we're done
			
			if($activeComp->{flags} & COMPFLAG_VIRTUALCHILDREN)
			{
				$page->setVirtualChildPath(@pathItems);
				return $activeComp;
			}			
		}
	}
	else
	{
		return $activeComp;
	}
	
	return $activeComp ? $activeComp->handleURLNotFound($page, $url, $id, @pathItems) : undef;
}

sub eatURLPathItems
{
	my XAP::Component $self = shift;
	my ($page, @pathItems) = @_;

	if(my $translate = $self->{translateURLParams})
	{
		if(ref $translate eq 'ARRAY')
		{
			foreach (@$translate)
			{
				$page->param($_, shift @pathItems);
				#$page->addError("No value found for '$_' while translating URL parameter.") unless $page->param($_, shift @pathItems);
			}
		}
		else
		{
			$page->param($translate, shift @pathItems);
			#$page->addError("No value found for '$translate' while translating URL parameter.") unless $page->param($translate, shift @pathItems);
		}
	}

	return @pathItems;
}

sub handleURLNotFound
{
	my XAP::Component $self = shift;
	my ($page, $url, @remainingPathItems) = @_;
	
	$page->addError(qq{
		URL '$url' not found. <br>
		Found '@{[ $self->getPathAsStr() ]}', but could not find '@{[ join('/', @remainingPathItems) ]}'.
		});
	
	return $self;
}

sub getPathAsStr
{
	my XAP::Component $self = shift;

	my XAP::Component $path = $self;
	my @pathItems = ();
	while($path)
	{
		unshift(@pathItems, $path->{id});
		$path = $path->{parent};
	}

	return join('/', @pathItems);
}

sub getURL
{
	my XAP::Component $self = shift;
	return $self->{url} if defined $self->{url};

	my $page = shift;
	my XAP::Component $path = $self;
	my @pathItems = ();
	while($path)
	{
		if(my $translate = $path->{translateURLParams})
		{
			if(ref $translate eq 'ARRAY')
			{
				foreach (@$translate)
				{
					unshift(@pathItems, $page->param($_));
				}
			}
			else
			{
				unshift(@pathItems, $page->param($translate));
			}
		}
		unshift(@pathItems, $path->{id});
		$path = $path->{parent};
	}

	my $url = join('/', @pathItems);
	$url .= '/' . $self->getVirtualChildURL($page, @_) if ($self->{flags} & COMPFLAG_VIRTUALCHILDREN) && $page->flagIsSet(XAP::CGI::Page::CGIPAGEFLAG_HAVEVIRTUALCHILDPATH());
	return $url;
}

sub getPathAsMenuItems
{
	my XAP::Component $self = shift;
	my $page = shift;
	my @menu = ();

	my XAP::Component $parentComp = $self->{parent};
	while($parentComp)
	{
		unshift(@menu, [$parentComp->getCaption(), $parentComp->getURL($page)]);
		$parentComp = $parentComp->{parent};
	}
	
	if(($self->{flags} & COMPFLAG_VIRTUALCHILDREN) && $page->flagIsSet(XAP::CGI::Page::CGIPAGEFLAG_HAVEVIRTUALCHILDPATH()))
	{
		push(@menu, [$self->getCaption(), '']);
		push(@menu, $self->getVirtualChildPathAsMenuItems($page, @_));
	}
	else
	{
		push(@menu, [$self->getCaption(), $self->getURL($page)]);
	}
	return @menu;
}

sub getSiblingsAsMenuItems
{
	my XAP::Component $self = shift;
	my $page = shift;

	# if we don't have children, the caller probably wants our siblings, so go up the chain
	return $self->{parent}->getChildrenAsMenuItems($page) if $self->{parent};
}

sub getChildrenAsMenuItems
{
	my XAP::Component $self = shift;
	my $page = shift;

	# if we have children ourselves, pass them back
	if($self->{childCompList})
	{
		my @items = ();
		foreach (@{$self->{childCompList}})
		{
			push(@items, $_) if $_->{flags} & COMPFLAG_URLADDRESSABLE;
		}
		return @items;
	}

	return undef;
}

# --- validity functions -----------------------------------------------------

sub needsValidation
{
	#my XAP::Component $self = shift;
	return 0;
}

sub invalidate
{
	my XAP::Component $self = shift;
	my $page = shift;
	$page->paramValidationError($self->{id}, @_);
}

sub isValid
{
	#my XAP::Component $self = shift;
	#my ($parent, $vFlags) = @_:
	return 1;
}

sub addError
{
	my XAP::Component $self = shift;
	$self->{errors} = [] unless $self->{errors};
	push(@{$self->{errors}}, @_);
	print STDERR join("\n", @_) if $self->{flags} & COMPFLAG_PRINTERRORS;
}

sub addWarning
{
	my XAP::Component $self = shift;
	$self->{warnings} = [] unless $self->{warnings};
	push(@{$self->{warnings}}, @_);
	print STDERR join("\n", @_) if $self->{flags} & COMPFLAG_PRINTERRORS;
}

# --- flag-management functions ----------------------------------------------
#
#   $self->updateFlag($mask, $onOff) -- either turn on or turn off $mask
#   $self->setFlag($mask) -- turn on $mask
#   $self->clearFlag($mask) -- turn off $mask
#   $self->flagIsSet($mask) -- return true if any $mask are set

sub flagsAsStr
{
	my XAP::Component $self = shift;
	my $str = unpack("B32", pack("N", $self->{flags}));
	$str =~ s/^0+(?=\d)// if $_[0]; # otherwise you'll get leading zeros
	return $str;
}

sub updateFlag
{
	my XAP::Component $self = shift;
	if($_[1])
	{
		$self->{flags} |= $_[0];
	}
	else
	{
		$self->{flags} &= ~$_[0];
	}
}

sub setFlag
{
	my XAP::Component $self = shift;
	$self->{flags} |= $_[0];
}

sub clearFlag
{
	my XAP::Component $self = shift;
	$self->{flags} &= ~$_[0];
}

sub flagIsSet
{
	my XAP::Component $self = shift;
	return $self->{flags} & $_[0];
}

sub getFlags
{
	my XAP::Component $self = shift;
	return $self->{flags};
}

# --- HTML functions ----------------------------------------------------

sub getHeading
{
	my XAP::Component $self = shift;
	return $self->{heading} || $self->{caption};
}

sub getCaption
{
	my XAP::Component $self = shift;
	return $self->{caption} || $self->{heading};
}

sub getBodyHtml
{
	return 'NO BODY HTML';
}

sub dumpDebugInfo
{
	my XAP::Component $self = shift;
	my ($level, $data) = @_;

	$level = 0 unless defined $level;
	$data = [] unless defined $data;

	my $indent = '  'x$level;
	push(@$data, $indent . qq{ I am a @{[ ref $self ]}, with the id '@{[ $self->{id} ? $self->{id} : 'NOID' ]}' (@{[ $self->getPathAsStr() ]}) });
	push(@$data, $indent . qq{ I have @{[ scalar(@{$self->{childCompList}}) ]} children. }) if $self->{childCompList};

	if($self->{childCompList})
	{
		foreach (@{$self->{childCompList}})
		{
			$_->dumpDebugInfo($level+1, $data);
		}
	}

	if($level == 0)
	{
		print join("\n", @$data);
	}
}

# --- page-management functions ----------------------------------------

sub initVirtualChildPath
{
	die "initVirtualChildPath should be overriden in a child class";
}

sub reportTemplateError
{
	my %args = @_;
	my XAP::Component $self = $args{arg}->[0];
	my ($page, $flags) = ($args{arg}->[1], $args{arg}->[2]);

	my $stackTrace = '';
	my $start = 0;
	my ($package, $fileName, $line) = caller($start);
	while($fileName)
	{
		$stackTrace .= "<BR>$fileName line $line";
		($package, $fileName, $line) = caller(++$start);
	}

	return qq{
		<h1>Template processing error</h1>
		<table>
			<tr>
				<td align="right">Text:</td><td><code>$args{text}</code></td>
				<td align="right">Error:</td><code>$args{error}</code><td></td>
				<td align="right">Line:</td><code>$args{lineno}</code><td></td>
				<td align="right">Stack:</td><code>$stackTrace</code><td></td>
			</tr>
		</table>
	};
}

sub getPageTemplate
{
	my XAP::Component $self = shift;
	my ($page, $flags) = @_;

	# if the page has overriden a pagebody, then use it
	return $page->{pageTemplate} if exists $page->{pageTemplate} && $page->{pageTemplate};

	# if we have a body ourselves, pass it back
	return $self->{pageTemplate} if $self->{pageTemplate};

	# if we get to here, see if there are any to inherit
	my $template = $self->getComponent('.../page.body', $page, $flags);
	return ($template && $template->isa('XAP::Component::Template')) ? $template->getTemplate() : 'NO PAGE TEMPLATE';
}

sub getPageHtml
{
	my XAP::Component $self = shift;
	my ($page, $flags) = @_;

	$page->addComponent($self);
	my $controller = $self->getComponent('.../controller', $page, $flags);
	my $html = '';
	my $component = $self;
	
	# if we're getting the page HTML, we're the "main" component
	$page->{mainComponent} = $self;
	$page->{page_controller} = $controller;

	my ($preInitMethod, $initMethod) = ($self->can(CUSTOMMETHODNAME_PAGEPREINIT()), $self->can(CUSTOMMETHODNAME_PAGEINIT()));
	unless($preInitMethod)
	{
		my XAP::Component $path = $self->{parent};
		while($path)
		{
			last if $preInitMethod = $path->can(CUSTOMMETHODNAME_PAGEPREINIT());
			$path = $path->{parent};
		}
	}

	$self->initVirtualChildPath($page, $flags, @{$page->{page_virtChildPathItems}}) if $page->flagIsSet(XAP::CGI::Page::CGIPAGEFLAG_HAVEVIRTUALCHILDPATH());

	unless($initMethod)
	{
		my XAP::Component $path = $self->{parent};
		while($path)
		{
			last if $initMethod = $path->can(CUSTOMMETHODNAME_PAGEINIT());
			$path = $path->{parent};
		}
	}

	&$preInitMethod($self, $page) if $preInitMethod;
	if(my $sessType = ($self->{sessType} || $controller->getSessionType()))
	{
		$controller->establishSession($page, $flags);

		if(	($page->sessionStatus() == XAP::CGI::Page::SESSIONSTATUS_ACTIVE()) &&
			($sessType == SESSIONTYPE_PERSON()) &&
			(! exists $page->{page_session}->{user_id}))
		{
			if($page->param('doLogin'))
			{
				# we're being called from the login dialog and we need to "execute" it so session
				# is set properly (we then try to establish the session again (if session was
				# invalid, login should happen again)) -- the BIG assumption here is that
				# the login dialog has setup the user_id appropriately
				#
				my $dialog = $self->getComponent($self->{sessLoginCompId}, $page, $flags);
				$dialog->getBodyHtml($page, $flags);
				$component = $dialog unless $dialog->getActiveFlags($page) & XAP::Component::Dialog::DLGFLAG_EXECUTE();
			}
			else
			{
				# we're not being called from a login dialog so call our login dialog now.
				# we do this by replacing "self" with a given login dialog component (faking it).
				# we keep the main component as $self because that's the URL we want to keep
				# when we come back
				#
				$component = $self->getComponent($self->{sessLoginCompId}, $page, $flags);
				die "Unable to locate a '$self->{sessLoginCompId}' component" unless $component;
			}
		}
	}
	&$initMethod($self, $page) if $initMethod && $component eq $self;

	my $processor = $component->{templateProcessor} ?
		$component->{templateProcessor} :
		new Text::Template(
				TYPE => 'STRING',
				SOURCE => $component->getPageTemplate($page, $flags),
				PREPEND => q{
					use strict;
					use vars qw($self $page $mc $flags $controller);
					use XAP::Component;
					},
				BROKEN => \&reportTemplateError, BROKEN_ARGS => [$self, $page, $flags],
				DELIMITERS => ['<%', '%>'],
				);

	no strict 'refs';
	my $package = (ref $component) . '::TMPL_NS';
	${"$package\::controller"} = $controller;
	${"$package\::self"} = $component;
	${"$package\::mc"} = $self;     # the main component is always us, especially when logging in
	${"$package\::page"} = $page;
	${"$package\::flags"} = $flags;

	$html = $processor->fill_in(PACKAGE => $package);

	my $httpHeader = $page->getHttpHeader();
	$html = $page->flagIsSet(XAP::CGI::Page::CGIPAGEFLAG_ISREDIRECT()) ? $httpHeader : ($httpHeader . $html);
	$controller->applyFilters(\$html, $page, $flags);

	delete $page->{page_session};
	delete $page->{page_controller};
	delete $page->{mainComponent};

	return $html;
}

sub processPage
{
	my $class = shift;
	my ($url, $page) = @_;
	
	my $count = 0;
	FIND_COMPONENT:
	if(my XAP::Component $comp = $ROOT_COMPONENT->findComponentForURL($url, $page, 0))
	{	
		if($comp->sourceChanged() || $page->param('_reload'))
		{
			$count++;
			if($count < 2)
			{
				$ROOT_COMPONENT->clearEntries();
				$ROOT_COMPONENT->readEntries();
				$page->addDebugStmt("Components reloaded.");
				goto FIND_COMPONENT;
			}
		}
		print $comp->getPageHtml($page, 0);
	}
	else
	{
		print $page->header();
		print "Component at '$url' not found";
	}

	undef $page;	
}

# --- XML functions ----------------------------------------------------

sub getXML
{
	#my XAP::Component $self = shift;
	#my ($page, $flags) = @_;

	return '';
}

# --- DBMS functions ----------------------------------------------------

sub importFromDBI
{
	#my XAP::Component $self = shift;
	#my ($schema, $dbh) = @_;

	#
	# return 0 if we're not going to process the tree, 1 if we processed it
	#
	return 0;
}

1;
