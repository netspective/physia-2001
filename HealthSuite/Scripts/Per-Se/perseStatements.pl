#!/usr/bin/perl -I.

##############################################################################
package Main;
##############################################################################

use strict;

use Date::Manip;
use IO::File;
use Dumpvalue;
use Getopt::Long;

use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use vars qw($page $sqlPlusKey);

use DBI::StatementManager;
use App::Statements::BillingStatement;
use App::Utilities::Statement;

use CommonUtils;
use OrgList;

my $TODAY = UnixDate('today', '%m/%d/%Y');
my $currencyFormat = "\$%.2f";
my $MESSAGE = "Client Billing Statement Transmitted to Per-Se";

# Config Params
# ----------------------------------------------------------
my $EDIHOST = $ENV{TESTMODE} ? 'gamma' : 'depot.medaphis.com';
my $STATEMENTDIR = '$HOME/statements';
my $STMT_OUTGOINGDIR = $STATEMENTDIR . '/outgoing';
my $SCRIPTDIR = '$HOME/projects/HealthSuite/Scripts/Per-Se';
# ----------------------------------------------------------

#########
# main
#########

my ($db, $orgs, $actions);
GetOptions ('db=s', \$db, 'orgs=s', \$orgs, 'actions=s', \$actions);
$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$db};
my ($page, $sqlPlusKey) = CommonUtils::connectDB();

print "\n-------------------------------\n";
print `date`;
print "-------------------------------\n";

OrgList::buildOrgList($page);

my @orgsToDo = split(/\s*,\s*/, $orgs);
@orgsToDo = sort keys %orgList unless @orgsToDo;
print "Orgs To Do = @orgsToDo \n";

my @whatToDo = split(/\s*,\s*/, $actions);
@whatToDo = ('create') unless @whatToDo;
print "What To Do = @whatToDo \n";

createStatementFiles(@orgsToDo) if grep(/create/, @whatToDo);
transmitStatementFiles() if grep(/transmit/, @whatToDo);
archiveStatementFiles() if grep(/archive/, @whatToDo);
exit;

############
# end main
############

sub createStatementFiles
{
	my (@orgsToDo) = @_;

	for my $orgKey (@orgsToDo)
	{
		my $providerId;
		my $orgInternalId = $orgKey;

		if ($orgKey =~ /(.*?)\..*/)
		{
			$providerId = $orgList{$orgKey}->{providerId};
			$orgInternalId = $1;
		}

		my $outstandingClaims;

		if ($providerId) {
			$outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
				'sel_statementClaims_perOrg_perProvider', $orgInternalId, $providerId);
		} else {
			$outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
				'sel_statementClaims_perOrg', $orgInternalId);
		}

		print "\n";
		unless (@$outstandingClaims) {
			warn "No outstanding claims found for Org $orgKey\n";
			next;
		} else {
			warn @$outstandingClaims . " outstanding claims found for Org $orgKey\n";
		}

		my $statements = App::Utilities::Statement::populateStatementsHash($page, $outstandingClaims, 
			$orgInternalId);

		unless (%{$statements}) {
			warn "No statements to send today for Org $orgKey\n";
			next;
		}

		my $now = UnixDate('today', '%m%d%Y_%H%M');
		my $stamp = UnixDate('today', '%m%d%Y %I:%M %p');

		my $fileName = $orgList{$orgKey}->{billingId} . '_' . $now . '.s01';
		writeStatementsFile($statements, $fileName, $orgInternalId, $stamp);
	}
}

