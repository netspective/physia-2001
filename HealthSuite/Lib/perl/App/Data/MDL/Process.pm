##############################################################################
package App::Data::MDL::Process;
##############################################################################

use strict;
use App::Universal;
use XML::Struct;
use File::Path;
use File::Spec;
use Schema::API;
use App::Data::MDL::Module;
use App::Data::MDL::Person;
use App::Data::MDL::Organization;
use App::Data::MDL::Invoice;
use App::Data::MDL::FeeSchedule;
use App::Data::MDL::HealthMaintenance;

use vars qw(%PHONE_TYPE_MAP %ASSOC_EMPLOYMENT_TYPE_MAP);

sub processFile
{
	my ($options, @srcFile) = @_;

	my $schema = undef;
	if(my $schemaFile = $options->{schemaDefnFile})
	{
		print STDOUT "Loading schema from $schemaFile\n";
		$schema = new Schema::API(xmlFile => $schemaFile);
		print STDOUT "Connecting to $options->{connectStr}\n" if exists $options->{connectStr};
		$schema->connectDB($options->{connectStr}) if exists $options->{connectStr};
	}

	my $person = new App::Data::MDL::Person(schema => $schema, db => $schema->{dbh});
	my $org = new App::Data::MDL::Organization(schema => $schema, db => $schema->{dbh});
	my $invoice = new App::Data::MDL::Invoice(schema => $schema, db => $schema->{dbh});
	my $feeSchedule = new App::Data::MDL::FeeSchedule(schema => $schema, db => $schema->{dbh});
	my $healthmaintenance = new App::Data::MDL::HealthMaintenance(schema => $schema, db => $schema->{dbh});
	my $flags = exists $options->{flags} ? $options->{flags} : MDLFLAGS_DEFAULT;

	#$schema->setFlag(SCHEMAAPIFLAG_LOGSQL);
	$schema->clearFlag(SCHEMAAPIFLAG_EXECSQL);

	foreach my $xmlFile (@srcFile)
	{
		my $struct = XML::Struct::xmlToStruct(File::Spec->catfile($options->{dataSrcPath}, $xmlFile));
		$person->{rootStruct} = $struct;
		$org->{rootStruct} = $struct;
		$healthmaintenance->{rootStruct} = $struct;
		if(my $list = $struct->{person})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach(@$list)
			{
				$person->importStruct($flags, $_);
				$person->printErrors();
			}
		}
		if(my $list = $struct->{org})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach(@$list)
			{
				$org->importStruct($flags, $_);
				$org->printErrors();
			}
		}
		if(my $list = $struct->{event})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach(@$list)
			{
				$invoice->importStruct($flags, $_);
				$invoice->printErrors();
			}
		}
		if(my $list = $struct->{'offering-catalogs'})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach(@$list)
			{
				$feeSchedule->importStruct($flags, $_);
				$feeSchedule->printErrors();
			}
		}
		if(my $list = $struct->{'health-maintenance'})
		{
			$list = [$list] if ref $list eq 'HASH';
			foreach(@$list)
			{
				$healthmaintenance->importStruct($flags, $_);
				$healthmaintenance->printErrors();
			}
		}

		my $log = $schema->getSqlLog();
		if(@$log)
		{
			my $errorsCount = 0;
			$xmlFile =~ s/\..*$/.log/;
			my $logFile = File::Spec->catfile($options->{sqlLogDestPath}, $xmlFile);
			if(open(SQLLOG, ">$logFile"))
			{
				foreach (@$log)
				{
					my ($sql, $errors) = @$_;
					$sql = "prompt $sql" if $sql =~ m/^\[DATA\]/;
					print SQLLOG "$sql\n";
					foreach(@$errors)
					{
						print SQLLOG "prompt ERROR $_\n";
						$errorsCount++;
					}
					print SQLLOG "\n";
				}
				close(SQLLOG);
				print STDOUT "$errorsCount errors encountered -- see $xmlFile\n" if $errorsCount;
			}
			else
			{
				warn "Unable to write SQL Log to $logFile: $!\n";
			}
			$schema->clearSqlLog();
		}
	}
}

1;