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
	path_WebSite => '$',
	path_temp => '$',
	path_Database => '$',
	path_SchemaSQL => '$',
	path_BillingTemplate => '$',
	path_Reports => '$',
	path_OrgReports => '$',
	path_OrgDirectory => '$',
	path_Conf => '$',
	path_AppConf => '$',
	path_HandheldPages => '$',
	# Next two for invoices...
	path_PDFOutput => '$',
	path_PDFOutputHREF => '$',
	path_PDFSuperBillOutput => '$',
	path_PDFSuperBillOutputHREF => '$',
	path_EDIData => '$',
	path_PerSeEDIData => '$',
	path_PerSeEDIDataIncoming => '$',
	path_PerSeEDIDataOutgoing => '$',
	path_PerSeEDIErrors => '$',
	path_PerSeEDIErrorsDelim => '$',
	path_PerSeEDIReports => '$',
	path_PerSeEDIReportsDelim => '$',
	path_PaperClaims => '$',
	path_OrgLib => '$',
	path_PersonLib => '$',
	path_XMLData => '$',
	path_XMLDataHREF => '$',

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
use constant PATH_LIB        => File::Spec->catfile(PATH_APPROOT, 'Lib', 'perl');
use constant PATH_APPLIB     => File::Spec->catfile(PATH_LIB, 'App');
use constant PATH_ORGLIB     => File::Spec->catfile(PATH_LIB, 'Org');
use constant PATH_PERSONLIB  => File::Spec->catfile(PATH_LIB, 'Person');
use constant PATH_DATABASE   => File::Spec->catfile(PATH_APPROOT, 'Database');
use constant PATH_REPORTS    => File::Spec->catfile(PATH_APPLIB, 'Dialog', 'Report');
use constant PATH_DIRECTORY	 => File::Spec->catfile(PATH_APPLIB, 'Dialog', 'Directory');
use constant PATH_HANDHELD   => File::Spec->catfile(PATH_APPLIB, 'Dialog', 'HandHeld');
use constant PATH_WEBSITE    => File::Spec->catfile(PATH_APPROOT, 'WebSite');
use constant PATH_TEMP       => File::Spec->catfile('temp');
use constant PATH_OUTPUTPDF  => File::Spec->catfile(PATH_TEMP, 'invoices');
use constant PATH_OUTPUTSUPERBILLPDF  => File::Spec->catfile(PATH_TEMP, 'superbills');
use constant PATH_CONF       => File::Spec->catfile(PATH_APPROOT, 'Conf');
use constant PATH_APPCONF    => File::Spec->catfile(PATH_CONF, 'app');
use constant PATH_EDIDATA    => File::Spec->catfile(defined $ENV{HS_EDIDATA} ? $ENV{HS_EDIDATA} : '/home/vusr_edi');
use constant PATH_XMLDATA    => File::Spec->catfile(PATH_WEBSITE, 'resources', 'data');

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
			my $umask = umask("0000");
			die "Can't create directory " . $_ unless (mkpath($_));
			umask($umask);
		}
	}
}

