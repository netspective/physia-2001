##############################################################################
package Schema::Generator::Oracle;
##############################################################################

use strict;
use Schema::Generator;
use File::Basename;
use File::Copy;

use vars qw(@ISA);
@ISA = qw(Schema::Generator);

sub storeForwardRef
{
	my ($self, $table, $ref) = @_;

	push(@{$self->{forwardRefs}->{$table}}, $ref);
}

sub createTriggerCodeStructs
{
	my $self = shift;
	my $tableName = shift;

	if(! exists $self->{triggers}->{$tableName})
	{
		$self->{triggers}->{$tableName} =
			{
				declares => {}, # code that appears in DECLARE section
				pretable => {}, # code that appears BEFORE all columns
				column => {},   # code that appears in COLUMN ORDER
				table => {},    # code that appears AFTER all columns
			};
	}
	return $self->{triggers}->{$tableName};
}

sub addTriggerCode
{
	my $self = shift;
	my %params = @_;

	#
	# setup the defaults
	#
	$params{type} ||= 'table';      # values: table | column | pretable
	$params{scope} ||= 'master';    # values: master | audit | any
	$params{time} ||= 'before';     # values: before | after
	$params{action} ||= 'insert';   # values: insert | update | delete
	#$params{declare}               # values: key: name, value: value

	if(exists $params{declare})
	{
		my $declares = $self->createTriggerCodeStructs($params{table})->{declares};
		if(! exists $declares->{$params{scope}}->{$params{time}}->{$params{action}})
		{
			$declares->{$params{scope}}->{$params{time}}->{$params{action}} = [];
		}
		my $area = $declares->{$params{scope}}->{$params{time}}->{$params{action}};
		if(ref $params{declare} eq 'ARRAY')
		{
			foreach my $stmt (@{$params{declare}})
			{
				if(! grep {	$_ eq $stmt } @{$area})
				{
					push(@{$area}, $stmt);
				}
			}
		}
		else
		{
			push(@{$area}, $params{declare});
		}
	}

	#
	# now make sure we have all required parameters
	#
	die "table parameter required in addTriggerCode" if ! $params{table};
	die "column parameter required in addTriggerCode" if ! $params{type} eq 'column' && ! $params{column};

	if(ref $params{code} eq 'ARRAY')
	{
		my $code = $params{code};
		delete $params{code};       # delete this so recursive function doesn't get it
		delete $params{declare};    # delete this so recursive function doesn't get it
		foreach (@{$code})
		{
			$self->addTriggerCode(%params, code => $_);
		}
	}
	elsif(my $code = $params{code})
	{
		my $triggers = $self->createTriggerCodeStructs($params{table})->{$params{type}};
		if($params{type} eq 'column')
		{
			if(! exists $triggers->{$params{column}})
			{
				$triggers->{$params{column}} = {};
			}
			$triggers = $triggers->{$params{column}};
		}

		if(! exists $triggers->{$params{scope}}->{$params{time}}->{$params{action}})
		{
			$triggers->{$params{scope}}->{$params{time}}->{$params{action}} = [];
		}
		my $area = $triggers->{$params{scope}}->{$params{time}}->{$params{action}};

		#
		# as long as the same code is not already in the trigger, add it now
		#
		if(! grep {	$_ eq $code } @{$area})
		{
			push(@{$area}, $code);
		}
	}
}

sub _mergeTriggerCode
{
	my ($self, $codeRef, $triggers, $time, $action) = @_;

	foreach my $line (@{$triggers->{$time}->{$action}})
	{
		${$codeRef} .= "\t$line\n";
	}
}

