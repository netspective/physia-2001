##############################################################################
package App::ResourceDirectory;
##############################################################################

use strict;
use App::Universal;
use App::Configuration;
use App::Page;
use App::Page::Error;
use XML::Generator;
use File::Spec;
use CGI qw(unescape);
use CGI::ImageManager;

use constant RESOURCE_NAME_SEPERATOR => '-';
use constant PAGE_RESOURCE_PREFIX => 'page' . RESOURCE_NAME_SEPERATOR;
use constant DIALOG_RESOURCE_PREFIX => 'dlg' . RESOURCE_NAME_SEPERATOR;
use constant COMPONENT_RESOURCE_PREFIX => 'comp' . RESOURCE_NAME_SEPERATOR;

use vars qw(@COMPONENT_CATALOG %PAGE_FLAGS %RESOURCES %RESOURCE_TYPES $ACCESS_CONTROL);

##############################################################################
# Directory of all available StatementManager Objects
##############################################################################

use App::Statements::Component;
use App::Statements::Component::Person;
use App::Statements::Component::Org;
use App::Statements::Component::Invoice;
use App::Statements::Component::Scheduling;
use App::Statements::Component::SDE;
use App::Statements::Component::WorkList;
use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Statements::IntelliCode;
use App::Statements::Invoice;
use App::Statements::Org;
use App::Statements::Page;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Statements::Transaction;
use App::Statements::Report::Accounting;
use App::Statements::Device;

#
# the following hash is create to keep track of "how" components
# are created or accessed (for logging, debugging, etc)
#

%RESOURCE_TYPES = (
	'Components' => {
		baseDir => File::Spec->catfile($App::Configuration::CONFDATA_SERVER->path_root, 'Lib', 'perl', 'App', 'Component'),
		prefix => COMPONENT_RESOURCE_PREFIX,
	},
	'Pages' => {
		baseDir => File::Spec->catfile($App::Configuration::CONFDATA_SERVER->path_root, 'Lib', 'perl', 'App', 'Page'),
		prefix => PAGE_RESOURCE_PREFIX,
	},
	'Dialogs' => {
		baseDir => File::Spec->catfile($App::Configuration::CONFDATA_SERVER->path_root, 'Lib', 'perl', 'App', 'Dialog'),
		excludeDirs => ['Report', 'Field', 'Directory', 'HandHeld'],
		prefix => DIALOG_RESOURCE_PREFIX,
	},
);


# Build IMAGETAGS hash at startup
my %IMAGE_TYPES = (
	'resources' => {
		baseDir => File::Spec->catfile($App::Configuration::CONFDATA_SERVER->path_WebSite, 'resources'),
		baseUrl => '/resources',
		excludeDirs => [],
	},
);
CGI::ImageManager::buildImageTags(\%IMAGE_TYPES);


# st-* are the default statement components
# stp-* are the statement panel components
# stpe-* are the statement panelEdit components
@COMPONENT_CATALOG = (
		$STMTMGR_COMPONENT_PERSON,
		$STMTMGR_COMPONENT_SDE,
		$STMTMGR_COMPONENT_ORG,
		$STMTMGR_COMPONENT_INVOICE,
		$STMTMGR_COMPONENT_WORKLIST,
		$STMTMGR_PAGE,
	);

# Build the master RESOURCES hash based on RESOURCE_TYPES and COMPONENT_CATALOG
buildResources(\%RESOURCES, \%RESOURCE_TYPES, \@COMPONENT_CATALOG);

$ACCESS_CONTROL = buildAccessControl();


##############################################################################
# Utility functions
##############################################################################

sub overrideClass
{
	my ($className) = @_;

	#
	# see if our page should be overriden
	#
	eval
	{
		my ($personId, $orgId) = CGI::Page::getActiveUser();
		if(defined $personId && defined $orgId)
		{
			warn "Got back $personId $orgId from getActiveUser";
			my $tryClass = $$className;
			my $findId = $personId;
			$tryClass =~ s/^App::/$findId\::/;

			my $file = $tryClass;
			$file =~ s!::!/!g;
			$file = File::Spec->catfile($CONFDATA_SERVER->path_PersonLib, $file) . '.pm';

			if(-f $file)
			{
				require $file;
				${$className} = "Person::$tryClass";
				return;
			}

			$tryClass = $$className;
			$findId = $orgId;
			$tryClass =~ s/^App::/$findId\::/;

			$file = $tryClass;
			$file =~ s!::!/!g;
			$file = File::Spec->catfile($CONFDATA_SERVER->path_OrgLib, $file) . '.pm';

			if(-f $file)
			{
				require $file;
				${$className} = "Org::$tryClass";
				return;
			}
		}
	};
}


