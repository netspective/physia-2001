use strict;
use App::Data::Collection;
use App::Data::Transform::DBI;

use App::Data::Obtain::Ntis::CPTinfo;
use App::Data::Obtain::InfoX::ICDinfo;
use App::Data::Obtain::HCFA::HCPCS;
use App::Data::Obtain::Envoy::Payers;
use App::Data::Obtain::ThinNet::Payers;
use App::Data::Obtain::Perse::Epayer;
use App::Data::Obtain::RBRVS::RVU;
use App::Data::Obtain::RBRVS::GPCI;
use App::Data::Obtain::EPSDT::EPSDT;
use App::Data::Obtain::TXgulf::FeeSchedules;
use App::Data::Obtain::EPSDT::CodeServType;


use File::Path;
use FindBin qw($Bin);
use Benchmark;
use File::Spec;
use Getopt::Long;
use File::Basename;
use Date::Manip;

$ENV{TZ} = 'EST' unless exists $ENV{TZ};
my @allModules = ( 'icd','thin', 'cpt', 'hcpcs', 'envoy', 'epayer', 'epsdt', 'rvu' . UnixDate('today', '%y'),'codeserv');

sub printUsage
{
	print qq{
Usage:  @{[basename $0]} <connect string> [ @{[ join(' ', @allModules) ]} ]
If no module is specified, the default is to load ALL modules.

Example: @{[basename $0]} sde_prime/sde\@sdedbs02 icd cpt
to only load icd and cpt modules.
	};
	exit;
}

sub Main
{
	my $connectString = shift;
	my @modules = @_ ? @_ : @allModules;

	printUsage() unless $connectString;
	$connectString =~ s/\@/\@dbi:Oracle:/;

	my $dataSrcPath = 'R:';
	#my $dataSrcPath = 'H:/HealthSuite-RefData';

	my @rvuFile = grep(/rvu/, @modules);
	
	my $properties =
	{
		startTime => new Benchmark,
		#connectStr => 'demo01/demo@dbi:Oracle:SDEDBS02',
		#dataSrcPath => 'Q:',

		connectStr => $connectString,
		scriptPath => $Bin,
		dataSrcInfoXPath => File::Spec->catfile($dataSrcPath, 'info-x'),
		dataSrcHCFAPath => File::Spec->catfile($dataSrcPath, 'hcfa'),
		dataSrcEnvoyPath => File::Spec->catfile($dataSrcPath, 'envoy'),
		dataSrcNtisPath => File::Spec->catfile($dataSrcPath, 'ntis'),
		dataSrcPersePath => File::Spec->catfile($dataSrcPath, 'perse'),
		dataSrcRBRVSPath => File::Spec->catfile($dataSrcPath, 'rbrvs'),
		dataSrcServCatPath => File::Spec->catfile($dataSrcPath, 'serv_cat'),
		rvuFile => \@rvuFile,
		dataSrcRTXgulfPath => File::Spec->catfile($dataSrcPath, 'TXgulf'),
		dataSrcEPSDTPath => File::Spec->catfile($dataSrcPath,'EPSDT'),
		dataSrcThinPath=>File::Spec->catfile($dataSrcPath,'ThinNet'),
	};

	importICDInfo($properties, transformDBI => 1) if grep(/icd/, @modules);
	importCPTInfo($properties, transformDBI => 1) if grep(/cpt/, @modules);
	importHCPCSInfo($properties, transformDBI => 1) if grep(/hcpcs/, @modules);
	importEnvoyPayers($properties, transformDBI => 1) if grep(/envoy/, @modules);
	importEPayers($properties, transformDBI => 1) if grep(/epayer/, @modules);
	importGPCIInfo($properties, transformDBI => 1) if grep(/rvu/, @modules);
	importRVUInfo($properties, transformDBI => 1) if grep(/rvu/, @modules);
	importEPSDTInfo($properties, transformDBI => 1) if grep(/epsdt/, @modules);	
	importCodeServTypeInfo($properties, transformDBI => 1) if grep(/codeserv/, @modules);	
	importTXGULFfs($properties, transformDBI => 1) if grep(/tgcmgfs/, @modules);
	#importServCat($properties, transformDBI => 1) if grep(/servcat/, @modules);
	importThinPayers($properties, transformDBI => 1) if grep(/thin/, @modules);	
}

sub importServCat
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::ServCat;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	print "Starting\n";
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFile => File::Spec->catfile($properties->{dataSrcServCatPath}, 'acs_serv_cat.xls'));
	if($importer->haveErrors())
	{
		$importer->printErrors();
		die "there are errors";
	}

	if($params{transformDBI})
	{
		my $exporter = new App::Data::Transform::DBI;

		$exporter->transform(App::Data::Manipulate::DATAMANIPFLAG_SHOWPROGRESS, $dataCollection,
			connect => $properties->{connectStr},
			doBefore => "delete from REF_Service_Category cascade//Delete from REF_Service_Category cascade.",
			insertStmt => "insert into REF_Service_Catergory
				(id,name,description )
			values (?,?,?, ?)",
			verifyCountStmt => "select count(*) from REF_Service_Category",
		);
		$exporter->printErrors();
	}
}