sub createTableTriggerSql
{
	my ($self, $table, $tableType, $trgNamePrefix, $trgNameSuffix) = @_;
	$tableType ||= 'master';
	$trgNamePrefix ||= '';
	$trgNameSuffix = $tableType eq 'audit' ? '_AUD' : '';
	my $sql = "";

	my $tableName = uc($table->{name});
	my $allTableTriggers = $self->{triggers}->{$table->{name}};
	return if ! $allTableTriggers;

	my $tableDeclares = $allTableTriggers->{declares};
	my $triggerCols =
		{
			before =>
				{
					insert => {	initials => 'BI' },
					update => {	initials => 'BU' },
					'insert or update' => {	initials => 'BIU' },
					'insert or update or delete' => { initials => 'BIUD' },
					delete => {	initials => 'BD' },
				},
			after =>
				{
					insert => {	initials => 'AI' },
					update => {	initials => 'AU' },
					'insert or update' => {	initials => 'AIU' },
					'insert or update or delete' => { initials => 'AIUD' },
					delete => {	initials => 'AD' },
				}
		};

	foreach my $time ('before', 'after')
	{
		foreach my $action ('insert', 'insert or update', 'insert or update or delete', 'update', 'delete')
		{
			my $trgCode = '';
			my $declaresCode = '';
			my $codeRef = \$trgCode;

			if(my $declares = $tableDeclares->{$tableType})
			{
				foreach (@{$declares->{$time}->{$action}})
				{
					$declaresCode .= "\t$_;\n";
				}
			}

			if(my $preTableTriggers = $allTableTriggers->{pretable}->{$tableType})
			{
				$self->_mergeTriggerCode($codeRef, $preTableTriggers, $time, $action);
			}
			if(my $preTableTriggers = $allTableTriggers->{pretable}->{'all'})
			{
				$self->_mergeTriggerCode($codeRef, $preTableTriggers, $time, $action);
			}

			foreach my $col (@{$table->{colsInOrder}})
			{
				if(my $colTriggers = $allTableTriggers->{column}->{$col->{name}}->{$tableType})
				{
					$self->_mergeTriggerCode($codeRef, $colTriggers, $time, $action);
				}
				if(my $colTriggers = $allTableTriggers->{column}->{$col->{name}}->{'all'})
				{
					$self->_mergeTriggerCode($codeRef, $colTriggers, $time, $action);
				}
			}

			if(my $postTableTriggers = $allTableTriggers->{table}->{$tableType})
			{
				$self->_mergeTriggerCode($codeRef, $postTableTriggers, $time, $action);
			}
			if(my $postTableTriggers = $allTableTriggers->{table}->{'all'})
			{
				$self->_mergeTriggerCode($codeRef, $postTableTriggers, $time, $action);
			}

			if($trgCode)
			{
				my $trgType = $triggerCols->{$time}->{$action}->{initials};
				$sql .= "create or replace trigger $trgNamePrefix$trgType\_$tableName$trgNameSuffix\n";
				$sql .= "$time $action on $tableName$trgNameSuffix\n";
				$sql .= "for each row\n";
				$sql .= "declare\n" if $declaresCode;
				$sql .= $declaresCode if $declaresCode;
				$sql .= "begin\n";
				$sql .= $trgCode;
				$sql .= "end;\n/\nshow errors;\n\n";
			}
		}

	}

	return $sql;
}

sub createOracleStoredProcs
{
	my ($self, $table, $level, $pkgHdrRef, $pkgBodyRef ) = @_;
	my $tableName = $table->{name};

	# On top level table, generate open package header & body statements
	if ($level == 0)
	{
		${$pkgHdrRef} = "create or replace package PKG_$tableName as \n\n";
		${$pkgBodyRef} = "create or replace package body PKG_$tableName as \n\n";
	}

	# Generate all procs for this table
	my ($nextHdr, $nextBody) = generateTableMgrAPI ( $self->{schema}, $table );
	${$pkgHdrRef} .= $nextHdr;
	${$pkgBodyRef} .= $nextBody;

	if($table->{name} eq 'Association')
	{
		($nextHdr, $nextBody) = createAssocAPISql($self, $table) ;
		${$pkgHdrRef} .= $nextHdr;
		${$pkgBodyRef} .= $nextBody;
	}

	if($table->isTableType('Attribute'))
	{
		($nextHdr, $nextBody) = createAttributesAPISql($self, $table);
		${$pkgHdrRef} .= $nextHdr;
		${$pkgBodyRef} .= $nextBody;
	}

	# Recursively call this sub for all child tables
	foreach (@{$table->{childTables}})
	{
		$self->createOracleStoredProcs($_, ($level + 1), $pkgHdrRef, $pkgBodyRef);
	}

	# Generate close package header and body statements when done with top level table
	if ($level == 0)
	{
		${$pkgHdrRef} .= "\nend PKG_$tableName; \n/ \nshow errors;";
		${$pkgBodyRef} .= "\nend PKG_$tableName; \n/ \nshow errors;";
	}
}

