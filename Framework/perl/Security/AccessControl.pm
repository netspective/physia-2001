##############################################################################
package Security::AccessControl;
##############################################################################

use strict;
use Exporter;
use XML::Parser;
use Set::IntSpan;
use File::Basename;
use File::Spec;

use vars qw(@ISA @EXPORT $cachedCtrlFiles);

@EXPORT = qw(
	RESTRICTPERMISSIONFLAG_OWNERPERSON RESTRICTPERMISSIONFLAG_OWNERORG RESTRICTPERMISSIONFLAG_CUSTOM
	RESTRICTPERMISSIONFLAGS_DEFAULT
	);
$cachedCtrlFiles = {} ;  # useful in Velocigen/mod_perl environment

sub clearCache
{
	$cachedCtrlFiles = {};
}

use constant PERMISSIONINFOIDX_LISTINDEX        => 0;
use constant PERMISSIONINFOIDX_ID               => 1;
use constant PERMISSIONINFOIDX_CHILDPERMISSIONS => 2;

use constant ROLEINFOIDX_LISTINDEX   => 0;
use constant ROLEINFOIDX_ID          => 1;
use constant ROLEINFOIDX_PERMISSIONS => 2;

use enum qw(BITMASK:RESTRICTPERMISSIONFLAG_ OWNERPERSON OWNERORG CUSTOM);
use constant RESTRICTPERMISSIONFLAGS_DEFAULT => 0;

sub new
{
	my $type = shift;
	my %params = @_;

	if(exists $params{xmlFile} && exists $cachedCtrlFiles->{$params{xmlFile}})
	{
		return $cachedCtrlFiles->{$params{xmlFile}};
	}

	my $properties =
		{
			fileLevel => 0,      # 0 for primary, greater than zero for include level
			sourceFiles =>
				{
					primaryPath => '',
					primary => '',
					includePaths => [],
					includes => [],
				},
			defineVars => {},
			permissionIds   => {}, # key is permission name, value is index in permissionsList
			permissionList  => [], # key is ID, value is permission name
			roleIds => {},
			roleList => [],
		};

	my %dontKeepParams = (xmlObjNode => 1, xmlFile => 1, dbConnectKey => 1);

	foreach (keys %params)
	{
		next if exists $dontKeepParams{$_};
		next if ! defined $params{$_};
		$properties->{$_} = $params{$_};
	}

	my $self = bless $properties, $type;

	$self->define(xmlObjNode => $params{xmlObjNode}) if exists $params{xmlObjNode};
	if($params{xmlFile})
	{
		$self->define(xmlFile => $params{xmlFile});
		$cachedCtrlFiles->{$params{xmlFile}} = $self if $self->{fileLevel} == 0;
	}

	return $self;
}

sub defineVar
{
	my $self = shift;
	$self->{defineVars}->{$_[0]} = defined $_[1] ? $_[1] : 1;
}

sub undefineVar
{
	my $self = shift;
	delete $self->{defineVars};
}

sub expandIncludeFile
{
	my $self = shift;
	my $sourceFile = shift;

	my $filedir = dirname($sourceFile);
	if($filedir eq '.')
	{
		my $found = 0;
		my $try = '';
		foreach (@{$self->{sourceFiles}->{includePaths}})
		{
			$try = File::Spec->catfile($self->{sourceFiles}->{primaryPath}, $sourceFile);
			if(-f $try)
			{
				$found = 1;
				$sourceFile = $try;
				last;
			}
		}
		if(! $found)
		{
			die "Unable to locate include file $sourceFile.\n;  Looked in: " . join(", ", @{$self->{sourceFiles}->{includePaths}}) . "\n";
		}
	}
	return $sourceFile;
}