sub handlePage
{
	my ($resource, $arl, $flags, $params, $pathItems) = @_;
	my $pathIndex = 0;
	my %arlParams = ();
	
	while (defined $pathItems->[$pathIndex])
	{
		print STDERR "pathIndex = $pathIndex\n";
		if (defined $resource->{_arlParams})
		{
			my $resourceArlParams = ref($resource->{_arlParams}) eq 'ARRAY' ? $resource->{_arlParams} : [$resource->{_arlParams}];
			foreach (@$resourceArlParams)
			{
				$arlParams{$_} = $pathItems->[$pathIndex];
				$pathIndex++;
			}
		}

		if (defined $resource->{$pathItems->[$pathIndex]})
		{
			my $subResource = $resource->{$pathItems->[$pathIndex]};
			if (ref $subResource eq 'HASH')
			{
				$resource = $subResource;
				$pathIndex++;
			}
		}
		else
		{
			last;
		}
	}
	
	if (defined $resource->{_default} && ref($resource->{_default}) eq 'HASH')
	{
		$resource = $resource->{_default};
	}

	unless (defined $resource->{_id} && defined $resource->{_class})
	{
		return 'ARL-000200';
	}

	my $resourceId = $resource->{_id};
	my $pageClass = $resource->{_class};
	overrideClass(\$pageClass);
	
	print STDERR "Resource ID = $resourceId\n";
	print STDERR "pageClass = $pageClass\n";

	my $page = $pageClass->new();
	#$page->addDebugStmt("Class is $pageClass");
	$page->property('resourceMap', $resource);
	foreach (keys %{$resource})
	{
		#$page->property($_, $resource->{$_});
	}

	#
	# some pages will need their own ARLs for calling themselves as popups, so set it up now
	#
	my $arlAsPopup = $arl;
	$arlAsPopup =~ s|^(\w+)|$1\-p|;

	# Remove the resource prefix from the ID
	my $prefix = PAGE_RESOURCE_PREFIX;
	$resourceId =~ s|^$prefix||;
	
	# Currently the page assumes that the first ARL item isn't included in $pathItems
	shift @$pathItems;

	$page->param('arl', $arl);
	$page->param('arl_asPopup', $arlAsPopup);
	$page->param('arl_resource', $resourceId);
	$page->param('arl_pathItems', @$pathItems) if $pathItems;
	$page->param('_isPopup', 1) if $flags & PAGEFLAG_ISPOPUP;
	
	foreach (keys %arlParams)
	{
		$page->param($_, $arlParams{$_});
	}

	$page->setFlag($flags);

	# CGI.pm doesn't auto parse the URL Query String if we're in POST mode
	if ($ENV{REQUEST_METHOD} eq 'POST')
	{
		$page->parse_params($params);
	}

	return $page->handleARL($arl, $params, $resourceId, $pathItems);
}


%PAGE_FLAGS =
(
	'f'  => PAGEFLAG_ISFRAMESET,
	'fh' => PAGEFLAG_ISFRAMEHEAD,
	'fb' => PAGEFLAG_ISFRAMEBODY,
	'p'  => PAGEFLAG_ISPOPUP,
	'a'  => PAGEFLAG_ISADVANCED,
);


