##############################################################################
package SQL::Generator;
##############################################################################

use strict;
use SDE::CVS ('$Id: Generator.pm,v 1.1 2000-08-31 14:26:39 robert_jenks Exp $', '$Name:  $');
use XML::Parser;
use fields qw(qdlFile id fields views);
use vars qw(%CACHE $COMPARISONS);

%CACHE = ();

$COMPARISONS = [
	{caption => 'is', id => 'is', operator => '=', value => 'criteria' },
	{caption => 'is not', id => 'isnot', operator => '!=', value => 'criteria' },
	{caption => 'contains', id => 'contains', operator => 'LIKE', value => '%criteria%' },
	{caption => 'does not contain', id => 'doesnotcontain', operator => 'NOT LIKE', value => '%criteria%'},
	{caption => 'does not match', id => 'doesnotmatch', operator => 'NOT LIKE', value => 'criteria'},
	{caption => 'starts with', id => 'startswith', operator => 'LIKE', value => 'criteria%'},
	{caption => 'ends with', id => 'endswith', operator => 'LIKE', value => '%criteria'},
	{caption => 'greater than', id => 'greaterthan', operator => '>', value => 'criteria'},
	{caption => 'less than', id => 'lessthan', operator => '<', value => 'criteria'},
	{caption => 'is defined', id => 'isdefined', operator => 'IS NOT NULL', value => ''},
	{caption => 'is not defined', id => 'isnotdefined', operator => 'IS NULL', value => ''},
	{caption => 'matches', id => 'matches', operator => 'LIKE', value => 'criteria'},
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
	my SQL::Generator $self = [\%{"${class}::FIELDS"}];
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
	my SQL::Generator $self = shift;
	return SQL::Generator::Condition->new($self, @_);
}


# AND together multiple condition object into a new merged condition object
sub AND
{
	my SQL::Generator $self = shift;
	return SQL::Generator::Condition->joinConditions($self, 'AND', @_);
}


# OR together multiple condition object into a new merged condition object
sub OR
{
	my SQL::Generator $self = shift;
	return SQL::Generator::Condition->joinConditions($self, 'OR', @_);
}


# Sets and/or returns the id of the object
sub id
{
	my SQL::Generator $self = shift;
	$self->{id} = $_[0] if defined $_[0];
	return $self->{id};
}