sub writeStatementsFile
{
	my ($statements, $fileName, $orgInternalId, $stamp) = @_;

	my $headerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-25s%-50s%-10s%-7s\n";
	my $dataFormat = "%1s%-4s%-16s%-10s%-16s%-7s%-7s%-7s%-7s%-7s%438s\n";
	my $footerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-50s%-7s%-7s%-7s%-7s%-7s%239s\n";

	my $fileHandle = new IO::File;
	open($fileHandle, ">$fileName") || die "Unable to open output file '$fileName': $! \n";

	my $i = 1;
	for my $key (sort keys %{$statements})
	{
		my $statement = $statements->{$key};
		$statement->{statementId} = $i++;  # Ordinal number for statements in this file

		my $uniqueStatementId = recordStatement($statement, $orgInternalId, $stamp);
		writeRecord($fileHandle, $headerFormat, getHeaderRecord($statement, $uniqueStatementId));

		for my $invoice (@{$statement->{invoices}})
		{
			writeRecord($fileHandle, $dataFormat, getDetailRecord($statement, $invoice));
		}

		writeRecord($fileHandle, $footerFormat, getFooterRecord($statement));

		foreach my $invoice (@{$statement->{invoices}})
		{
			addInvoiceHistory($invoice->{invoiceId}, $MESSAGE, $fileName) if $ENV{RECORD_HISTORY};
		}
	}

	if ($ENV{DEBUGMODE})
	{
		my $dv = new Dumpvalue;
		$dv->dumpValue($statements);
	}
}

sub recordStatement
{
	my ($statement, $orgInternalId, $stamp) = @_;

	if (my $planId = $statement->{paymentPlan})
	{
		$page->schemaAction(0, 'Payment_Plan', 'update',
			plan_id => $planId,
			laststmt_date => $TODAY,
		);
	}
	
	my @invoiceIds = ();
	for (@{$statement->{invoices}})
	{
		push(@invoiceIds, $_->{invoiceId});
	}

	return $page->schemaAction(0, 'Statement', 'add',
		cr_user_id => 'STATEMENTS_CRON',
		cr_org_internal_id => $orgInternalId || undef,
		payto_id => $statement->{payToId},
		billto_id => $statement->{billToId},
		billto_type => $statement->{billPartyType},
		patient_id => $statement->{clientId},
		statement_source => 2,
		transmission_stamp => $stamp,
		transmission_status => 0,
		amount_due => $statement->{amountDue},
		inv_ids => join(',', @invoiceIds),
	);
}

sub writeRecord
{
	my ($fileHandle, $format, @record) = @_;
	print $fileHandle sprintf($format, @record);
}

sub numToStr
{
	my ($number) = @_;

	my $str = sprintf("%08.2f", $number);
	$str =~ s/\.//g;
	return $str;
}

sub getHeaderRecord
{
	my ($statement, $uniqueStatementId) = @_;

	my $suffix = $statement->{paymentPlan} ? 'PP' : $STMTMGR_STATEMENTS->getSingleValue($page, 
		STMTMGRFLAG_CACHE, 'sel_internalStatementId', $uniqueStatementId);

	my @fromAddress = getOrgAddress($statement->{payToId}, 'Mailing');
	my @payToAddress = getOrgAddress($statement->{payToId}, 'Payment');

	return (
		'H',
		$statement->{statementId},
		@fromAddress,
		getSendToAddress($statement->{billToId}, $statement->{billPartyType}),
		@payToAddress,
		$statement->{clientId} . '-' . $suffix,
		$statement->{patientName},
		$TODAY,
		numToStr($statement->{amountDue}),
	);
}

sub getDetailRecord
{
	my ($statement, $invoice) = @_;

	return (
		'D',
		$statement->{statementId},
		$invoice->{invoiceId},
		$invoice->{invoiceDate},
		$invoice->{careProviderId},
		numToStr($invoice->{totalCost}),
		numToStr($invoice->{insuranceReceipts}),
		numToStr($invoice->{totalAdjust}),
		numToStr($invoice->{patientReceipts}),
		numToStr($invoice->{balance}),
		' ',
	);
}

sub getFooterRecord
{
	my ($statement) = @_;

	my $billingPhone = getBillingPhone($statement->{payToId});

	return (
		'F',
		$statement->{statementId},
		getPersonAddress($statement->{billingProviderId}),
		'PAYMENT DUE UPON RECEIPT',
		$billingPhone ? "Please call $billingPhone with any questions."
			: 'PLEASE RETAIN THIS STATEMENT FOR YOUR RECORDS',
		numToStr($statement->{agingCurrent}),
		numToStr($statement->{aging30}),
		numToStr($statement->{aging60}),
		numToStr($statement->{aging90}),
		numToStr($statement->{aging120}),
		' ',
	);
}

