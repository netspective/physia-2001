package Schema::API;

#
# this package defines functions that are useful in a run-time or API-base
# environment for adding/updating/removing/selecting records from Table
# objects
#

use strict;
use DBI;
use Schema;
use enum qw(BITMASK:SCHEMAAPIFLAG_ LOGSQL EXECSQL UNITSQL EMBEDVALUES);
use constant DEFAULT_SCHEMAAPIFLAGS => SCHEMAAPIFLAG_EXECSQL;

use vars qw(@ISA @EXPORT $cachedDbHdls $cachedSchemaFiles $cachedSchemaNames);

@ISA = qw(Exporter Schema);
@EXPORT = qw(
	DEFAULT_SCHEMAAPIFLAGS
	SCHEMAAPIFLAG_EXECSQL
	SCHEMAAPIFLAG_LOGSQL
	SCHEMAAPIFLAG_UNITSQL
	SCHEMAAPIFLAG_EMBEDVALUES
);

$cachedDbHdls = {};        # useful in Velocigen/mod_perl environment
$cachedSchemaFiles = {} ;  # useful in Velocigen/mod_perl environment
$cachedSchemaNames = {} ;  # useful in Velocigen/mod_perl environment

sub clearCache
{
	$cachedDbHdls = {};
	$cachedSchemaFiles = {} ;
	$cachedSchemaNames = {} ;
}

sub new
{
	my $type = shift;
	my %params = @_;

	#
	# if this file's schema is available already (like might be in a persistent
	# mod_perl or Velocigen environment), then don't create another object --
	# instead just return a reference to the existing object. Just be careful,
	# though since the key is the filename (not the <schema name="xxx"> param).
	#
	if(exists $params{xmlFile} && exists $cachedSchemaFiles->{$params{xmlFile}})
	{
		return $cachedSchemaFiles->{$params{xmlFile}};
	}

	my $self = Schema::new($type, @_);
	$self->{flags} = DEFAULT_SCHEMAAPIFLAGS unless exists $self->{flags};

	$cachedSchemaFiles->{$self->{sourceFiles}->{primary}} = $self;
	$cachedSchemaNames->{$self->{name}} = $self;

	$self;
}

sub pingDB
{
	my $self = shift;
	my $dbh = shift;
	
	eval {
		$dbh->ping() or die $dbh->errstr();
	};
	my $error = $@;
	$@ = undef;
	return $error ? 0 : 1;
}

sub connectDB
{
	my $self = shift;
	my $connectKey = shift;

	unless(exists $cachedDbHdls->{$connectKey} && defined $cachedDbHdls->{$connectKey}->{dbiHdl} && $self->pingDB($cachedDbHdls->{$connectKey}->{dbiHdl}))
	{
		my ($un, $pw, $connectStr) = $connectKey =~ m/\s*(.*?)\/(.*?)\@(.*)\s*/;
		if (exists $cachedDbHdls->{$connectKey})
		{
			delete $cachedDbHdls->{$connectKey};
			warn "Database connection lost. Reconnecting\n";
			# Need to send e-mail
		}
		if($un && $pw && $connectStr)
		{
			my ($dbi, $dbms, $server) = split(/:/, $connectStr);

			$cachedDbHdls->{$connectKey}->{dbiHdl} = DBI->connect($connectStr, $un, $pw);
			if(! $cachedDbHdls->{$connectKey}->{dbiHdl})
			{
				delete $cachedDbHdls->{$connectKey};
				die "Unable to connect to the database '$server' as '$un'.\n";
			}
			else
			{
				$cachedDbHdls->{$connectKey}->{dbms} = $dbms;
				$cachedDbHdls->{$connectKey}->{dbserver} = $server;
				$cachedDbHdls->{$connectKey}->{dbiHdl}->{RaiseError} = 0;
				$cachedDbHdls->{$connectKey}->{dbiHdl}->{LongReadLen} = 8192;
				$cachedDbHdls->{$connectKey}->{dbiHdl}->{LongTruncOk} = 1;
			}
		}
		else
		{
			die "connectDB error: username/password\@dbserver format incorrect";
		}
	}

	$self->{connectKey} = $connectKey;
	$self->{dbinfo} = $cachedDbHdls->{$connectKey};
	$self->{dbh} = $cachedDbHdls->{$connectKey}->{dbiHdl};
}

sub colDataAsStr
{
	my ($msg, $colDataRef) = @_;

	my @kvPair = ();
	foreach my $key (sort keys %$colDataRef)
	{
		push(@kvPair, "$key = $colDataRef->{$key}") if exists $colDataRef->{$key} && defined $colDataRef->{$key};
	}
	return $msg . join(', ', @kvPair);
}

