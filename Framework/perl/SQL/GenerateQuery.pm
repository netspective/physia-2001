##############################################################################
package SQL::GenerateQuery;
##############################################################################

use strict;
use SDE::CVS ('$Id: GenerateQuery.pm,v 1.3 2000-09-13 23:40:36 robert_jenks Exp $', '$Name:  $');
use XML::Parser;
use fields qw(qdlFile id fields joins views);
use vars qw(%CACHE $COMPARISONS);

%CACHE = ();

$COMPARISONS = [
	{id => 'startswith', caption => 'starts with', operator => 'LIKE', value => '$%'},
	{id => 'endswith', caption => 'ends with', operator => 'LIKE', value => '%$'},
	{id => 'is', caption => 'is', operator => '='},
	{id => 'isnot', caption => 'is not', operator => '!='},
	{id => 'contains', caption => 'contains', operator => 'LIKE', value => '%$%' },
	{id => 'doesnotcontain', caption => 'does not contain', operator => 'NOT LIKE', value => '%$%'},
	{id => 'greaterthan', caption => 'greater than', operator => '>'},
	{id => 'lessthan', caption => 'less than', operator => '<'},
	{id => 'isdefined', caption => 'is defined', operator => 'IS NOT NULL', value => ''},
	{id => 'isnotdefined', caption => 'is not defined', operator => 'IS NULL', value => ''},
	{id => 'matches', caption => 'matches', operator => 'LIKE'},
	{id => 'doesnotmatch', caption => 'does not match', operator => 'NOT LIKE'},
	{id => 'between', caption => 'is between', operator => 'BETWEEN', placeholder => '? AND ?'},
	{id => 'notbetween', caption => 'is not between', operator => 'NOT BETWEEN', placeholder => '? AND ?'},
	{id => 'oneof', caption => 'is one of', operator => 'IN', placeholder => '(?[, ?]+)'},
	{id => 'notoneof', caption => 'is not one of', operator => 'NOT IN', placeholder => '(?[, ?]+)'},
	{id => 'gtany', caption => 'greater than any one of', operator => '> ANY', placeholder => '(?[, ?]+)'},
	{id => 'geany', caption => 'greater than or is any one of', operator => '>= ANY', placeholder => '(?[, ?]+)'},
	{id => 'ltany', caption => 'less than any one of', operator => '< ANY', placeholder => '(?[, ?]+)'},
	{id => 'leany', caption => 'less than or is any one of', operator => '<= ANY', placeholder => '(?[, ?]+)'},
	{id => 'gtall', caption => 'greater than all of', operator => '> ALL', placeholder => '(?[, ?]+)'},
	{id => 'geall', caption => 'greater than or is all of', operator => '>= ALL', placeholder => '(?[, ?]+)'},
	{id => 'ltall', caption => 'less than all of', operator => '< ALL', placeholder => '(?[, ?]+)'},
	{id => 'leall', caption => 'less than or is all of', operator => '<= ALL', placeholder => '(?[, ?]+)'},
	{id => 'exists', caption => 'exists', operator => 'EXISTS', placeholder => '@'},
	{id => 'notexists', caption => 'does not exist', operator => 'NOT EXISTS', placeholder => '@'},
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
	my SQL::GenerateQuery $self = [\%{"${class}::FIELDS"}];
	bless $self, $class;
	
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
		my %newField = %{$value};

		# Add it to the Psuedo-Hash
		push @{$self->{fields}}, \%newField or return 0;
		$self->{fields}->[0]->{$newField{id}} = $#{$self->{fields}};
		return 1;
	}
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
	my $id = shift;
	unless (defined $id)
	{
		return keys %{$self->{views}};
	}
	return $self->{views}->{$id};
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
	return $COMPARISONS->{$id};
}