sub generateTableMgrAPI
{
	my ($schema, $table) = @_;
	return ('', '') if scalar(@{$table->{colsInOrder}}) <= 0;

	my $tableName = $table->{name};
	my @colGroups = ('priKeyCols', 'columns');
	my @colData = ();
	my @addAPIParams = ();
	my @updateAPIParams = ();
	my @removeAPIParams = ();

	sub requiredParams
	{
		$b->{primarykey} <=> $a->{primarykey}    # primary keys go first
		or
		$b->{required} <=> $a->{required}        # required columns come next
		or
		$b->{name} cmp $a->{name};               # just for safety
	}
	my @sorted = sort requiredParams @{$table->{colsInOrder}};

	my @colNames = ();
	my @colNamesForAdd = ();
	my @paramNames = ();
	my @paramNamesForAdd = ();
	my @priKeyNames = ();
	my @priKeyParams = ();
	my @priKeyNamesEqualParamNames = ();
	my @colNamesEqualParamNames = ();
	my @priSeqCols = ();

	foreach my $column (@sorted)
	{
		next if $column->{name} =~ m/^cr_/;
		next if $column->{name} eq 'version_id';

		my $paramName = "p_" . $column->{name};
		my $paramType = "$table->{name}.$column->{name}%TYPE";
		push(@colData,
			{
				column => $column,
				paramName => $paramName,
				typeDefn => $paramType,
			});

		my $isSequence = $column->{type} eq 'autoinc';
		push(@priSeqCols, $column) if $column->{primarykey} && $isSequence;

		push(@colNames, $column->{name});
		push(@colNamesForAdd, $column->{name}) unless $isSequence;
		push(@paramNames, $paramName);
		push(@paramNamesForAdd, $paramName) unless $isSequence;
		push(@priKeyNames, $column->{name}) if $column->{primarykey};
		push(@colNamesEqualParamNames, "$column->{name} = $paramName") if ! $column->{primarykey};
		push(@priKeyNamesEqualParamNames, "$column->{name} = $paramName") if $column->{primarykey};

		push(@priKeyParams, "$paramName in $paramType") if $column->{primarykey};

		my $addDefault = exists $column->{default} && $column->{default} ne '' ? $column->{default} : 'NULL';
		push(@addAPIParams, "$paramName in $paramType" . ($column->{required} eq 'yes' ? '' : " := $addDefault"))  unless $isSequence;
		push(@updateAPIParams, "$paramName in $paramType" . ($column->{descriptorKey} ? '' : ' := NULL'));
		push(@removeAPIParams, "$paramName in $paramType") if $column->{primarykey};
	}

	my $primaryKeyIsSeq = scalar(@priSeqCols) == 1;

	my $indent = "\t\t\t\t";
	my ($sqlSpec, $sqlBody) = ('', '');
	my $addProcParams = join(", \n$indent", @addAPIParams);
	my $updateProcParams = join(", \n$indent", @updateAPIParams);
	my $removeProcParams = join(", \n$indent", @removeAPIParams);
	my $allPriKeyParams = join(", \n$indent", @priKeyParams);

	if($primaryKeyIsSeq)
	{
		$sqlSpec .= "	function add$tableName(\n$indent$addProcParams) return number;\n\n";
	}
	else
	{
		$sqlSpec .= "	procedure add$tableName(\n$indent$addProcParams);\n\n";
	}
	$sqlSpec .= "	procedure upd$tableName(\n$indent$updateProcParams);\n\n" if @priKeyParams && @colNamesEqualParamNames;
	$sqlSpec .= "	procedure remove$tableName(\n$indent$removeProcParams);\n\n" if @removeAPIParams;

	$sqlSpec .= "	function exists$tableName(\n$indent$allPriKeyParams) return integer;\n" if @priKeyParams;
	$sqlSpec .= "	PRAGMA RESTRICT_REFERENCES(exists$tableName, WNDS, WNPS, RNPS);\n\n" if @priKeyParams;

	$table->{dbdd}->{pkgAPISpec} = $sqlSpec;

	if($primaryKeyIsSeq)
	{
		$sqlBody .= "	function add$tableName(\n$indent$addProcParams) return number is\n";
		$sqlBody .= "		v_currSeqVal $table->{name}.$priSeqCols[0]->{name}%TYPE;\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		insert into $table->{name}\n";
		$sqlBody .= "		( " . join(",\n\t\t  ", @colNamesForAdd) .") values\n";
		$sqlBody .= "		( " . join(",\n\t\t  ", @paramNamesForAdd) . ");\n";
		$sqlBody .= "		select $table->{abbrev}_$priSeqCols[0]->{abbrev}_SEQ.currval into v_currSeqVal from dual;\n";
		$sqlBody .= "		return v_currSeqVal;\n";
		$sqlBody .= "	end;\n\n";
	}
	else
	{
		$sqlBody .= "	procedure add$tableName(\n$indent$addProcParams) is\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		insert into $table->{name}\n";
		$sqlBody .= "		( " . join(",\n\t\t  ", @colNamesForAdd) .") values\n";
		$sqlBody .= "		( " . join(",\n\t\t  ", @paramNamesForAdd) . ");\n";
		$sqlBody .= "	end;\n\n";
	}

	if(@priKeyParams && @colNamesEqualParamNames)
	{
		$sqlBody .= "	procedure upd$tableName(\n$indent$updateProcParams) is\n\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		update $table->{name}\n";
		$sqlBody .= "		set " . join(",\n\t\t    ", @colNamesEqualParamNames) ."\n";
		$sqlBody .= "		where " . join(" and ", @priKeyNamesEqualParamNames) .";\n";
		$sqlBody .= "	end;\n\n";
	}

	if(@removeAPIParams)
	{
		$sqlBody .= "	procedure remove$tableName(\n$indent$removeProcParams) is\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		delete from $table->{name} where " . join(" and ", @priKeyNamesEqualParamNames) .";\n";
		$sqlBody .= "	end;\n\n";
	}

	if(@priKeyParams)
	{
		$sqlBody .= "	function exists$tableName(\n$indent$allPriKeyParams) return integer is\n";
		$sqlBody .= "		cursor c_find is\n";
		$sqlBody .= "		select " . join(', ', @priKeyNames) ." from $table->{name}\n";
		$sqlBody .= "		where " . join(" and ", @priKeyNamesEqualParamNames) .";\n";
		$sqlBody .= "		result boolean;\n";
		$sqlBody .= "		find_rec c_find%ROWTYPE;\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		open c_find;\n";
		$sqlBody .= "		fetch c_find into find_rec;\n";
		$sqlBody .= "		result := c_find%FOUND;\n";
		$sqlBody .= "		close c_find;\n";
		$sqlBody .= "		if result then\n";
		$sqlBody .= "			return 1;\n";
		$sqlBody .= "		else\n";
		$sqlBody .= "			return 0;\n";
		$sqlBody .= "		end if;\n";
		$sqlBody .= "	end;\n\n";
	}

	foreach my $column (@{$table->{colsByAPIMethod}->{set}})
	{
		$sqlSpec .= "	procedure $column->{setColMethod}(\n";
		$sqlSpec .= "				$allPriKeyParams,\n";
		$sqlSpec .= "				p_$column->{name} in $table->{name}.$column->{name}%TYPE);\n\n";

		$sqlBody .= "	procedure $column->{setColMethod}(\n";
		$sqlBody .= "				$allPriKeyParams,\n";
		$sqlBody .= "				p_$column->{name} in $table->{name}.$column->{name}%TYPE) is\n";
		$sqlBody .= "	begin\n";
		$sqlBody .= "		update $table->{name} set $column->{name} = p_$column->{name}\n";
		$sqlBody .= "		where " . join(" and ", @priKeyNamesEqualParamNames) .";\n";
		$sqlBody .= "	end;\n\n";
	}
	return ($sqlSpec, $sqlBody);
}

