##############################################################################
package App::Configuration;
##############################################################################

use strict;
use Exporter;
use File::Spec;
use Class::Struct;
use File::Path;

use vars qw(@ISA @EXPORT %AVAIL_CONFIGS %ENV $CONFDATA_SERVER);
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
	path_PDFOutput => '$',
	path_PDFOutputHREF => '$',
	file_SchemaDefn => '$',
	file_AccessControlDefn => '$',
	file_BuildLog => '$',
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

sub requirePath
{
	foreach (@_)
	{
		die "Directory " . $_ . " doesn't exist!" unless (-d $_);
	}
}

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
	$config->path_PDFOutput(File::Spec->catfile(PATH_WEBSITE, PATH_OUTPUTPDF));
	$config->path_PDFOutputHREF(File::Spec->catfile('', PATH_OUTPUTPDF));
	$config->file_SchemaDefn(File::Spec->catfile(PATH_DATABASE, 'schema-physia-src', 'schema.xml'));
	$config->file_AccessControlDefn(File::Spec->catfile(PATH_APPLIB, 'Conf', 'AccessControl.xml'));
	return $config;
}

%AVAIL_CONFIGS =
(
	# per-machine configurations go here
	'TOKYO' => getDefaultConfig('Tokyo Main Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'MEDINA' => getDefaultConfig('Medina Configuration', CONFIGGROUP_PRO, 'prod_01/prod01@dbi:Oracle:SDEDBS02'),
	'LIMA' => getDefaultConfig('Lima Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'TITAN' => getDefaultConfig('Thai Home PC Configuration', CONFIGGROUP_SOLO, 'hs/hs@dbi:Oracle:HealthSuiteIvory'),

	# other keyed configurations go here
	# if a particular UNIX user needs a special configuration, use 'account-username'
	# if a particular UNIX group needs a special configuration, use 'group-groupname'
	'group-swdev' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	'group-virtuser' => getDefaultConfig('Virtual User Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
	'account-vusr_demo01' => getDefaultConfig('Demo01 Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'account-alex_hillman' => getDefaultConfig('Alex Hillman Configuration', CONFIGGROUP_SWDEV, 'sde_prime/sde@dbi:Oracle:SDEDBS02'),
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
#print "path_Root = " . $CONFDATA_SERVER->path_root . "\n";
#print "name_Config = " . $CONFDATA_SERVER->name_Config . "\n";
#print "name_Group = " . $CONFDATA_SERVER->name_Group . "\n";
#print "db_ConnectKey = " . $CONFDATA_SERVER->db_ConnectKey . "\n";
1;
