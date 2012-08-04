##############################################################################
package SQL::GenerateQuery;
##############################################################################

use strict;
use SDE::CVS ('$Id: GenerateQuery.pm,v 1.11 2000-11-22 20:31:21 robert_jenks Exp $', '$Name:  $');
use XML::Parser;
use fields qw(qdlFile id fields joins views params);
use Class::PseudoHash;
use vars qw(%CACHE $COMPARISONS);

%CACHE = ();

$COMPARISONS = [
	{id => 'startswith', caption => 'starts with', operator => 'LIKE', value => '$%', exact => 'no'},
	{id => 'endswith', caption => 'ends with', operator => 'LIKE', value => '%$', exact => 'no'},
	{id => 'is', caption => 'is', operator => '=', exact => 'yes'},
	{id => 'isnot', caption => 'is not', operator => '!=', exact => 'yes'},
	{id => 'contains', caption => 'contains', operator => 'LIKE', value => '%$%', exact => 'no' },
	{id => 'doesnotcontain', caption => 'does not contain', operator => 'NOT LIKE', value => '%$%', exact => 'no'},
	{id => 'greaterthan', caption => 'greater than', operator => '>', exact => 'yes'},
	{id => 'lessthan', caption => 'less than', operator => '<', exact => 'yes'},
	{id => 'isdefined', caption => 'is defined', operator => 'IS NOT NULL', value => '', exact => 'yes'},
	{id => 'isnotdefined', caption => 'is not defined', operator => 'IS NULL', value => '', exact => 'yes'},
	{id => 'matches', caption => 'matches', operator => 'LIKE', exact => 'no'},
	{id => 'doesnotmatch', caption => 'does not match', operator => 'NOT LIKE', exact => 'no'},
	{id => 'between', caption => 'is between', operator => 'BETWEEN', placeholder => '? AND ?', exact => 'yes'},
	{id => 'notbetween', caption => 'is not between', operator => 'NOT BETWEEN', placeholder => '? AND ?', exact => 'yes'},
	{id => 'oneof', caption => 'is one of', operator => 'IN', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'notoneof', caption => 'is not one of', operator => 'NOT IN', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'gtany', caption => 'greater than any one of', operator => '> ANY', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'geany', caption => 'greater than or is any one of', operator => '>= ANY', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'ltany', caption => 'less than any one of', operator => '< ANY', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'leany', caption => 'less than or is any one of', operator => '<= ANY', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'gtall', caption => 'greater than all of', operator => '> ALL', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'geall', caption => 'greater than or is all of', operator => '>= ALL', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'ltall', caption => 'less than all of', operator => '< ALL', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'leall', caption => 'less than or is all of', operator => '<= ALL', placeholder => '(?[, ?]+)', exact => 'yes'},
	{id => 'exists', caption => 'exists', operator => 'EXISTS', placeholder => '@', exact => 'yes'},
	{id => 'notexists', caption => 'does not exist', operator => 'NOT EXISTS', placeholder => '@', exact => 'yes'},
];

# Turn it into a Psuedo-Hash
# This allows us to maintain the order of the comparisons in the list
# and yet still quickly access an individual item by it's id
{
	my $i = 1;
	my %compIndex = map {$_->{id}, $i++} @$COMPARISONS;
	unshift @$COMPARISONS, \%compIndex;
}

sub new
{
	my $class = shift;
	my %opts = @_;

	# 'file' is a required parameter and it must exist
	die "file must be specified and exist" unless $opts{file} && -f $opts{file};

	# If caching is enabled use cached object if available
	if (exists $opts{cache} && $opts{cache})
	{
		return $CACHE{$opts{file}} if exists $CACHE{$opts{file}};
	}

	# Create a new object
	$class = ref($class) || $class;
	no strict 'refs';
	my SQL::GenerateQuery $self = fields::new($class);
	use strict 'refs';

	$self->{qdlFile} = $opts{file};

	# Initialize it
	$self->initialize();

	# Cache the object if requested
	if (exists $opts{cache} && $opts{cache})
	{
		$CACHE{$opts{file}} = $self;
	}

	return $self;
}


