#
# Define these UNIVERSAL methods so that all XML node classes inherit
# these basic functions
#

sub UNIVERSAL::getNodeName
{
	my $name = ref $_;
	$name =~ s/^\w+:://;
	return $name;
}

sub UNIVERSAL::findElement
{
	foreach (@{$_[0]->{Kids}})
	{
		return $_ if $_->isa("SchemaXML::$_[1]");
	}
	return undef;
}

sub UNIVERSAL::findElementOrAttrValue
{
	return $_[0]->{$_[1]} if exists $_[0]->{$_[1]};
	if(my $node = $_[0]->findElement($_[1]))
	{
		return $node->getTextOnly();
	}
}

sub UNIVERSAL::getBoolAttribute
{
	my ($self, $attrName, $defaultValue) = @_;
	$defaultValue ||= "no";
	return uc(exists $self->{$attrName} ? $self->{$attrName} : $defaultValue) eq "YES";
}

sub UNIVERSAL::getTextOnly
{
	my $textOnly = '';
	foreach (@{$_[0]->{Kids}})
	{
		$textOnly .= $_->{Text} if $_->isa('SchemaXML::Characters');
	}
	return $textOnly;
}

##############################################################################
package Column;
##############################################################################

use strict;
use App::Data::Manipulate;

sub new
{
	my $type = shift;
	my %params = @_;

	die "table parameter required" unless exists $params{table};

	my $properties =
		{
			schema => $params{table}->{schema},
			name => '',
			caption => '',
			abbrev => '',
			type => '',
			sqldefn => '',
			sqlwritefmt => '',
			group => '',
			descr => '',
			required => 0,    # can be 0 (not required), 1 required (normal -- front end + dbms), 2 required only by dbms (not front-end)
			calc => 0,        # can be 0 (not calculated), 1 (trigger)
			unique => 0,      # can be 0 (not unique) or 1 (is unique)
			uniquegrp => '',  # if this column belongs to a group of other columns that together should be unique
			indexed => 0,     # can be 0 (not indexed), 1 (is indexed), 2 (is bitmap indexed -- ORACLE only?)
			indexgrp => '',   # if this column belongs to a group of other columns that together should be indexed
			primarykey => 0,  # can be 0 (not a primary key) or 1 (is a primary key)
			templateFlags => {},
			# ref     => ''   >> this should be defined if type == 'ref'
			# refType => ''   >> this should be defined if type == 'ref'
			# refForward => $ >> 1 if forward reference, 0 if immediate
			# foreignCol => $ >> this should be defined if type == 'ref' or useType != NULL
			# useType => $    >> using a foreign column's type definition?
			# useTypeForward $>> using a foreign column's type def (forward decl)?
			# size => 32      >> this should be defined if a size is needed
			# dbmscustom => {}>> this should be defined if needed
			# foreignRefs => []> this is set if any other tables' cols reference this one (string list only)
			# cache => []      > this is set if this column caches the values of any other columns (string list only)
			# cacheRefs => []  > this is set if any other tables' have "cache" values that reference this column (string list only)
			# copytype           when this column is copied (useType), copy this instead of 'type'
		};

	foreach (keys %params)
	{
		next if $_ eq 'xmlObjNode';
		next if ! defined $params{$_};
		$properties->{$_} = $params{$_};
	}

	my $self = bless $properties, $type;
	$self->define(xmlObjNode => $params{xmlObjNode}) if exists $params{xmlObjNode};

	return $self;
}

sub DESTROY
{
	my $self = shift;

	delete $self->{schema};
	delete $self->{table};
	delete $self->{parent};
	delete $self->{ref};
	delete $self->{sqldefn};
	delete $self->{size};
	delete $self->{dbmscustom};
	delete $self->{foreignRefs};
}

sub getTable()      { return $_[0]->{table}; }
sub getTableName()  { return $_[0]->{table}->{name}; }
sub getName()       { return $_[0]->{name}; }
sub getAbbrev()     { return $_[0]->{abbrev}; }
sub getCaption()    { return $_[0]->{caption} || $_[0]->{name}; }
sub getType()       { return $_[0]->{type}; }
sub getSize()       { return $_[0]->{size}; }
sub isPrimaryKey()  { return $_[0]->{primaryKey}; }
sub isForeignKey()  { return $_[0]->{type} eq 'ref'; }
sub isRequiredUI()  { return $_[0]->{required} == 1; }  # required column for front-end (UI)?
sub isRequiredAny() { return $_[0]->{required} > 0; }   # required column for either front-end (UI) or dbms?
sub isUnique()      { return $_[0]->{unique}; }
sub getUniqueGrp()  { return $_[0]->{uniqueGrp}; }
sub getForeignCol() { return $_[0]->{foreignCol}; }
sub getDefaultVal() { return $_[0]->{default}; }

sub _assignForeignCol
{
	my $self = shift;

	my $foreignKey = $self->{ref};

	die "foreign reference to '$foreignKey' does not exist in $self->{table}->{name}.$self->{name}"
		unless exists $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey};

	$self->{foreignCol} = $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey};
	push(@{$self->{foreignCol}->{foreignRefs}}, "$self->{table}->{name}.$self->{name}");

	$self->{sqldefn} = $self->{foreignCol}->{sqldefn};
	$self->{sqlwritefmt} = $self->{foreignCol}->{sqlwritefmt};
}

sub _assignForeignType
{
	my $self = shift;
	my $foreignKey = $self->{useType};

	die "useType reference to '$foreignKey' ($self->{useTypeForward}) does not exist in $self->{table}->{name}.$self->{name}"
		unless exists $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey};

	$self->{foreignCol} = $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey};
	push(@{$self->{foreignCol}->{useTypeRefs}}, "$self->{table}->{name}.$self->{name}");

	$self->{type} = $self->{foreignCol}->{copytype} || $self->{foreignCol}->{type};
	$self->{size} = $self->{foreignCol}->{size};
	$self->{sqldefn} = $self->{foreignCol}->{sqldefn};
	$self->{sqlwritefmt} = $self->{foreignCol}->{sqlwritefmt};
}

sub foreignKey
{
	my $self = shift;
	my $refType = shift;
	my $foreignKey = uc(shift);

	$self->{type} = 'ref';
	$self->{refType} = $refType;
	$self->{ref} = $foreignKey;

	if(exists $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey})
	{
		$self->{refForward} = 0;
		$self->_assignForeignCol();
	}
	else
	{
		$self->{refForward} = 1;
		$self->{table}->addFixupCol($self);
	}
}

