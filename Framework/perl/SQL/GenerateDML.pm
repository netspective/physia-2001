##############################################################################
package SQL::GenerateDML;
##############################################################################

use strict;
use base qw(Exporter);

use enum qw(BITMASK:DMLCOLUMNFLAG_ PRIMARYKEY GETSEQNEXTVAL DATE DATEFMT CUSTOMFMT);
use vars qw(@EXPORT);

# DATE means date is provided, format is implied
# DATEFMT means date is provided, format is specified as a bind parameter

#
# datetime is synomous with DATE
#
use constant DMLCOLUMNFLAG_DATETIME => DMLCOLUMNFLAG_DATE;
use constant DMLCOLUMNFLAG_DATETIMEFMT => DMLCOLUMNFLAG_DATEFMT;

@EXPORT = qw(
	DMLCOLUMNFLAG_PRIMARYKEY 
	DMLCOLUMNFLAG_GETSEQNEXTVAL 
	DMLCOLUMNFLAG_CUSTOMFMT
	DMLCOLUMNFLAG_DATE
	DMLCOLUMNFLAG_DATEFMT
	DMLCOLUMNFLAG_DATETIME
	DMLCOLUMNFLAG_DATETIMEFMT
	generateDML
	);

sub generateDML
{
	my %params = @_;
	
	my $command = $params{command} || 'insert';
	my $tableName = $params{tableName} || die "'tableName' required as a parameter";
	my $columns = $params{columns} || ($command eq 'delete' ? undef : (die "'columns' required as a parameter"));
	my $defaultDateFormat = $params{dateFormat} || 'MM/DD/YYYY';
	
	#
	# if $columns is a string, then it's append right after the INSERT INTO stmt
	# if $columns is a hash ref like { col_a => 'col_a_value', col_b => 'col_b_value' },
	#   then the INSERT statement is constructed using the following rules
	#   if a value is a scalar, it's considered a literal bind parameter
	#   if a value is a reference to a scalar, it's appended into the SQL statement (instead of as a bind param)
	#   if a value is undefined (undef) then NULL is put in its place
	#   if a value is a reference to a subroutine, the subroutine is executed to get bind value (first parameter is \%params)
	#   if a value is a reference to an array, then the items in the array are as follows
	#     0  - special-handling flags (one or more of DMLCOLUMNFLAG_*)
	#     1+ - any additional parameters necessary for special-handling
	#          almost always, position 1 is the value of the column
	#          when DMLCOLUMNFLAG_GETSEQNEXTVAL is specified, then position 1 must have the sequence name
	#          when DMLCOLUMNFLAG_DATE is specified, then position 2 could have the format string including '?'
	#
	
	my @bind_params;
	my @sequences;
	my $sql = ($command eq 'insert' ? 'insert into' : ($command eq 'update' ? 'update' : 'delete from')) . " $tableName";
	my $isInsert = $command eq 'insert';

	unless($command eq 'delete')
	{
		if (ref($columns) eq 'HASH') 
		{
			my @colNames = keys(%$columns);
			my @colValues = values(%$columns);
			die "generateDML must have columns" unless $#colNames > -1;

			if($isInsert)
			{
				$sql .= ' (';
				for (my $i = 0; $i <= $#colNames; $i++) 
				{
					if ($i) { $sql .= ', ' }
					$sql .= $colNames[$i];
				}
				$sql .= ') values (';
			}
			else
			{
				$sql .= ' set ';
			}

			my $colValue;
			for (my $i = 0; $i <= $#colNames; $i++) 
			{
				$colValue = $colValues[$i];

				$sql .= ', ' if $i;
				$sql .= "$colNames[$i] = " unless $isInsert;
				if (ref $colValue) 
				{
					if(ref $colValue eq 'SCALAR')
					{
						$sql .= $$colValue;
					}
					elsif(ref $colValue eq 'ARRAY')
					{
						my $colFlags = $colValue->[0];
						if($colFlags & DMLCOLUMNFLAG_GETSEQNEXTVAL)
						{
							$sql .= '?';
							push(@sequences, [$colNames[$i], $colFlags, $colValue->[1], scalar(@bind_params)]);
							push(@bind_params, '$' . $colValue->[1]);
						}
						elsif(defined($colValue->[1])) 
						{
							if($colFlags & (DMLCOLUMNFLAG_DATE | DMLCOLUMNFLAG_DATEFMT))
							{
								$sql .= "to_date(?, ?)";
								push(@bind_params, $colFlags & DMLCOLUMNFLAG_DATEFMT ? $colValue->[1] : $defaultDateFormat);
							}
							elsif($colFlags & DMLCOLUMNFLAG_CUSTOMFMT)
							{
								$sql .= $colValue->[1];
								my @bindValues = @$colValue;
								splice(@bindValues, 0, 2);
								push(@bind_params, @bindValues);
							}
						} 
						else
						{
							$sql .= 'NULL';
						}
					}
					elsif(ref $colValue eq 'CODE')
					{
						$sql .= '?';
						push(@bind_params, &$colValue(\%params));
					}
				} 
				else 
				{
					if (defined($colValue)) 
					{
						$sql .= '?';
						push(@bind_params, $colValue);
					} 
					else
					{
						$sql .= 'NULL';
					}
				}
			}

			$sql .= ')' if $isInsert;
		} 
		elsif (!ref($columns) and $columns) 
		{
			$sql .= $columns;
		} 
	}
	
	if(!$isInsert && exists $params{whereCond})
	{
		$sql .= ' where ' . $params{whereCond};
		push(@bind_params, @{$params{whereCondBindParams}}) if exists $params{whereCondBindParams} && $params{whereCondBindParams};
	}
	
	return ($sql, \@bind_params, \@sequences);
}

##############################################################################
package SQL::GenerateDML_UnitTest;
##############################################################################

use strict;
use SQL::GenerateDML;

#
# you can execute the UNIT TEST from the command line as:
# perl -MSQL::GenerateDML -w -e "SQL::GenerateDML_UnitTest::executeTest();"
#

sub showDML
{
	my ($sql, $bindParams, $sequences) = @_;
	my $seqData = '';
	foreach (@$sequences)
	{
		$seqData .= "$_->[0]: '$_->[2]' at bind position $_->[3] (flags: $_->[1])\n";
	}
	
	print "\n---------------------\n";
	print "SEQUENCES: $seqData\nDML: $sql\n" . 'BIND PARAMS: ' . ($bindParams ? join(', ', @$bindParams) : 'NONE');
}

sub getColJValue
{
	my $params = shift;
	return 'COLJVALUE_is_' . ($params->{colJCallbackParam} || $params->{columns}->{cola});
}
	
sub executeTest
{
	my ($sql, $bindParams, $sequences) = SQL::GenerateDML::generateDML(
		command => 'insert',
		tableName => 'tableabc', 
		dateFormat => 'AA/BB/CCCC',
		columns => { 
			cola => 'a',
			colb => 'b',
			colc => \"'LITERAL'",
			cold => [SQL::GenerateDML::DMLCOLUMNFLAG_CUSTOMFMT, 'this(?, ?)', 'this1', 'this2'],
			cole => [SQL::GenerateDML::DMLCOLUMNFLAG_GETSEQNEXTVAL, 'sequence_name'],
			colf => [SQL::GenerateDML::DMLCOLUMNFLAG_DATE, '12/02/1999'],
			colg => [SQL::GenerateDML::DMLCOLUMNFLAG_DATEFMT, '12/02/2000', 'MM/DD/YY'],
			colh => undef,
			coli => undef,
			colj => \&getColJValue,
		});
	showDML($sql, $bindParams, $sequences);

	($sql, $bindParams, $sequences) = SQL::GenerateDML::generateDML(
		command => 'update',
		tableName => 'xyz', 
		columns => { 
			cola => 'a',
			colb => 'b',
			colc => \"'LITERAL'",
			cold => [SQL::GenerateDML::DMLCOLUMNFLAG_CUSTOMFMT, 'this(?, ?)', 'this1', 'this2'],
			cole => [SQL::GenerateDML::DMLCOLUMNFLAG_GETSEQNEXTVAL, 'sequence_name'],
			colf => [SQL::GenerateDML::DMLCOLUMNFLAG_DATE, '12/02/1999'],
			colg => [SQL::GenerateDML::DMLCOLUMNFLAG_DATEFMT, '12/02/2000', 'MM/DD/YY'],
			colh => [SQL::GenerateDML::DMLCOLUMNFLAG_GETSEQNEXTVAL, 'sequence_name2'],
			coli => undef,
			colj => \&getColJValue,
		},
		colJCallbackParam => 'hello',
		whereCond => 'cola = ?', 
		whereCondBindParams => ['x']);
	showDML($sql, $bindParams, $sequences);

	($sql, $bindParams, $sequences) = SQL::GenerateDML::generateDML(
		command => 'delete',
		tableName => 'xyz',
		whereCond => 'cola = ?', 
		whereCondBindParams => ['x']);

	showDML($sql, $bindParams, $sequences);
}

1;
