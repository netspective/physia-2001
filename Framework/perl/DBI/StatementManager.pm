##############################################################################
package DBI::StatementManager;
##############################################################################

#
# STMTMGRFLAG_CACHE IS NOT IMPLEMENTED YET, BUT NEEDS TO BE
# THIS PACKAGE DOES NOT LIKE ITS METHODS TO BE OVERRIDEN (PERFORMANCE)
#

use strict;
use Exporter;
use Number::Format;
use CGI::Layout;
use Data::Publish;

use enum qw(BITMASK:STMTMGRFLAG_ NULLIFNAMENOTFOUND DYNAMICSQL DEBUG
	CACHE REPLACEVARS FLATTREE);

use vars qw(@ISA @EXPORT $ALL_STMT_MANAGERS $SQLSTMT_DEFAULTDATEFORMAT
	$SQLSTMT_DEFAULTCURRENCYFORMAT $SQLSTMT_DEFAULTTIMEFORMAT $SQLSTMT_DEFAULTSTAMPFORMAT %REPORT_STYLE);

use constant STMTMGRFLAGS_NONE => 0;

@ISA    = qw(Exporter);
@EXPORT = qw(
	$SQLSTMT_DEFAULTDATEFORMAT
	$SQLSTMT_DEFAULTTIMEFORMAT
	$SQLSTMT_DEFAULTSTAMPFORMAT
	$SQLSTMT_DEFAULTCURRENCYFORMAT
	$ALL_STMT_MANAGERS
	STMTMGRFLAG_DEBUG
	STMTMGRFLAG_NONE
	STMTMGRFLAG_CACHE
	STMTMGRFLAG_DYNAMICSQL
	STMTMGRFLAG_REPLACEVARS
	STMTMGRFLAG_RPT_DEFINITIONPROVIDED
	STMTMGRFLAG_RPT_DATAPROVIDED
	STMTMGRFLAG_RPT_HIDEROWSEP
	STMTMGRFLAGS_NONE
);

use constant STMTMGRFLAG_NONE => 0;
use constant STMTPUBLCALLBACKKEY => 'publishFunc';
use constant STMTPUBLDEFNKEY_BASE => 'publishDefn';

$SQLSTMT_DEFAULTDATEFORMAT     = 'MM/DD/YYYY';
$SQLSTMT_DEFAULTTIMEFORMAT     = 'HH12:MI AM';
$SQLSTMT_DEFAULTSTAMPFORMAT	   = 'MM/DD/YYYY HH12:MI AM';
$SQLSTMT_DEFAULTCURRENCYFORMAT = 'L999G999G990D99';

$ALL_STMT_MANAGERS = {};

sub new
{
	my ($type, %params) = @_;
	my $self = bless \%params, $type;

	# the keys are
	#   -- xxx => statement name (normal)
	#   -- _sth_xxx => cached statement handle for statement xxx
	#   -- _dta_xxx_aa_bb => cached data for statement xxx, param aa & bb
	#   -- _dpc_zzz_xxx => data publish component (a CODE ref that can publish a statement xxx using component prefix zzz) -- accepts $page, $flags and returns a string (like a component)
	#   -- _dpd_xxx => default data publication definition (dpd) for statement xxx [used by Data::Publish]
	#   -- _dpd_xxx_zzz => named ("zzz") data publication definition (dpd) for statement xxx
	#   -- _yyy => private variable for object

	$self->fixupStatements();

	my $name = "$self";
	$name =~ s/\=.*$//;
	$ALL_STMT_MANAGERS->{$name} = $self;
	$self->{id} = $name;

	$self;
}