sub schemaAction
{
	my ($self, $page, $table, $action, %data) = @_;

	#$page->addDebugStmt (colDataAsStr('DATA',\%data));
	if(my $table = $self->getTable($table))
	{
		return $table->dbCommand($page, $action, \%data);
	}
	else
	{
		$page->addError("table $table not found in schemaAction") if $page && $page->can('unitWork') && ! $page->unitWork();		
		$page->storeSql('',[],["table $table not found in schemaAction"]) if $page && $page->can('unitWork') && $page->unitWork();		
		return 0;
	}
}

# --- flag-management functions ----------------------------------------------
#
#   $self->updateFlag($mask, $onOff) -- either turn on or turn off $mask
#   $self->setFlag($mask) -- turn on $mask
#   $self->clearFlag($mask) -- turn off $mask
#   $self->flagIsSet($mask) -- return true if any $mask are set

sub flagsAsStr
{
	my $str = unpack("B32", pack("N", $_[0]->{flags}));
	$str =~ s/^0+(?=\d)// if $_[1]; # otherwise you'll get leading zeros
	return $str;
}

sub updateFlag
{
	if($_[2])
	{
		$_[0]->{flags} |= $_[1];
	}
	else
	{
		$_[0]->{flags} &= ~$_[1];
	}
}

sub setFlag
{
	$_[0]->{flags} |= $_[1];
}

sub clearFlag
{
	$_[0]->{flags} &= ~$_[1];
}

sub flagIsSet
{
	return $_[0]->{flags} & $_[1];
}

sub getFlags
{
	return $_[0]->{flags};
}

#-----------------------------------------------------------------------------
# Create extension methods for the Table object
#-----------------------------------------------------------------------------