sub importCodeServTypeInfo
{

	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::EPSDT::CodeServType;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	print "Starting\n";
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFile => File::Spec->catfile($properties->{dataSrcEPSDTPath}, 'code_mapping.xls'));
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
			doBefore => "delete from REF_Code_Service_Type cascade//Delete from REF_Code_Service_Type cascade.",
			insertStmt => "insert into REF_Code_Service_Type
				(CODE_MIN,CODE_MAX, ENTRY_TYPE,SERVICE_TYPE)
			values (?,?,?, ?)",
			verifyCountStmt => "select count(*) from REF_CODE_SERVICE_TYPE",
		);
		$exporter->printErrors();
	}


}


sub importEPSDTInfo
{

	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::EPSDT::EPSDT;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	print "Starting\n";
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFile => File::Spec->catfile($properties->{dataSrcEPSDTPath}, 'EPSDT.xls'));
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
			doBefore => "delete from REF_EPSDT cascade//Delete from REF_EPSDT cascade.",
			insertStmt => "insert into REF_EPSDT
				(epsdt,name, description)
			values (?,?, ?)",
			verifyCountStmt => "select count(*) from REF_EPSDT",
		);
		$exporter->printErrors();
	}


}

sub importRVUInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::RBRVS::RVU;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	my $year = $properties->{rvuFile}->[0];
	$year =~ s/\D+//;
	die "For rvu a two digit year must be supplied  [ example : rvu00 for rvu for 2000 ]" if ! $year;
	my $begin_yr = "01-JAN-$year";
	my $end_yr = "31-DEC-$year";
	print "\nREF_PFS_RVU BEGIN YEAR => $begin_yr END YEAR =>$end_yr \n";
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFile => File::Spec->catfile($properties->{dataSrcRBRVSPath}, 'pprrvu'.$year.'.xls'));
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
			doBefore => "delete from REF_PFS_RVU WHERE EFF_BEGIN_DATE = to_date('$begin_yr', 'dd-MON-yy') ",
			insertStmt => "insert into REF_PFS_RVU ( EFF_BEGIN_DATE, EFF_END_DATE,CODE,MODIFIER ,
			  DESCRIPTION, STATUS_CODE , MEDICARE_IND , WORK_RVU , NON_FAC_PE_RVU ,
			  NA_IND, TRANS_NON_FAC_PE_RVU , FAC_PE_RVU,TRANS_FAC_PE_RVU,MAL_PRACTICE_RVU ,
			  TLT_NON_FAC_RVU, TLT_TRANS_NON_FAC_RVU, TLT_FAC_RVU,TLT_TRANS_FAC_RVU , PC_TC_IND,
			  GLOBAL_SURGERY, PREOP_PERCENT,INTRAOP_PERCENT,POSTOP_PERCENT,MULTI_PROCEDURE,
			  BILAT_SURGERY,  ASST_SURGERY,CO_SURGEONS, TEAM_SURGERY, PHY_SUPERVISE,
			   BILL_MED_CODE ,  ENDO_BASE_CODE ,CONVERSION_FACT)
			values (to_date('$begin_yr', 'dd-MON-yy'), to_date('$end_yr', 'dd-MON-yy'),?,?,?,?,?,?,?,?,
				?,?,?,?,?,?,?,?,?,?,
				?,?,?,?,?,?,?,?,?,?,
				?,?)",
			verifyCountStmt => "select count(*) from REF_PFS_RVU",
		);
		$exporter->printErrors();
	}
}

sub importGPCIInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::RBRVS::GPCI;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	my $year = $properties->{rvuFile}->[0];
	$year =~ s/\D+//;
	my $begin_yr = "01-JAN-$year";
	my $end_yr = "31-DEC-$year";
	print "\nGPCI BEGIN YEAR => $begin_yr END YEAR =>$end_yr \n";
	die "For rvu a two digit year must be supplied  [ example : rvu00 for rvu for 2000 ]" if ! $year;
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
						srcFileGPCI=> File::Spec->catfile($properties->{dataSrcRBRVSPath}, $year.'gpcis.xls'),
						srcFileLocal => File::Spec->catfile($properties->{dataSrcRBRVSPath}, $year.'locco.xls'),
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
			doBefore => "delete REF_GPCI WHERE EFF_BEGIN_DATE='$begin_yr' ",
			insertStmt => "insert into REF_GPCI
			( EFF_BEGIN_DATE  ,EFF_END_DATE ,
 			  CARRIER_NUMBER  , LOCALITY_NUMBER ,
 			  LOCALITY_NAME    , STATE  ,
			  COUNTY  ,     WORK ,
 			  PRACTICE_EXPENSE ,MAL_PRACTICE )
 			 values
 			  (to_date('$begin_yr', 'dd-MON-yy'), to_date('$end_yr', 'dd-MON-yy'),?,?,?,?,?,?,?,?) ",
			verifyCountStmt => "select count(*) from REF_GPCI",
		);
		$exporter->printErrors();
	}
}