sub fixupStatements
{
	my ($self) = @_;
	my %appendKeyValues = ();

	my $className = $self;
	$className =~ s/\=.*$//;

	while(my ($key, $value) = each(%$self))
	{
		next if $key =~ /^_/;

		# when a statement is a hash ref, then it's contents may have variable substitutions
		# and Data::Publish definitions embedded;
		if(ref $value eq 'HASH')
		{
			# If we find a sqlStmt or _stmtFmt (old-style) variable, it means that we want
			# the statement to be based on another statement with some simple variable
			# substitutions by using %key%. This allows run-time generation of multiple
			# SQL statements from a single template without incurring the database
			# performance penalty
			#
			my $stmt = $value->{_stmtFmt} || $value->{sqlStmt};
			if (defined $stmt)
			{
				$stmt =~ s!\%(\w+:)?(.*?)\%!
					if(defined $1 and $1 eq 'simpleDate:')
					{
						"decode(to_char($2, 'YYYY'), to_char(sysdate, 'YYYY'), to_char($2, 'Mon DD'), to_char($2, 'MM/DD/YY'))"
					}
					elsif (defined $1 and $1 eq 'simpleStamp:')
					{
						my $element = $2;
						my $offset = $2;
						$offset =~ /.*?([+-].*)/;
						"decode(to_char($element, 'YYYYMMDD'), to_char(sysdate $1, 'YYYYMMDD'), to_char($element, 'hh:miam'), to_char($element, 'MM/DD/YYYY hh:miam'))"
					}
					else { $value->{$2} || "" }
					!ge;
			}
			$self->{$key} = defined $stmt ? $stmt : undef;

			# see if any Data::Publish definitions (DPD) exist
			#
			my $basePublDefn = $value->{STMTPUBLDEFNKEY_BASE()};
			while(my ($paramName, $paramValue) = each(%$value))
			{
				if($paramName =~ m/^publishDefn_(.*)$/)
				{
					inheritHashValues($paramValue, $basePublDefn) if $basePublDefn;
					inheritHashValues($paramValue, $value->{"publishDefn_$paramValue->{inherit}"}) if $paramValue->{inherit};
					$appendKeyValues{"_dpd_$key\_$1"} = $paramValue;
				}
				elsif($paramName =~ m/^publishComp_(.*)$/)
				{
					$appendKeyValues{"_dpc_$1\_$key"} = $paramValue;
				}
			}
			$appendKeyValues{"_dpd_$key"} = $basePublDefn if $basePublDefn;
		}
	}

	# we couldn't modify the $self hash in the "each" loop above so we do it now
	while(my ($key, $value) = each %appendKeyValues)
	{
		$self->{$key} = $value;
	}
}

sub getStatementHdl
{
	my ($self, $dbpage, $flags, $name) = @_;
	if($flags & STMTMGRFLAG_DYNAMICSQL)
	{
		my $stmtHdl = $dbpage->{db}->prepare($name) or die $dbpage->{db}->errstr();
		return $stmtHdl;
	}

	my $sthName = '_sth_' . $name;

	if(my $handle = $self->{$sthName})
	{
		return $handle;
	}
	else
	{
		if(my $statement = $self->{$name})
		{
			my $stmtHdl = undef;
			eval {
				$stmtHdl = $dbpage->{db}->prepare($statement) or die $dbpage->{db}->errstr();
			};
			if($@ || ! $stmtHdl)
			{
				$dbpage->addDebugStmt("PREPARE_ERROR (Statement '$name')", $statement);
				die "PREPARE_ERROR (Statement '$name'): $@";
			}
			#return $self->{$sthName} = $stmtHdl;
			return $stmtHdl;
		}
		else
		{
			if($flags & STMTMGRFLAG_NULLIFNAMENOTFOUND)
			{
				return undef;
			}
			else
			{
				die "sql statement handle '$name' not found";
			}
		}
	}
}

#
# NOTE: the way in which execute method is called in get* methods, it can NOT be subclassed
#

