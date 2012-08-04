##############################################################################
package CommonUtils;
##############################################################################

use strict;

use Schema::API;
use App::Data::MDL::Module;
use App::Configuration;

use DBI::StatementManager;
use App::Statements::BillingStatement;

use constant NSFDEST_ARRAY => 0;
use constant NSFDEST_FILE  => 1;
use constant NSF_HALLEY    => '0';
use constant NSF_ENVOY     => '1';
use constant NSF_THIN      => '2';

sub connectDB
{
	my $page = new App::Data::MDL::Module();
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

		my $sqlPlusKey = $connectKey;
		$sqlPlusKey =~ s/dbi:Oracle://;

		return ($page, $sqlPlusKey);
	}
	else
	{
		die "DB Schema File and Connect Key are required!";
	}
}

sub findSubmittedClaims
{
	my ($page, $orgInternalId, $providerId) = @_;

	if ($providerId)
	{
		return $STMTMGR_STATEMENTS->getSingleValueList($page, STMTMGRFLAG_NONE,
			'sel_submittedClaims_perOrg_perProvider', $orgInternalId, $providerId);
	}
	else
	{
		return $STMTMGR_STATEMENTS->getSingleValueList($page, STMTMGRFLAG_NONE,
			'sel_submittedClaims_perOrg', $orgInternalId);
	}
}

1;
