##############################################################################
# package Driver;
##############################################################################

use strict;
use Exporter;
use Carp;
use DBI;
use Schema::API;
use Class::Generate qw(class subclass);

class 'Driver' =>
[
	id => '$',
	name => '$',
	dataModel => 'App::DataModel::Collection', # CHANGE THIS TO App::DataModel::Collection instead of $
	context => '$',
	cmdLineArgs => '$',
	verbose => { type => '$', default => '0' },
	attributes => '%',
	errors => '@',
	warnings => '@',	
	
	'&init' => q{ 1; },
	'&open' => q{ &abstract; },
	'&close' => q{ &abstract; },
	'&abstract' => q{ 
		my ($pkg, $file, $line, $method) = caller(1);
		confess("$method is an abstract method");
		},
	'&reportStatus' => q{ if($verbose) { print "\r$_[0]\n" } },
	'&updateStatus' => q{ if($verbose) { print "\r$_[0]" } },	

];

#-----------------------------------------------------------------------------

subclass 'Driver::Input' =>
[
	'&populateDataModel' => q{ &abstract; },
], -parent => 'Driver';


subclass 'Driver::Input::DBI' =>
[
	dbh => '$',
	statements => '%',
	dbiConnectKey => { type => '$', default => '""' },
	dbiUserName => { type => '$', default => '""' },
	dbiPassword => { type => '$', default => '""' },
	
	'&open' => q{ &reportStatus("Opening database '$dbiConnectKey' as '$dbiUserName'"); $dbh = DBI->connect($dbiConnectKey, $dbiUserName, $dbiPassword); },
	'&close' => q{ &reportStatus("Closing database '$dbiConnectKey'"); $dbh->disconnect(); },
	'&execute' => q{ my $sth = $dbh->prepare($statements{shift()}); $sth->execute(@_); return $sth; },
], -parent => 'Driver::Input';

#-----------------------------------------------------------------------------

subclass 'Driver::Output' =>
[
	'&transformDataModel' => q{ &abstract; },
], -parent => 'Driver';

subclass 'Driver::Output::PhysiaDB' =>
[
	context => '$',
	
	'&open' => q{ &reportStatus("Opening PhysiaDB context"); $context = App::External::initializeContext($cmdLineArgs)},
	'&close' => q{ &reportStatus("Closing PhysiaDB context"); },
	'&storeSql'=>q{	$context->{schemaFlags} = Schema::API::SCHEMAAPIFLAG_LOGSQL | Schema::API::SCHEMAAPIFLAG_EMBEDVALUES;},
	'&getSql'=>q{	my $statements = $context->getSqlLog();
			my $statement;
			foreach (@$statements)
			{
				$statement .=@$_[0] . ";\n";			
			}	
			return $statement;
		   },	
	'&schemaAction'=>q{return $context->schemaAction(@_);},
], -parent => 'Driver::Output';

1;