sub createLink
{
	my (%links) = @_;

	foreach my $key (keys %links)
	{
		unless(-l $key)
		{
			system(qq{
				ln -fs $links{$key} $key
			});
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
	$config->path_WebSite(PATH_WEBSITE);
	$config->path_temp(File::Spec->catfile(PATH_WEBSITE, PATH_TEMP));
	$config->path_Database(PATH_DATABASE);
	$config->path_Reports(PATH_REPORTS);
	$config->path_HandheldPages(PATH_HANDHELD);
	$config->path_SchemaSQL(File::Spec->catfile(PATH_DATABASE, 'schema-physia'));
	$config->path_BillingTemplate(File::Spec->catfile(PATH_APPLIB, 'Billing'));
	$config->path_OrgReports(File::Spec->catfile(PATH_REPORTS, 'Org'));
	$config->path_OrgDirectory(File::Spec->catfile(PATH_DIRECTORY, 'Org'));
	$config->path_Conf(PATH_CONF);
	$config->path_AppConf(PATH_APPCONF);
	$config->path_PDFOutput(File::Spec->catfile(PATH_WEBSITE, PATH_OUTPUTPDF));
	$config->path_PDFOutputHREF(File::Spec->catfile('', PATH_OUTPUTPDF));
	$config->path_PDFSuperBillOutput(File::Spec->catfile(PATH_WEBSITE, PATH_OUTPUTSUPERBILLPDF));
	$config->path_PDFSuperBillOutputHREF(File::Spec->catfile('', PATH_OUTPUTSUPERBILLPDF));
	$config->path_EDIData(PATH_EDIDATA);
	$config->path_PerSeEDIData(File::Spec->catfile(PATH_EDIDATA, 'per-se'));
	$config->path_PerSeEDIDataIncoming(File::Spec->catfile($config->path_PerSeEDIData(), 'incoming'));
	$config->path_PerSeEDIDataOutgoing(File::Spec->catfile($config->path_PerSeEDIData(), 'outgoing'));
	$config->path_PerSeEDIErrors(File::Spec->catfile($config->path_PerSeEDIDataIncoming(), 'errors'));
	$config->path_PerSeEDIErrorsDelim(File::Spec->catfile($config->path_PerSeEDIDataIncoming(), 'errors-delim'));
	$config->path_PerSeEDIReports(File::Spec->catfile($config->path_PerSeEDIDataIncoming(), 'reports'));
	$config->path_PerSeEDIReportsDelim(File::Spec->catfile($config->path_PerSeEDIDataIncoming(), 'reports-delim'));
	$config->path_OrgLib(PATH_ORGLIB);
	$config->path_PersonLib(PATH_PERSONLIB);
	$config->path_XMLData(File::Spec->catfile('', PATH_XMLDATA));
	$config->path_XMLDataHREF(File::Spec->catfile('', PATH_XMLDATA));

	if ($group eq CONFIGGROUP_PRO) {
		$config->path_PaperClaims(File::Spec->catfile(PATH_EDIDATA, 'paper-claims'));
	}
	elsif ($group eq CONFIGGROUP_TEST) {
		$config->path_PaperClaims(File::Spec->catfile(PATH_EDIDATA, 'test-paper-claims'));
	}
	elsif ($group eq CONFIGGROUP_DEMO) {
		$config->path_PaperClaims(File::Spec->catfile(PATH_EDIDATA, 'demo-paper-claims'));
	}
	else {
		$config->path_PaperClaims(File::Spec->catfile(PATH_EDIDATA, 'dev-paper-claims'));
	}

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
	'PSLINUX' => getDefaultConfig('ProSys Configuration', CONFIGGROUP_SOLO, 'physia/physia@dbi:Oracle:physia'),
	'SILICON' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDEDBS04'),

	# other keyed configurations go here
	# if a particular UNIX user needs a special configuration, use 'account-username'
	# if a particular UNIX group needs a special configuration, use 'group-groupname'
	'group-swdev' => getDefaultConfig('SWDev Group Configuration', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDEDBS04'),
	'group-virtuser' => getDefaultConfig('Virtual User Configuration', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDEDBS04'),
	'account-vusr_demo01' => getDefaultConfig('Demo01 Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'account-vusr_test01' => getDefaultConfig('Testing Configuration', CONFIGGROUP_TEST, 'pro_test/pro@dbi:Oracle:SDEDBS04'),
	'account-alex_hillman' => getDefaultConfig('Alex Hillman Configuration', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDEDBS04'),

	# configs specifically for use with $ENV{HS_CONFIG}
	'db-demo01' => getDefaultConfig('Demo01 Configuration', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:SDEDBS02'),
	'db-demo02' => getDefaultConfig('Demo02 Configuration', CONFIGGROUP_DEMO, 'demo02/demo@dbi:Oracle:SDEDBS02'),
	'db-demosnap' => getDefaultConfig('DemoSnap Configuration', CONFIGGROUP_DEMO, 'demosnap/demo@dbi:Oracle:SDEDBS02'),
	'db-pro01' => getDefaultConfig('Production Configuration', CONFIGGROUP_PRO, 'prod_01/prod01@dbi:Oracle:SDEDBS02'),
	'db-pro_test' => getDefaultConfig('Production Test Configuration', CONFIGGROUP_TEST, 'pro_test/pro@dbi:Oracle:SDEDBS04'),
	'db-pro_new' => getDefaultConfig('New Production Configuration', CONFIGGROUP_PRO, 'pro_new/usuz1v4y@dbi:Oracle:SDEDBS03'),
	'db-sde01' => getDefaultConfig('New SWDev Configuration', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDEDBS04'),
	'db-pro_thai' => getDefaultConfig('Production Test Configuration', CONFIGGROUP_TEST, 'sde04/sde@dbi:Oracle:SDEDBS05'),
	'db-sde02' => getDefaultConfig('New SWDev Configuration', CONFIGGROUP_SWDEV, 'sde02/sde@dbi:Oracle:SDEDBS04'),
	'db-pro_munir' => getDefaultConfig("Munir's Database", CONFIGGROUP_SWDEV, 'sde02/sde@dbi:Oracle:SDEDBS05'),
	'db-acs_test' => getDefaultConfig("ACS TEST Database", CONFIGGROUP_SWDEV, 'ACS_TEST/ACS@dbi:Oracle:SDEDBS04'),
	'db-pro_fkm' => getDefaultConfig("ACS TEST Database", CONFIGGROUP_SWDEV, 'sde03/sde@dbi:Oracle:SDEDBS05'),

	# New SUN Databases
	'db-sun-pro01' => getDefaultConfig('SUN Production Configuration 01', CONFIGGROUP_PRO, 'pro01/pro@dbi:Oracle:PRO-DBS-A'),
	'db-sun-pro02' => getDefaultConfig('SUN Production Configuration 02', CONFIGGROUP_PRO, 'pro02/pro@dbi:Oracle:PRO-DBS-A'),
	'db-sun-pro03' => getDefaultConfig('SUN Production Configuration 03', CONFIGGROUP_PRO, 'pro03/pro@dbi:Oracle:PRO-DBS-B'),
	'db-sun-pro04' => getDefaultConfig('SUN Production Configuration 04', CONFIGGROUP_PRO, 'pro04/pro@dbi:Oracle:PRO-DBS-B'),
	'db-sun-demo01' => getDefaultConfig('SUN Demo Configuration 01', CONFIGGROUP_DEMO, 'demo01/demo@dbi:Oracle:DEMO-DBS-A'),
	'db-sun-demo02' => getDefaultConfig('SUN Demo Configuration 02', CONFIGGROUP_DEMO, 'demo02/demo@dbi:Oracle:DEMO-DBS-A'),
	'db-sun-demo03' => getDefaultConfig('SUN Demo Configuration 03', CONFIGGROUP_DEMO, 'demo03/demo@dbi:Oracle:DEMO-DBS-B'),
	'db-sun-demo04' => getDefaultConfig('SUN Demo Configuration 04', CONFIGGROUP_DEMO, 'demo04/demo@dbi:Oracle:DEMO-DBS-B'),
	'db-sun-test01' => getDefaultConfig('SUN Test Configuration 01', CONFIGGROUP_TEST, 'test01/test@dbi:Oracle:TEST-DBS-A'),
	'db-sun-test02' => getDefaultConfig('SUN Test Configuration 02', CONFIGGROUP_TEST, 'test02/test@dbi:Oracle:TEST-DBS-A'),
	'db-sun-test03' => getDefaultConfig('SUN Test Configuration 03', CONFIGGROUP_TEST, 'test03/test@dbi:Oracle:TEST-DBS-B'),
	'db-sun-test04' => getDefaultConfig('SUN Test Configuration 04', CONFIGGROUP_TEST, 'test04/test@dbi:Oracle:TEST-DBS-B'),
	'db-sun-sde01' => getDefaultConfig('SUN SDE Configuration 01', CONFIGGROUP_SWDEV, 'sde01/sde@dbi:Oracle:SDE-DBS-A'),
	'db-sun-sde02' => getDefaultConfig('SUN SDE Configuration 02', CONFIGGROUP_SWDEV, 'sde02/sde@dbi:Oracle:SDE-DBS-A'),
	'db-sun-sde03' => getDefaultConfig('SUN SDE Configuration 03', CONFIGGROUP_SWDEV, 'sde03/sde@dbi:Oracle:SDE-DBS-A'),
	'db-sun-sde04' => getDefaultConfig('SUN SDE Configuration 04', CONFIGGROUP_SWDEV, 'sde04/sde@dbi:Oracle:SDE-DBS-A'),
	'db-sun-sde05' => getDefaultConfig('SUN SDE Configuration 05', CONFIGGROUP_SWDEV, 'sde05/sde@dbi:Oracle:SDE-DBS-B'),
	'db-sun-sde06' => getDefaultConfig('SUN SDE Configuration 06', CONFIGGROUP_SWDEV, 'sde06/sde@dbi:Oracle:SDE-DBS-B'),
	'db-sun-sde07' => getDefaultConfig('SUN SDE Configuration 07', CONFIGGROUP_SWDEV, 'sde07/sde@dbi:Oracle:SDE-DBS-B'),
	'db-sun-sde08' => getDefaultConfig('SUN SDE Configuration 08', CONFIGGROUP_SWDEV, 'sde08/sde@dbi:Oracle:SDE-DBS-B'),
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
	$userName = getpwuid($>) || '';
	$groupName = getgrgid($)) || '';

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
	$CONFDATA_SERVER->path_PDFOutput,
	$CONFDATA_SERVER->path_PDFSuperBillOutput,
	$CONFDATA_SERVER->path_XMLData,
);
requirePath(
	$CONFDATA_SERVER->path_Database,
	$CONFDATA_SERVER->path_Reports,
	$CONFDATA_SERVER->path_BillingTemplate,
	$CONFDATA_SERVER->path_OrgReports,
	$CONFDATA_SERVER->path_EDIData,
	$CONFDATA_SERVER->path_PerSeEDIData,
);
createLink(
	App::Configuration::PATH_WEBSITE . '/paperclaims' => $CONFDATA_SERVER->path_PaperClaims,
);

1;
