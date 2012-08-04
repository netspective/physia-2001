package Schema::Generator;

use strict;
use Text::Template 'fill_in_file';
use File::Basename;

sub new
{
	my $type = shift;
	my %params = @_;

	die "schema parameter required" unless exists $params{schema};
	die "srcPath parameter required" unless exists $params{srcPath};
	die "defaultFileExtn parameter required" unless exists $params{defaultFileExtn};
	die "templatePath parameter required" unless exists $params{templatePath};
	die "templates parameter required" unless exists $params{templates} && ref($params{templates}) eq 'HASH';

	my $properties =
		{
			createPaths => {},
			templates => {},
			warnings => [],
		};

	foreach (keys %params)
	{
		next if ! defined $params{$_};
		$properties->{$_} = $params{$_};
	}

	my $self = bless $properties, $type;
	return $self;
}

sub warn
{
	my $self = shift;
	push(@{$self->{warnings}}, @_);
}

sub saveFile
{
	my $self = shift;
	my %params = @_;

	die "fileName parameter required" if ! exists $params{fileName};
	die "dataRef parameter required" if ! exists $params{dataRef};

	$self->createPathIfNeeded($params{path}) if exists $params{path};

	$params{append} = 0 if ! exists $params{append};
	$params{extn} = $self->{defaultFileExtn} if ! exists $params{extn} && $params{fileName} !~ m/(\..*)$/;

	$params{fileName} .= $params{extn} if exists $params{extn};
	if($params{path})
	{
		my $relative = File::Spec->catfile($self->{createPaths}->{$params{path}}->{relative}, $params{fileName});
		if(! grep
			{
				$_ eq $relative;
			} @{$self->{createPaths}->{$params{path}}->{files}})
		{
			push(@{$self->{createPaths}->{$params{path}}->{files}}, $relative) if $params{path};
		}
	}

	$params{fileName} = File::Spec->catfile($self->{createPaths}->{$params{path}}->{absolute}, $params{fileName}) if exists $params{path};

	my $openParam = $params{append} ? ">>$params{fileName}" : ">$params{fileName}";
	open(FILE, $openParam) || die "unable to write to $params{fileName}: $!";
	print FILE ${$params{dataRef}};
	close(FILE);
}

sub createPathIfNeeded
{
	my ($self, $name) = (shift, shift);

	return if exists $self->{createPaths}->{$name};
	$self->{createPaths}->{$name}->{relative} = File::Spec->catfile(@_ ? @_ : $name);
	$self->{createPaths}->{$name}->{absolute} = File::Spec->catfile($self->{srcPath}, @_ ? @_ : $name);
	$self->{createPaths}->{$name}->{files} = [];
	mkdir($self->{createPaths}->{$name}->{absolute}, 0775) if ! -d $self->{createPaths}->{$name}->{absolute};
}

sub setupPaths
{
	my $self = shift;
	$self->createPathIfNeeded('base', '');
}

sub fillTemplates
{
	my $self = shift;
	my %params = @_;

	die "name param required" if ! exists $params{name} || ! $params{name};
	return if ! exists $self->{templates}->{$params{name}};

	$TMPL_NS::processor = $self;
	$TMPL_NS::templRunIdx = 0;

	foreach(@{$self->{templates}->{$params{name}}})
	{
		$TMPL_NS::templName = $_;
		$TMPL_NS::templNameFull = File::Spec->catfile($self->{templatePath}, $TMPL_NS::templName);
		$TMPL_NS::templOutputPathId = exists $params{outputPathId} ? $params{outputPathId} : $params{name};
		$TMPL_NS::templAllowAppend = $TMPL_NS::templRunIdx > 0 ? 1 : 0;

		# the template (or caller) needs to specify this or nothing will be written out
		$TMPL_NS::templOutputFile = '';

		#
		# now see if the caller wants to create any new variables or override
		# existing variables (defind above)
		#
		if(exists $params{setTemplateVars})
		{
			foreach(keys %{$params{setTemplateVars}})
			{
				my $evalStr = "\$TMPL_NS::$_ = \$params{setTemplateVars}->{$_};";
				eval($evalStr);
			}
		}

		my $data = fill_in_file($TMPL_NS::templNameFull, PACKAGE => 'TMPL_NS');
		die "Template problem in fillTemplates:\n  template: $TMPL_NS::templNameFull\n  error:\n$Text::Template::ERROR" if ! defined $data;

		# if the template didn't specify a name, don't bother writing it out
		next if $TMPL_NS::templOutputFile eq '';

		# the append flags works like this: if this is the first template, no append happens
		# at all; if this is not the first template, then the file will be appended
		# if it happens to already exist from a previous template run in this sequence

		$self->saveFile(
				append => $TMPL_NS::templAllowAppend,
				path => $TMPL_NS::templOutputPathId,
				fileName => $TMPL_NS::templOutputFile,
				dataRef => \$data);

		$TMPL_NS::templRunIdx++;
	}

	# this is defined so that perl -w won't complain in strict mode
	my $temp = $TMPL_NS::processor;
}

sub processBegin
{
	my $self = shift;
	$self->fillTemplates(name => 'pre');
}