sub execute
{
	my ($self, $dbpage, $flags, $name) = (shift, shift, shift, shift);

	my $execRV = undef;

	# Prepare a debug message for logging and fatal error handling
	my $debugMsg = '';
	my $stack = '';
	if (1) # FIX ME!!! Need to skip this block if we're in production for performance.
	{
		my $stmtMgrName = ref($self);
		my $stmtName = $flags & STMTMGRFLAG_DYNAMICSQL ? '<i>Dynamic SQL</i>' : $name;
		my $stmt = $flags & STMTMGRFLAG_DYNAMICSQL ? $name : $self->{$name};
		for my $i (0..50)
		{
			my ($pack, $file, $line) = caller($i);
			last unless $pack;
			$stack .= '&nbsp;&nbsp;' . "$i - $pack line $line<br>";
		}
		$stack = "<b>Stack Trace:</b><br>$stack<br>";
		$debugMsg = "<b>Statement Manager:</b> <a href='/sde/stmgrs/$stmtMgrName'>$stmtMgrName</a><br>";
		$debugMsg .= "<b>Statement Name:</b> ";
		$debugMsg .= $flags & STMTMGRFLAG_DYNAMICSQL ? "$stmtName<br>" : "<a href='/sde/stmgrs/$stmtMgrName/$stmtName'>$stmtName</a><br>";
		$debugMsg .= "<b>Query:</b><pre>$stmt</pre>";
		$debugMsg .= "<b>Bind Parameters:</b><BR>" if defined $_[0];
		for my $i ( 0..$#_)
		{
			my $value = defined $_[$i] ? "'$_[$i]'" : '<i>undef</i>';
			$debugMsg .= '&nbsp;&nbsp;:' . ($i+1) . " = $value<br>";
		}
		$debugMsg .= "<br>";
	}
	
	my $stmtHdl = $self->getStatementHdl($dbpage, $flags, $name);
	
	# Check for #something# replacements
	my @params = @_;
	if($flags & STMTMGRFLAG_REPLACEVARS)
	{
		#
		# the substitution here (regexp) should be the same as the one in CGI::Page
		# basically, it replaces session.xxx with $page->session('xxx'), param.yyy with
		# $page->param('yyy'), and field.abc with $page->field('abc')
		#	
		grep
		{
			s/\#(\w+)\.?([\w\-\.]*)\#/
				if(my $method = $dbpage->can($1))
				{
					&$method($dbpage, $2);
				}
				else
				{
					"method '$1' not found in $dbpage";
				}
				/ge;
		} @params;
	}
	
	# Execute the SQL & handle errors
	eval {
		$execRV = $stmtHdl->execute(@params) or die $stmtHdl->errstr();
	};
	
	# Add the debug message if we're in debug mode or an error 
	if($@ || ($flags & STMTMGRFLAG_DEBUG) || $dbpage->param('_debug_stmt') eq $name || $dbpage->param('_debug_stmt_all'))
	{
		$debugMsg .= "<b>Execute Result Code:</b> " . (defined $execRV ? $execRV : '<i>undef</i>') . '<br>';
		$debugMsg .= $stack if $dbpage->param('_debug_stack') || $@;
		$debugMsg = "$@<br><br>" . $debugMsg if $@;
		die "$debugMsg\n" if $@;
		$dbpage->addDebugStmt($debugMsg);
	}
	
	wantarray ? ($stmtHdl, $execRV) : $stmtHdl;
}

sub recordExists
{
	my $stmtHdl = execute(@_);
	if(my $row = $stmtHdl->fetch())
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub getRowCount
{
	my $stmtHdl = execute(@_);
	return $stmtHdl->fetch()->[0];
}

sub getSingleValue
{
	my $stmtHdl = execute(@_);
	if(my $row = $stmtHdl->fetch())
	{
		$row->[0];
	}
	else
	{
		undef;
	}
}

sub getSingleValueList
{
	my $stmtHdl = execute(@_);
	my $list = ();

	while(my $row = $stmtHdl->fetch())
	{
		push(@$list, $row->[0]);
	}
	return $list;
}

sub getRowsAsArray
{
	my $stmtHdl = execute(@_);
	my @tableRows;
	
	while (my $currentRowRef = $stmtHdl->fetch()) {
		push @tableRows, [ @{$currentRowRef} ];
	}
	
	return \@tableRows;
}


sub getRowAsArray
{
	my $stmtHdl = execute(@_);
	return $stmtHdl->fetch();
}

sub getRowAsHash
{
	# params expected: self, dbpage, flags, stmtName, followed by any DBI ? param values
	my $data = undef;
	eval
	{
		my $stmtHdl = execute(@_);
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});

		my $rowRef = $stmtHdl->fetch();
		if($rowRef)
		{
			foreach (my $i = 0; $i < $colsCount; $i++)
			{
				$data->{lc($namesRef->[$i])} = $rowRef->[$i];
			}
		}
	};
	if($@)
	{
		my ($self, $dbpage, $flags, $name) = (shift, shift, shift, shift);
		my $sql = $self->{$name};
		#$dbpage->dbiErrorBox($@, $sql, @_);
		die "DBI Error: $@\n$sql\n" . join(', ', @_);
		$data = undef;
	}
	return $data;
}

