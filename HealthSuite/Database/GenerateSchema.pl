#!/usr/bin/perl -w

use strict;
use File::Path;
use FindBin qw($Bin);
use Schema;
use Schema::Generator::Oracle;
use Benchmark;
use File::Spec;
use App::Configuration;

sub Main
{
	my $startTime      = new Benchmark;
	#my $connectStr     = 'hs/hs@HealthSuiteCairo';
	#my $connectStr     = 'physia/physia@Physia';
	#my $connectStr     = 'physia/physia@SDEdbs01';
	#my $connectStr     = 'sde01/sde@SDEdbs01';
	my $connectStr     = $CONFDATA_SERVER->db_ConnectKey();
	$connectStr        =~ s/dbi:Oracle://;
	my $scriptPath     = "$Bin";
	my $srcPath        = File::Spec->catfile($scriptPath, 'schema-physia-src');
	my $srcFile        = File::Spec->catfile($srcPath, 'schema.xml');
	my $tmplPath       = File::Spec->catfile($srcPath, 'oracle-templates');
	my $importsPath    = File::Spec->catfile($srcPath, 'oracle-imports');
	my $destPath       = File::Spec->catfile($scriptPath, 'schema-physia');
	#my $cmdProcessor   = 'plus80';
	my $cmdProcessor   = 'sqlplus';
	my $loadProcessor  = 'sqlldr80';

	my $deletefilesStyle = 'os'; # can be 'none', 'os', or 'perl'
	my $generateSchema = 1;

	my $removedFiles = 0;
	if(-d $destPath)
	{
		if($deletefilesStyle ne 'os' && $deletefilesStyle ne 'perl')
		{
			print "Keeping contents of $destPath (not deleting first).\n";
			$removedFiles = 'none';
		}
		else
		{
			print "Removing contents of $destPath.\n";
			if($deletefilesStyle eq 'os' && $^O eq 'MSWin32')  # need to add linux/unix style rm -rf, too
			{
				system("rmdir /s $destPath");
				$removedFiles = 'yes';
			}
			else
			{
				$removedFiles = rmtree($destPath, 0, 1);
			}
		}
	}
	else
	{
		$removedFiles = 'none (destination does not exist)';
	}

	print qq{
Generating schema:
  perl library: $ENV{PERL5LIB}
db destination: $connectStr
 deleted files: $removedFiles
   source file: $srcFile
     templates: $tmplPath
       imports: $importsPath
   destination: $destPath
 cmd processor: $cmdProcessor
load processor: $loadProcessor
};

	my $schemaBldStartTime = new Benchmark;
	my $schema = new Schema(verboseLevel => 0);

	$schema->defineVar('generating_schema');   # this is how we know we're generating a schema
	print " define var(s): " . join(", ", sort keys %{$schema->{defineVars}}) . "\n";

	$schema->define(xmlFile => $srcFile);
	my $schemaBldEndTime = new Benchmark;

	my @warnings = ();
	my @imports = ();
	if($generateSchema && $schema->isValid())
	{
		my $sqlProcess = new Schema::Generator::Oracle(
			schema => $schema,
			srcPath => $destPath,
			templatePath => $tmplPath,
			importPath => $importsPath,
			defaultFileExtn => '.sql',
			connectStr => $connectStr,
			cmdProcessor => $cmdProcessor,
			loadProcessor => $loadProcessor,
			templates =>
				{
					pre => [ ],
					table =>
						[
							'cacheinform.sqt', # this is first since it updates trigger code
							'table.sqt',
							'data.sqt',
							#'enum.sqt',
						],
					'table-code' => ['tablecode.sqt'],
					data => ['data.sqt'],
					post =>
						[
							'forwardref.sqt',
							'tableapi.sqt',
							#'index.sqt',  # this should be LAST
						],
				},
			);
		$sqlProcess->process();
		@warnings = @{$sqlProcess->{warnings}};
		@imports = @{$sqlProcess->{imports}};
	}

	my $endTime = new Benchmark;
	my $runTime = timestr(timediff($endTime, $startTime));
	my $schemaBldTime = timestr(timediff($schemaBldEndTime, $schemaBldStartTime));
	my $dataTypesCount = scalar(keys %{$schema->{dataDict}->{datatypes}});
	my $tableTypesCount = scalar(keys %{$schema->{dataDict}->{tabletypes}});
	my $tableCount = scalar(@{$schema->{tables}->{asList}});
	my $columnsCount = scalar(keys %{$schema->{columns}->{byQualifiedName}});
	my $includesCount = scalar(@{$schema->{sourceFiles}->{includes}});
	my $tableDataCount = scalar(@{$schema->{tableData}});
	my $importsCount = scalar(@imports);
	my $warningsCount = scalar(@warnings);

	print qq{
    parse time: $schemaBldTime
    total time: $runTime
 include files: $includesCount
     datatypes: $dataTypesCount
    tabletypes: $tableTypesCount
        tables: $tableCount
       columns: $columnsCount
    table data: $tableDataCount
       imports: $importsCount
      warnings: $warningsCount
        status: processing completed
};

	if($warningsCount > 0)
	{
		print "\n" . join("\n", @warnings) . "\n";
	}
}

Main();