sub importCPTInfo
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::Ntis::CPTinfo;
	my $dataCollection = $params{collection} || new App::Data::Collection;
	print "\n";
	
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
	print "\n";

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
	print "\n";

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
	print "\n";

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
	print "\n";

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
				(id,  name, psource, ptype)
			values (?, ?, ?, ?)",
			verifyCountStmt => "select count(*) from REF_Epayer where psource =2",
		);
		$exporter->printErrors();
	}
}

sub importThinPayers
{
	my ($properties, %params) = @_;
	my $dataCollection = new App::Data::Collection;
	print "\n";

	my $importer = new App::Data::Obtain::ThinNet::Payers;
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		srcThin => File::Spec->catfile($properties->{dataSrcThinPath}, 'net_payer.dot'),
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
			doBefore => "delete from REF_EPAYER where psource = 3//Deleting Thin Net Payers.",
			insertStmt => "insert into REF_EPAYER (id, name, ptype, state, flags, remarks, psource)
				values (?, ?, ?, ?, ?, ?, 3)",
			verifyCountStmt => "select count(*) from REF_EPAYER where psource =3",
		);
		$exporter->printErrors();
	}
}

sub importTXGULFfs
{
	my ($properties, %params) = @_;

	my $importer = new App::Data::Obtain::TXgulf::FeeSchedules;
	my $dataCollection = $params{collection} || new App::Data::Collection;

	die "\nPlease set Environment Variable ORG_ID for this import." unless exists $ENV{ORG_ID};
	die "\nPlease set Environment Variable CATALOG_ID_OFFSET for this import.\nIts value should be max(internal_catalog_id) +1 from Offering_Catalog." 
		unless exists $ENV{CATALOG_ID_OFFSET};
	
	print "\n";
	
	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		srcFile=> File::Spec->catfile($properties->{dataSrcRTXgulfPath}, 'TXGULF Fee Schedules.xls'),
		importAction => 'IMPORT_FEE_SCHEDULE',
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
				doBefore => qq{delete from Offering_Catalog where catalog_id in ('REGULAR', 'MC_99',
					'BCBS', 'MEDICAID', 'WC', 'ML_IPA', 'USFHP', 'CIGNA_CAP', 'NYLC_UTMB', 'CL_IPA',
					'UMC', 'PRUD', 'KIM_CAP', 'RVU', 'MMG', 'MC2000', 'KELSEY', 'TRICARE', 'NINETEEN',
					'TWENTY') and org_id = '$ENV{ORG_ID}'//
					delete from Offering_Catalog where catalog_id in ('REGULAR', 'MC_99',
					'BCBS', 'MEDICAID', 'WC', 'ML_IPA', 'USFHP', 'CIGNA_CAP', 'NYLC_UTMB', 'CL_IPA',
					'UMC', 'PRUD', 'KIM_CAP', 'RVU', 'MMG', 'MC2000', 'KELSEY', 'TRICARE', 'NINETEEN',
					'TWENTY') and org_id = '$ENV{ORG_ID}'},
				insertStmt => qq{insert into Offering_Catalog
					(cr_stamp, cr_org_id, catalog_id, caption, org_id, catalog_type, description)
					values (sysdate, 'PHYSIA', ?, ?, '$ENV{ORG_ID}', 0, 'Imported Fee Schedule')
				},
				verifyCountStmt => "select count(*) from Offering_Catalog",
			);
			$exporter->printErrors();
	}

	# ---------------------------------------------------------------------------------------

	$importer = new App::Data::Obtain::TXgulf::FeeSchedules;
	$dataCollection = $params{collection} || new App::Data::Collection;
	print "\n";

	$importer->obtain(App::Data::Manipulate::DATAMANIPFLAG_VERBOSE, $dataCollection,
		srcFile=> File::Spec->catfile($properties->{dataSrcRTXgulfPath}, 'TXGULF Fee Schedules.xls'),
		importAction => 'IMPORT_FS_ENTRIES',
		catalog_id_offset => $ENV{CATALOG_ID_OFFSET},		
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
			doBefore => "delete from Offering_catalog_Entry where catalog_id >= $ENV{CATALOG_ID_OFFSET}
				// delete from Offering_catalog_Entry where catalog_id >= $ENV{CATALOG_ID_OFFSET}",
			insertStmt => "insert into Offering_Catalog_Entry
				(catalog_id, entry_type, flags, status, code, name, default_units, cost_type, unit_cost,
				description, units_avail)
			values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)",
			verifyCountStmt => "select count(*) from Offering_Catalog_Entry where catalog_id >= $ENV{CATALOG_ID_OFFSET}",
		);
		$exporter->printErrors();
	}
}

Main(@ARGV);