sub getRowsAsHashList
{
	# params expected: dbpage, stmtName, followed by any DBI ? param values
	my $data = [];
	eval
	{
		my $stmtHdl = execute(@_);
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});

		my $rowRef = undef;
		while($rowRef = $stmtHdl->fetch())
		{
			my $rowData = {};
			foreach (my $i = 0; $i < $colsCount; $i++)
			{
				$rowData->{lc($namesRef->[$i])} = $rowRef->[$i];
			}
			push(@{$data}, $rowData);
		}
	};
	if($@)
	{
		my ($self, $dbpage, $flags, $name) = (shift, shift, shift, shift);
		my $sql = $self->{$name};
		#$dbpage->dbiErrorBox($@, $sql, @_);
		die "DBI Error: $@\n$sql\n" . join(', ', @_);
		$data = undef;
	}
	return $data;
}

#
# the getRowsAsHashTree is designed to work almost identically to getRowsAsHashList except
# it adds a new item to each record called _kids that allows hiearchical data to be displayed easily
#
sub getRowsAsHashTree
{
	# params expected: dbpage, flags, [stmtName, idColName, parentIdColName], followed by any DBI ? param values
	my %allRecords = ();
	my ($stmtName, $idColName, $parentIdColName) = @{$_[3]};
	my ($idColIdx, $parentIdColIdx) = (undef, undef);
	$_[3] = $stmtName; # make sure execute works properly since execute expects param4 to be $stmtName, not array ref
	eval
	{
		my $stmtHdl = execute(@_);
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});
		my $colIndex = 0;
		($idColName, $parentIdColName) = (lc($idColName), lc($parentIdColName));
		foreach (@{$namesRef})
		{
			$_ = lc($_);
			$idColIdx = $colIndex if ! defined $idColIdx && $idColName eq $_;
			$parentIdColIdx = $colIndex if ! defined $parentIdColIdx && $parentIdColName eq $_;
			$colIndex++;
		}

		my $rowRef = undef;
		my $rowIndex = 0;
		while($rowRef = $stmtHdl->fetch())
		{
			my $rowData = { _rowIndex => $rowIndex };
			foreach (my $i = 0; $i < $colsCount; $i++)
			{
				$rowData->{$namesRef->[$i]} = $rowRef->[$i];
			}
			$allRecords{$rowRef->[$idColIdx]} = $rowData;
		}
	};
	my $data = [];
	if($@)
	{
		my ($self, $dbpage, $flags, $info) = (shift, shift, shift, shift);
		my $sql = $self->{$stmtName};
		#$dbpage->dbiErrorBox($@, $sql, @_);
		die "DBI Error: $@\n$sql\n" . join(', ', @_);
		$data = undef;
	}
	else
	{
		while(my ($id, $record) = each %allRecords)
		{
			if(my $parentId = $record->{$parentIdColName})
			{
				push(@{$allRecords{$parentId}->{_kids}}, $record);
				$record->{_moved} = 1;
			}
		}

		foreach (sort { $a->{_rowIndex} <=> $b->{_rowIndex} } values %allRecords)
		{
			if(my $kids = $_->{_kids})
			{
				my @kids = sort { $a->{_rowIndex} <=> $b->{_rowIndex} } @$kids;
				$_->{_kids} = \@kids;
			}
			push(@$data, $_) unless $_->{_moved};
		}
	}
	undef %allRecords;
	return $data;
}

