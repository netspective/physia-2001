use strict;
use App::Data::Collection;
use App::Data::Obtain::Ntis::CPTinfo;
use App::Data::Obtain::InfoX::ICDinfo;
use App::Data::Obtain::HCFA::HCPCS;
use App::Data::Obtain::Envoy::Payers;
use App::Data::Obtain::Perse::Epayer;
use App::Data::Transform::DBI;
use File::Path;
use FindBin qw($Bin);
use Benchmark;
use File::Spec;
use Getopt::Long;
use File::Basename;

sub printUsage
{
	print qq{
Usage:  @{[basename $0]} <connect string> [icd cpt hcpcs envoy epayer]
If no module is specified, the default is to load ALL modules.
		
Example: @{[basename $0]} sde_prime/sde\@sdedbs02 icd cpt
to only load icd and cpt modules.
	};
	exit;
}

sub Main
{
	my $connectString = shift;
	my @modules = @_ ? @_ : ('icd', 'cpt', 'hcpcs', 'envoy', 'epayer');
		
	printUsage() unless $connectString;
	$connectString =~ s/\@/\@dbi:Oracle:/;
	
	my $dataSrcPath = 'R:';
	#my $dataSrcPath = 'H:/HealthSuite-RefData';
	my $properties =
	{
		startTime => new Benchmark,
		#connectStr => 'demo01/demo@dbi:Oracle:SDEDBS02',
		connectStr => $connectString,
		scriptPath => $Bin,
		dataSrcPath => 'Q:',
		dataSrcInfoXPath => File::Spec->catfile($dataSrcPath, 'info-x'),
		dataSrcHCFAPath => File::Spec->catfile($dataSrcPath, 'hcfa'),
		dataSrcEnvoyPath => File::Spec->catfile($dataSrcPath, 'envoy'),
		dataSrcNtisPath => File::Spec->catfile($dataSrcPath, 'ntis'),
		dataSrcPersePath => File::Spec->catfile($dataSrcPath, 'perse'),
	};

	importICDInfo($properties, transformDBI => 1) if grep(/icd/, @modules);
	importCPTInfo($properties, transformDBI => 1) if grep(/cpt/, @modules);
	importHCPCSInfo($properties, transformDBI => 1) if grep(/hcpcs/, @modules);
	importEnvoyPayers($properties, transformDBI => 1) if grep(/envoy/, @modules);
	importEPayers($properties, transformDBI => 1) if grep(/epayer/, @modules);
}

sub importCPTInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::Ntis::CPTinfo;
	my $dataCollection = $params{collection} || new App::Data::Collection;

	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		cptShortFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'cpt_short.txt'),
		cptLongFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'cpt_long.txt'),
		cpEditFile => File::Spec->catfile($properties->{dataSrcNtisPath}, 'A_cpedit.txt'),
		meEditFile => File::Spec->catfile($properties->{dataSrcNtisPath}, 'C_meedit.txt'),
		crosswalkFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'Cpt-Icd1.txt'),
		cptOceFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'CptOce.txt'),
	);
	if($importer->haveErrors())
	{
		$importer->printErrors();
		die "there are errors";
	}

	undef $importer;

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => "delete from REF_CPT cascade//Delete from REF_CPT cascade.",
			insertStmt => "insert into REF_CPT
				(CPT, name, description, comprehensive_compound_cpts, comprehensive_compound_flags,
				mutual_exclusive_cpts, mutual_exclusive_flags, sex, unlisted, questionable, asc_,
				non_rep, non_cov
				)
				values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			verifyCountStmt => "select count(*) from REF_CPT",
		);
		$exporter->printErrors();
	}
}