#
# inserts a record into the schema's default database
# returns array ref filled with error messages on error
# returns 1 if successful and there is no primary autoinc key
# returns the primary autoinc key value if there is a primary autoinc key
#
sub Table::insertRec
{
	my ($self, $page, $colDataRef) = @_;
	my $autoIncPriKeyValue = -1;
	my $schema = $self->{schema};

	#$colDataRef->{session_id} = 1;

	die "no database connected -- trying to insertRec in $self->{name}" unless $schema->{dbh};

	#
	# FOR ORACLE: if there is one primary key and it's a sequence (autoinc)
	# then we need to get the value so that we can return it to the caller;
	#
	if(my $priKeys = $self->{colsByGroup}->{_primaryKeys})
	{
		if(scalar(@$priKeys) == 1 && $priKeys->[0]->{type} eq 'autoinc')
		{
			my $col = $self->{colsByGroup}->{_primaryKeys}->[0];
			my $seqName = "$self->{abbrev}_$col->{name}_SEQ";
			my $preSql = "BEGIN select $seqName.nextVal into :retValue from dual; END;";
			eval
			{
				my $csr = $schema->{dbh}->prepare($preSql);
				$csr->bind_param_inout(":retValue", \$autoIncPriKeyValue, 128);
				$csr->execute();
			};
			#print "\n---\n$preSql\n$autoIncPriKeyValue\n---\n";
			if($@)
			{
				return ["$self (insertRec)", "Error getting autoinc value for $col->{name}", $@];
			}

			# store this value so that we can put it into the database with everything else
			$colDataRef->{$col->{name}} = $autoIncPriKeyValue;
		}
	}

	my $flags = $page->{schemaFlags};	
	my $options = $flags & SCHEMAAPIFLAG_EMBEDVALUES ? { ignoreUndefs => 1, ignoreColsNotFound => 0 } : { ignoreUndefs => 1, ignoreColsNotFound => 0 , placeHolder =>1} ;
	my ($sql,$colValue, $errors) = $self->createInsertSql($colDataRef,$options);
	$sql = $page->replaceVars($sql) if $page && $page->can('replaceVars');	
	my $sqlCol = $sql || colDataAsStr("[DATA] Update ($self->{name}): ", $colDataRef);
	$sqlCol .= "  " . join ',',@$colValue;
	push(@{$page->{sqlLog}}, [$sqlCol, $errors]) if $flags & SCHEMAAPIFLAG_LOGSQL;			
	$page->storeSql($sql,$colValue,$errors) if $page && $page->can('unitWork') &&$page->unitWork();		
	my $ret_value = $autoIncPriKeyValue ? $autoIncPriKeyValue : 1;
	return $ret_value unless $flags & SCHEMAAPIFLAG_EXECSQL;

	if(scalar(@{$errors}) == 0)
	{
		my $rowsInserted = 0;
		eval
		{
			$rowsInserted = $schema->{dbh}->do($sql,undef,@{$colValue}) or die $DBI::errstr;
			
		};
		if($rowsInserted == 0 || $@ || $colDataRef->{_debug})
		{
			my $debugMsg = "<b>SQL:</b> <pre>$sql</pre>";
			$debugMsg .= "<b>Bind Parameters:</b><BR>" if defined $_[0];
			for my $i ( 0..$#{$colValue})
			{
				my $value = defined $$colValue[$i] ? "'$$colValue[$i]'" : '<i>undef</i>';
				$debugMsg .= '&nbsp;&nbsp;:' . ($i+1) . " = $value<br>";
			}
			$debugMsg .= '<br>';
			$debugMsg .= "<b>Rows Inserted:</b> $rowsInserted<br>";
			$debugMsg .= "<b>DBI Error:</b> $@<br>" if $@;
			if ($@ || $rowsInserted == 0)
			{
				$debugMsg = "<b>Schema Error in " . ref($self) . '::insertRec()</b><br>' . $debugMsg;
				push(@{$errors}, $debugMsg);
			}
			else
			{
				$debugMsg = "<b>Schema Debug in " . ref($self) . '::insertRec()</b><br>' . $debugMsg;
				$page->addDebugStmt($debugMsg) if $page;
			}
		}
		if ($rowsInserted)
		{
			return $autoIncPriKeyValue if $autoIncPriKeyValue != -1;
			return $rowsInserted; # success
		}
	}

	# if we get to here, we have errors
	if($page)
	{
		# running in a web environment, so give errors in HTML
		$page->addError(join("<br>", @{$errors}));
		return 0;
	}
	else
	{
		return $errors;
	}
}

sub Table::updateRec
{
	my ($self, $page, $colDataRef) = @_;
	my $schema = $self->{schema};

	die "no database connected" if ! $schema->{dbh};

	my $flags = $page->{schemaFlags};
	my $options = $flags & SCHEMAAPIFLAG_EMBEDVALUES ? { ignoreUndefs => 0, ignoreColsNotFound => 0 } : { ignoreUndefs => 0, ignoreColsNotFound => 0 , placeHolder =>1 }  ;
	my ($sql, $colValue, $errors) = $self->createUpdateSql($colDataRef, $options);
	$sql = $page->replaceVars($sql) if $page && $page->can('replaceVars');
	my $sqlCol = $sql || colDataAsStr("[DATA] Update ($self->{name}): ", $colDataRef);	
	$sqlCol .= "  " . join ',',@$colValue;
	push(@{$page->{sqlLog}}, [$sqlCol, $errors]) if $flags & SCHEMAAPIFLAG_LOGSQL;			
	$page->storeSql($sql,$colValue,$errors) if $page && $page->can('unitWork') &&$page->unitWork();		
	return 1 unless $flags & SCHEMAAPIFLAG_EXECSQL;

	if(scalar(@{$errors}) == 0)
	{
		my $rowsUpdated = 0;
		eval
		{
			 $rowsUpdated = $schema->{dbh}->do($sql,undef,@{$colValue}) or die $DBI::errstr;
		};
		if($rowsUpdated == 0 || $@ || $colDataRef->{_debug})
		{			
			my $debugMsg = "<b>SQL:</b> <pre>$sql</pre>";
			$debugMsg .= "<b>Bind Parameters:</b><BR>" if defined $_[0];
			for my $i ( 0..$#{$colValue})
			{
				my $value = defined $$colValue[$i] ? "'$$colValue[$i]'" : '<i>undef</i>';
				$debugMsg .= '&nbsp;&nbsp;:' . ($i+1) . " = $value<br>";
			}
			$debugMsg .= '<br>';
			$debugMsg .= "<b>Rows Updated:</b> $rowsUpdated<br>";
			$debugMsg .= "<b>DBI Error:</b> $@<br>" if $@;
			if ($@)
			{
				$debugMsg = "<b>Schema Error in " . ref($self) . '::updateRec()</b><br>' . $debugMsg;
				push(@{$errors}, $debugMsg);
			}
			else
			{
				$debugMsg = "<b>Schema Debug in " . ref($self) . '::updateRec()</b><br>' . $debugMsg;
				$page->addDebugStmt($debugMsg) if $page;
			}
		}
		if ($rowsUpdated)
		{
			return 1;
		}
	}

	# if we get to here, we have errors
	if($page)
	{
		# running in a web environment, so give errors in HTML
		$page->addError(join("<br>", @{$errors}));
		return 0;
	}
	else
	{
		return $errors;
	}
}

sub Table::deleteRec
{
	my ($self, $page, $colDataRef) = @_;
	my $schema = $self->{schema};

	die "no database connected" if ! $schema->{dbh};

	my $flags = $page->{schemaFlags};
	my $options = $flags & SCHEMAAPIFLAG_EMBEDVALUES ? { ignoreUndefs => 1, ignoreColsNotFound => 0  } : { ignoreUndefs => 1, ignoreColsNotFound => 0 , placeHolder =>1} ;
	my ($sql, $colValue, $errors) = $self->createDeleteSql($colDataRef, $options);
	$sql = $page->replaceVars($sql) if $page && $page->can('replaceVars');
	my $sqlCol = $sql || colDataAsStr("[DATA] Update ($self->{name}): ", $colDataRef);
	$sqlCol .= "  " . join ',',@$colValue;
	push(@{$page->{sqlLog}}, [$sqlCol, $errors]) if $flags & SCHEMAAPIFLAG_LOGSQL;			
	$page->storeSql($sql,$colValue,$errors) if $page && $page->can('unitWork') &&$page->unitWork();	
	return 1 unless $flags & SCHEMAAPIFLAG_EXECSQL;
	if(scalar(@{$errors}) == 0)
	{
		my $rowsDeleted = 0;
		eval
		{
			 $rowsDeleted = $schema->{dbh}->do($sql,undef,@{$colValue}) or die $DBI::errstr;
		};
		if($rowsDeleted == 0 || $@ || $colDataRef->{_debug})
		{			
			my $debugMsg = "<b>SQL:</b> <pre>$sql</pre>";
			$debugMsg .= "<b>Bind Parameters:</b><BR>" if defined $_[0];
			for my $i ( 0..$#{$colValue})
			{
				my $value = defined $$colValue[$i] ? "'$$colValue[$i]'" : '<i>undef</i>';
				$debugMsg .= '&nbsp;&nbsp;:' . ($i+1) . " = $value<br>";
			}
			$debugMsg .= '<br>';
			$debugMsg .= "<b>Rows Deleted:</b> $rowsDeleted<br>";
			$debugMsg .= "<b>DBI Error:</b> $@<br>" if $@;
			if ($@)
			{
				$debugMsg = "<b>Schema Error in " . ref($self) . '::deleteRec()</b><br>' . $debugMsg;
				push(@{$errors}, $debugMsg);
			}
			else
			{
				$debugMsg = "<b>Schema Debug in " . ref($self) . '::deleteRec()</b><br>' . $debugMsg;
				$page->addDebugStmt($debugMsg) if $page;
			}
		}
		if ($rowsDeleted)
		{
			return 1;
		}
	}

	# if we get to here, we have errors
	if($page)
	{
		# running in a web environment, so give errors in HTML
		$page->addError(join("<br>", @{$errors}));
		return 0;
	}
	else
	{
		return $errors;
	}
}

sub Table::existsRec
{
	my $self = shift;
	my $page = shift;
	my %colData = %{$_[0]};      # copy this 'cause we're going to modify it locally
	my $options = defined $_[1] ? $_[1] : { ignoreUndefs => 1, ignoreColsNotFound => 0 };

	die "no database connected" if ! $self->{schema}->{dbh};

	my ($sql, $errors) = ('', []);

	my @colNames = ();
	my @colValues = ();

	if($self->fillColumnData('_primaryKeys', \%colData, \@colNames, \@colValues, $errors, $options))
	{
		#$page->addDebugStmt('here');
		my $whereCond = $self->createEquality(\@colNames, \@colValues, " and ");
		$sql = "SELECT $colNames[0]\nFROM $self->{name}\nWHERE $whereCond";
		$sql = $page->replaceVars($sql) if $page && $page->can('replaceVars');
		my $rowsFound = 0;
		eval
		{
			my $cursor = $self->{schema}->{dbh}->prepare($sql);
			$cursor->execute();
			$rowsFound = 1 if $cursor->fetch();
		};
		if($@ || $colData{_debug})
		{			
			my $debugMsg = "<b>SQL:</b> <pre>$sql</pre>";
			$debugMsg .= "<b>Rows Found:</b> $rowsFound<br>";
			$debugMsg .= "<b>DBI Error:</b> $@<br>" if $@;
			if ($@ || $rowsFound == 0)
			{
				$debugMsg = "<b>Schema Error in " . ref($self) . '::existsRec()</b><br>' . $debugMsg;
				push(@{$errors}, $debugMsg);
			}
			else
			{
				$debugMsg = "<b>Schema Debug in " . ref($self) . '::existsRec()</b><br>' . $debugMsg;
				$page->addDebugStmt($debugMsg) if $page;
			}
		}
		return $rowsFound;
	}
	
	# if we get to here, we have errors
	if($page)
	{
		# running in a web environment, so give errors in HTML
		$page->addError(join("<br>", @{$errors}));
		return 0;
	}
	else
	{
		return $errors;
	}
}

sub Table::fetchHash
{
	my ($self, $page, $cursor) = @_;
	my $data = {};

	my $namesRef = $cursor->{NAME};
	my $colsCount = scalar(@{$namesRef});

	if(my $rowRef = $cursor->fetch())
	{
		my $rowData = {};
		foreach (my $i = 0; $i < $colsCount; $i++)
		{
			$data->{lc($namesRef->[$i])} = $rowRef->[$i];
		}
	}
	else
	{
		$data = undef;
	}

	return $data;
}

sub Table::fetchFields
{
	my ($self, $page, $cursor) = @_;
	my $data = -1;

	my $namesRef = $cursor->{NAME};
	my $colsCount = scalar(@{$namesRef});

	if(my $rowRef = $cursor->fetch())
	{
		my $rowData = {};
		foreach (my $i = 0; $i < $colsCount; $i++)
		{
			$page->field(lc($namesRef->[$i]), $rowRef->[$i]);
		}
	}
	else
	{
		$data = undef;
	}

	return $data;
}

sub Table::getSingleRec
{
	my ($self, $page, $colDataRef, $populateFields) = @_;
	my $data = undef;
	my $options = defined $_[4] ? $_[4] : { ignoreUndefs => 1, ignoreColsNotFound => 0 };
	my $errors = [];

	my @colNames = ();
	my @colValues = ();

	if($self->fillColumnData('', $colDataRef, \@colNames, \@colValues, $errors, $options))
	{
		my $whereCond = $self->createEquality(\@colNames, \@colValues, " and ");
		my $sql = "select * from $self->{name} where $whereCond";
		$sql = $page->replaceVars($sql) if $page && $page->can('replaceVars');

		my $recFound = 0;
		eval
		{
			my $cursor = $self->{schema}->{dbh}->prepare($sql);
			$cursor->execute();
			$data = $populateFields ? $self->fetchFields($page, $cursor) : $self->fetchHash($page, $cursor);
			if($cursor->fetch())
			{
				$page->addError('Expected single row in Table::getSingleRec, got multiple') if $page;
			}
		};
		$page->addDebugStmt($sql) if $colDataRef->{_debug} && $page;
		if($@)
		{
			if($page)
			{
				# running in a web environment, so give errors in HTML
				$page->addError("$self (getRec DBI Error) $@");
				return 0;
			}
			else
			{
				return $@;
			}
		}
	}
	return $data;
}

sub Table::setRec
{
	my ($self, $page, $colDataRef) = @_;

	if($self->existsRec($colDataRef))
	{
		return $self->updateRec($colDataRef);
	}
	else
	{
		return $self->insertRec($colDataRef);
	}
}

sub Table::dbCommand
{
	my ($self, $page, $command, $colDataRef) = @_;
	my $error = '';

	die "don't put _command in dbCommand" if $colDataRef->{_command};
	die "don't put _page in dbCommand" if $colDataRef->{_page};

	if($page->can('session')) # remember, this API can be called from non-web source too
	{
		$colDataRef->{cr_user_id} = $page->session('user_id');
		$colDataRef->{cr_org_internal_id} = $page->session('org_internal_id') || undef;
		$colDataRef->{cr_session_id} = $page->session('_session_id');
	}

	if($command eq 'add')
	{
		my $value = $self->insertRec($page, $colDataRef);
		return $value;
	}
	elsif($command eq 'update')
	{
		my $value = $self->updateRec($page, $colDataRef);
		return $value;
	}
	elsif($command eq 'remove')
	{
		my $value = $self->deleteRec($page, $colDataRef);
		return $value;
	}
	else
	{
		my $data = colDataAsStr("table $self->{name}: ", $colDataRef);
		$error = "unknown command '$command' in Table::dbCommand ($data)";
	}

	if($error && $page)
	{
		$page->addError($error);
		return '';
	}
}

1;