#
# the getRowsAsArrayTree reads in all the records produced by executing $stmtName
# it adds a new item to at the end of each record called $row->[lastItem] that allows hiearchical
# data to be displayed easily
#
sub getRowsAsArrayTree
{
	# params expected: dbpage, flags, [stmtName, idColIdx, parentIdColIdx], followed by any DBI ? param values
	my %allRecords = ();
	my ($stmtName, $idColIdx, $parentIdColIdx) = @{$_[3]};
	$_[3] = $stmtName; # make sure execute works properly since execute expects param4 to be $stmtName, not array ref

	my $stmtHdl = undef;
	eval
	{
		$stmtHdl = execute(@_);
		my $rowIndex = 0;
		while(my @row = $stmtHdl->fetchrow_array())
		{
			push(@row, { _rowIndex => $rowIndex, _kids => [] });
			$allRecords{$row[$idColIdx]} = \@row;
			#$_[1]->addDebugStmt($rowIndex . ' ' . join(', ', @rowData));
			$rowIndex++;
		}
		#$_[1]->addDebugStmt($rowIndex, join('-', keys %allRecords));
	};

	if($@)
	{
		my ($self, $dbpage, $flags, $info) = (shift, shift, shift, shift);
		my $sql = $self->{$stmtName};
		#$dbpage->dbiErrorBox($@, $sql, @_);
		die "DBI Error: $@\n$sql\n" . join(', ', @_);

		return (undef, $stmtHdl);
	}
	else
	{
		# move all the children under the appropriate parents
		my @moved = ();
		while(my ($id, $record) = each %allRecords)
		{
			if(my $parentId = $record->[$parentIdColIdx])
			{
				push(@{$allRecords{$parentId}->[-1]->{_kids}}, $record);
				$record->[-1]->{_moved} = 1;
			}
		}

		my @hierData = ();
		while(my ($id, $record) = each %allRecords)
		{
			my $moved = $record->[-1]->{_moved};
			if(my $kids = $record->[-1]->{_kids})
			{
				#my @kids = sort { $a->[-1]->{_rowIndex} <=> $b->[-1]->{_rowIndex} } @$kids;
				pop(@$record);
				#push(@$record, \@kids);
				push(@$record, $kids);
			}
			else
			{
				pop(@$record);
				push(@$record, []);
			}

			push(@hierData, $record) unless $moved;
		}

		# now sort everything by the original sort order and remove superfluous records
		#foreach (sort { $a->[$#$a]->{_rowIndex} <=> $b->[$#$b]->{_rowIndex} } values %allRecords)
		#foreach (values %allRecords)
		#{
			#my $hierData = $_->[-1];
			#my $moved = $hierData->{_moved};
			#$_[1]->addDebugStmt(join(', ', @{$_}) . " $hierData");
			#my $moved = 0;
			#if(ref $hierData eq 'HASH')
			#{
			#	my $moved = $hierData->{_moved};
				#if(my $kids = $hierData->{_kids})
				#{
				#	my @kids = sort { $a->[$#$a]->{_rowIndex} <=> $b->[$#$b]->{_rowIndex} } @$kids;
				#	pop(@{$_});
				#	push(@{$_}, \@kids);
				#}
				#else
				#{
				#	pop(@{$_});
				#	push(@{$_}, []);
				#}
			#}
			#push(@$data, $_) unless $moved;
		#}

		if($_[2] & STMTMGRFLAG_FLATTREE)
		{
			return ($_[0]->flattenArrayTree(\@hierData, [], 1), $stmtHdl);
		}
		else
		{
			return (\@hierData, $stmtHdl);
		}
	}
}