sub importICDInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::InfoX::ICDinfo;
	my $dataCollection = $params{collection} || new App::Data::Collection;

	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		icdEditFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'Icd1Edit.txt'),
		icdCptCrosswalkFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'Icd1-cpt.txt'),
		icdDescrFile => File::Spec->catfile($properties->{dataSrcInfoXPath}, 'Icd.txt'),
	);
	if($importer->haveErrors())
	{
		$importer->printErrors();
		die "there are errors";
	}

	undef $importer;

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => ["delete from REF_ICD cascade//Delete from REF_ICD cascade.",
									 "drop index REF_ICD_DESCR//Drop index REF_ICD_DESCR"],
			insertStmt => "insert into REF_ICD
				(icd, name, descr, non_specific_code, sex, age, major_diag_category,
					comorbidity_complication, medicare_secondary_payer, manifestation_code,
					questionable_admission, unacceptable_primary_wo, unacceptable_principal,
					unacceptable_procedure, non_specific_procedure, non_covered_procedure,
					cpts_allowed)
			values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			doAfter => "create index REF_ICD_DESCR on REF_ICD (descr)//Creating index REF_ICD_DESCR",
			verifyCountStmt => "select count(*) from REF_ICD",
		);
		$exporter->printErrors();
	}
}

sub importHCPCSInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::HCFA::HCPCS;
	my $dataCollection = $params{collection} || new App::Data::Collection;

	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFile => File::Spec->catfile($properties->{dataSrcHCFAPath}, '99ANWEB.XLS'));
	if($importer->haveErrors())
	{
		$importer->printErrors();
		die "there are errors";
	}

	undef $importer;

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => "delete from REF_HCPCS cascade//Delete from REF_HCPCS cascade.",
			insertStmt => "insert into REF_HCPCS
				(hcpcs, name, description)
			values (?, ?, ?)",
			verifyCountStmt => "select count(*) from REF_HCPCS",
		);
		$exporter->printErrors();
	}
}

sub importEnvoyPayers
{
	my ($properties, %params) = @_;
	my $dataCollection = new App::Data::Collection;

	my $payersPath = File::Spec->catfile($properties->{dataSrcEnvoyPath}, 'payers-08-13-99-msword');
	my $importer = new App::Data::Obtain::Envoy::Payers;
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		srcCommercial => File::Spec->catfile($payersPath, 'mcomm.doc'),
		srcBCBS => File::Spec->catfile($payersPath, 'MHblue.doc'),
		srcMedicare => File::Spec->catfile($payersPath, 'MHcare.doc'),
		srcMedicaid => File::Spec->catfile($payersPath, 'MHcaid.doc'),
		);
	if($importer->haveErrors())
	{
		$importer->printErrors();
		return;
	}
	undef $importer;
	#$dataCollection->printDataSamples();

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;
		#$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
		#	connect => $properties->{connectStr},
		#	doBefore => "truncate table REF_ENVOY_PAYER//Truncating REF_ENVOY_PAYER table.",
		#	insertStmt => "insert into REF_ENVOY_PAYER (id, name, ptype, state, flags, remarks) values (?, ?, ?, ?, ?, ?)",
		#	verifyCountStmt => "select count(*) from REF_ENVOY_PAYER",
		#);

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => "delete from REF_EPAYER where psource = 1//Deleting Envoy Payers.",
			insertStmt => "insert into REF_EPAYER (id, name, ptype, state, flags, remarks, psource) 
				values (?, ?, ?, ?, ?, ?, 1)",
			verifyCountStmt => "select count(*) from REF_EPAYER where psource =1",
		);
		$exporter->printErrors();
	}
}

sub importEPayers
{
	my ($properties, %params) = @_;
	my $dataCollection = new App::Data::Collection;
	
	my $importer = new App::Data::Obtain::Perse::Epayer;
	my $dataCollection = $params{collection} || new App::Data::Collection;

	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		ePayersFile => File::Spec->catfile($properties->{dataSrcPersePath}, 'perse_payers.csv'),
	);
	if($importer->haveErrors())
	{
		$importer->printErrors();
		die "there are errors";
	}

	undef $importer;

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => "delete from REF_Epayer where psource = 2//Deleting Perse payers.",
			insertStmt => "insert into REF_Epayer
				(id, id2, name, psource, ptype)
			values (?, ?, ?, ?, ?)",
			verifyCountStmt => "select count(*) from REF_Epayer where psource =2",
		);
		$exporter->printErrors();
	}
}

Main(@ARGV);
