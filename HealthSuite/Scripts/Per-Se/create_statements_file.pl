#!/usr/bin/perl -w -I.

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

use CommonUtils;
use OrgList;

my $TODAY = UnixDate('today', '%m/%d/%Y');
my $currencyFormat = "\$%.2f";
my $MESSAGE = "Client Billing Statement Transmitted to Per-Se";

#########
# main
#########

my $forceConfig = shift || die "\nUsage: $0 <db-connect-key>\n";
my $daysBack = shift;
$daysBack = defined $daysBack ? $daysBack : 30;

$CONFDATA_SERVER = $App::Configuration::AVAIL_CONFIGS{$forceConfig};
my ($page, $sqlPlusKey) = connectDB();

my $outstandingClaims = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
	'sel_outstandingClaims', $daysBack);

unless (@$outstandingClaims)
{
	warn "No outstanding claims found\n";
	exit;
}
else
{
	warn @$outstandingClaims . " outstanding claims found\n";
}

my $statements = populateStatementsHash($outstandingClaims);

unless (%{$statements})
{
	warn "No statements to send today\n";
	exit;
}

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

	my $headerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-30s%-30s%-20s%-2s%-9s%-25s%-50s%-10s%-7s\n";
	my $dataFormat = "%1s%-4s%-16s%-10s%-16s%-7s%-7s%-7s%-7s%-7s%438s\n";
	my $footerFormat = "%1s%-4s%-50s%-30s%-30s%-20s%-2s%-9s%-50s%-50s%-7s%-7s%-7s%-7s%-7s%239s\n";

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

		foreach my $invoice (@{$statement->{invoices}})
		{
			addInvoiceHistory($invoice->{invoiceId}, $MESSAGE, $fileName) unless $ENV{NO_HISTORY};
		}
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

	my @fromAddress = getOrgAddress($statement->{payToId}, 'Mailing');
	my @payToAddress = getOrgAddress($statement->{payToId}, 'Payment');

	return (
		'H',
		$statement->{statementId},
		@fromAddress,
		getSendToAddress($statement->{billToId}, $statement->{billPartyType}),
		@payToAddress,
		$statement->{clientId} . '-' . $statement->{statementId} * 1000000,
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
	die "orgInternalId required" unless defined $orgInternalId;
	$addrName = 'Mailing' unless defined $addrName && $addrName;

	# First try to get the requested address
	my $org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddressByName', $orgInternalId, $addrName);

	# If the requested address isn't defined, fall back to 'Mailing' address (which "should" always be defined)
	if (!$org && $addrName ne 'Mailing')
	{
		warn "WARNING: Org ID '$orgInternalId' doesn't have a $addrName Address defined!\n";
		$org = $STMTMGR_STATEMENTS->getRowAsHash($page, STMTMGRFLAG_CACHE, 'sel_orgAddressByName', $orgInternalId, 'Mailing');
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
		return (' ', ' ', ' ', ' ', ' ', ' ');
	}
}

sub getSendToAddress
{
	my ($billToId, $billPartyType) = @_;
	return $billPartyType < 2 ? getPersonAddress($billToId) : getOrgAddress($billToId, 'Mailing');
}

sub populateStatementsHash
{
	my ($claims) = @_;
	my %statements = ();
	my $billingEvents;

	unless ($ENV{OVERRIDE_BILLING_CYCLE} eq 'YES')
	{
		# Get a list of billingEvents for this day of the month
		my $mday = (localtime)[3];
		$billingEvents = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 
			'sel_daysBillingEvents', $mday);

		# Nothing to do if there are no billing events for today
		unless (@$billingEvents)
		{
			warn "ABORTING: No billing events found for this day of the month '$mday'\n";
			return \%statements;
		}
	}

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
		$statements{$key}->{patientLastName} = $_->{patient_name_last};

		unless (defined $_->{invoice_id} && defined $_->{invoice_date} && $_->{care_provider_id})
		{
			warn "Data not valid";
			next;
		}
		my $totalCost = defined $_->{total_cost} ? $_->{total_cost} : 0;
		my $balance = defined $_->{balance} ? $_->{balance} : 0;
		my $patientReceipts = defined $_->{patient_receipts} ? $_->{patient_receipts} : 0;
		my $insuranceReceipts = defined $_->{insurance_receipts} ? $_->{insurance_receipts} : 0;
		my $totalAdjust = defined $_->{total_adjust} ? $_->{total_adjust} : 0;

		my $invObject = new InvoiceObject(
			invoiceId => $_->{invoice_id},
			invoiceDate => $_->{invoice_date},
			careProviderId => $_->{care_provider_id},
			totalCost => $totalCost,
			totalAdjust => $totalAdjust < 0 ? $totalAdjust * (-1) : $totalAdjust,
			insuranceReceipts => $insuranceReceipts < 0 ? $insuranceReceipts * (-1) : $insuranceReceipts,
			patientReceipts => $patientReceipts < 0 ? $patientReceipts * (-1) : $patientReceipts,
			balance => $balance,
		);

		push(@{$statements{$key}->{invoices}}, $invObject);
	}

	my @keys = sort keys %statements;

	for my $key (@keys)
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

		unless (sendStatementToday($statements{$key}, $billingEvents))
		{
			# This statement doesn't get sent today
			delete $statements{$key};
			next;
		}
	}

	return \%statements;
}

sub sendStatementToday
{
	my ($stmt, $events) = @_;

	return 1 if $ENV{OVERRIDE_BILLING_CYCLE} eq 'YES';
	
	foreach my $event (@$events)
	{
		# Check org_internal_id of billing org
		next unless $stmt->{payToId} == $event->{parent_id};

		# Check name
		next if uc(substr($stmt->{patientLastName}, 0, 1)) lt $event->{name_begin};
		next if uc(substr($stmt->{patientLastName}, 0, 1)) gt $event->{name_end};

		# Check balance
		next if $event->{balance_condition} > 0 && $stmt->{amountDue} < $event->{balance_criteria};
		next if $event->{balance_condition} < 0 && $stmt->{amountDue} > $event->{balance_criteria};
		next if $event->{balance_condition} == 0 && $stmt->{amountDue} != $event->{balance_criteria};

		# We have a winner
		warn "Sending statement for billing org '$stmt->{payToId}' last name '$stmt->{patientLastName}' balance '\$$stmt->{amountDue}'\n";
		return 1;
	}

	# Bummer dude, no billing event matches this statement
	warn "No billing event rule matched billing org '$stmt->{payToId}' last name '$stmt->{patientLastName}' balance '\$$stmt->{amountDue}'\n";
	return 0;
}

sub addInvoiceHistory
{
	my ($invoiceId, $message, $fileName) = @_;
	
	return $page->schemaAction(0, 'Invoice_History', 'add',
		parent_id => $invoiceId,
		cr_user_id => 'EDI_PERSE',
		value_text => $message,
		value_textB => $fileName,
		value_date => $TODAY,
	);
}