# Create a new condition object
sub WHERE
{
	my SQL::GenerateQuery $self = shift;
	return SQL::GenerateQuery::Condition->new($self, @_);
}


# AND together multiple condition object into a new merged condition object
sub AND
{
	my SQL::GenerateQuery $self = shift;
	return SQL::GenerateQuery::Condition->joinConditions($self, 'AND', @_);
}


# OR together multiple condition object into a new merged condition object
sub OR
{
	my SQL::GenerateQuery $self = shift;
	return SQL::GenerateQuery::Condition->joinConditions($self, 'OR', @_);
}


# Sets and/or returns the id of the object
sub id
{
	my SQL::GenerateQuery $self = shift;
	$self->{id} = $_[0] if defined $_[0];
	return $self->{id};
}


# Sets and/or returns the definition of a field
# Without a param, it returns a list of fields
sub fields
{
	my SQL::GenerateQuery $self = shift;
	my ($id, $value) = @_;
	unless (defined $id)
	{
		return map {$_->{id}} @{$self->{fields}}[1..$#{$self->{fields}}];
	}
	if (defined $value)
	{
		die "Field data must be a hash ref" unless ref($value) eq 'HASH';

		# Add it to the Psuedo-Hash
		my $newField = SQL::GenerateQuery::Field->new($value) or return 0;
		push @{$self->{fields}}, $newField;
		$self->{fields}->[0]->{$newField->{id}} = $#{$self->{fields}};
		return 1;
	}
	$id = $1 if $id =~ /\{(\w+)\}/;
	return exists $self->{fields}->{$id} ? $self->{fields}->{$id} : undef;
}

# Sets and/or returns the definition of a join
# Without a param, it returns a list of joins
sub joins
{
	my SQL::GenerateQuery $self = shift;
	my ($id, $value) = @_;
	unless (defined $id)
	{
		return keys %{$self->{joins}};
	}
	if (defined $value)
	{
		die "Field data must be a hash ref" unless ref($value) eq 'HASH';
		my %newView = %{$value};
		$self->{joins}->{$id} = \%newView;
		return 1;
	}
	return $self->{joins}->{$id};
}


# Returns a view definition or a list of views
# Without a param, it returns a list of views
sub views
{
	my SQL::GenerateQuery $self = shift;
	my ($id, $value) = @_;
	unless (defined $id)
	{
		return map {$_->{id}} @{$self->{views}}[1..$#{$self->{views}}];
	}
	if (defined $value)
	{
		die "View data must be a hash ref" unless ref($value) eq 'HASH';

		# Add it to the Psuedo-Hash
		push @{$self->{views}}, $value;
		$self->{views}->[0]->{$id} = $#{$self->{views}};
		return $value;
	}
	return exists $self->{views}->{$id} ? $self->{views}->{$id} : undef;
}

# Returns the definition of a comparison
# Without a param, it returns a list of comparisons
sub comparisons
{
	my SQL::GenerateQuery $self = shift;
	my $id = shift;
	
	unless (defined $id)
	{
		return map {$_->{id}} @$COMPARISONS[1..$#{$COMPARISONS}];
	}
	#Pseudohash doesn't work, so use this expanded notation
	my $compword = $COMPARISONS->[$COMPARISONS->[0]{$id}];
	return $compword;
}

# Reads/Parses the QDL file
#   Can be called multiple times to re-load after a data-file change
sub initialize
{
	my SQL::GenerateQuery $self = shift;
	my $qdlFile = $self->{qdlFile};

	$self->{fields} = Class::PseudoHash->new;  # Psuedo-Hash to maintain field order
	$self->{joins} = {};
	$self->{views} = Class::PseudoHash->new; # Psuedo-Hash to maintain view order

	# Import the QDL data
	my $parser = new XML::Parser(Style => 'Tree');
	my $qdl = $parser->parsefile($qdlFile) or die "Unable to open '$qdlFile'";

	$self->parseTags($qdl);
}


sub parseTags
{
	my SQL::GenerateQuery $self = shift;
	my $tags = shift;
	while (defined (my $tag = shift @$tags) and defined(my $value = shift @$tags))
	{
		next unless $tag;
		if ($tag eq 'query-defn')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->id($value->[0]->{id});
				$self->{params} = $value->[0];
			}
		}
		elsif ($tag eq 'field')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->fields($value->[0]->{id}, $value->[0]);
			}
		}
		elsif ($tag eq 'join')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->joins($value->[0]->{id}, $value->[0]);
			}
		}
		elsif ($tag eq 'view')
		{
			# If the style contains no tags then ignore it
			next unless $#{$value};

			# Pass control to parseStyle() to build the styles hash
			my $condition = $self->parseView($value->[0]->{id}, [@$value[1..$#{$value}]], $value->[0]);
			$self->views($value->[0]->{id})->{condition} = $condition->[0];

			# Since we already handled the contents of this tag, skip to the next
			next;
		}
		# If the tag contains more tags call on Mr Recursion
		if ($#{$value})
		{
			# Passes a ref to a slice (which excludes the element 0 attributes)
			$self->parseTags([@$value[1..$#{$value}]]);
		}
	}
}


sub parseView
{
	my SQL::GenerateQuery $self = shift;
	my ($id, $tags, $attributes) = @_;
	my @conditions = ();

	my $view = $self->views($id);
	$view = $self->views($id, {id => $id}) unless $view;

	# Check for and add top level attributes
	if (defined $attributes)
	{
		foreach my $key (keys %{$attributes})
		{
			$view->{$key} = $attributes->{$key};
		}
	}

	while (defined (my $tag = shift @$tags) and defined(my $value = shift @$tags))
	{
		next unless $tag;
		if ($tag eq 'column')
		{
			$view->{columns} = [] unless exists $view->{columns};
			my %column = %{$value->[0]};
			push @{$view->{columns}}, \%column;
		}
		elsif ($tag eq 'order-by')
		{
			$view->{'order-by'} = [] unless exists $view->{'order-by'};
			my %orderby = %{$value->[0]};
			push @{$view->{'order-by'}}, \%orderby;

		}
		elsif ($tag eq 'group-by')
		{
			$view->{'group-by'} = [] unless exists $view->{'group-by'};
			my %groupby = %{$value->[0]};
			push @{$view->{'group-by'}}, \%groupby;
		}
		elsif ($tag eq 'condition')
		{
			my $att = $value->[0];
			push @conditions, $self->WHERE($att->{field}, $att->{comparison}, $att->{criteria});
		}

		if ($#{$value})
		{
			# Passes a ref to a slice (which excludes the element 0 attributes)
			my $childConditions = $self->parseView($id, [@$value[1..$#{$value}]]);
			if ($tag eq 'and-conditions')
			{
				push @conditions, $self->AND(@{$childConditions});
			}
			elsif ($tag eq 'or-conditions')
			{
				push @conditions, $self->OR(@{$childConditions});
			}
			else
			{
				push @conditions, @{$childConditions};
			}
		}
	}
	return \@conditions;
}


##############################################################################
package SQL::GenerateQuery::Condition;
##############################################################################

use strict;
use fields qw(sqlGen compares outColumns orderBy distinct);


# Creates a new condition object
sub new
{
	my $class = shift;
	my SQL::GenerateQuery $sqlGen = shift;
	my $field = shift;
	my $comparison = shift;
	my @criteria = @_;
	my $options = @criteria && ref($criteria[-1]) eq 'HASH' ? pop @criteria : {};
	my $fieldDefn;

	$class = ref($class) || $class;
	no strict 'refs';
	#my SQL::GenerateQuery::Condition $self = [\%{"${class}::FIELDS"}];
	my SQL::GenerateQuery::Condition $self = fields::new($class);

	$self->{sqlGen} = $sqlGen;

	# Validate the field & get the join name
	die "Field '$field' is invalid" unless $sqlGen->fields($field);
	if ($field =~ /\{/)
	{
		my @fields = $field =~ /\{(\w+)\}/g;
		die "Only one field may be specified" if $#fields;
		$fieldDefn = $field;
		$field = $fields[0];
	}

	# Validate the comparison
	my $compare = $sqlGen->comparisons($comparison);

	unless ($compare)
	{
		die "Comparison '$comparison' is invalid";
	}

	# Add it
	my $compareHash =
		{
			field => $field,
			comparison => $comparison,
			criteria => \@criteria,
			startParen => 0,
			endParen => 0,
			options => $options,
			join => '',
		};
	$compareHash->{fieldDefn} = $fieldDefn if defined $fieldDefn;
	$self->{compares} = [$compareHash];

	$self->{outColumns} = [];
	$self->{orderBy} = [];
	$self->{distinct} = 0;

	return $self;
}


# Creates a new comparison object by combining two or more existing
# comparison objects
sub joinConditions
{
	my $class = shift;
	my SQL::GenerateQuery $sqlGen = shift;
	my $type = shift;
	my @conditions = @_;

	# Validate the join type
	return 0 unless $type eq 'AND' || $type eq 'OR';

	# Validate the conditions
	foreach (@conditions)
	{
		return 0 unless ref($_) && $_->isa('SQL::GenerateQuery::Condition');
	}

	# Create an object
	$class = ref($_[0]) || $_[0];
	no strict 'refs';
	#my SQL::GenerateQuery::Condition $self = [\%{"${class}::FIELDS"}];
	my SQL::GenerateQuery::Condition $self = fields::new($class);
	use strict;

	$self->{sqlGen} = $sqlGen;
	$self->{compares} = [];
	$self->{outColumns} = [];
	$self->{orderBy} = [];
	$self->{distinct} = 0;

	# Copy the conditions into the new object
	my $lastCond = $#conditions;
	foreach my $i (0..$#conditions)
	{
		my SQL::GenerateQuery::Condition $curCond = $conditions[$i];
		unless ($self->{sqlGen} == $curCond->{sqlGen})
		{
			die "All conditions must be generated from the same SQL::GenerateQuery object";
		}

		# Copy each compare from the current condition
		# to the new condition
		foreach my $y (0..$#{$curCond->{compares}})
		{
			my $curCompare = $curCond->{compares}[$y];
			my $newCompare = {};
			foreach (keys %{$curCompare})
			{
				$newCompare->{$_} = $curCompare->{$_};
			}

			# If the current condition has more than one compare
			# we need to add parens around it
			$newCompare->{startParen}++ if $y == 0 && $#{$curCond->{compares}};
			$newCompare->{endParen}++ if $y == $#{$curCond->{compares}} && $#{$curCond->{compares}};

			# If it is the last compare and not the last condition add the join type
			$newCompare->{join} = $type if $y == $#{$curCond->{compares}} && $i != $#conditions;

			# If it is the last compare of the last condition then join is blank
			$newCompare->{join} = '' if $y == $#{$curCond->{compares}} && $i == $#conditions;

			# Add the new compare the the end of the new object's list
			push @{$self->{compares}}, $newCompare;
		}
	}

	return $self;
}


sub outColumns
{
	my $self = shift;

	if (@_)
	{
		$self->{outColumns} = [];
		foreach my $colDefn (@_)
		{
			if (ref $colDefn)
			{
				die "A column in outColumns cannot be a reference";
			}
			push @{$self->{outColumns}}, $colDefn;
		}
	}
	return @{$self->{outColumns}};
}


sub orderBy
{
	my $self = shift;

	if (@_)
	{
		$self->{orderBy} = [];
		foreach my $colDefn (@_)
		{
			if (ref $colDefn && (ref $colDefn ne 'HASH' || ! defined $colDefn->{id}))
			{
				die "ColDefn '$colDefn' is not valid";
			}
			
			unless (ref $colDefn eq 'HASH')
			{
				$colDefn = {id => $colDefn, order => 'Ascending'};
			}
			
			push @{$self->{orderBy}}, $colDefn;
		}
	}
	return @{$self->{orderBy}};
}


sub distinct
{
	my $self = shift;
	my $value = shift;

	$self->{distinct} = defined $value && $value ? 1 : 0;

	return $self->{distinct};
}


# Generate a SQL statement
sub genSQL
{
	my SQL::GenerateQuery::Condition $self = shift;
	my %opts = @_;

	my @SELECT = ();
	my @FROM = ();
	my @WHERE = ();
	my @ORDER_BY = ();
	my @GROUP_BY = ();
	my @bindParams = ();
	my $needGroupBy = 0;

	my SQL::GenerateQuery $sqlGen = $self->{sqlGen};

	# Add any autoInclude tables to the query
	foreach my $join ($sqlGen->joins())
	{
		my $joinData = $sqlGen->joins($join) or die "Can't get view '$join'";
		if (defined $joinData->{autoInclude} && $joinData->{autoInclude})
		{
			$self->addTableToFROM($join, \@FROM, \@WHERE, \@bindParams) ;
		}
	}

	# Process the comparisons
	foreach my $i (0 .. $#{$self->{compares}})
	{
		my $compare = $self->{compares}[$i];
		my $field = $compare->{field};
		my $comparison = $compare->{comparison};
		my $criteria = $compare->{criteria};
		my $join = $compare->{join};
		my $startParen = $compare->{startParen};
		my $endParen = $compare->{endParen};

		$join = " " . $join if $join;

		my $fieldData = $sqlGen->fields($field);
		my $columnDefn = defined $fieldData->{join} ? $fieldData->{join} . "." : '';
		if (defined $fieldData->{column})
		{
			$columnDefn .= $fieldData->{column};
		}
		elsif (defined $fieldData->{columndefn})
		{
			$columnDefn = $fieldData->{columndefn};
		}
		else
		{
			die "Field must have a column or columndefn defined";
		}


		# Get a copy of the default comparison operator data
		my $compData = { %{$sqlGen->comparisons($comparison)} };
		
		# Add overridden parameters to the comparison operator data
		foreach my $opt (keys %{$compare->{options}})
		{
			$compData->{$opt} = $compare->{options}->{$opt};
		}

		# Add the appropriate FROM tables and join WHERE conditions
		$self->addTableToFROM($fieldData->{join}, \@FROM, \@WHERE, \@bindParams) if $fieldData->{join};

		# Add the bind parameter(s) and get the placeHolder
		my $placeHolder = $self->addCriteria($criteria, $compData, \@bindParams);

		$startParen++ if $i == 0;
		$endParen++ if $i == $#{$self->{compares}};
		$startParen = '(' x $startParen;
		$endParen = ')' x $endParen;

		# Check to see if we have a custom field definition and use it
		if (exists $compare->{fieldDefn})
		{
			my $fieldDefn = $compare->{fieldDefn};
			$fieldDefn =~ s/\{\w+\}/$columnDefn/;
			$columnDefn = $fieldDefn;
		}

		# Add the WHERE condition
		push @WHERE, $startParen . $columnDefn . " " . $compData->{operator} . $placeHolder . $endParen . $join;

		# If they didn't specify a join for this parameter we're done!
		last unless $join;
		$i++;
	}

	# Process the Output Columns
	my $outColsList = defined $opts{outColumns} ? $opts{outColumns} : $self->{outColumns};
	foreach my $field (@$outColsList)
	{
		my $fieldDefn;
		die "Field '$field' is invalid" unless my $fieldData = $sqlGen->fields($field);

		# If they gave us a field wrapped in a function call
		if ($field ne $fieldData->{id})
		{
			$fieldDefn = $field;
			$field = $fieldData->{id};
		}

		# Add the selected columns to the SELECT clause
		my $selectCol = defined $fieldData->{join} ? $fieldData->{join} . '.' : '';
		$selectCol .= $fieldData->{column};
		if (defined $fieldData->{columndefn})
		{
			$selectCol = $fieldData->{columndefn};
		}

		if (defined $fieldDefn)
		{
			$fieldDefn =~ s/(\{\w+\})/$selectCol/;
			$selectCol = $fieldDefn;
		}

		# See if we need to use a GROUP BY clause
		if (defined $fieldData->{groupbyexp} && lc($fieldData->{groupbyexp}) eq 'yes')
		{
			$needGroupBy = 1;
		}
		else
		{
			push @GROUP_BY, $selectCol;
		}


		$selectCol .= " AS $field";
		push @SELECT, $selectCol;

		# Add the appropriate FROM tables and join WHERE conditions
		$self->addTableToFROM($fieldData->{join}, \@FROM, \@WHERE, \@bindParams) if $fieldData->{join};
	}

	# Process the Order By
	my $orderByList = defined $opts{orderBy} ? $opts{orderBy} : $self->{orderBy};
	foreach my $field (@$orderByList)
	{
		if (ref $field eq 'HASH')
		{
			die "Order By specification is invalid" unless defined $field->{id};
			die "Field '$field->{id}' is invalid" unless my $fieldData = $sqlGen->fields($field->{id});
			my $fieldSpec = $fieldData->{id};
			$fieldSpec .= " DESC" if defined $field->{order} && lc($field->{order}) =~ /^d/;
			push @ORDER_BY, $fieldSpec;
		}
		elsif (! ref $field)
		{
			die "Field '$field' is invalid" unless my $fieldData = $sqlGen->fields($field);

			# Add the selected column to the ORDER BY clause
			push @ORDER_BY, $fieldData->{id};
		}
	}

	my $SQL = '';
	my $distinct = defined $opts{distinct} && lc($opts{distinct}) eq 'yes' ? 1 : $self->{distinct};

	# SELECT
	$SQL .= "SELECT";
	$SQL .= " DISTINCT" if $distinct;
	$SQL .= "\n";
	$SQL .= join ",\n", map {"\t$_"} @SELECT;
	$SQL .= "\n";

	# FROM
	$SQL .= "FROM\n";
	$SQL .= join ",\n", map {"\t$_"} @FROM;
	$SQL .= "\n";

	# WHERE
	if (@WHERE)
	{
		$SQL .= "WHERE\n";
		$SQL .= join "\n", map {"\t$_"} @WHERE;
		$SQL .= "\n";
	}

	# GROUP BY
	if ($needGroupBy && @GROUP_BY)
	{
		$SQL .= "GROUP BY\n";
		$SQL .= join ",\n", map {"\t$_"} @GROUP_BY;
		$SQL .= "\n";
	}

	# ORDER BY
	if (@ORDER_BY)
	{
		$SQL .= "ORDER BY\n";
		$SQL .= join ",\n", map {"\t$_"} @ORDER_BY;
		$SQL .= "\n";
	}

	return wantarray ? ($SQL, \@bindParams) : $SQL;
}


sub addCriteria
{
	my SQL::GenerateQuery::Condition $self = shift;
	my @criteria = @{shift()};
	my $compData = shift;
	my $bindParams = shift;

	# Get the templates
	my $tempPlaceHolder = defined $compData->{placeholder} ? $compData->{placeholder} : '?';
	my $tempValue = defined $compData->{value} ? $compData->{value} : '$';

	# If the value template is empty, then the condition has no right side
	return '' unless $tempValue ne '';

	my $placeHolder = '';
	while ($tempPlaceHolder ne '')
	{
		my $remainder;
		$_ = $tempPlaceHolder;
		if (/^([^\?\@\[]+)(.*)$/)
		{
			$placeHolder .= $1;
			$remainder = defined $2 ? $2 : '';
		}
		elsif (/^\?(.*)$/) # Handle criteria
		{
			my $param = shift @criteria;
			my $ph = '?';
			if (ref($param))
			{
				if ($param->isa('SQL::GenerateQuery::Condition'))
				{
					# Handle a field-to-subselect comparison
					my ($subSql, $subBindParams) = $param->genSQL();
					push @$bindParams, @{$subBindParams};
					$ph .= '(' . $subSql . ')';
					$param = undef;
				}
				elsif ($param->isa('SQL::GenerateQuery::Field'))
				{
					# Handle a field-to-field comparison
				}
				else
				{
					die "Unknown criteria reference of type: '" . ref($param) . "'";
				}
			}

			if (defined $param)
			{
				my $newParam = $tempValue;
				$newParam =~ s/\$/$param/g;
				push @$bindParams, $newParam;
			}
			$placeHolder .= $ph;
			$remainder = defined $1 ? $1 : '';
		}
		elsif (/^\@(.*)$/)  # Handle Required Sub-Selects
		{
			$remainder = defined $1 ? $1 : '';
			my $param = shift @criteria;
			die "Sub-Select is required" unless ref($param) && $param->isa('SQL::GenerateQuery::Condition');
			my ($subSql, $subBindParams) = $param->genSQL();
			push @$bindParams, @{$subBindParams};
			$placeHolder .= '(' . $subSql . ')';
		}
		elsif (/^\[(.*?)\]([^\?\@]*)$/) # Handle
		{
			my $optPattern = $1;
			$remainder = defined $2 ? $2 : '';
			my $multiple = $remainder =~ s/^\+//;
			my $remainCriteria = @criteria;
			if ($multiple)
			{
				$remainder = ($optPattern x $remainCriteria) . $remainder;
			}
			elsif ($remainCriteria)
			{
				$remainder = $optPattern . $remainder;
			}
		}
		else
		{
			die "Invalid placeholder specification!";
		}
		$tempPlaceHolder = $remainder;
	}
	die "Too many criteria parameters " . join(', ', map("'$_'",@criteria)) . ". SQL Generation Aborted!" if @criteria;
	return ' ' . $placeHolder;
}


sub addTableToFROM
{
	my SQL::GenerateQuery::Condition $self = shift;
	my ($join, $FROM, $WHERE, $bindParams) = @_;
	my SQL::GenerateQuery $sqlGen = $self->{sqlGen};
	my $joinData = $sqlGen->joins($join);

	# See if this join requires any prerequisite joins
	if (defined $joinData->{requires})
	{
		my $requires = $joinData->{requires};
		if (ref($requires) eq 'ARRAY')
		{
			foreach (@$requires)
			{
				$self->addTableToFROM($_, $FROM, $WHERE, $bindParams);
			}
		}
		else
		{
			foreach my $reqJoin (split ',', $requires)
			{
				$self->addTableToFROM($reqJoin, $FROM, $WHERE, $bindParams);
			}
		}

	}

	# Construct a proper FROM clause member
	my $table = $joinData->{table};
	my $from = $table;
	$from .= " $join" unless $table eq $join;

	# If we haven't already added this FROM clause
	unless (grep {$_ eq $from} @$FROM)
	{
		# Add the table to the bottom of the FROM clause
		push @$FROM, $from;

		if (exists $joinData->{condition})
		{
			# Add the appropriate join to the top of the WHERE clause
			unshift @$WHERE, '(' . $joinData->{condition} . ') AND';
		}
		if (exists $joinData->{bindParams})
		{
			# Add necessary bind params to top of list
			unshift @$bindParams, @{$joinData->{bindParams}};
		}
	}
}



##############################################################################
package SQL::GenerateQuery::Field;
##############################################################################

use strict;

sub new
{
	my $class = shift;
	$class = ref($class) || $class;

	my $attributes = shift;
	die "attributes is a " . ref($attributes) . " but must be a HASH" unless ref($attributes) eq 'HASH';
	my %self = %{$attributes};
	my $self = \%self;
	bless $self, $class;
}



1;


__END__

=head1 NAME

SQL::GenerateQuery - Perl Object Interface for Generating SQL Statements

=head1 SYNOPSIS

 use SQL::GenerateQuery;

 my $personQuery = new SQL::GenerateQuery(file => 'person.qdl', cache => 1);

 my $eyeCond1 = $personQuery->WHERE('eye_color', 'is', 'GREEN');
 my $eyeCond2 = $personQuery->WHERE('eye_color', 'is', 'BLUE');
 my $cond = $personQuery->OR($eyeCond1, $eyeCond2);

 my ($SQL1, $params1) = $cond->genSQL(
	 outFields => ['first_name', 'last_name', 'eye_color', 'hair_color'],
	 sortFields => ['last_name', 'first_name'],
	 distinct => 1
	 );

 my $ageCond = $personQuery->WHERE('age', 'greaterthan', '21');
 $cond = $personQuery->AND($cond, $ageCond);

 my ($SQL2, $params2) = $cond->genSQL(
	 outFields => ['first_name', 'last_name', 'age', 'height'],
	 sortFields => ['age', 'last_name', 'first_name'],
	 );

 my $fieldCond = $personQuery->WHERE('last_name', 'is', $personQuery->fields('first_name'));

=head1 DESCRIPTION


=cut