sub useType
{
	my $self = shift;
	my $foreignKey = uc(shift);

	$self->{type} = 'use';
	$self->{useType} = $foreignKey;

	if(exists $self->{schema}->{columns}->{byQualifiedName}->{$foreignKey})
	{
		$self->{useTypeForward} = 0;
		$self->_assignForeignType();
	}
	else
	{
		$self->{useTypeForward} = 1;
		$self->{table}->addFixupCol($self);
	}
}

sub fixup
{
	my $self = shift;

	$self->_assignForeignCol() if $self->{refForward};
	$self->_assignForeignType() if $self->{useTypeForward};
}

sub cache
{
	my $self = shift;
	my $cacheInfo = shift;

	my ($type, $cacheKey) = $cacheInfo =~ /^(\w+:)?(.*)$/;
	$type ||= 'copy:';
	$cacheKey = uc($cacheKey);

	die "reference to cache $cacheKey does not exist in $self->{table}->{name}.$self->{name}" if ! exists $self->{schema}->{columns}->{byQualifiedName}->{$cacheKey};

	my $foreignCol = $self->{schema}->{columns}->{byQualifiedName}->{$cacheKey};
	push(@{$self->{cache}}, "$type$foreignCol->{table}->{name}.$foreignCol->{name}");
	push(@{$foreignCol->{cacheRefs}}, "$type$self->{table}->{name}.$self->{name}");
}