sub readXML
{
	my $self = shift;
	my $sourceFile = shift;
	my $include = defined $_[0] ? shift : 0;

	if(! $include)
	{
		$self->{sourceFiles}->{primary} = $sourceFile;
		$self->{sourceFiles}->{primaryPath} = dirname($sourceFile);
		unshift(@{$self->{sourceFiles}->{includePaths}}, $self->{sourceFiles}->{primaryPath});
	}
	else
	{
		push(@{$self->{sourceFiles}->{includes}}, $self->expandIncludeFile($sourceFile));
	}

	my ($parser, $document);
	eval
	{
		$parser = new XML::Parser(Style => 'Objects', Pkg => 'ControlXML');
		$document = $parser->parsefile($sourceFile);
	};
	die "Error parsing control information in $sourceFile\n$@\n" if $@;

	$self->{fileLevel}++ if $include;
	$self->define(xmlObjNode => $document->[0]);
	$self->{fileLevel}-- if $include;
}

sub definePermissions
{
	my ($self, $activeNode, @parentNodes) = @_;

	my $permissionList = $self->{permissionList};
	my $permissionIds = $self->{permissionIds};

	my $newIndex = scalar(@$permissionList);
	my $parentId = '';
	foreach (@parentNodes)
	{
		$parentId .= ($parentId ? '/' : '') . ($_->{root} || $_->{id});
		$permissionIds->{$parentId}->[PERMISSIONINFOIDX_CHILDPERMISSIONS]->insert($newIndex);
	}
	my $activeId = ($parentId ? "$parentId/" : '') . ($activeNode->{root} || $activeNode->{id});
	my $permissionInfo = [ $newIndex, $activeId, new Set::IntSpan ];
	push(@$permissionList, $permissionInfo);
	$permissionIds->{$activeId} = $permissionInfo;
	$permissionInfo->[PERMISSIONINFOIDX_CHILDPERMISSIONS]->insert($newIndex);

	foreach my $childNode (@{$activeNode->{Kids}})
	{
		if($childNode->isa('ControlXML::permission'))
		{
			$self->definePermissions($childNode, @parentNodes, $activeNode);
		}
	}
}

sub defineRoles
{
	my ($self, $activeNode, @parentNodes) = @_;

	my $roleList = $self->{roleList};
	my $roleIds = $self->{roleIds};
	my $permissionIds = $self->{permissionIds};

	my $newIndex = scalar(@$roleList);
	my $parentId = '';
	foreach (@parentNodes)
	{
		$parentId .= ($parentId ? '/' : '') . ($_->{root} || $_->{id});
	}
	my $activeId = ($parentId ? "$parentId/" : '') . ($activeNode->{root} || $activeNode->{id});
	my $roleInfo = [ $newIndex, $activeId, new Set::IntSpan ];
	push(@$roleList, $roleInfo);
	$roleIds->{$activeId} = $roleInfo;

	foreach my $childNode (@{$activeNode->{Kids}})
	{
		if($childNode->isa('ControlXML::role'))
		{
			$self->defineRoles($childNode, @parentNodes, $activeNode);
		}
		elsif($childNode->isa('ControlXML::grant'))
		{
			if(my $permissionInfo = $permissionIds->{$childNode->{permission}})
			{
				$roleInfo->[ROLEINFOIDX_PERMISSIONS] = $roleInfo->[ROLEINFOIDX_PERMISSIONS]->union($permissionInfo->[PERMISSIONINFOIDX_CHILDPERMISSIONS]);
			}
			else
			{
				die "grant permission '$childNode->{permission}' in role '$activeId' does not exist";
			}
		}
		elsif($childNode->isa('ControlXML::revoke'))
		{
			if(my $permissionInfo = $permissionIds->{$childNode->{permission}})
			{
				$roleInfo->[ROLEINFOIDX_PERMISSIONS] = $roleInfo->[ROLEINFOIDX_PERMISSIONS]->diff($permissionInfo->[PERMISSIONINFOIDX_CHILDPERMISSIONS]);
			}
			else
			{
				die "revoke permission '$childNode->{permission}' in role '$activeId' does not exist";
			}
		}
	}
}

