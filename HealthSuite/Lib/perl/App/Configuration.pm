##############################################################################
package App::Configuration;
##############################################################################
 
use strict;
use Exporter;
use File::Spec;
use Class::Struct;

use vars qw(
	@ISA @EXPORT
	%AVAIL_HOSTS %ENV
	$CONFDATA_SERVER
	$SERVERCONFDATA_TYPE_PRODUCTION $SERVERCONFDATA_TYPE_DEVELOPMENT $SERVERCONFDATA_TYPE_LOCAL
	$SERVERCONFDATA_SDE01 $SERVERCONFDATA_SDE02
	);
@ISA    = qw(Exporter);
@EXPORT = qw($CONFDATA_SERVER);

struct(ServerConfigData => [
	db_ConnectKey => '$',
	path_root => '$',
	path_Database => '$',
	path_SchemaSQL => '$',
	path_BillingTemplate => '$',
	path_Reports => '$',
	path_OrgReports => '$',
	path_PDFOutput => '$',
	file_SchemaDefn => '$',
	file_AccessControlDefn => '$',
]);

use constant PATH_UNIXROOT	 => defined $ENV{HEALTHSUITE} ? $ENV{HEALTHSUITE} : '/HealthSuite';
use constant PATH_ROOTDIR    => File::Spec->catfile($^O eq 'MSWin32' ? 'h:' : PATH_UNIXROOT);
use constant PATH_DATABASE   => File::Spec->catfile(PATH_ROOTDIR, 'Database');
use constant PATH_SCHEMASQL  => File::Spec->catfile(PATH_DATABASE, 'schema-physia');
use constant PATH_APPLIB     => File::Spec->catfile(PATH_ROOTDIR, 'Lib', 'perl', 'App');
use constant PATH_BILLTMPL   => File::Spec->catfile(PATH_APPLIB, 'Billing');
use constant PATH_REPORTS    => File::Spec->catfile(PATH_APPLIB, 'Dialog', 'Report');
use constant PATH_ORGREPORTS => File::Spec->catfile(PATH_REPORTS, 'Org');
use constant PATH_PDFOUTPUT  => File::Spec->catfile(PATH_ROOTDIR, 'WebSite', 'temp', 'invoice');
use constant FILE_SCHEMADEFN => File::Spec->catfile(PATH_DATABASE, 'schema-physia-src', 'schema.xml');
use constant FILE_ACLDEFN    => File::Spec->catfile(PATH_APPLIB, 'Conf', 'AccessControl.xml');

$SERVERCONFDATA_TYPE_PRODUCTION = new ServerConfigData;
$SERVERCONFDATA_TYPE_PRODUCTION->db_ConnectKey('physia/physia@dbi:Oracle:Physia');
$SERVERCONFDATA_TYPE_PRODUCTION->path_root(PATH_ROOTDIR);
$SERVERCONFDATA_TYPE_PRODUCTION->path_Database(PATH_DATABASE);
$SERVERCONFDATA_TYPE_PRODUCTION->path_SchemaSQL(PATH_SCHEMASQL);
$SERVERCONFDATA_TYPE_PRODUCTION->path_BillingTemplate(PATH_BILLTMPL);
$SERVERCONFDATA_TYPE_PRODUCTION->path_Reports(PATH_REPORTS);
$SERVERCONFDATA_TYPE_PRODUCTION->path_OrgReports(PATH_ORGREPORTS);
$SERVERCONFDATA_TYPE_PRODUCTION->path_PDFOutput(PATH_PDFOUTPUT);
$SERVERCONFDATA_TYPE_PRODUCTION->file_SchemaDefn(FILE_SCHEMADEFN);
$SERVERCONFDATA_TYPE_PRODUCTION->file_AccessControlDefn(FILE_ACLDEFN);

$SERVERCONFDATA_TYPE_DEVELOPMENT = new ServerConfigData;
$SERVERCONFDATA_TYPE_DEVELOPMENT->db_ConnectKey('physia/physia@dbi:Oracle:SDEDBS01');
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_root(PATH_ROOTDIR);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_Database(PATH_DATABASE);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_SchemaSQL(PATH_SCHEMASQL);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_BillingTemplate(PATH_BILLTMPL);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_Reports(PATH_REPORTS);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_OrgReports(PATH_ORGREPORTS);
$SERVERCONFDATA_TYPE_DEVELOPMENT->path_PDFOutput(PATH_PDFOUTPUT);
$SERVERCONFDATA_TYPE_DEVELOPMENT->file_SchemaDefn(FILE_SCHEMADEFN);
$SERVERCONFDATA_TYPE_DEVELOPMENT->file_AccessControlDefn(FILE_ACLDEFN);