sub createAssocAPISql
{
	my ($self, $table) = @_;
	my ($spec, $body) = ('','');

	my $entityTypes = ['Person', 'Org'];
	my ($pid, $cid) = (-1, -1);

	foreach my $parentRel (@{$entityTypes})
	{
		$pid++;
		$cid = -1;

		foreach my $childRel (@{$entityTypes})
		{
			$cid++;

			my $relPrefix = '';
			if($pid == $cid)
			{
				$relPrefix = 'rel_';
			}

			my $procSpec = qq{
				procedure setAssoc_$parentRel$childRel(
							p_$parentRel\_id in $table->{name}.entity_id%TYPE,
							p_$relPrefix$childRel\_id in $table->{name}.rel_id%TYPE,
							p_class in $table->{name}.class%TYPE,
							p_name in $table->{name}.name%TYPE,
							p_status in $table->{name}.status%TYPE := NULL,
							p_data in $table->{name}.data%TYPE := NULL,
							p_begin_date in $table->{name}.assoc_begin_date%TYPE := NULL,
							p_end_date in $table->{name}.assoc_begin_date%TYPE := NULL);

				function hasAssoc_$parentRel$childRel(
							p_$parentRel\_id in $table->{name}.entity_id%TYPE,
							p_$relPrefix$childRel\_id in $table->{name}.rel_id%TYPE,
							p_class in $table->{name}.class%TYPE,
							p_name in $table->{name}.name%TYPE) return integer;

			};

			my $procBody = qq{
				procedure setAssoc_$parentRel$childRel(
							p_$parentRel\_id in $table->{name}.entity_id%TYPE,
							p_$relPrefix$childRel\_id in $table->{name}.rel_id%TYPE,
							p_class in $table->{name}.class%TYPE,
							p_name in $table->{name}.name%TYPE,
							p_status in $table->{name}.status%TYPE := NULL,
							p_data in $table->{name}.data%TYPE := NULL,
							p_begin_date in $table->{name}.assoc_begin_date%TYPE := NULL,
							p_end_date in $table->{name}.assoc_begin_date%TYPE := NULL) is
					v_assocFound integer := 0;
					v_clean$parentRel\_id $table->{name}.entity_id%TYPE;
					v_clean$relPrefix$childRel\_id $table->{name}.rel_id%TYPE;
				begin
					v_clean$parentRel\_id := pkg_Entity.CleanupEntityId(p_$parentRel\_id);
					v_clean$relPrefix$childRel\_id := pkg_Entity.CleanupEntityId(p_$relPrefix$childRel\_id);

					select count(*) into v_assocFound
					from $table->{name}
					where entity_type = $pid
					and entity_id = v_clean$parentRel\_id
					and rel_type = $cid
					and rel_id = v_clean$childRel\_id
					and class = p_class
					and name = p_name;

					if v_assocFound > 0 then
						update $table->{name}
						set status = p_status,
							data = p_data,
							assoc_begin_date = p_begin_date,
							assoc_end_date = p_end_date
						where entity_type = $pid
						and entity_id = v_clean$parentRel\_id
						and rel_type = $cid
						and rel_id = v_clean$relPrefix$childRel\_id
						and class = p_class
						and name = p_name;
					else
						insert into $table->{name}
						(entity_type, entity_id, rel_type, rel_id, class, name, status, data, assoc_begin_date, assoc_end_date) values
						($pid, v_clean$parentRel\_id, $cid, v_clean$relPrefix$childRel\_id, p_class, p_name, p_status, p_data, p_begin_date, p_end_date);
					end if;
				end;

				function hasAssoc_$parentRel$childRel(
							p_$parentRel\_id in $table->{name}.entity_id%TYPE,
							p_$relPrefix$childRel\_id in $table->{name}.rel_id%TYPE,
							p_class in $table->{name}.class%TYPE,
							p_name in $table->{name}.name%TYPE) return integer is
					v_assocFound integer := 0;
					v_clean$parentRel\_id $table->{name}.entity_id%TYPE;
					v_clean$relPrefix$childRel\_id $table->{name}.rel_id%TYPE;
				begin
					v_clean$parentRel\_id := pkg_Entity.CleanupEntityId(p_$parentRel\_id);
					v_clean$relPrefix$childRel\_id := pkg_Entity.CleanupEntityId(p_$relPrefix$childRel\_id);

					select count(*) into v_assocFound
					from $table->{name}
					where entity_type = $pid
					and entity_id = v_clean$parentRel\_id
					and rel_type = $cid
					and rel_id = v_clean$relPrefix$childRel\_id
					and class = p_class
					and name = p_name;

					if v_assocFound <= 0 then
						return 0;
					else
						return 1;
					end if;
				end;
			};

			# remove the additional tabs we added for code readability in this script
			$procSpec =~ s/^\t\t\t\t/\t/mg;
			$procBody =~ s/^\t\t\t\t/\t/mg;

			$spec .= $procSpec;
			$body .= $procBody;
		}
	}

	$spec .= qq{;
	procedure setOwner_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE);

	procedure setUser_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE);

	function isOwner_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) return integer;

	function isUser_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) return integer;

	};

	$body .= qq{
	procedure setOwner_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) is
	begin
		setAssoc_OrgPerson(p_org_id, p_person_id, 'owner', 'org_person');
	end;

	procedure setUser_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) is
	begin
		setAssoc_OrgPerson(p_org_id, p_person_id, 'user', 'org_person');
	end;

	function isOwner_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) return integer is
	begin
		return hasAssoc_OrgPerson(p_org_id, p_person_id, 'owner', 'org_person');
	end;

	function isUser_OrgPerson(
				p_org_Id in $table->{name}.entity_id%TYPE,
				p_person_Id in $table->{name}.rel_id%TYPE) return integer is
	begin
		return hasAssoc_OrgPerson(p_org_id, p_person_id, 'user', 'org_person');
	end;

	};

	return ($spec, $body);
}