sub handleARL
{
	my ($arl) = @_;

	my $errorCode = 'ARL-000100'; # invalid ARL
	my $flags = 0;


	# Look for (and remove) page flags in the ARL
	if ($arl =~ s{^(\w+)\-(\w+)/}{$1/})
	{
		$flags |= $PAGE_FLAGS{$2};
	}
	
	my($resPath, $params) = split(/\?/, $arl);
	$resPath = 'search' unless $resPath;
	$resPath = PAGE_RESOURCE_PREFIX . $resPath;
	my @pathItems = split(/\//, unescape($resPath));

	$errorCode = handlePage(\%RESOURCES, $arl, $flags, $params, \@pathItems);
	
	if($errorCode)
	{
		my $page = new App::Page::Error;
		$page->param('errorcode', $errorCode);
		$page->printContents();
	}
}


##############################################################################
# Resource Builder Functions
##############################################################################

sub buildResources
{
	my ($RESOURCES, $RESOURCE_TYPES, $COMPONENT_CATALOG) = @_;

	# Auto-Generate Resources from RESOURCE_TYPES
	foreach my $type (keys %$RESOURCE_TYPES)
	{
		my $baseDir = defined $$RESOURCE_TYPES{$type}->{baseDir} ? $$RESOURCE_TYPES{$type}->{baseDir} : '';
		my $prefix = defined $$RESOURCE_TYPES{$type}->{prefix} ? $$RESOURCE_TYPES{$type}->{prefix} : '';
		my $excludeDirs = defined $$RESOURCE_TYPES{$type}->{excludeDirs} ? $$RESOURCE_TYPES{$type}->{excludeDirs} : [];
		findModules(\&addResourcesFromModule, $baseDir, $excludeDirs, [$RESOURCES, $prefix]) if $baseDir;
	}

	# Auto-Generate StmtMgr Component Resources from COMPONENT_CATALOG
	foreach my $stmtMgr (@$COMPONENT_CATALOG)
	{
		my $resourceName;
		while(my($key, $value) = each %$stmtMgr)
		{
			# the "dpc" keys are the "data publish component callback" functions
			next unless $key =~ m/^_dpc_(\w+?)\_(.*)$/;
			my $resourceData = {};
			$resourceData->{_class} = $value;
			$resourceData->{_stmtMgr} = $stmtMgr;
			$resourceData->{_stmtId} = $2;
			$resourceName = COMPONENT_RESOURCE_PREFIX . "$1-$2";
			next unless registerResource($RESOURCES, "$1-$2", $resourceData, COMPONENT_RESOURCE_PREFIX);
#			$COMPONENT_CATALOG_SOURCE{$resourceName} = [App::Universal::COMPONENTTYPE_STATEMENT, $resourceName, $stmtMgr, $2];
		}
	}

	# Auto-Generate Synonym Resources
	addSynonyms($RESOURCES);
}


# Find perl modules and pass them to a callback function
sub findModules
{
	my $callback = shift;
	my $baseDir = shift;
	my $excludeDirs = shift;
	my $callbackArgs = shift;
	opendir DIR, $baseDir;
	my @entries = readdir DIR;
	closedir DIR;
	foreach my $entry (@entries)
	{
		if ( -f "$baseDir/$entry" )
		{
			next unless $entry =~ /\.pm$/;
			&$callback("$baseDir/$entry", $callbackArgs);
		}
		elsif ( -d "$baseDir/$entry")
		{
			next if grep {$_ eq $entry} @$excludeDirs;
			next if grep {$_ eq $entry} ('CVS','.','..');
			findModules($callback, "$baseDir/$entry", $excludeDirs, $callbackArgs);
		}
	}
}


# Finds/adds resource packages to a hash reference
sub addResourcesFromModule
{
	my $module = shift;
	my $args = shift;
	my $RESOURCES = $$args[0];
	my $prefix = $$args[1];
	my $keepModule = 0;

	# Only want perl module files
	return unless $module =~ /\.pm$/;

	# Check to see if module us already loaded
	foreach (values %INC)
	{
		$keepModule = 1 if $module eq $_;
	}

	# Compile the module into memory
	eval { require $module unless $keepModule == 1; };
	if ($@)
	{
		# Skip module on errors
		die "$@\n";
		$@ = undef;
		return 0;
	}

	# Loop through a list of packages in the module
	my $packages = getPackagesFromModule($module);
	return unless ref $packages eq 'ARRAY';
	foreach my $package (@{$packages})
	{
		no strict 'refs';
		unless (exists ${"${package}::"}{RESOURCE_MAP})
		{
			warn "Package $package doesn't contain a \%RESOURCE_MAP\n";
			# Check to see if an existing resource needs this package;
			$keepModule = 1 if isResourceClass($package, \%RESOURCES);
			next;
		}
		my $resourceMap = \%{"${package}::RESOURCE_MAP"};
		$keepModule = 1;
		foreach (keys %{$resourceMap})
		{
			${$resourceMap}{$_}{_package} = $package;
			registerResource(\%RESOURCES, $_, ${$resourceMap}{$_}, $prefix, $package);
		}
	}

	# Delete compiled modules from memory if not needed
	unless ($keepModule)
	{
		#warn "Dropping unused module $module\n";
		delete $INC{$module};
	}
}

# Register a resource in a hash
sub registerResource
{
	my ($RESOURCES, $resourceId, $resourceData, $prefix, $class) = @_;

	$resourceData->{_id} = $prefix . $resourceId unless exists $resourceData->{_id};

	# If the resource is a sub-resource, envoke the power of recursion
	if ($resourceId =~ /^([^\/]+)\/(.+?)$/)
	{
		$$RESOURCES{$prefix . $1} = {} unless defined $$RESOURCES{$prefix . $1};
		if (ref $$RESOURCES{$prefix . $1} eq 'HASH')
		{
			return registerResource($$RESOURCES{$prefix . $1}, $2, $resourceData, '', $class);
		}
		else
		{
			die "Cannot add a sub-resource '$resourceId' to a parent resource '$1' that is not a hash\n";
			return 0;
		}
	}

	# Make a copy of the resource data (so we don't modify the original)
	my %newResource = $resourceData ? %$resourceData : ( _class => $class );

	# Make sure it has some class
	$newResource{_class} = $class unless defined $newResource{_class} || defined $newResource{_default};

	# Add the prefix to any synonyms
	if (defined $newResource{_idSynonym})
	{
		if (ref $newResource{_idSynonym} eq 'ARRAY')
		{
			@{$newResource{_idSynonym}} = addPrefix($newResource{_idSynonym}, $prefix);
		}
		else
		{
			$newResource{_idSynonym} = addPrefix($newResource{_idSynonym}, $prefix);
		}
	}

	# See if we already have this resource key
	if (defined $$RESOURCES{$prefix . $resourceId})
	{
		my $existingResource = $$RESOURCES{$prefix . $resourceId};
		
		# If the existing resource has a class then we have a duplicate resourceID
		if (defined $existingResource->{_class})
		{
			my $firstClass = $existingResource->{_class};
			die "Cannot create duplicate resource '$prefix$resourceId'.  Conflict between '$firstClass' and '$class'\n";
			return 0;
		}
		
		# We will only get here if a parent resource is getting added after one of it's children
		# Copy of the new stuff into the existing resource
		foreach (keys %newResource)
		{
			$existingResource->{$_} = $newResource{$_};
		}
		
	}
	else
	{
		# Register the resource
		$$RESOURCES{$prefix . $resourceId} = \%newResource;
	}
	return 1;
}


# Adds a prefix string to a string or each string in an array
sub addPrefix
{
	my $resource = shift;
	my $prefix = shift;
	return $prefix . $resource unless ref $resource;
	return '' unless ref $resource eq 'ARRAY';
	foreach (0 .. $#{$resource})
	{
		$$resource[$_] = $prefix . $$resource[$_];
	}
	return (@$resource);
}


# Check to see if the package is already used by a resource in $resource (hash ref)
sub isResourceClass
{
	my ($package, $resources) = @_;
	foreach (keys %{$resources})
	{
		if (ref $_ eq 'SCALAR')
		{
			return 1 if $_ eq $package;
		}
		elsif (ref $_ eq 'HASH')
		{
			return 1 if isResourceClass($package, $_);
		}
	}
	return 0;
}


# Find all packages within a perl module file
sub getPackagesFromModule
{
	my $file = shift;
	my @packages = ();
	open MODULE, $file or return 0;
	while(<MODULE>)
	{
		if (/^\s*package\s+(\S+?)\s*\;/)
		{
			push @packages, $1;
		}
	}
	return \@packages;
}


# Look for _idSynonyms and create additional resources
sub addSynonyms
{
	my $RESOURCES = shift;
	my @RESOURCE_KEYS = keys %$RESOURCES;
	foreach my $Id (@RESOURCE_KEYS)
	{
		next unless ref $$RESOURCES{$Id} eq 'HASH';

		# Search for nested resources
		addSynonyms($$RESOURCES{$Id});

		next unless defined $$RESOURCES{$Id}->{_idSynonym};
		if (ref $$RESOURCES{$Id}->{_idSynonym} eq 'ARRAY')
		{
			foreach (@{$$RESOURCES{$Id}->{_idSynonym}})
			{
				registerResource($RESOURCES, $_, $$RESOURCES{$Id}, '');
			}
		}
		else
		{
			registerResource($RESOURCES, $$RESOURCES{$Id}->{_idSynonym}, $$RESOURCES{$Id}, '');
		}
	}
}


sub buildAccessControl
{
	my $gen = XML::Generator->new('pretty' => 4, 'escape' => 'always', 'conformance' => 'strict', 'namespace' => '');
	my %data = ();

	$data{modes} = [];
	foreach my $mode ('add', 'remove','update', 'view')
	{
		push @{$data{modes}}, $gen->permission({id => $mode});
	}
	$data{root} = [];
	foreach my $type ('comp', 'dlg', 'page')
	{
		$data{$type} = [];
		foreach my $key (sort keys %RESOURCES)
		{
			if ( $key =~ /^$type\-(.*)/ )
			{
				my $id = $1;
				if ($key eq $RESOURCES{$key}{_id}) # Not a Synonym
				{
					$data{sub} = [];
					foreach my $subKey (sort keys %{$RESOURCES{$key}})
					{
						next if $subKey eq '_default';
						if (ref $RESOURCES{$key}{$subKey} eq 'HASH' && exists $RESOURCES{$key}{$subKey}{_class})
						{
							$data{subSub} = [];
							foreach my $subSubKey (sort keys %{$RESOURCES{$key}{$subKey}})
							{
								next if $subSubKey eq '_default';
								if (ref $RESOURCES{$key}{$subKey}{$subSubKey} eq 'HASH' && exists $RESOURCES{$key}{$subKey}{$subSubKey}{_class})
								{
									push @{$data{subSub}}, $gen->permission({id => $subSubKey});
								}
							}
							push @{$data{sub}}, $gen->permission({id => $subKey}, @{$data{subSub}});
						}
					}
					$data{views} = [];
					if ( exists $RESOURCES{$key}{_views} )
					{
						foreach my $view (sort @{$RESOURCES{$key}{_views}})
						{
							push @{$data{views}}, $gen->permission({id => $view->{name}});
						}
					}
					if ($type eq 'dlg')
					{
						if (exists $RESOURCES{$key}{_modes})
						{
							my @modes = ();
							foreach my $mode (@{$RESOURCES{$key}{_modes}})
							{
								push @modes, $gen->permission({id => $mode});
							}
							push @{$data{$type}}, $gen->permission({id => $id}, @modes);
						}
						else
						{
							push @{$data{$type}}, $gen->permission({id => $id}, @{$data{modes}});
						}
					}
					else
					{
						push @{$data{$type}}, $gen->permission({id => $id}, @{$data{sub}}, @{$data{views}});
					}
				}
				else # It's a Synonym
				{
					my $alias;
					$alias = "$type/$1" if $RESOURCES{$key}{_id} =~ /^$type\-(.*)/;
					push @{$data{"alias_$type"}}, $gen->permission({id => $id}, @{[$gen->permission({alias => $alias})]});
				}
			}
		}
		if ($type eq 'dlg')
		{
			push @{$data{root}}, $gen->permissions({root=>"$type"}, @{$data{$type}}, @{$data{"alias_$type"}}, @{$data{modes}});
		}
		else
		{
			push @{$data{root}}, $gen->permissions({root=>"$type"}, @{$data{$type}}, @{$data{"alias_$type"}});
		}
	}
	my $data = '<?xml version="1.0"?>';
	$data .= $gen->accesscontrol({name=>'auto'}, @{$data{root}});

	my $filename = $CONFDATA_SERVER->file_AccessControlAutoPermissons();
	open FH, ">$filename" or die "Can't open new file '$filename'";
	print FH join ">\n<", split '><', $data;
	close FH;
	return \$data;
}

1;