sub flattenArrayTree
{
	my ($self, $data, $newList, $level) = @_;

	# if we want a "flat" tree, then sort by high-level (parent), then by kids;
	# make the last items of each row the "level" numbers
	foreach (@$data)
	{
		push(@$newList, $_);
		my $kids = $_->[$#{$_}];
		$self->flattenArrayTree($kids, $newList, $level+1) if $kids && scalar(@$kids) > 0;
		pop(@{$_}); # remove the "kids" reference
		push(@{$_}, $level); # add the leve number
	}

	return $newList;
}

sub getRowsFormatted
{
	my ($self, $dbpage, $flags, $rowDefn, $name) = @_;
	my $stmtHdl = execute(@_);

	my $formattedStr = '';
	my $rowFmt = ref $rowDefn eq 'HASH' ? $rowDefn->{rowFmt} : $rowDefn;
	eval
	{
		my $stmtHdl = execute(@_);
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});

		my ($outRow, $rowRef) = ('', undef);
		while($rowRef = $stmtHdl->fetch())
		{
			($outRow = $rowFmt) =~ s/\#([\-]?\d+)\#/$rowRef->[$1]/g;
			$formattedStr .= $outRow;
		}
	};
	if($@)
	{
		my $sql = $self->{$name};
		$formattedStr = "DBI Error: $@\n$sql\n" . join(', ', @_);
	}
	if(ref $rowDefn eq 'HASH')
	{
		return $rowDefn->{prepend} . $formattedStr . $rowDefn->{append};
	}
	else
	{
		return $formattedStr;
	}
}

sub createParamsFromSingleRow
{
	my ($self, $dbpage, $flags, $name) = @_;
	my $stmtHdl = execute(@_);
	if(my $row = $stmtHdl->fetch())
	{
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});
		foreach (my $i = 0; $i < $colsCount; $i++)
		{
			$dbpage->param(lc($namesRef->[$i]), $row->[$i]);
		}

		if($row = $stmtHdl->fetch())
		{
			$dbpage->addError("Expected only one row, got more than one for statment <code>'$name'</code>");
		}
		return scalar(@{$namesRef});
	}
}

sub createFieldsFromSingleRow
{
	my ($self, $dbpage, $flags, $name) = @_;
	my $stmtHdl = execute(@_);
	if(my $row = $stmtHdl->fetch())
	{
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});
		foreach (my $i = 0; $i < $colsCount; $i++)
		{
			$dbpage->field(lc($namesRef->[$i]), $row->[$i]);
		}

		if($row = $stmtHdl->fetch())
		{
			$dbpage->addError("Expected only one row, got more than one for statment <code>'$name'</code>");
		}
		return scalar(@{$namesRef});
	}
}

sub createPropertiesFromSingleRow
{
	my ($self, $dbpage, $flags, $name) = @_;

	my $propertyPrefix = '';
	if(ref $name eq 'ARRAY')
	{
		$propertyPrefix = $name->[1];
		$_[3] = $name->[0];
	}

	my $stmtHdl = execute(@_);
	if(my $row = $stmtHdl->fetch())
	{
		my $namesRef = $stmtHdl->{NAME};
		my $colsCount = scalar(@{$namesRef});
		foreach (my $i = 0; $i < $colsCount; $i++)
		{
			$dbpage->property(lc($propertyPrefix ? ($propertyPrefix . $namesRef->[$i]) : $namesRef->[$i]), $row->[$i]);
		}

		if($row = $stmtHdl->fetch())
		{
			$dbpage->addError("Expected only one row, got more than one for statment <code>'$name'</code>");
		}
		return scalar(@{$namesRef});
	}
}

sub createHtml
{
	my ($self, $dbpage, $flags, $name, $bindColsRef, $defnAltName, $publParams, $pubD) = @_;
	
	my $stmtHdl = $self->execute($dbpage, $flags, $name, @$bindColsRef);
	my $defnName = $defnAltName ? "$name\_$defnAltName" : $name;
	my $publDefn = $self->{"_dpd_$defnName"} || {};
	$publDefn = $pubD if $pubD;

	$publParams = {} unless $publParams;
	$publParams->{stmtId} = $name unless exists $publParams->{stmtId};

	prepareStatementColumns($dbpage, $flags, $stmtHdl, $publDefn) unless exists $publDefn->{columnDefn};
	return
		createHtmlFromStatement($dbpage, $flags, $stmtHdl, $publDefn, $publParams);
}