sub createAttributesAPISql
{
	my ($self, $table) = @_;
	my ($parentName) = $table->{name} =~ m/^(\w+)\_/;
	my ($spec, $body) = ('','');

	my @attrTypeCols = ('value_text', 'value_int', 'value_date');

	my $coreProcsSpec = qq{
	procedure set$parentName\_TextAttribute(
				p_parentId in $table->{name}.parent_id%TYPE,
				p_itemName in $table->{name}.item_name%TYPE,
				p_itemValue in $table->{name}.value_text%TYPE,
				p_valueType in $table->{name}.value_type%TYPE := 0);

	};

	my $coreProcsBody = qq{
	procedure set$parentName\_TextAttribute(
				p_parentId in $table->{name}.parent_id%TYPE,
				p_itemName in $table->{name}.item_name%TYPE,
				p_itemValue in $table->{name}.value_text%TYPE,
				p_valueType in $table->{name}.value_type%TYPE) is
		v_cleanPid $table->{name}.parent_id%TYPE;
		v_attrsFound integer := 0;
	begin
		v_cleanPid := pkg_Entity.CleanupEntityId(p_parentId);

		select count(*) into v_attrsFound
		from $table->{name}
		where parent_id = v_cleanPid
		and item_name = p_itemName;

		if v_attrsFound > 0 then
			update $table->{name}
			set value_text = p_itemValue
			where parent_id = v_cleanPid
			and item_name = p_itemName;
		else
			insert into $table->{name}
			(parent_id, item_name, value_type, value_text) values
			(v_cleanPid, p_itemName, p_valueType, p_itemValue);
		end if;
	end;

	};

	$spec = $coreProcsSpec;
	$body = $coreProcsBody;

	foreach ('Telephone:10', 'Fax:15', 'EMail:40', 'Internet:50', 'Pager:20')
	{
		my ($type, $valueType) = split(/:/);
		$spec .= "\tprocedure set$parentName\_$type(\n\t\t\t\tp_parentId in $table->{name}.parent_id%TYPE, \n\t\t\t\tp_name in varchar2, \n\t\t\t\tp_value in $table->{name}.value_text%TYPE);\n\n";
		$body .= "\tprocedure set$parentName\_$type(\n\t\t\t\tp_parentId in $table->{name}.parent_id%TYPE, \n\t\t\t\tp_name in varchar2, \n\t\t\t\tp_value in $table->{name}.value_text%TYPE) is \n";
		$body .= "\tbegin\n";
		$body .= "\t\tset$parentName\_TextAttribute(p_parentId, 'Contact Method' || '/$type/' || p_name, p_value, $valueType);\n";
		$body .= "\tend;\n\n";
	}

	return ($spec, $body);
}