sub define
{
	my $self = shift;
	my %params = @_;

	die "xmlObjNode parameter required" if ! exists $params{xmlObjNode};
	$params{isTemplate} = 0 if ! exists $params{isTemplate};
	$params{isCompositeFragment} = 0 if ! exists $params{isCompositeFragment};
	$params{recurseLevel} = 0 if ! exists $params{recurseLevel};

	my $xmlNode = $params{xmlObjNode};

	die "name attribute is required" unless $xmlNode->{name};
	if($self->{schema}->{verboseLevel} >= 4)
	{
		$self->{schema}->outputMessage(4, "column", $xmlNode->{name}) if ! $params{isTemplate} && ! $params{isCompositeFragment};
		$self->{schema}->outputMessage(5, "inherit datatype", $xmlNode->{name}) if $params{isTemplate};
		$self->{schema}->outputMessage(5, "inherit composite", $xmlNode->{name}) if $params{isCompositeFragment};
	}

	# if we're dealing with a template, name and abbrev are irrelavent
	if(! $params{isTemplate})
	{
		if(! exists $self->{isCompositeFragment})
		{
			$self->{name} = $xmlNode->{name};
			$self->{abbrev} = $xmlNode->{abbrev} || $self->{name};
		}
		elsif($self->{isCompositeFragment})
		{
			die "composite fragments require a parent instance parameter" if ! exists $self->{instance};
			# make any replacements of $name$, $abbrev$ inside the composite fields
			my $realName = $xmlNode->{name};
			$realName =~ s/\$name\$/$self->{instance}->{name}/g;
			$self->{name} = $realName;
			my $realAbbrev = $xmlNode->{abbrev} || $self->{name};
			$realAbbrev =~ s/\$abbrev\$/$self->{instance}->{abbrev}/g;
			$self->{abbrev} = $realAbbrev;
		}
	}

	my @findRef = ('parent', 'self', 'lookup');
	my $foundRefType = '';
	my $actualRef = '';
	foreach my $refType (@findRef)
	{
		if($actualRef = $xmlNode->{$refType . "ref"})
		{
			$foundRefType = $refType;
			$actualRef = $self->{table}->replaceMacros($actualRef);
			$actualRef .= ".id" if $refType eq 'lookup' && $actualRef !~ m/\..*$/;
			last;
		}
	}

	if($foundRefType)
	{
		$self->foreignKey($foundRefType, $actualRef);
	}
	elsif(my $useType = $xmlNode->{usetype})
	{
		$self->useType($self->{table}->replaceMacros($useType));
	}
	elsif($xmlNode->{type})
	{
		$self->{type} = $xmlNode->{type};
		foreach my $inheritType (split(/,/, $self->{type}))
		{
			die "Datatype '$inheritType' in column '$self->{table}->{name}.$self->{name}' is not valid." if ! exists $self->{schema}->{dataDict}->{datatypes}->{$inheritType};
			$self->define(
				xmlObjNode => $self->{schema}->{dataDict}->{datatypes}->{$inheritType},
				isTemplate => 1,
				recurseLevel => $params{recurseLevel} + 1,
				);
		}
	}

	if(my $compositeNode = $xmlNode->findElement('composite'))
	{
		$self->{type} = 'composite';
		foreach (@{$compositeNode->{Kids}})
		{
			next unless $_->isa('SchemaXML::column');
			new Column(
				xmlObjNode => $_,
				table => $self->{table},
				isCompositeFragment => 1,
				recurseLevel => $params{recurseLevel} + 1,
				instance => $self,
				);
		}
	}

	die "unable to determine type for $self->{table}->{name}.$self->{name}" if $self->{type} eq '';

	$self->{caption} = $xmlNode->{caption} if exists $xmlNode->{caption};
	$self->{primarykey} = $xmlNode->getBoolAttribute('primarykey') if exists $xmlNode->{primarykey};
	$self->{unique} = $xmlNode->getBoolAttribute('unique') if exists $xmlNode->{unique};
	$self->{uniquegrp} = $xmlNode->{uniquegrp} if exists $xmlNode->{uniquegrp};
	$self->{indexed} = $xmlNode->getBoolAttribute('indexed') if exists $xmlNode->{indexed};
	$self->{indexgrp} = $xmlNode->{indexgrp} if exists $xmlNode->{indexgrp};
	$self->{group} = $xmlNode->{group} if exists $xmlNode->{group};
	$self->{descr} = $xmlNode->{descr} if exists $xmlNode->{descr};

	if(my $indexed = $xmlNode->{indexed})
	{
		if($indexed eq 'no')
		{
			$self->{indexed} = 0;
		}
		elsif($indexed eq 'yes')
		{
			$self->{indexed} = 1;
		}
		elsif($indexed eq 'bitmap')
		{
			$self->{indexed} = 2;
		}
		else
		{
			die "unknown value for 'indexed' attribute in $self->{table}->{name}.$self->{name} -- must be 'no', 'yes' (simple) or 'bitmap' (bitmapped index)";
		}
	}
	if(my $reqd = exists $xmlNode->{required} ? $xmlNode->{required} : undef)
	{
		if($reqd eq 'no')
		{
			$self->{required} = 0;
		}
		elsif($reqd eq 'yes')
		{
			$self->{required} = 1;
		}
		elsif($reqd eq 'dbms')
		{
			$self->{required} = 2;
		}
		else
		{
			die "unknown value for 'required' attribute in $self->{table}->{name}.$self->{name} -- must be 'no', 'yes' (front-end) or 'dbms' (back-end)";
		}
	}

	if(my $calc = exists $xmlNode->{calc} ? $xmlNode->{calc} : undef)
	{
		if($calc eq 'trigger')
		{
			$self->{calc} = 1;
		}
		elsif($calc eq 'no')
		{
			$self->{calc} = 0;
		}
		else
		{
			die "unknown value for 'calc' attribute in $self->{table}->{name}.$self->{name} -- must be set to 'trigger' or 'no'";
		}
	}

	if(my $dbmsCustomNode = $xmlNode->findElement('dbmscustom'))
	{
		foreach my $dbmsNode (@{$dbmsCustomNode->{Kids}})
		{
			foreach my $dbmsItem (@{$dbmsNode->{Kids}})
			{
				if($dbmsItem->isa('SchemaXML::trigger'))
				{
					push(@{$self->{dbmscustom}->{triggers}->{$dbmsItem->{time}}->{$dbmsItem->{action}}}, $dbmsItem->getTextOnly());
				}
				elsif(! $dbmsItem->isa('SchemaXML::Characters'))
				{
					$self->{dbmscustom}->{$dbmsNode->getNodeName()}->{$dbmsItem->getNodeName()} = $dbmsItem->getTextOnly();
				}
			}
		}
	}

	if(my $sqldefn = $xmlNode->findElementOrAttrValue('sqldefn'))
	{
		$self->{sqldefn} = $sqldefn;
	}
	if(my $sqlwritefmt = $xmlNode->findElementOrAttrValue('sqlwritefmt'))
	{
		$self->{sqlwritefmt} = $sqlwritefmt;
	}
	if(my $descr = $xmlNode->findElementOrAttrValue('description'))
	{
		$self->{descr} = $descr;
	}
	if(my $size = $xmlNode->findElementOrAttrValue('size'))
	{
		$self->{size} = $size;
	}
	if(my $copytype = $xmlNode->findElementOrAttrValue('copytype'))
	{
		$self->{copytype} = $copytype;
	}

	# remember, default values can be "0" so don't just say "if($default)"
	my $default = $xmlNode->findElementOrAttrValue('default');
	if(defined $default)
	{
		$self->{default} = $default;
	}

	if(my $cache = $xmlNode->findElementOrAttrValue('cache'))
	{
		$self->cache($self->{table}->replaceMacros($cache));
	}
	foreach (@{$xmlNode->{Kids}})
	{
		$self->cache($_->getTextOnly()) if $_->isa('SchemaXML::cache');
		$self->{schema}->addGenerateTableColumn($self, $_) if $_->isa('SchemaXML::table');
		$self->{templateFlags}->{$_->{name}} = $_->{value} if $_->isa('SchemaXML::templateflag');
	}

	#
	# only "real" columns should be added to the schema/table
	#
	if(! $params{isTemplate} && $self->{type} ne 'composite')
	{
		die "sqldefn not found: $self->{table}->{name}.$self->{name}" if ! $self->{sqldefn} && ! $self->{refForward} && ! $self->{useTypeForward};
		die "sqlwritefmt not found: $self->{table}->{name}.$self->{name}" if ! $self->{sqlwritefmt} &&  ! $self->{refForward} && ! $self->{useTypeForward};
		die "table column defined twice: $self->{table}->{name}.$self->{name}" if exists $self->{table}->{colsByName}->{$self->{name}};

		my $qualifiedName = uc("$self->{table}->{name}.$self->{name}");
		$self->{schema}->{columns}->{byQualifiedName}->{$qualifiedName} = $self;
		$self->{schema}->outputMessage(5, "qualified name is '" . $qualifiedName . "'");

		push(@{$self->{schema}->{columns}->{byName}->{$self->{name}}}, $self);
		push(@{$self->{schema}->{columns}->{byType}->{$self->{type}}}, $self);

		$self->{table}->{colsByName}->{$self->{name}} = $self;
		push(@{$self->{table}->{colsByType}->{$self->{type}}}, $self);
		if($self->{group})
		{
			foreach my $group (split(/,/, $self->{group}))
			{
				push(@{$self->{table}->{colsByGroup}->{$group}}, $self);
			}
		}

		my $tableColGroups = $self->{table}->{colsByGroup};
		push(@{$self->{table}->{colsInOrder}}, $self);
		push(@{$tableColGroups->{'_foreignKeys'}}, $self) if $self->{type} eq 'ref';
		push(@{$tableColGroups->{'_parentKeys'}}, $self) if $self->{type} eq 'ref' && $self->{refType} eq 'parent';
		push(@{$tableColGroups->{'_selfKeys'}}, $self) if $self->{type} eq 'ref' && $self->{refType} eq 'self';
		push(@{$tableColGroups->{'_lookupKeys'}}, $self) if $self->{type} eq 'ref' && $self->{refType} eq 'lookup';
		push(@{$tableColGroups->{'_primaryKeys'}}, $self) if $self->{primarykey};
		push(@{$tableColGroups->{'_nonPrimaryKeys'}}, $self) if ! $self->{primarykey};
		push(@{$tableColGroups->{'_indexes'}}, $self) if $self->{indexed};
		push(@{$tableColGroups->{'_required'}}, $self) if $self->{required};
		push(@{$tableColGroups->{'_requiredFrontEnd'}}, $self) if $self->{required} == 1;  # remember, value 2 of means is needed only by the dbms (not front-end)
		push(@{$tableColGroups->{'_primaryAndRequiredKeys'}}, $self) if $self->{primarykey} || $self->{required};
		push(@{$tableColGroups->{'_primaryAndRequiredFrontEndKeys'}}, $self) if $self->{primarykey} || $self->{required} == 1;  # remember, value 2 of means is needed only by the dbms (not front-end)
		push(@{$tableColGroups->{'_unique'}}, $self) if $self->{unique};
		push(@{$tableColGroups->{'_generateTables'}}, $self) if $self->{generateTables};

		if(my $uniqGrpName = $self->{uniquegrp})
		{
			push(@{$tableColGroups->{"_uniquegrp_$uniqGrpName"}}, $self);
			my $allGroupsRef = $self->{table}->{colsInUniqueGroups};
			if(exists $allGroupsRef->{$uniqGrpName})
			{
				$allGroupsRef->{$uniqGrpName}++;
			}
			else
			{
				$allGroupsRef->{$uniqGrpName} = 1;
			}
		}
		if(my $indexGrpName = $self->{indexgrp})
		{
			push(@{$tableColGroups->{"_indexgrp_$indexGrpName"}}, $self);
			my $allGroupsRef = $self->{table}->{colsInIndexGroups};
			if(exists $allGroupsRef->{$indexGrpName})
			{
				$allGroupsRef->{$indexGrpName}++;
			}
			else
			{
				$allGroupsRef->{$indexGrpName} = 1;
			}
		}

		my $colNameLen = length($self->{name});
		$self->{table}->{maxColNameLen} = $colNameLen if $colNameLen > $self->{table}->{maxColNameLen};

		# perform table parameter replacements
		$self->{sqldefn} = $self->{table}->replaceMacros($self->{sqldefn}) if $self->{sqldefn};
		$self->{size} = $self->{table}->replaceMacros($self->{size}) if $self->{size};
		$self->{default} = $self->{table}->replaceMacros($self->{default}) if $self->{default};

		# replace any $size$ parameters	in the SQL definition
		if(! $params{isTemplate} && exists $self->{sqldefn})
		{
			$self->{sqldefn} =~ s/\%size\%/$self->{size}/g if exists $self->{size};
		}

		# now just copy all the remaining attributes in the column for later use
		grep
		{
			$self->{$_} = $xmlNode->{$_} unless exists $self->{$_};
		} keys %$xmlNode;
	}
}

