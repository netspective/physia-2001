#!/usr/bin/perl -I.

##############################################################################
package InvoiceObject;
##############################################################################

sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}

1;

use strict;

use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use vars qw($page $sqlPlusKey);

use DBI::StatementManager;
use App::Statements::BillingStatement;

use Date::Manip;
use IO::File;

use Dumpvalue;

my $TODAY = UnixDate('today', '%m/%d/%Y');
my $currencyFormat = "\$%.2f";

#########
# main
#########

my $forceConfig = shift || die "\nUsage: $0 <db-connect-key>\n";
my $daysBack = shift;
$daysBack = defined $daysBack ? $daysBack : 30;

$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$forceConfig};
connectDB();

my $connectKey = $CONFDATA_SERVER->db_ConnectKey() =~ /(.*?)\/(.*?)\@(.*)/;
my ($userName, $password, $connectString) = ($1, $2, $3);

my $outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 
	'sel_outstandingClaims', $daysBack);
		
my $statements = populateStatementsHash($outstandingClaims);
writeStatementsFile($statements);

exit;

############
# end main
############

sub writeStatementsFile
{
	my ($statements) = @_;
	
	my $now = UnixDate('today', '%m%d%Y_%H%M');
	my $fileName = 'phy169_' . $now . '.s01';
	
	my $headerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-16s%-50s%-10s%-7s\n";
	my $dataFormat = "%1s%-4s%-16s%-10s%-16s%-7s%-7s%-7s%-7s%-7s%429s\n";
	my $footerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-50s%-7s%-7s%-7s%-7s%-7s%230s\n";
	
	my $fileHandle = new IO::File;
	open($fileHandle, ">$fileName") || die "Unable to open output file '$fileName': $! \n";
	
	my $i = 1;
	for my $key (sort keys %{$statements})
	{
		my $statement = $statements->{$key};
		
		$statement->{statementId} = $i++;
	
		writeRecord($fileHandle, $headerFormat, getHeaderRecord($statement));
		
		for my $invoice (@{$statement->{invoices}})
		{
			writeRecord($fileHandle, $dataFormat, getDetailRecord($statement, $invoice));
		}
		
		writeRecord($fileHandle, $footerFormat, getFooterRecord($statement));
	}
	
	if ($ENV{DEBUGMODE})
	{
		my $dv = new Dumpvalue;
		$dv->dumpValue($statements);
	}
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
	my ($statement) = @_;

	my @payToAddress = getOrgAddress($statement->{payToId});
	
	return (
		'H',
		$statement->{statementId},
		@payToAddress,
		getSendToAddress($statement->{billToId}, $statement->{billPartyType}),
		@payToAddress,
		$statement->{clientId},
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
	my ($orgInternalId) = @_;
	
	my $org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddress', $orgInternalId);
	if (defined $org)
	{
		my $primaryName = $org->{name_primary};
		$primaryName =~ s/\s/ /g;
		return ($primaryName || ' ', $org->{line1} || ' ', $org->{line2} || ' ', 
			$org->{city} || ' ', $org->{state} || ' ', $org->{zip} || ' ');
	}
	else
	{
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
		return (' ', ' ', ' ', ' ', ' ', ' ');
	}
}

sub getSendToAddress
{
	my ($billToId, $billPartyType) = @_;
	return $billPartyType < 2 ? getPersonAddress($billToId) : getOrgAddress($billToId);
}

sub populateStatementsHash
{
	my ($claims) = @_;
	my %statements = ();
	
	for (@{$claims})
	{
		my $key = $_->{billing_facility_id} . '_' . $_->{bill_to_id} . '_' . $_->{client_id};
		
		$statements{$key}->{billToId} = $_->{bill_to_id};
		$statements{$key}->{payToId} = $_->{billing_facility_id};
		$statements{$key}->{clientId} = $_->{client_id};
		
		$statements{$key}->{billingProviderId} = $_->{provider_id};
		$statements{$key}->{careProviderId} = $_->{care_provider_id};
		
		$statements{$key}->{billPartyType} = $_->{bill_party_type};
		$statements{$key}->{patientName} = $_->{patient_name};
		
		my $invObject = new InvoiceObject(
			invoiceId => $_->{invoice_id},
			invoiceDate => $_->{invoice_date},
			careProviderId => $_->{care_provider_id},
			totalCost => $_->{total_cost},
			totalAdjust => $_->{total_adjust} < 0 ? $_->{total_adjust} * (-1) : $_->{total_adjust},
			insuranceReceipts => $_->{insurance_receipts} < 0 ? $_->{insurance_receipts} * (-1) : $_->{insurance_receipts},
			patientReceipts => $_->{patient_receipts} < 0 ? $_->{patient_receipts} * (-1) : $_->{patient_receipts},
			balance => $_->{balance},
		);
		
		push(@{$statements{$key}->{invoices}}, $invObject);
	}
	
	for my $key (sort keys %statements)
	{
		my $clientId = $statements{$key}->{clientId};
		my $billToId = $statements{$key}->{billToId};
		
		$statements{$key}->{agingCurrent} = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_CACHE, 
			'sel_aging', $clientId, 30, 0, $billToId);
		
		$statements{$key}->{aging30} = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_CACHE, 
			'sel_aging', $clientId, 60, 30, $billToId);

		$statements{$key}->{aging60} = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_CACHE,
			'sel_aging', $clientId, 90, 60, $billToId);

		$statements{$key}->{aging90} = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_CACHE,
			'sel_aging', $clientId, 120, 90, $billToId);

		$statements{$key}->{aging120} = $STMTMGR_STATEMENTS->getSingleValue($page, STMTMGRFLAG_CACHE,
			'sel_aging', $clientId, 10950, 120, $billToId);
			
		$statements{$key}->{amountDue} = $statements{$key}->{agingCurrent} + $statements{$key}->{aging30} +
			$statements{$key}->{aging60} + $statements{$key}->{aging90} + $statements{$key}->{aging120};
	}
	
	return \%statements;
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