sub createAllProcs
{
	my $self = shift;

	# Create 1 package (2 files:  header and body) for each top-level table,
	# where the package contains all procs for all tables in that hierarchy

	foreach (@{$self->{schema}->{tables}->{hierarchy}})
	{
		# don't create packages for reference tables
		next if $_->{name} =~ m/^(Ref_|Reference_Item)/i;

		my $pkgHdr = '';
		my $pkgBody = '';
		$self->createOracleStoredProcs($_, 0, \$pkgHdr, \$pkgBody);

		# saveFiles
		$self->saveFile(
			path => 'api',
			fileName => "pkg_$_->{name}",
			dataRef => \$pkgHdr
			);
		$self->saveFile(
			path => 'api',
			fileName => "pkg_$_->{name}_body",
			dataRef => \$pkgBody
			);
	}
}

sub processEnd
{
	my $self = shift;
	$self->SUPER::processEnd();
	$self->createLoadFiles();
}

sub copyImportFile
{
	my ($self, $importPath, $importName, $destRelPath) = @_;
	my $destName = $importName;

	$self->createPathIfNeeded($destRelPath);

	# import files may have nnn- prefixed (for sorting purposes), so remove it
	$destName =~ s/^[0-9]+\-//;
	copy(File::Spec->catfile($importPath, $importName), File::Spec->catfile($self->{srcPath}, $destRelPath, $destName));
	push(@{$self->{imports}}, File::Spec->catfile($importPath, $importName));

	return $destName;
}

