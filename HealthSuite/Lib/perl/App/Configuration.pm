##############################################################################
package App::Configuration;
##############################################################################

use strict;
use Exporter;
use File::Spec;
use Class::Struct;
use File::Path;

use vars qw(@ISA @EXPORT %AVAIL_CONFIGS %ENV $CONFDATA_SERVER $DEBUG);
@ISA    = qw(Exporter);
@EXPORT = qw($CONFDATA_SERVER);

struct(ServerConfigData => [
	name_Config => '$',
	name_Group => '$',
	db_ConnectKey => '$',
	path_root => '$',
	path_temp => '$',
	path_Database => '$',
	path_SchemaSQL => '$',
	path_BillingTemplate => '$',
	path_Reports => '$',
	path_OrgReports => '$',
	path_Conf => '$',
	path_AppConf => '$',
	path_PDFOutput => '$',
	path_PDFOutputHREF => '$',

	file_SchemaDefn => '$',
	file_BuildLog => '$',
	file_NSFHeader => '$',
	file_NSFCounter => '$',
	file_AccessControlDefn => '$',
	file_AccessControlAutoPermissons => '$',
]);

use constant CONFIGGROUP_PRO => 'production';
use constant CONFIGGROUP_SWDEV => 'development';
use constant CONFIGGROUP_TEST => 'testing';
use constant CONFIGGROUP_DEMO => 'demonstration';
use constant CONFIGGROUP_SOLO => 'solo';

use constant PATH_APPROOT    => File::Spec->catfile(defined $ENV{HS_HOME} ? $ENV{HS_HOME} : 'HealthSuite');
use constant PATH_APPLIB     => File::Spec->catfile(PATH_APPROOT, 'Lib', 'perl', 'App');
use constant PATH_DATABASE   => File::Spec->catfile(PATH_APPROOT, 'Database');
use constant PATH_REPORTS    => File::Spec->catfile(PATH_APPLIB, 'Dialog', 'Report');
use constant PATH_WEBSITE    => File::Spec->catfile(PATH_APPROOT, 'WebSite');
use constant PATH_TEMP       => File::Spec->catfile('temp');
use constant PATH_OUTPUTPDF  => File::Spec->catfile(PATH_TEMP, 'invoices');
use constant PATH_CONF       => File::Spec->catfile(PATH_APPROOT, 'Conf');
use constant PATH_APPCONF    => File::Spec->catfile(PATH_CONF, 'app');


# Returns true if debug mode is on
sub debugMode
{
	$DEBUG = shift if defined $_[1];
	unless (defined $DEBUG)
	{
		$DEBUG = 0;
		my $group = $CONFDATA_SERVER->name_Group();
		$DEBUG = 1 if $group eq CONFIGGROUP_SWDEV || $group eq CONFIGGROUP_TEST;
		if (exists $ENV{HS_DEBUG} && defined $ENV{HS_DEBUG})
		{
			$DEBUG = $ENV{HS_DEBUG} ? 1 : 0;
		}
	}
	return $DEBUG;
}


# Require that specified directory path(s) already exists
sub requirePath
{
	foreach (@_)
	{
		die "Directory " . $_ . " doesn't exist!" unless (-d $_);
	}
}


# Create specified directory path(s) if they don't already exist
sub createPath
{
	foreach (@_)
	{
		unless (-d $_)
		{
			die "Can't create directory " . $_ unless (mkpath($_));
		}
	}
}


# Populate the config with some default values
sub getDefaultConfig
{
	my ($name, $group, $dbConnectKey) = @_;
	die '$name, $group and $dbConnectKey are required' unless $name && $group && $dbConnectKey;

	my $config = new ServerConfigData;

	$config->name_Config($name);
	$config->name_Group($group);
	$config->db_ConnectKey($dbConnectKey);
	$config->path_root(PATH_APPROOT);
	$config->path_temp(File::Spec->catfile(PATH_WEBSITE, PATH_TEMP));
	$config->path_Database(PATH_DATABASE);
	$config->path_Reports(PATH_REPORTS);
	$config->path_SchemaSQL(File::Spec->catfile(PATH_DATABASE, 'schema-physia'));
	$config->path_BillingTemplate(File::Spec->catfile(PATH_APPLIB, 'Billing'));
	$config->path_OrgReports(File::Spec->catfile(PATH_REPORTS, 'Org'));
	$config->path_Conf(PATH_CONF);
	$config->path_AppConf(PATH_APPCONF);
	$config->path_PDFOutput(File::Spec->catfile(PATH_WEBSITE, PATH_OUTPUTPDF));
	$config->path_PDFOutputHREF(File::Spec->catfile('', PATH_OUTPUTPDF));
	$config->file_SchemaDefn(File::Spec->catfile(PATH_DATABASE, 'schema-physia-src', 'schema.xml'));
	$config->file_NSFHeader(File::Spec->catfile(PATH_APPCONF, 'nsf-header-conf'));
	$config->file_NSFCounter(File::Spec->catfile(PATH_APPCONF, 'nsf-submission-counter'));
	$config->file_AccessControlDefn(File::Spec->catfile(PATH_APPCONF, 'acl-main.xml'));

	# if you change this file location/name, please update /usr/local/bin/start_httpd
	$config->file_AccessControlAutoPermissons(File::Spec->catfile(PATH_APPCONF, 'acl-auto-permissions.xml'));
	return $config;
}


