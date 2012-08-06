#!/usr/bin/perl -I.

use strict;

use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use vars qw($page $sqlPlusKey);

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Page::Utilities;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use App::Billing::Output::PDF;


use Date::Manip;

#########
# main
#########

my $forceConfig = shift || die "\nUsage: $0 <db-connect-key>\n";
my $drawBG = shift || 0;

$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$forceConfig};
connectDB();

my $connectKey = $CONFDATA_SERVER->db_ConnectKey() =~ /(.*?)\/(.*?)\@(.*)/;
my ($userName, $password, $connectString) = ($1, $2, $3);

my $orgs = \@ARGV;
$orgs = findDistinctOrgs() unless scalar @{$orgs};

for my $orgInternalId (@{$orgs})
{
	my $claims = App::Page::Utilities::findPaperClaims($page, $orgInternalId);

	unless (defined $claims)
	{
		print "\nNo claim found for Org $orgInternalId.\n";
		next;
	}
	
	App::Page::Utilities::createBatchPaperClaims($page, $claims, $orgInternalId, $drawBG);
	App::Page::Utilities::updatePaperClaimsPrinted($page, $claims);
}

exit;

############
# end main
############

sub findDistinctOrgs
{
	return $STMTMGR_INVOICE->getSingleValueList($page, STMTMGRFLAG_DYNAMICSQL, 
		qq{
			SELECT distinct owner_id from Invoice 
			where invoice_status = @{[ App::Universal::INVOICESTATUS_SUBMITTED ]} 
				and owner_type = @{[ App::Universal::ENTITYTYPE_ORG ]}
		}
	);
}

sub connectDB
{
	$page = new App::Data::MDL::Module();
	$page->{schema} = undef;
	$page->{schemaFlags} = SCHEMAAPIFLAG_LOGSQL | SCHEMAAPIFLAG_EXECSQL;
	if($CONFDATA_SERVER->db_ConnectKey() && $CONFDATA_SERVER->file_SchemaDefn())
	{
		my $schemaFile = $CONFDATA_SERVER->file_SchemaDefn();
		print STDOUT "Loading schema from $schemaFile\n";
		$page->{schema} = new Schema::API(xmlFile => $schemaFile);

		my $connectKey = $CONFDATA_SERVER->db_ConnectKey();
		print STDOUT "Connecting to $connectKey\n";

		$page->{schema}->connectDB($connectKey);
		$page->{db} = $page->{schema}->{dbh};

		$sqlPlusKey = $connectKey;
		$sqlPlusKey =~ s/dbi:Oracle://;
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
}