sub formatSqlData
{
	my $self = shift;
	my $data = shift;
	
	return unless defined $data;
	$data = App::Data::Manipulate::trim($data);
	return undef if $data =~ /^$/;
	return $data if $self->{sqlwritefmt} eq '$value$';

	my $fmt = $self->{sqlwritefmt};
	$fmt =~ s/\$(\w+)\$/
				if($1 eq 'value')
				{
					$data;
				}
				elsif($1 eq 'escapedTextValue')
				{
					$data =~ s!'!''!g;
					"$data";
				}
				else
				{
					"#$1\_UNDEFINED#";
				}
			/egx;
	return $fmt;
}

sub formatPlaceHolderData
{
	my $self = shift;
	my $data = shift;
	
	return unless defined $data;
	$data = App::Data::Manipulate::trim($data);
	#Just in case a NULL is passed into a non text field change to undef place holders
	#do not appear to like NULLs
	$data = undef if ! m/'\$escapedTextValue\$\'/ && $data eq 'NULL';	
	return $data;
	
}

sub formatPlaceHolder
{
	my $self = shift;
	my $data = shift;	
	my $fmt = $self->{sqlwritefmt};	
	$fmt =~ s/\'\$escapedTextValue\$\'/\$value\$/;
	$fmt =~ s/\'\$value\$\'/\$value\$/;
	return unless defined $data;
	$data = App::Data::Manipulate::trim($data);
	return undef if $data =~ /^$/;	
	return $data if $self->{sqlwritefmt} eq '$value$';		
	$fmt =~ s/\$(\w+)\$/
				if($1 eq 'value')
				{
					$data;
				}
				elsif($1 eq 'escapedTextValue')
				{
					$data =~ s!'!''!g;
					"$data";
				}
				else
				{
					"#$1\_UNDEFINED#";
				}
			/egx;
	return $fmt;
}


sub isValid
{
	my $self = shift;
	return 1;
}

##############################################################################
package TableData;
##############################################################################

use strict;

sub new
{
	my $type = shift;
	my %params = @_;

	die "schema parameter required" unless exists $params{schema};

	my $properties =
		{
			delim => ',',
			blanks => 'ignore',
			tableName => '',
			import => [],
			rows => [],			# contents can be a scalar or an array ref, so check first
		};

	foreach (keys %params)
	{
		next if $_ eq 'xmlObjNode';
		next if ! defined $params{$_};
		$properties->{$_} = $params{$_};
	}

	my $self = bless $properties, $type;
	$self->define(xmlObjNode => $params{xmlObjNode}) if exists $params{xmlObjNode};

	return $self;
}

sub define
{
	my $self = shift;
	my %params = @_;

	die "xmlObjNode param required" unless exists $params{xmlObjNode};
	my $xmlNode = $params{xmlObjNode};

	if($xmlNode->isa('SchemaXML::data'))
	{
		if(my $datadelim = $xmlNode->{delim})
		{
			$self->{delim} = $datadelim;
		}
		if(my $blanks = $xmlNode->{blanks})
		{
			$self->{blanks} = $blanks;
		}
		foreach my $childNode (@{$xmlNode->{Kids}})
		{
			if($childNode->isa('SchemaXML::import'))
			{
				push(@{$self->{import}},
					{
						method => $childNode->{method} || 'load',
						src => $childNode->{src}
					});
			}
			elsif($childNode->isa('SchemaXML::delimrow'))    # entire row is a delimited string
			{
				# get the text and remove all new-lines, and leading and trailing whitespace in
				# case there is any indentation
				my $line = $childNode->getTextOnly();
				$line =~ s/\n//m;   # remove new-lines (line separators)
				$line =~ s/^\s+//m; # remove leading whitespace
				$line =~ s/\s+$//m; # remove trailing whitespace
				next if ! $line;
				push(@{$self->{rows}}, $line);
			}
			elsif($childNode->isa('SchemaXML::delimrows'))   # multiple delimited rows, delimited by newlines
			{
				my $block = $childNode->getTextOnly();
				foreach my $row (split(/\n/, $block))
				{
					$row =~ s/^\s+//m; # remove leading whitespace
					$row =~ s/\s+$//m; # remove trailing whitespace
					next if ! $row;
					push(@{$self->{rows}}, $row);
				}
			}
			elsif($childNode->isa('SchemaXML::row'))      # row is comprised of multiple, named columns
			{
				my $cols = {};
				foreach my $colNode (@{$childNode->{Kids}})
				{
					next unless $colNode->isa('SchemaXML::col');
					if(my $colName = $colNode->{name})
					{
						die "column name $colName does not exist in table $self->{tableName} (data row)" if ! exists $self->{schema}->{columns}->{byQualifiedName}->{uc("$self->{tableName}.$colName")};
						$cols->{$colName} = $colNode->getTextOnly();
					}
				}
				push(@{$self->{rows}}, $cols);
			}
		}
	}
	elsif($xmlNode->isa('SchemaXML::enum'))
	{
		my $row = [];
		my $id = $xmlNode->{id};
		my $caption = $xmlNode->getTextOnly();
		my $abbrv = $xmlNode->{abbrev};

		my $data = { caption => $caption };
		$data->{id} = $id if $id;
		$data->{abbrev} = $abbrv if $abbrv;

		push(@{$self->{rows}}, $data);
	}
}

##############################################################################
package Table;
##############################################################################

use strict;
use XML::Parser;