sub processEnd
{
	my $self = shift;

	$self->setupPaths();
	$self->fillTemplates(name => 'post');
}

sub process
{
	my $self = shift;

	$self->setupPaths();
	$self->processBegin();

	my $objectIdx;
	foreach my $dbobject (@{$self->{schema}->{dbobjects}})
	{
		if(ref $dbobject eq 'Table')
		{
			$self->{tablesProcessed}++;

			# first check to see if there are any columntype-specific templates
			# (these are templates that should be executed if a table has one or more specific
			# instances of a column type)
			foreach (@{$self->{templates}->{'table'}})
			{
				my ($fname, $path, $suffix) = fileparse($_, '\..*');
				foreach (sort keys %{$dbobject->{colsByType}})
				{
					my $tableTmplBase = $fname . '-datatype-' . $_ . $suffix;
					my $tableTmplName = File::Spec->catfile($self->{templatePath}, $tableTmplBase);
					push(@{$self->{templates}->{"table_$dbobject->{name}"}}, $tableTmplBase) if -f $tableTmplName;
					print "\r$tableTmplBase ($dbobject->{name} $_)\n" if -f $tableTmplName;
				}
				foreach my $column (@{$dbobject->{colsInOrder}})
				{
					foreach my $colFlag (sort keys %{$column->{templateFlags}})
					{
						my $flagValue = $column->{templateFlags}->{$colFlag};
						my $tableTmplBase = "$fname-colflag-$colFlag-$flagValue$suffix";
						my $tableTmplName = File::Spec->catfile($self->{templatePath}, $tableTmplBase);
						push(@{$self->{templates}->{"table_$dbobject->{name}"}}, $tableTmplBase) if -f $tableTmplName;
					}
				}
			}

			# now check to see if there are any tabletype-specific templates
			foreach (@{$self->{templates}->{'table'}})
			{
				my ($fname, $path, $suffix) = fileparse($_, '\..*');
				foreach (@{$dbobject->{inherit}})
				{
					my $tableTmplBase = $fname . '-type-' . $_ . $suffix;
					my $tableTmplName = File::Spec->catfile($self->{templatePath}, $tableTmplBase);
					push(@{$self->{templates}->{"table_$dbobject->{name}"}}, $tableTmplBase) if -f $tableTmplName;
				}
				foreach my $tableFlag (sort keys %{$dbobject->{templateFlags}})
				{
					my $flagValue = $dbobject->{templateFlags}->{$tableFlag};
					my $tableTmplBase = "$fname-tblflag-$tableFlag-$flagValue$suffix";
					my $tableTmplName = File::Spec->catfile($self->{templatePath}, $tableTmplBase);
					push(@{$self->{templates}->{"table_$dbobject->{name}"}}, $tableTmplBase) if -f $tableTmplName;
				}
			}

			# then check to see if there are any table-specific templates
			foreach (@{$self->{templates}->{'table'}})
			{
				my ($fname, $path, $suffix) = fileparse($_, '\..*');
				my $tableTmplBase = $fname . '-' . $dbobject->{name} . $suffix;
				my $tableTmplName = File::Spec->catfile($self->{templatePath}, $tableTmplBase);

				push(@{$self->{templates}->{"table_$dbobject->{name}"}}, $tableTmplBase) if -f $tableTmplName;
			}

			$self->fillTemplates(
					name => "table_$dbobject->{name}",
					outputPathId => 'tables',
					setTemplateVars =>
					{
						'tableIdx' => $objectIdx,
						'table' => $dbobject,
						'data' => $dbobject->{data},
						'templOutputFile' => $dbobject->{name},
						'genericTemplate' => 0,
					});

			$self->fillTemplates(
					name => 'table',
					outputPathId => 'tables',
					setTemplateVars =>
					{
						'tableIdx' => $objectIdx,
						'table' => $dbobject,
						'data' => $dbobject->{data},
						'templOutputFile' => $dbobject->{name},
						'genericTemplate' => 1,
					});

			foreach my $col (@{$dbobject->{colsInOrder}})
			{
				if($col->{calc})
				{
					my $triggers = $self->{triggers}->{$dbobject->{name}}->{column}->{$col->{name}};
					$self->warn("$dbobject->{name}.$col->{name} is a calc column, but has no triggers")
						if ! defined $triggers || ref($triggers) ne 'HASH' || scalar(keys %{$triggers}) == 0;
				}
			}
		}
		$objectIdx++;
	}

	$objectIdx = 0;
	foreach my $dbobject (@{$self->{schema}->{dbobjects}})
	{
		if(ref $dbobject eq 'Table')
		{
			$self->fillTemplates(
					name => 'table-code',
					outputPathId => 'tables-code',
					setTemplateVars =>
					{
						'tableIdx' => $objectIdx,
						'table' => $dbobject,
						'data' => $dbobject->{data},
						'templOutputFile' => $dbobject->{name},
						'genericTemplate' => 1,
					});
		}
		$objectIdx++;
	}

	foreach my $data (@{$self->{schema}->{tableData}})
	{
		$self->fillTemplates(name => 'data', setTemplateVars => { 'data' => $data });
	}

	$self->processEnd();
}

1;