sub getBillingPhone
{
	my ($orgInternalId) = @_;

	my $billingPhone = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_NONE,
		'sel_billingPhone', $orgInternalId);

	return $billingPhone;
}

sub getOrgAddress
{
	my ($orgInternalId, $addrName) = @_;
	#die "orgInternalId required.  addrName = $addrName" unless defined $orgInternalId;
	$addrName = 'Mailing' unless defined $addrName && $addrName;

	# First try to get the requested address
	my $org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddressByName',
		$orgInternalId, $addrName);

	# If the requested address isn't defined, fall back to 'Mailing' address (which "should" always be defined)
	if (!$org && $addrName ne 'Mailing')
	{
		warn "WARNING: Org ID '$orgInternalId' doesn't have a $addrName Address defined!\n";
		$org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddressByName',
			$orgInternalId, 'Mailing');
	}

	# If we got an address
	if (defined $org)
	{
		my $primaryName = $org->{name_primary};
		$primaryName =~ s/\s/ /g;
		return ($primaryName || ' ', $org->{line1} || ' ', $org->{line2} || ' ',
			$org->{city} || ' ', $org->{state} || ' ', $org->{zip} || ' ');
	}
	else # D'oh
	{
		warn "BIG-WARNING: Org ID '$orgInternalId' doesn't have a Mailing Address defined!\n";
		return (' ', ' ', ' ', ' ', ' ', ' ');
	}
}

sub getPersonAddress
{
	my ($personId) = @_;

	my $person = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_personAddress', $personId);

	if (defined $person)
	{
		return ($person->{complete_name} || ' ', $person->{line1} || ' ', $person->{line2} || ' ',
			$person->{city} || ' ', $person->{state} || ' ', $person->{zip} || ' ');
	}
	else
	{
		return ($personId, ' ', ' ', ' ', ' ', ' ');
	}
}

sub getSendToAddress
{
	my ($billToId, $billPartyType) = @_;
	return $billPartyType < 2 ? getPersonAddress($billToId) : getOrgAddress($billToId, 'Mailing');
}


sub transmitStatementFiles
{
	my $ftpCommands = qq{
		ftp $EDIHOST << !!!
	};

	my @files = ();

	opendir(DIR, ".") || die "Can't opendir HOME/statements: $!\n";
  for my $file (readdir(DIR))
  {
		next unless $file =~ /\.s01$/;
		push(@files, $file);
		my $pgpFile = $file . '.pgp';
		$ftpCommands .= qq{put $pgpFile $file\n};
	}

	unless (@files)
	{
		print "No '.s01' file found to transmit -- " . `date`;
		return;
	}

	$ftpCommands .= qq{dir
		bye
	!!!
	};

	system(qq{
		cd $STATEMENTDIR
		for f in *s01; do
			\$HOME/bin/encrypt \$f
		done
		$ftpCommands
	});
}

sub archiveStatementFiles
{
	for my $orgKey (keys %orgList)
	{
		my $stem = $orgList{$orgKey}->{billingId};
		my $orgInternalId = $orgKey;
		$orgInternalId =~ s/\..*//g;

		system(qq{
			cd $STATEMENTDIR
			mkdir -p $STMT_OUTGOINGDIR/$orgInternalId

			for f in $stem*s01; do
				if [ -f \$f ]; then
					mv \$f $STMT_OUTGOINGDIR/$orgInternalId
				fi
			done
			for f in $stem*pgp; do
				if [ -f \$f ]; then
					rm -f \$f 
				fi
			done
		});
	}
}

sub addInvoiceHistory
{
	my ($invoiceId, $message, $fileName) = @_;

	return $page->schemaAction(0, 'Invoice_History', 'add',
		parent_id => $invoiceId,
		cr_user_id => 'STATEMENTS_CRON',
		value_text => $message,
		value_textB => $fileName,
		value_date => $TODAY,
	);
}