sub new
{
	my $type = shift;
	my %params = @_;

	die "schema parameter required" unless exists $params{schema};

	my $properties =
		{
			name => '',
			abbrev => '',
			group => '',
			type => '',
			maxColNameLen => 0,
			params => {},
			inherit => [],
			parentTblName => '',
			parentRef => '',
			data => new TableData(schema => $params{schema}),
			childTables => [],
			colsInOrder => [],
			colsByName => {},
			colsByGroup => {},
			colsByType => {},
			colsInUniqueGroups => {},
			colsInIndexGroups => {},
			fixupCols => [],   # cols that require fixups after entire schema is loaded
			templateFlags => {},
		};

	foreach (keys %params)
	{
		next if $_ eq 'xmlObjNode';
		next if ! defined $params{$_};
		$properties->{$_} = $params{$_};
	}

	my $self = bless $properties, $type;
	$self->define(xmlObjNode => $params{xmlObjNode}) if exists $params{xmlObjNode};

	return $self;
}

sub DESTROY
{
	my $self = shift;

	# need to add code to
	# make sure any duplicate references are diposed of properly
}

sub getName()    { return $_[0]->{name} }
sub getType()    { my $inherits = $_[0]->{inherit}; return $inherits->[$#$inherits]; }
sub getTypes()   { return $_[0]->{inherit}; }
sub getAbbrev()  { return $_[0]->{abbrev} }

sub hasColumns
{
	my $self = shift;
	return scalar(@{$self->{colsInOrder}});
}

sub addFixupCol
{
	my ($self, $col) = @_;

	# don't put duplicates in here
	foreach (@{$self->{fixupCols}})
	{
		return if $_ == $col;
	}

	push(@{$self->{fixupCols}}, $col);
	$self->{schema}->addFixupTable($self);
}

sub fixup
{
	my $self = shift;
	foreach my $col (@{$self->{fixupCols}})
	{
		$col->fixup();
	}
}

sub getColIdxFromName
{
	my $self = shift;
	my $colName = shift;

	my $colCount = $self->hasColumns();
	for(my $colIdx = 0; $colIdx < $colCount; $colIdx++)
	{
		return $colIdx if $self->{colsInOrder}->[$colIdx]->{name} eq $colName;
	}
	return undef;
}

sub replaceMacros
{
	my $self = shift;
	my $replaceIn = shift;

	$replaceIn =~ s/\$(\w+)\$/exists $self->{params}->{$1} ? $self->{params}->{$1} : "#PARAM_$1\_UNDEFINED#"/ge if $replaceIn;
	$replaceIn =~ s/\$parentcol\.(\w+)\$/exists $self->{parentColInstance}->{$1} ? $self->{parentColInstance}->{$1} : "#PARENTCOL.$1\_UNDEFINED#"/ge if $replaceIn;
	return $replaceIn;
}

sub define
{
	my $self = shift;
	my %params = @_;
	die "xmlObjNode parameter required" if ! exists $params{xmlObjNode};
	$params{isTemplate} = 0 if ! exists $params{isTemplate};

	my $xmlNode = $params{xmlObjNode};
	die "table name is required" unless $xmlNode->{name};

	my $tblParams = $self->{params};
	if(my $parentInst = $self->{parentTblInstance})
	{
		$tblParams->{"parenttbl_name"} = $parentInst->{name};
		$tblParams->{"parenttbl_Name"} = ucfirst($parentInst->{name});
		$tblParams->{"parenttbl_abbrev"} = $parentInst->{abbrev};
		$tblParams->{"parenttbl_prikey"} = $parentInst->{colsByGroup}->{_primaryKeys}->[0]->{name} if scalar(@{$parentInst->{colsByGroup}->{_primaryKeys}});
	}
	if(my $parentInst = $self->{parentColInstance})
	{
		$tblParams->{"parentcol_name"} = $parentInst->{name};
		$tblParams->{"parentcol_Name"} = ucfirst($parentInst->{name});
		$tblParams->{"parentcol_abbrev"} = $parentInst->{abbrev};
		$tblParams->{"parentcol_short"} = $parentInst->{abbrev} ? $parentInst->{abbrev} : substr($parentInst->{name}, 0, 3);
		$tblParams->{"parentcol_Short"} = ucfirst($tblParams->{"parentcol_short"});
	}

	$self->{name} = $self->replaceMacros($xmlNode->{name}) if ! $params{isTemplate};
	die "table already exists: " . $self->{name} if exists $self->{schema}->{tables}->{byName}->{$self->{name}};

	$self->{abbrev} = $self->replaceMacros($xmlNode->{abbrev}) || $self->{name} if ! $params{isTemplate};
	$self->{data}->{tableName} = $self->{name};

	if($self->{schema}->{verboseLevel} >= 2)
	{
		$self->{schema}->outputMessage(2, "table", $self->{name}) if ! $params{isTemplate};
		$self->{schema}->outputMessage(3, "inherit table", $xmlNode->{name}) if $params{isTemplate};
	}

	# read any parameters that might be needed by the table template(s)
	foreach my $paramNode (@{$xmlNode->{Kids}})
	{
		if($paramNode->isa('SchemaXML::param') && ! exists $self->{params}->{$paramNode->{name}})
		{
			$tblParams->{$paramNode->{name}} = $paramNode->getTextOnly();
		}
		$self->{templateFlags}->{$paramNode->{name}} = $paramNode->{value} if $paramNode->isa('SchemaXML::templateflag');
	}

	my $tableTypes = $xmlNode->{type};
	if($tableTypes)
	{
		foreach my $typeName (split(/,/, $tableTypes))
		{
			die "tabletype '$typeName' not found in table " . $xmlNode->{name} if ! exists $self->{schema}->{dataDict}->{tabletypes}->{$typeName};

			# now "inherit" all of the data from the table template
			$self->define(
				xmlObjNode => $self->{schema}->{dataDict}->{tabletypes}->{$typeName},
				isTemplate => 1);
		}
	}

	if(my $parentTableName = $xmlNode->findElementOrAttrValue('parent'))
	{
		$self->{parentTblName} = $self->replaceMacros($parentTableName);
	}

	foreach my $childNode (@{$xmlNode->{Kids}})
	{
		if($childNode->isa('SchemaXML::column'))
		{
			new Column(xmlObjNode => $childNode, table => $self);
		}
		elsif($childNode->isa('SchemaXML::data'))
		{
			$self->{data}->define(xmlObjNode => $childNode);
		}
		elsif($childNode->isa('SchemaXML::enum'))
		{
			$self->{data}->define(xmlObjNode => $childNode);
		}
		elsif($childNode->isa('Schema::assert'))
		{
			if(my $assertion = $childNode->{check})
			{
				if($assertion eq 'parentTblHasSinglePrimaryKey')
				{
					if(my $parentInst = $self->{parentTblInstance})
					{
						die "Assertion [parentTblHasSinglePrimaryKey] failed: $parentInst->{name} table must have a single primary key ($self->{name})"
							unless scalar(@{$parentInst->{colsByGroup}->{_primaryKeys}}) == 1;
					}
					else
					{
						die "Assertion [parentTblHasSinglePrimaryKey] failed: no parent table found in $self->{name}";
					}
				}
			}
		}
	}

	$self->{descr} = $xmlNode->{descr} if $xmlNode->{descr};
	if(my $descrNode = $xmlNode->findElement('description'))
	{
		$self->{descr} = $descrNode->getTextOnly();
	}

	if(! $params{isTemplate})
	{
		$self->{schema}->{tables}->{byName}->{$self->{name}} = $self;
		push(@{$self->{schema}->{tables}->{asList}}, $self);
		push(@{$self->{schema}->{dbobjects}}, $self);
		if($self->{group})
		{
			foreach my $group (split(/,/, $self->{group}))
			{
				push(@{$self->{schema}->{tables}->{byGroup}->{$group}}, $self);
			}
		}

		# now setup the table in the hieararchy of tables/columns
		if(exists $self->{colsByGroup}->{_parentKeys})
		{
			if($self->{parentRef})
			{
				print STDERR "Table $self->{name} has more than one parentref columns\n";
				push(@{$self->{schema}->{tables}->{hierarchy}}, $self);
			}
			else
			{
				my $parentKey = $self->{colsByGroup}->{_parentKeys}->[0];
				$self->{parentRef} = $parentKey->{ref};
				die "Parent reference $parentKey->{ref} in $self->{name} is invalid. Use selfref instead." if $parentKey->{foreignCol}->{table} == $self;
				push(@{$parentKey->{foreignCol}->{table}->{childTables}}, $self);
			}
		}
		elsif($self->{parentTblName})
		{
			if(exists $self->{schema}->{tables}->{byName}->{$self->{parentTblName}})
			{
				my $parentTable = $self->{schema}->{tables}->{byName}->{$self->{parentTblName}};
				push(@{$parentTable->{childTables}}, $self);
			}
			else
			{
				die "Parent table $self->{parentTblName} does not exist for table $self->{name}";
			}
		}
		else
		{
			push(@{$self->{schema}->{tables}->{hierarchy}}, $self);
		}

		$self->handleSpecialColTypes();
	}
	else
	{
		push(@{$self->{inherit}}, $xmlNode->{name});
	}

	undef $self->{parentTblInstance};
	undef $self->{parentColInstance};
}

sub handleSpecialColTypes
{
	my $self = shift;
}

sub isTableType
{
	my $self = shift;
	my $match = 0;

	foreach my $typeName (@_)
	{
		$match++ if grep { m/$typeName/; } @{$self->{inherit}};
	}

	return $match;
}

sub isOnlyTableType
{
	my $self = shift;

	return (scalar(@{$self->{inherit}}) == 1) && ($self->{inherit}->[0] eq $_[0]);
}

sub getColumnGroups
{
	my $self = shift;
	my $style = shift;

	my $totalCols = scalar(@{$self->{colsInOrder}});
	my @includeCols = ();
	my @colsAlreadyTaken = ();

	for(my $colIdx = 0; $colIdx < $totalCols; $colIdx++)
	{
		# create a temporary map for each column into our "flags" array
		$self->{colsInOrder}->[$colIdx]->{__colIdx} = $colIdx;
		$includeCols[$colIdx] = 0;
		$colsAlreadyTaken[$colIdx] = 0;
	}

	foreach my $group (@_)
	{
		# if the first character of the group name is a "minus" it means we
		# want to remove this group's members from the list
		if($group =~ m/^\-(.*)/)
		{
			next if ! exists $self->{colsByGroup}->{$1};
			foreach my $col (@{$self->{colsByGroup}->{$1}})
			{
				$includeCols[$col->{__colIdx}] = 0;
			}
		}
		else
		{
			next if ! exists $self->{colsByGroup}->{$group};
			foreach my $col (@{$self->{colsByGroup}->{$group}})
			{
				$includeCols[$col->{__colIdx}] = 1;
			}
		}
	}

	if($style eq 'names_cs' || $style eq 'names_list')
	{
		my @names = ();
		for(my $colIdx = 0; $colIdx < $totalCols; $colIdx++)
		{
			if($includeCols[$colIdx] > 0)
			{
				push(@names, $self->{colsInOrder}->[$colIdx]->{name});
			}
		}
		return $style eq 'names_cs' ? join(", ", @names) : \@names;
	}
	elsif($style eq 'sorted_by_group')
	{
		my @columns = ();
		foreach my $group (@_)
		{
			next if $group =~ m/^\-(.*)/;
			next if ! exists $self->{colsByGroup}->{$group};

			foreach my $col (@{$self->{colsByGroup}->{$group}})
			{
				next if $colsAlreadyTaken[$col->{__colIdx}];
				push(@columns, $col);
				$colsAlreadyTaken[$col->{__colIdx}] = 1;
			}
		}
		return \@columns;
	}
	else
	{
		my @columns = ();
		for(my $colIdx = 0; $colIdx < $totalCols; $colIdx++)
		{
			if($includeCols[$colIdx] > 0)
			{
				push(@columns, $self->{colsInOrder}->[$colIdx]);
			}
		}
		return \@columns;
	}
}

sub fillColumnData
{
	my ($self, $groupName, $colDataRef, $colNamesRef, $colValuesRef,$colPlaceHolder, $errorsRef, $options) = @_;
	#
	# NOTE: values specified as __xxxx => yyy are "default" values
	# e.g.  abc => 123 means column abc has value 123, __abc => 234 means that if
	# abc column is not found in hash, default it to 234. Hash keys
	# that exist but have an undef value can be ignored or set to null (see $options),
	# columns that are not found can also be ignored (see $options).
	#
	my $colValue;

	if($groupName)
	{
		#
		# if groupName is provided, it means that every column in the group
		# is required
		#
		foreach(@{$self->{colsByGroup}->{$groupName}})
		{
			my $name = $_->{name};
			my $value =
				exists $colDataRef->{$name} ? $colDataRef->{$name} :
					(exists $colDataRef->{"__$name"} ? $colDataRef->{"__$name"} :
						(exists $_->{default} ? $_->{default} : undef));

			if(defined $value && $value ne '')
			{
				push(@{$colNamesRef}, $name);				
				$colValue = $options->{placeHolder} ?  $_->formatPlaceHolderData($value) : $_->formatSqlData($value);
				push(@{$colValuesRef}, $colValue);
				push(@{$colPlaceHolder}, $_->formatPlaceHolder('?')) if $options->{placeHolder};
				delete $colDataRef->{$name};      # take it out of the list so we don't process again
				delete $colDataRef->{"__$name"};  # take it out of the list so we don't process again
			}
			else
			{
				push(@{$errorsRef}, "no value provided for required column '$self->{name}.$name' ($_->{primarykey}:$_->{required})");
			}
		}
	}
	else
	{
		foreach (sort keys %{$colDataRef})
		{
			# don't process any "default" values, "private" keys, or "session" variables yet
			next if m/^(__|_|session_)/;

			# if we want to ignore keys that are set but have no values do it now
			next if $options->{ignoreUndefs} && exists $colDataRef->{$_} && not(defined $colDataRef->{$_});

			if(! exists $self->{colsByName}->{$_})
			{
				push(@{$errorsRef}, "column $_ does not exist in table $self->{name}") unless $options->{ignoreColsNotFound};
			}
			else
			{
				my $column = $self->{colsByName}->{$_};
				$colValue = $options->{placeHolder} ?  $column->formatPlaceHolderData($colDataRef->{$_}) : $column->formatSqlData($colDataRef->{$_});
				my $colPlace = $column->formatPlaceHolder('?') if $options->{placeHolder};
				#
				# the ordering is purely cosmetic and it will be slower
				#
				if($column->{primarykey} || $column->{required})
				{
					unshift(@{$colNamesRef}, $_);
					unshift(@{$colValuesRef}, $colValue);
					unshift(@{$colPlaceHolder},$colPlace) if $options->{placeHolder};		
				}
				else
				{
					push(@{$colNamesRef}, $_);
					push(@{$colValuesRef}, $colValue);
					push(@{$colPlaceHolder},$colPlace) if $options->{placeHolder};		
				}
				delete $colDataRef->{$_};      # take it out of the list so we don't process again
				delete $colDataRef->{"__$_"};  # take out any default value so its not processed later
			}
		}
		#
		# any keys still left (that we care about) are "default" values of the form __xxxx => yyyy
		#
		foreach (sort keys %{$colDataRef})
		{
			# the real column name is after the __, so get rid of the __
			next unless m/^__/;
			s/^__//;

			if(! exists $self->{colsByName}->{$_})
			{
				push(@{$errorsRef}, "column '$_' does not exist in table '$self->{name}'") unless $options->{ignoreColsNotFound};
			}
			else
			{
				#
				# the ordering is purely cosmetic and it will be slower
				#
				my $column = $self->{colsByName}->{$_};
				$colValue = $options->{placeHolder}==1 ?  $column->formatPlaceHolderData($colDataRef->{"__$_"}) : $column->formatSqlData($colDataRef->{"__$_"});					
				if($column->{primarykey} || $column->{required})
				{
					unshift(@{$colNamesRef}, $_);					
					unshift(@{$colValuesRef}, $colValue);
					unshift(@{$colPlaceHolder},$column->formatPlaceHolder('?')) if $options->{placeHolder};
				}
				else
				{
					push(@{$colNamesRef}, $_);
					push(@{$colValuesRef}, $colValue);
					push(@{$colPlaceHolder},$column->formatPlaceHolder('?')) if $options->{placeHolder};
				}
				delete $colDataRef->{"__$_"};  # take it out so we know we processed it
			}
		}
	}

	return scalar(@{$errorsRef}) == 0;
}

sub createEquality
{
	my ($self, $namesRef, $valuesRef, $joinClause) = @_;
	$joinClause ||= ", ";

	my $count = scalar(@{$namesRef});
	my @equality = ();
	for(my $i = 0; $i < $count; $i++)
	{
		if (defined ($valuesRef->[$i]) && $valuesRef->[$i] ne '')
		{
			push(@equality, "$namesRef->[$i] = $valuesRef->[$i]");
		}
		else
		{
			push(@equality, "$namesRef->[$i] = NULL");
		}
	}
	return join($joinClause, @equality);
}

sub createInsertSql
{
	my $self = shift;
	my %colData = %{$_[0]};      # copy this 'cause we're going to modify it locally
	my $options = defined $_[1] ? $_[1] : { ignoreUndefs => 1, ignoreColsNotFound => 0 };

	my ($sql, $errors) = ('', []);

	my @colNames = ();
	my @colValues = ();
	my @placeHolder = ();
	
	if($self->fillColumnData('_primaryAndRequiredFrontEndKeys', \%colData, \@colNames, \@colValues,\@placeHolder,$errors, $options))
	{
		$self->fillColumnData('', \%colData, \@colNames, \@colValues,\@placeHolder, $errors, $options);
 		$sql = "insert into $self->{name} (" . join(', ', @colNames) . ") values (" . join(', ', @placeHolder) . ")" if $options->{placeHolder};
 		$sql = "insert into $self->{name} (" . join(', ', @colNames) . ") values (" . join(', ', @colValues) . ")" if !$options->{placeHolder};
	}
	@colValues=() if ! $options->{placeHolder};
	return ($sql, \@colValues,$errors);
}

sub createUpdateSql
{
	my $self = shift;
	my %colData = %{$_[0]};    # copy this 'cause we're going to modify it locally
	my $options = defined $_[1] ? $_[1] : { ignoreUndefs => 0, ignoreColsNotFound => 0 };

	my ($sql, $errors) = ('', []);

	my @priKeyColNames = ();
	my @priKeyColValues = ();
	my @priPlaceHolder = ();
	my @updateColNames = ();
	my @updateColValues = ();
	my @updatePlaceHolder = ();
	my @colValues=();
	my $setStatements;
	my $whereCond;
	

	if($self->fillColumnData('_primaryKeys', \%colData, \@priKeyColNames, \@priKeyColValues,\@priPlaceHolder, $errors, $options))
	{
		$self->fillColumnData('', \%colData, \@updateColNames, \@updateColValues, \@updatePlaceHolder,$errors, $options);

		$whereCond = $self->createEquality(\@priKeyColNames, \@priPlaceHolder, " and ") if $options->{placeHolder};
		$whereCond = $self->createEquality(\@priKeyColNames, \@priKeyColValues, " and ") if ! $options->{placeHolder};
		unshift(@updateColNames, @priKeyColNames);
		unshift(@updateColValues, @priKeyColValues);
		unshift(@updatePlaceHolder,@priPlaceHolder);		
		push(@colValues ,@updateColValues, @priKeyColValues);
		$setStatements = $self->createEquality(\@updateColNames, \@updatePlaceHolder) if $options->{placeHolder};
		$setStatements = $self->createEquality(\@updateColNames, \@updateColValues) if ! $options->{placeHolder};

		$sql = "update $self->{name} set $setStatements where $whereCond";
	}
	@colValues=() if ! $options->{placeHolder};	
	return ($sql, \@colValues,$errors) 
}

sub createDeleteSql
{
	my $self = shift;
	my %colData = %{$_[0]};   # copy this 'cause we're going to modify it locally
	my $options = defined $_[1] ? $_[1] : { ignoreUndefs => 1, ignoreColsNotFound => 0 };

	my ($sql, $errors) = ('', []);

	my @colNames = ();
	my @colValues = ();
	my @placeHolder =();
	my $whereCond;

	if($self->fillColumnData('_primaryKeys', \%colData, \@colNames, \@colValues,\@placeHolder, $errors, $options))
	{
		$whereCond = $self->createEquality(\@colNames, \@placeHolder, " and ")if $options->{placeHolder};
		$whereCond = $self->createEquality(\@colNames, \@colValues, " and ")if ! $options->{placeHolder};
		$sql = "delete from $self->{name} where $whereCond";
	}
	@colValues=() if !$options->{placeHolder};
	return ($sql, \@colValues,$errors);
}

sub isValid
{
	my $self = shift;
	return 1;
}

##############################################################################
package Schema;
##############################################################################

use strict;
use XML::Parser;
use File::Basename;
use File::Spec;

sub new
{
	my $type = shift;
	my %params = @_;

	my $properties =
		{
			dbConnectKey => '',  # format is un/pw@connectStr (if set, db connection is automatic)
			dbh => undef,        # when a connection is active, this is the dbi handle
			dbinfo => undef,     # when a connection is active, this is general dbms-specific info

			verboseLevel => 0,   # 0 for none, 1 for schema, 2 for table, 3 for tabletype, 4 for column, 5 for datatype, composite
			fileLevel => 0,      # 0 for primary, greater than zero for include level
			sourceFiles =>
				{
					primaryPath => '',
					primary => '',
					includePaths => [],
					includes => [],
				},
			defineVars => {},
			dataDict =>
				{
					datatypes => {},   # all datatypes (as XML nodes)
					tabletypes => {},  # just the table templates (as XML nodes)
				},
			columns =>
				{
					byName => {},          # each col name points to a list
					byQualifiedName => {}, # each item is a complete TABLE.COL_NAME
					byType => {},          # each type name points to a list
					generateTbls => [],    # list of columns (in object and RAW XML form [pair]) for which tables are to be generated
				},
			tables =>
				{
					byName => {},
					byGroup => {},
					asList => [],
					hierarchy => [],
					fixup => [],
				},
			tableData => [],
			dbobjects => [],            # all objects, created in order listed
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
	$self->define(xmlFile => $params{xmlFile}) if exists $params{xmlFile};
	$self->connectDB($params{dbConnectKey}) if $params{dbConnectKey};

	return $self;
}

sub DESTROY
{
	my $self = shift;

	# need to add code to
	# make sure any duplicate references are diposed of properly
	# VERY IMPORTANT IN MOD_PERL/VELOCIGEN ENVIRONMENT
}

sub addFixupTable
{
	my ($self, $table) = @_;

	# don't put duplicates in here
	foreach (@{$self->{tables}->{fixup}})
	{
		return if $_ == $table;
	}

	push(@{$self->{tables}->{fixup}}, $table);
}

sub addGenerateTableColumn
{
	my ($self, $column, $xmlNode) = @_;
	push(@{$self->{columns}->{generateTbls}}, $column, $xmlNode);
}

sub fixup
{
	my $self = shift;

	my $genTblsList = $self->{columns}->{generateTbls};
	while(@$genTblsList)
	{
		my ($column, $xmlNode) = (shift(@$genTblsList), shift(@$genTblsList));
		new Table(xmlObjNode => $xmlNode, schema => $self, parentColInstance => $column, parentTblInstance => $column->{table});
		undef $xmlNode;
	}

	foreach my $table (@{$self->{tables}->{fixup}})
	{
		$table->fixup();
	}
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
		$parser = new XML::Parser(Style => 'Objects', Pkg => 'SchemaXML');
		$document = $parser->parsefile($sourceFile);
	};
	die "Error parsing schema in $sourceFile\n$@\n" if $@;

	$self->{fileLevel}++ if $include;
	$self->define(xmlObjNode => $document->[0]);
	$self->fixup() if $self->{fileLevel} == 0;
	$self->{fileLevel}-- if $include;
}

sub getColumn
{
	return $_[0]->{columns}->{byQualifiedName}->{uc($_[1])};
}

sub getTable
{
	return $_[0]->{tables}->{byName}->{$_[1]};
}

sub outputMessage
{
	my $self = shift;
	my $level = shift;

	my $indent = "  "x$self->{fileLevel} . "  "x$level;
	print STDERR $indent . join(" ", @_) . "\n" if $self->{verboseLevel} >= $level;
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
		die "only schema tags allowed here: $xmlNode" unless $xmlNode->isa('SchemaXML::schema');

		if($self->{fileLevel} == 0)
		{
			die "schema name is required" unless $xmlNode->{name};
			$self->{name} = $xmlNode->{name};
		}
		$self->outputMessage(1, "schema", $xmlNode->{name});

		foreach my $childNode (@{$xmlNode->{Kids}})
		{
			if($childNode->isa('SchemaXML::datatype'))
			{
				my $typeName = $childNode->{name};
				if(! exists $self->{dataDict}->{datatypes}->{$typeName})
				{
					$self->{dataDict}->{datatypes}->{$typeName} = $childNode;
					$self->outputMessage(1, "stored datatype", $typeName);
				}
				else
				{
					die "datatype $typeName defined twice";
				}
			}
			elsif($childNode->isa('SchemaXML::tabletype'))
			{
				my $typeName = $childNode->{name};
				if(! exists $self->{dataDict}->{tabletypes}->{$typeName})
				{
					$self->{dataDict}->{tabletypes}->{$typeName} = $childNode;
					$self->outputMessage(1, "stored tabletype", $typeName);
				}
				else
				{
					die "tabletype $typeName defined twice";
				}
			}
			elsif($childNode->isa('SchemaXML::table'))
			{
				new Table(xmlObjNode => $childNode, schema => $self);
			}
			elsif($childNode->isa('SchemaXML::data'))
			{
				my $tableName = $childNode->{table};
				die "tabledata requires table attribute for name" if ! $tableName;
				push(@{$self->{tableData}}, new TableData(xmlObjNode => $childNode, schema => $self, tableName => $tableName));
				$self->outputMessage(1, "stored tableData for table $tableName");

			}
			elsif($childNode->isa('SchemaXML::include'))
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
					$self->outputMessage(1, "*** include file already included", $file);
					next;
				}

				$self->outputMessage(1, "==> start include", $file);
				$self->define(xmlFile => $file, include => 1);
				$self->outputMessage(1, "==> end include", $file);
			}
			else
			{
				warn "unknown node type encountered: $childNode\n" if ! $childNode->isa('SchemaXML::Characters');
			}
		}
	}
}

sub isValid
{
	my $self = shift;
	return 1;
}

1;