$SERVERCONFDATA_SDE01 = new ServerConfigData;
$SERVERCONFDATA_SDE01->db_ConnectKey('sde01/sde@dbi:Oracle:SDEDBS01');
$SERVERCONFDATA_SDE01->path_root(PATH_ROOTDIR);
$SERVERCONFDATA_SDE01->path_Database(PATH_DATABASE);
$SERVERCONFDATA_SDE01->path_SchemaSQL(PATH_SCHEMASQL);
$SERVERCONFDATA_SDE01->path_BillingTemplate(PATH_BILLTMPL);
$SERVERCONFDATA_SDE01->path_Reports(PATH_REPORTS);
$SERVERCONFDATA_SDE01->path_OrgReports(PATH_ORGREPORTS);
$SERVERCONFDATA_SDE01->path_PDFOutput(PATH_PDFOUTPUT);
$SERVERCONFDATA_SDE01->file_SchemaDefn(FILE_SCHEMADEFN);
$SERVERCONFDATA_SDE01->file_AccessControlDefn(FILE_ACLDEFN);

$SERVERCONFDATA_SDE02 = new ServerConfigData;
$SERVERCONFDATA_SDE02->db_ConnectKey('sde_prime/sde@dbi:Oracle:SDEDBS02');
$SERVERCONFDATA_SDE02->path_root(PATH_ROOTDIR);
$SERVERCONFDATA_SDE02->path_Database(PATH_DATABASE);
$SERVERCONFDATA_SDE02->path_SchemaSQL(PATH_SCHEMASQL);
$SERVERCONFDATA_SDE02->path_BillingTemplate(PATH_BILLTMPL);
$SERVERCONFDATA_SDE02->path_Reports(PATH_REPORTS);
$SERVERCONFDATA_SDE02->path_OrgReports(PATH_ORGREPORTS);
$SERVERCONFDATA_SDE02->path_PDFOutput(PATH_PDFOUTPUT);
$SERVERCONFDATA_SDE02->file_SchemaDefn(FILE_SCHEMADEFN);
$SERVERCONFDATA_SDE02->file_AccessControlDefn(FILE_ACLDEFN);

$SERVERCONFDATA_TYPE_LOCAL = new ServerConfigData;
$SERVERCONFDATA_TYPE_LOCAL->db_ConnectKey('hs/hs@dbi:Oracle:HealthSuiteIvory');
$SERVERCONFDATA_TYPE_LOCAL->path_root(PATH_ROOTDIR);
$SERVERCONFDATA_TYPE_LOCAL->path_Database(PATH_DATABASE);
$SERVERCONFDATA_TYPE_LOCAL->path_SchemaSQL(PATH_SCHEMASQL);
$SERVERCONFDATA_TYPE_LOCAL->path_BillingTemplate(PATH_BILLTMPL);
$SERVERCONFDATA_TYPE_LOCAL->path_Reports(PATH_REPORTS);
$SERVERCONFDATA_TYPE_LOCAL->path_OrgReports(PATH_ORGREPORTS);
$SERVERCONFDATA_TYPE_LOCAL->path_PDFOutput(PATH_PDFOUTPUT);
$SERVERCONFDATA_TYPE_LOCAL->file_SchemaDefn(FILE_SCHEMADEFN);
$SERVERCONFDATA_TYPE_LOCAL->file_AccessControlDefn(FILE_ACLDEFN);

%AVAIL_HOSTS =
(
	'DEFIANT' => $SERVERCONFDATA_TYPE_PRODUCTION,
#	'MEDINA'  => $SERVERCONFDATA_TYPE_DEVELOPMENT,
#	'MEDINA'  => $SERVERCONFDATA_SDE01,
	'MEDINA'  => $SERVERCONFDATA_SDE02,
	'MEMPHIS' => $SERVERCONFDATA_TYPE_DEVELOPMENT,
	'CAIRO'   => $SERVERCONFDATA_TYPE_DEVELOPMENT,
	'LIMA'    => $SERVERCONFDATA_TYPE_DEVELOPMENT,
	'TITAN'   => $SERVERCONFDATA_TYPE_LOCAL,
	'TOKYO.PHYSIA.COM' => $SERVERCONFDATA_SDE02,
);

my $hostName = uc(`hostname`);
chomp($hostName);
$CONFDATA_SERVER = $AVAIL_HOSTS{$hostName};
die "Unable to find configuration for server/host '$hostName'\n" unless $CONFDATA_SERVER;

1;