sub define
{
	my $self = shift;
	my %params = @_;

	if(exists $params{xmlFile})
	{
		$self->readXML($params{xmlFile}, exists $params{include} ? $params{include} : 0);
	}
	elsif(exists $params{xmlObjNode})
	{
		my $xmlNode = $params{xmlObjNode};
		die "only accesscontrol tags allowed here: $xmlNode" unless $xmlNode->isa('ControlXML::accesscontrol');

		if($self->{fileLevel} == 0)
		{
			die "accesscontrol name is required" unless $xmlNode->{name};
			$self->{name} = $xmlNode->{name};
		}

		foreach my $childNode (@{$xmlNode->{Kids}})
		{
			if($childNode->isa('ControlXML::permissions'))
			{
				$self->definePermissions($childNode);

			}
			elsif($childNode->isa('ControlXML::roles'))
			{
				$self->defineRoles($childNode);
			}
			elsif($childNode->isa('ControlXML::include'))
			{
				# some includes may be conditional, depending upon a variable like "build"
				# or "run"
				if(my $ifdef = (exists $childNode->{ifdefined} ? $childNode->{ifdefined} : undef))
				{
					next if ! exists $self->{defineVars}->{$ifdef};
				}
				if(my $ifnotdef = (exists $childNode->{ifnotdefined} ? $childNode->{ifnotdefined} : undef))
				{
					next if exists $self->{defineVars}->{$ifnotdef};
				}

				my $file = $self->expandIncludeFile($childNode->{file});
				if(grep { $_ eq $file } @{$self->{sourceFiles}->{includes}})
				{
					# include file already included
					next;
				}
				$self->define(xmlFile => $file, include => 1);
			}
			else
			{
				warn "unknown node type encountered: $childNode\n" if ! $childNode->isa('ControlXML::Characters');
			}
		}
	}
}

sub getPermissionsDict
{
	return $_[0]->{permissionIds};
}

sub getPermissionsList
{
	return $_[0]->{permissionList};
}

sub getRolesDict
{
	return $_[0]->{roleIds};
}

sub getRolesList
{
	return $_[0]->{roleList};
}

sub getPermissionInfo
{
	my $self = shift;
	my $dictionary = $self->{permissionIds};
	my $list = $self->{permissionList};

	if(scalar(@_) == 1 && ! ref $_[0])
	{
		my $item = $_[0];
		my $info = ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item]));
		return $info unless wantarray;
		return ($info) if wantarray;
	}

	my @output = ();
	foreach my $item (@_)
	{
		if(ref $item eq 'ARRAY')
		{
			foreach my $item (@$item)
			{
				push(@output, ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item])));
			}
		}
		else
		{
			push(@output, ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item])));
		}
	}
	return @output;
}

sub getRoleInfo
{
	my $self = shift;
	my $dictionary = $self->{roleIds};
	my $list = $self->{roleList};

	if(scalar(@_) == 1 && ! ref $_[0])
	{
		my $item = $_[0];
		my $info = ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item]));
		return $info unless wantarray;
		return ($info) if wantarray;
	}

	my @output = ();
	foreach my $item (@_)
	{
		if(ref $item eq 'ARRAY')
		{
			foreach my $item (@$item)
			{
				push(@output, ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item])));
			}
		}
		else
		{
			push(@output, ($item =~ m/^\d+$/ ? ($dictionary->{item}) : ($list->[$item])));
		}
	}
	return @output;
}

sub getPermissionsForRoles
{
	my ($self, $roles) = @_;
	my $permissions = new Set::IntSpan;
	my $allRoles = $self->{roleIds};

	foreach ($roles)
	{
		if(my $roleInfo = $allRoles->{$_})
		{
			$permissions = $roleInfo->[ROLEINFOIDX_PERMISSIONS]->union($permissions);
		}
	}

	return $permissions;
}

sub dumpACL
{
	my ($self) = @_;
	print "Permissions (and their child permissions indexes)\n";
	foreach my $item (sort keys %{$self->{permissionIds}})
	{
		print "$item: " . $self->{permissionIds}->{$item}->[PERMISSIONINFOIDX_CHILDPERMISSIONS]->run_list() . "\n";
	}
	print "Roles (and their permissions indexes)\n";
	foreach my $item (sort keys %{$self->{roleIds}})
	{
		next unless $self->{roleIds}->{$item}->[ROLEINFOIDX_PERMISSIONS];
		print "$item: " . $self->{roleIds}->{$item}->[ROLEINFOIDX_PERMISSIONS]->run_list() . "\n";
	}
}

1;