%AVAIL_CONFIGS =
(
	# per-machine configurations go here
	'TOKYO' => getDefaultConfig('Tokyo Main Configuration', CONFIGGROUP_PRO, 'pro_new/pro@dbi:Oracle:SDEDBS03'),
	'MEDINA' => getDefaultConfig('Medina Configuration', CONFIGGROUP_PRO, 'prod_01/prod01@dbi:Oracle:SDEDBS02'),
	'LIMA' => getDefaultConfig('Lima Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'TITAN' => getDefaultConfig('Thai Home PC Configuration', CONFIGGROUP_SOLO, 'hs/hs@dbi:Oracle:HealthSuiteIvory'),

	# other keyed configurations go here
	# if a particular UNIX user needs a special configuration, use 'account-username'
	# if a particular UNIX group needs a special configuration, use 'group-groupname'
	'group-swdev' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	'group-virtuser' => getDefaultConfig('Virtual User Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	'account-vusr_demo01' => getDefaultConfig('Demo01 Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'account-vusr_test01' => getDefaultConfig('Testing Configuration', CONFIGGROUP_TEST, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'account-alex_hillman' => getDefaultConfig('Alex Hillman Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	
	# configs specifically for use with $ENV{HS_CONFIG}
	'db-sde_prime' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	'db-sde_prime2' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde_prime2/sde@dbi:Oracle:SDEDBS02'),
	'db-demo01' => getDefaultConfig('Demo01 Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'db-pro01' => getDefaultConfig('Production Configuration', CONFIGGROUP_PRO, 'prod_01/prod01@dbi:Oracle:SDEDBS02'),
	'db-pro_test' => getDefaultConfig('Production Test Configuration', CONFIGGROUP_TEST, 'pro_test/pro@dbi:Oracle:SDEDBS03'),
	'db-pro_new' => getDefaultConfig('New Production Configuration', CONFIGGROUP_PRO, 'pro_new/pro@dbi:Oracle:SDEDBS03'),
);

my $userName = '';
my $groupName = '';
my $hostName = uc(`hostname`);

if(my $forceConfig = $ENV{HS_CONFIG})
{
	$CONFDATA_SERVER = $AVAIL_CONFIGS{$forceConfig};
	print "Forced configuration to '$forceConfig'\n";
}

if($^O ne 'MSWin32')
{
	my $userName = getpwuid($>) || '';
	my $groupName = getgrgid($)) || '';

	$CONFDATA_SERVER = $AVAIL_CONFIGS{"account-$userName"} unless $CONFDATA_SERVER;
	$CONFDATA_SERVER = $AVAIL_CONFIGS{"group-$groupName"} unless $CONFDATA_SERVER;
}
unless ($CONFDATA_SERVER)
{
	$hostName = $1 if $hostName =~ /^(\w+?)\..*$/;
	chomp($hostName);
	$CONFDATA_SERVER = $AVAIL_CONFIGS{$hostName};
}
die "Unable to find configuration for 'account-$userName', 'group-$groupName' or '$hostName'\n" unless $CONFDATA_SERVER;

createPath(
	$CONFDATA_SERVER->path_SchemaSQL,
	$CONFDATA_SERVER->path_temp,
	$CONFDATA_SERVER->path_PDFOutput
	);
requirePath(
	$CONFDATA_SERVER->path_Database,
	$CONFDATA_SERVER->path_Reports,
	$CONFDATA_SERVER->path_BillingTemplate,
	$CONFDATA_SERVER->path_OrgReports,
	);
	
1;