# Sets and/or returns the definition of a field
# Without a param, it returns a list of fields
sub field
{
	my SQL::Generator $self = shift;
	my ($id, $value) = @_;
	unless (defined $id)
	{
		return map {$_->{id}} @{$self->{fields}}[1..$#{$self->{fields}}];
	}
	if (defined $value)
	{
		die "Field data must be a hash ref" unless ref($value) eq 'HASH';
		my %newField = %{$value};
		push @{$self->{fields}}, \%newField or return 0;
		return 1;
	}
	return $self->{fields}->{$id};
}

# Sets and/or returns the definition of a view
# Without a param, it returns a list of views
sub view
{
	my SQL::Generator $self = shift;
	my ($id, $value) = @_;
	unless (defined $id)
	{
		return keys %{$self->{views}};
	}
	if (defined $value)
	{
		die "Field data must be a hash ref" unless ref($value) eq 'HASH';
		my %newView = %{$value};
		$self->{views}->{$id} = \%newView;
		return 1;
	}
	return $self->{views}->{$id};
}


# Returns the definition of a comparison
# Without a param, it returns a list of comparisons
sub comparison
{
	my SQL::Generator $self = shift;
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
	my SQL::Generator $self = shift;
	my $qdlFile = $self->{qdlFile};
	
	$self->{fields} = [];
	$self->{views} = {};
	
	# Import the QDL data
	my $parser = new XML::Parser(Style => 'Tree');
	my $qdl = $parser->parsefile($qdlFile) or die "Unable to open '$qdlFile'";

	$self->parseTags($qdl);
	
	# Turn $self->{fields} into a Psuedo-Hash
	my $i = 1;
	my %fieldIndex = map {$_->{id}, $i++} @{$self->{fields}};
	unshift @{$self->{fields}}, \%fieldIndex;
}


sub parseTags
{
	my SQL::Generator $self = shift;
	my $tags = shift;
	while (defined (my $tag = shift @$tags) and defined(my $value = shift @$tags))
	{
		next unless $tag;
		if ($tag eq 'query')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->id($value->[0]->{id});
			}
		}
		if ($tag eq 'field')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->field($value->[0]->{id}, $value->[0]);
			}
		}
		if ($tag eq 'view')
		{
			if (exists $value->[0]->{id} && defined $value->[0]->{id})
			{
				$self->view($value->[0]->{id}, $value->[0]);
			}
		}
		# If the tag contains more tags call on Mr Recursion
		if ($#{$value})
		{
			# Passes a ref to a slice (which excludes the element 0 attributes)
			$self->parseTags([@$value[1..$#{$value}]]);
		}
	}
}



##############################################################################
package SQL::Generator::Condition;
##############################################################################

use strict;
use SQL::Generator;
use fields qw(sqlGen compares);


# Creates a new comparison object
sub new
{
	my $class = shift;
	my SQL::Generator $sqlGen = shift;
	my ($field, $comparison, $criteria) = @_;
		
	$class = ref($class) || $class;
	no strict 'refs';
	my SQL::Generator::Condition $self = [\%{"${class}::FIELDS"}];
	
	$self->{sqlGen} = $sqlGen;
	
	# Validate the field & get the view name
	$sqlGen->field($field) or die "Field '$field' is invalid";
	
	# Validate the comparison
	my $compare = $sqlGen->comparison($comparison);
	unless ($compare)
	{
		die "Comparison '$comparison' is invalid";
	}
	
	# Validate the criteria
	#if (defined $criteria && $compare->{value} !~ /criteria/)
	#{
	#	die "Criteria '$criteria' cannot be specified for a '$comparison' comparison";
	#}
	#if (! defined $criteria && $compare->{value} =~ /criteria/)
	#{
	#	die "Criteria must be specified when using a '$comparison' comparison";
	#}
	
	# Add it
	$self->{compares} = [
		{
			field => $field,
			comparison => $comparison,
			criteria => $criteria,
			startParen => 0,
			endParen => 0,
			join => '',
		},
	];
	
	bless $self, $class;
	return $self;
}


# Creates a new comparison object by combining two or more existing 
# comparison objects
sub joinConditions
{
	my $class = shift;
	my SQL::Generator $sqlGen = shift;
	my $type = shift;
	my @conditions = @_;
	
	# Validate the join type
	return 0 unless $type eq 'AND' || $type eq 'OR';
	
	# Validate the conditions
	foreach (@conditions)
	{
		return 0 unless ref($_) && $_->isa('SQL::Generator::Condition');
	}
	
	# Create an object
	$class = ref($_[0]) || $_[0];
	no strict 'refs';
	my SQL::Generator::Condition $self = [\%{"${class}::FIELDS"}];
	use strict;
	
	$self->{sqlGen} = $sqlGen;
	$self->{compares} = [];
	
	# Copy the conditions into the new object
	my $lastCond = $#conditions;
	foreach my $i (0..$#conditions)
	{
		my SQL::Generator::Condition $curCond = $conditions[$i];
		unless ($self->{sqlGen} == $curCond->{sqlGen})
		{
			die "All conditions must be generated from the same SQL::Generator object";
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
	my SQL::Generator::Condition $self = shift;
	my %opts = @_;
	
	my @SELECT = ();
	my @FROM = ();
	my @WHERE = ();
	my @ORDER_BY = ();
	my @GROUP_BY = ();
	my @bindParams = ();
	
	my SQL::Generator $sqlGen = $self->{sqlGen};
	
	# Add any autoInclude tables to the query
	foreach my $view ($sqlGen->view())
	{
		my $viewData = $sqlGen->view($view) or die "Can't get view '$view'";
		if (defined $viewData->{autoInclude} && $viewData->{autoInclude})
		{
			$self->addTableToFROM($view, \@FROM, \@WHERE, \@bindParams) ;
		}
	}
	
	# Process the Query Definition
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

		my $fieldData = $sqlGen->field($field);
		my $columnDefn = defined $fieldData->{columndefn} ? $fieldData->{columndefn} : $fieldData->{view} . "." . $fieldData->{column};
		my $compData = $sqlGen->comparison($comparison);
		
		# Add the appropriate FROM tables and join WHERE conditions		
		$self->addTableToFROM($fieldData->{view}, \@FROM, \@WHERE, \@bindParams);

		# Add the bind parameter		
		my $placeHolder = '';
		if ($compData->{value} ne '')
		{
			my $value = $compData->{value};
			$value =~ s/criteria/$criteria/g if defined $criteria;
			push @bindParams, $value;
			$placeHolder = ' ?';
		}

		$startParen++ if $i == 0;
		$endParen++ if $i == $#{$self->{compares}};
		$startParen = '(' x $startParen;
		$endParen = ')' x $endParen;
		
		# Add the WHERE condition
		push @WHERE, $startParen . $columnDefn . " " . $compData->{operator} . $placeHolder . $endParen . $join;

		# If they didn't specify a join for this parameter we're done!
		last unless $join;
		$i++;
	}
	
	# Process the Output Columns
	foreach my $field (@{$opts{outColumns}})
	{
		# Add the selected columns to the SELECT clause
		my $fieldData = $sqlGen->field($field);
		my $selectCol = $fieldData->{view} . '.' . $fieldData->{column};
		$selectCol .= " AS $field";
		push @SELECT, $selectCol;
		
		# Add the appropriate FROM tables and join WHERE conditions
		$self->addTableToFROM($fieldData->{view}, \@FROM, \@WHERE, \@bindParams);
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


sub addTableToFROM
{
	my SQL::Generator::Condition $self = shift;
	my ($view, $FROM, $WHERE, $bindParams) = @_;
	my SQL::Generator $sqlGen = $self->{sqlGen};
	my $viewData = $sqlGen->view($view);
	
	# Construct a proper FROM clause member
	my $table = $viewData->{table};
	my $from = $table;
	$from .= " $view" unless $table eq $view;

	# If we haven't already added this FROM clause
	unless (grep {$_ eq $from} @$FROM)
	{
		# Add the table to the bottom of the FROM clause
		push @$FROM, $from;

		if (exists $viewData->{condition})
		{
			# Add the appropriate join to the top of the WHERE clause
			unshift @$WHERE, $viewData->{condition} . " AND";
		}
		if (exists $viewData->{bindParams})
		{
			# Add necessary bind params to top of list
			unshift @$bindParams, @{$viewData->{bindParams}};
		}
	}
}


# Generates XAP Dialog XML
sub genXAP
{
	my SQL::Generator::Condition $self = shift;
	my %opts = @_;
	
	# TODO: Something Useful :-)
}


1;


__END__

=head1 NAME

SQL::Generator - Perl Object Interface for Generating SQL Statements

=head1 SYNOPSIS

 use SQL::Generator;
 
 my $personQuery = new SQL::Generator(file => 'person.qdl', cache => 1);
 
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