sub createLoadFiles
{
	my $self = shift;
	my $allsql = "spool load_all_sql\n\n";

	#foreach my $subdir ('pre', 'tables', 'tables-code', 'data', 'api', 'post')
	foreach my $subdir ('pre', 'tables', 'tables-code', 'data', 'post')
	{
		my $sqlFiles = "";
		my @importFiles = ();

		my $includeImportsFromAbs = File::Spec->catfile($self->{importPath}, $subdir);
		if(-d $includeImportsFromAbs)
		{
			opendir(IMPORTDIR, $includeImportsFromAbs) || die "Can't open directory $includeImportsFromAbs: $!\n";
			@importFiles = sort readdir(IMPORTDIR);
			closedir(IMPORTDIR);

			foreach my $importFile (@importFiles)
			{
				# before-xxx and after-xxx will be handled later
				next if $importFile eq '.' || $importFile eq '..';
				next if $importFile =~ m/^(pre|post)\-/i;

				my $destNameOnly = $self->copyImportFile($includeImportsFromAbs, $importFile, $subdir);
				$sqlFiles .= "start $subdir/$destNameOnly\n";
			}
		}

		if(exists $self->{createPaths}->{$subdir})
		{
			foreach (@{$self->{createPaths}->{$subdir}->{files}})
			{
				my ($fname, $path, $suffix) = fileparse($_, '\..*');
				foreach my $importFile (@importFiles)
				{
					if(lc($importFile) eq lc("pre-$fname$suffix"))
					{
						my $destNameOnly = $self->copyImportFile($includeImportsFromAbs, $importFile, $subdir);
						$sqlFiles .= "start $subdir/$destNameOnly\n";
					}
				}

				$sqlFiles .= "start $_\n";

				foreach my $importFile (@importFiles)
				{
					if(lc($importFile) eq lc("post-$fname$suffix"))
					{
						my $destNameOnly = $self->copyImportFile($includeImportsFromAbs, $importFile, $subdir);
						$sqlFiles .= "start $subdir/$destNameOnly\n";
					}
				}
			}
		}
		next if ! $sqlFiles;
		$self->saveFile(path => 'base', fileName => "load_$subdir", dataRef => \$sqlFiles);
		$allsql .= "start load_$subdir\n";
	}

	$allsql .= "exit;\n";
	$self->saveFile(path => 'base', fileName => "load_all_sql", dataRef => \$allsql);

	my $haveCtls = 0;
	if(exists $self->{createPaths}->{ctls}->{files})
	{
		$haveCtls = 1;
		my $ctlFiles = "";
		foreach (@{$self->{createPaths}->{ctls}->{files}})
		{
			$ctlFiles .= "$self->{loadProcessor} $self->{connectStr} control=$_\n";
		}
		$self->saveFile(path => 'base', fileName => "load_all_ctl.bat", dataRef => \$ctlFiles);
	}

	my $setupFile = "$self->{cmdProcessor} -s $self->{connectStr} \@load_all_sql.sql\n";
	$setupFile .= "load_all_ctl.bat\n" if $haveCtls;

	$self->saveFile(path => 'base', fileName => "setupdb.bat", dataRef => \$setupFile);
}

1;