sub createHierHtml
{
	my ($self, $dbpage, $flags, $name, $bindColsRef, $defnAltName, $publParams) = @_;

	my ($data, $stmtHdl) = $self->getRowsAsArrayTree($dbpage, $flags | STMTMGRFLAG_FLATTREE, $name, @$bindColsRef);
	my $defnName = $defnAltName ? "$name\_$defnAltName" : $name;
	my $publDefn = $self->{"_dpd_$defnName"} || {};
	$publParams = {} unless $publParams;
	$publParams->{stmtId} = $name unless exists $publParams->{stmtId};

	prepareStatementColumns($dbpage, $flags, $stmtHdl, $publDefn) unless exists $publDefn->{columnDefn};
	return
		createHtmlFromData($dbpage, $flags, $data, $publDefn, $publParams);
}

sub createHtmlCustom
{
	my ($self, $dbpage, $flags, $name, $bindColsRef, $publDefn, $publParams) = @_;

	my $stmtHdl = $self->execute($dbpage, $flags, $name, @$bindColsRef);

	prepareStatementColumns($dbpage, $flags, $stmtHdl, $publDefn) unless exists $publDefn->{columnDefn};
	return
		createHtmlFromStatement($dbpage, $flags, $stmtHdl, $publDefn, $publParams);
}

sub createHierHtmlCustom
{
	my ($self, $dbpage, $flags, $name, $bindColsRef, $publDefn, $publParams) = @_;

	my ($data, $stmtHdl) = $self->getRowsAsArrayTree($dbpage, $flags | STMTMGRFLAG_FLATTREE, $name, @$bindColsRef);

	prepareStatementColumns($dbpage, $flags, $stmtHdl, $publDefn) unless exists $publDefn->{columnDefn};
	return
		createHtmlFromData($dbpage, $flags, $data, $publDefn, $publParams);
}

sub getAttribute
{
	my $data = getRowAsHash(@_);

	if($data->{item_name} =~ m/^(.*)\/(.*)$/)
	{
		$data->{attr_path} = $1;
		$data->{attr_name} = $2;
	}
	else
	{
		$data->{attr_path} = '';
		$data->{attr_name} = $data->{item_name};
	}
	return $data;
}

sub getAttributes
{
	my $list = getRowsAsHashList(@_);
	foreach (@$list)
	{
		# the name is the piece after the last /
		if($_->{item_name} =~ m/^(.*)\/(.*)$/)
		{
			$_->{attr_path} = $1;
			$_->{attr_name} = $2;
		}
		else
		{
			$_->{attr_path} = '';
			$_->{attr_name} = $_->{item_name};
		}
	}
	return $list;
}

sub storeCachedData
{
	my ($self, $id, $dataHashRef, $expires) = @_;
	$dataHashRef->{_expires} = $expires;
	$self->{$id} = $dataHashRef;
}

sub removeCachedData
{
	my ($self, $id) = @_;
	delete $self->{$id};
}

sub createText
{
	my ($self, $dbpage, $flags, $name, $bindColsRef, $defnAltName, $publParams, $pubD) = @_;
	
	my $stmtHdl = $self->execute($dbpage, $flags, $name, @$bindColsRef);
	my $defnName = $defnAltName ? "$name\_$defnAltName" : $name;
	my $publDefn = $self->{"_dpd_$defnName"} || {};
	$publDefn = $pubD if $pubD;

	$publParams = {} unless $publParams;
	$publParams->{stmtId} = $name unless exists $publParams->{stmtId};

	prepareStatementColumns($dbpage, $flags, $stmtHdl, $publDefn) unless exists $publDefn->{columnDefn};
	
	return
		createHtmlFromStatement($dbpage, $flags, $stmtHdl, $publDefn, $publParams);
}

1;