# Reads/Parses the QDL file
#   Can be called multiple times to re-load after a data-file change
sub initialize
{
	my SQL::GenerateQuery $self = shift;
	my $qdlFile = $self->{qdlFile};
	
	$self->{fields} = [{},];  # Psuedo-Hash to maintain field order
	$self->{joins} = {};
	$self->{views} = {};
	
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
			$self->{views}->{$value->[0]->{id}}->{condition} = $condition->[0];
			
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
	
	$self->{views}->{$id} = {} unless exists $self->{views}->{$id};
	my $style = $self->{views}->{$id};
	
	# Check for and add top level attributes
	if (defined $attributes)
	{
		foreach my $key (keys %{$attributes})
		{
			next if $key eq 'id';
			$style->{$key} = $attributes->{$key};
		}
	}
	
	while (defined (my $tag = shift @$tags) and defined(my $value = shift @$tags))
	{
		next unless $tag;
		if ($tag eq 'column')
		{
			$style->{columns} = [] unless exists $style->{columns};
			my %column = %{$value->[0]};
			push @{$style->{columns}}, \%column;
		}
		elsif ($tag eq 'order-by')
		{
			$style->{'order-by'} = [] unless exists $style->{'order-by'};
			my %orderby = %{$value->[0]};
			push @{$style->{'order-by'}}, \%orderby;
			
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
use fields qw(sqlGen compares);


# Creates a new comparison object
sub new
{
	my $class = shift;
	my SQL::GenerateQuery $sqlGen = shift;
	my $field = shift;
	my $comparison = shift;
	my @criteria = @_;
	my $fieldDefn;
	
	$class = ref($class) || $class;
	no strict 'refs';
	my SQL::GenerateQuery::Condition $self = [\%{"${class}::FIELDS"}];
	
	$self->{sqlGen} = $sqlGen;
	
	# Validate the field & get the join name
	unless($sqlGen->fields($field))
	{
		my @fields = $field =~ /\{(\w+)\}/g;
		die "Only one field may be specified" if $#fields;
		die "Field '$_' is invalid" unless $sqlGen->fields($fields[0]);
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
			join => '',
		};
	$compareHash->{fieldDefn} = $fieldDefn if defined $fieldDefn;
	$self->{compares} = [$compareHash];
	
	bless $self, $class;
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
	my SQL::GenerateQuery::Condition $self = [\%{"${class}::FIELDS"}];
	use strict;
	
	$self->{sqlGen} = $sqlGen;
	$self->{compares} = [];
	
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

	bless $self, $class;
	return $self;
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
		$columnDefn .= defined $fieldData->{'comp-column'} ? $fieldData->{'comp-column'} : $fieldData->{column};
		my $compData = $sqlGen->comparisons($comparison);
		
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
			print "handling special fieldDefn '$fieldDefn' for columnDefn '$columnDefn'\n";
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
	foreach my $field (@{$opts{outColumns}})
	{
		my $fieldDefn;
		unless ($sqlGen->fields($field))
		{
			my @fields = $field =~ /\{(\w+)\}/g;
			die "Only one field may be specified" if $#fields;
			die "Field '$_' is invalid" unless $sqlGen->fields($fields[0]);
			$fieldDefn = $field;
			$field = $fields[0];
		}
		# Add the selected columns to the SELECT clause
		my $fieldData = $sqlGen->fields($field);
		
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
		$selectCol .= " AS $field";
		push @SELECT, $selectCol;
		
		# Add the appropriate FROM tables and join WHERE conditions
		$self->addTableToFROM($fieldData->{join}, \@FROM, \@WHERE, \@bindParams) if $fieldData->{join};
	}
	
	# Process the Order By
	foreach my $field (@{$opts{orderBy}})
	{
		my $fieldDefn;
		unless ($sqlGen->fields($field))
		{
			my @fields = $field =~ /\{(\w+)\}/g;
			die "Only one field may be specified" if $#fields;
			die "Field '$_' is invalid" unless $sqlGen->fields($fields[0]);
			$field = $fields[0];
		}
		
		push @ORDER_BY, $field;
	}
	
	my $SQL = '';
	
	# SELECT
	$SQL .= "SELECT";
	$SQL .= defined $opts{distinct} && $opts{distinct} ? " DISTINCT\n" : "\n";
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
	
	# ORDER BY
	if (@ORDER_BY)
	{
		$SQL .= "ORDER BY\n";
		$SQL .= join ",\n", map {"\t$_"} @ORDER_BY;
		$SQL .= "\n";
	}
	
	# GROUP BY
	if (@GROUP_BY)
	{
		$SQL .= "GROUP BY\n";
		$SQL .= join ",\n", map {"\t$_"} @GROUP_BY;
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

=head1 DESCRIPTION


=cut
