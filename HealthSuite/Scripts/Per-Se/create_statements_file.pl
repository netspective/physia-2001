#!/usr/bin/perl -I.

use strict;

use Schema::API;
use App::Data::MDL::Module;
use App::Universal;
use App::Configuration;

use vars qw($page $sqlPlusKey);

use DBI::StatementManager;
use App::Statements::Scheduling;

use App::Billing::Claims;
use App::Billing::Input::DBI;
use Date::Manip;

my $DATEFORMAT = 'mm/dd/yyyy';

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

my $outstandingClaims = findOutStandingClaims();

unless (defined $outstandingClaims)
{
	print "\nNo claim found to meet search criteria.  Exit with nothing to do.\n";
	exit;
}

my $claimList = new App::Billing::Claims;
my $input = new App::Billing::Input::DBI;

$input->populateClaims($claimList,
	UID => $userName,
	PWD => $password,
	connectStr => $connectString,
	invoiceIds => $outstandingClaims,
) || die "Unable to call populateClaims routine: $!\n";

my $records = processClaimList($claimList);
writeFile($records);

exit;

############
# end main
############

sub writeFile
{
	my ($records) = @_;
	
	my $now = UnixDate('today', '%m%d%Y_%H%M');
	my $fileName = 'phy169_' . $now . '.s01';
	
	open(OUTPUT, ">$fileName") || die "Unable to open output file '$fileName': $! \n";
	
	for my $record (@{$records})
	{
		my $numFields = @{$record} -1;
		for my $i (0..$numFields)
		{
			print OUTPUT '"' . $record->[$i] . '"';
			print OUTPUT ',' if $i < $numFields;
		}
		print OUTPUT "\n";
	}
}

sub processClaimList
{
	my ($claimList) = @_;

	my $invoiceInfoStmt = qq{
		select client_id, total_cost, to_char(invoice_date, '$DATEFORMAT') as invoice_date,
			nvl(total_adjust, 0) as total_adjust, balance, bill_party_type, bill_to_id, 
			provider_id, care_provider_id
		from Transaction, Invoice_Billing, Invoice
		where Invoice.invoice_id = ?
			and Invoice_Billing.bill_id = Invoice.billing_id
			and Transaction.trans_id = Invoice.main_transaction
	};
	
	my $insReceiptStmt = qq{
		select nvl(sum(adjustment_amount), 0) from Invoice_Item_Adjust
		where parent_id in (select item_id from Invoice_Item where parent_id = ?)
			and adjustment_type = 0
			and payer_type <> 0
	};
	
	my $patReceiptStmt = qq{
		select nvl(sum(adjustment_amount), 0) from Invoice_Item_Adjust
		where parent_id in (select item_id from Invoice_Item where parent_id = ?)
			and adjustment_type = 0
			and payer_type = 0
	};
	
	my $agingStmt = qq{
		select nvl(sum(balance), 0) 
		from Invoice_Billing, Invoice
		where client_id = ?
			and invoice_date >= trunc(sysdate) - ?
			and invoice_date <= trunc(sysdate) - ?
			and invoice_status > 3
			and invoice_status < 15
			and bill_id = billing_id
			and bill_party_type != 3
	};

	my $today = UnixDate('today', '%m/%d/%Y');
	my @records = ();

	for my $claim (@{$claimList->getClaim()} )
	{
		my $invoiceId = $claim->{id};

		my $invoice = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_DYNAMICSQL,
			$invoiceInfoStmt, $invoiceId);

		my ($sendToName, $sendToAddr1, $sendToAddr2, $sendToAddrCity, $sendToAddrState, $sendToAddrZip)
			= getSendToAddress($invoice);

		my $renderingProvider = $claim->{renderingProvider};
		my $renderingProviderAddress = $renderingProvider->{address};

		my $payToOrg = $claim->{payToOrganization};
		my $payToOrgAddress = $payToOrg->{address};

		my $patient = $claim->{careReceiver};
		my $patientAddress = $patient->{address};
		
		my $insuranceReceipts = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$insReceiptStmt, $invoiceId);
		my $patientReceipts = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$patReceiptStmt, $invoiceId);
		
		my $agingCurrent = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$agingStmt, $invoice->{client_id}, 30, 0);
		
		my $aging30 = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$agingStmt, $invoice->{client_id}, 60, 30);
		
		my $aging60 = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$agingStmt, $invoice->{client_id}, 90, 60);
		
		my $aging90 = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$agingStmt, $invoice->{client_id}, 120, 90);
		
		my $aging120 = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_DYNAMICSQL,
			$agingStmt, $invoice->{client_id}, 10950, 120);

		my @record = (
			$invoiceId,
			getName($renderingProvider), $renderingProvider->{name},
			$renderingProviderAddress->getAddress1(),
			$renderingProviderAddress->getAddress2(),
			$renderingProviderAddress->getCity(),
			$renderingProviderAddress->getState(),
			$renderingProviderAddress->getZipCode(),

			$sendToName,
			$sendToAddr1,
			$sendToAddr2,
			$sendToAddrCity,
			$sendToAddrState,
			$sendToAddrZip,

			$payToOrg->{name},
			$payToOrgAddress->getAddress1(),
			$payToOrgAddress->getAddress2(),
			$payToOrgAddress->getCity(),
			$payToOrgAddress->getState(),
			$payToOrgAddress->getZipCode(),

			'Y',
			$invoice->{client_id},
			getName($patient),
			$today,

			'RETURN SERVICE REQUESTED',
			
			$invoice->{invoice_date},
			$invoice->{care_provider_id} || $invoice->{provider_id},
			$invoice->{total_cost},
			$insuranceReceipts,
			$invoice->{total_adjust},
			$patientReceipts,
			$invoice->{balance},
			
			undef,
			'PAYMENT DUE UPON RECEIPT',

			getName($renderingProvider),
			$renderingProviderAddress->getAddress1(),
			$renderingProviderAddress->getAddress2(),
			$renderingProviderAddress->getCity(),
			$renderingProviderAddress->getState(),
			$renderingProviderAddress->getZipCode(),
			undef,
			
			$agingCurrent,
			$aging30,
			$aging60,
			$aging90,
			$aging120,
			'PLEASE RETAIN THIS STATEMENT FOR YOUR RECORDS'
		);
		
		push(@records, \@record);
	}
	
	return \@records;
}

sub getSendToAddress
{
	my ($invoice) = @_;

	if ($invoice->{bill_party_type} < 2)
	{
		my $person = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_DYNAMICSQL,
			q{select complete_name, line1, line2, city, State, zip
				from Person_Address, Person
				where person_id = ?
					and Person_Address.parent_id = Person.person_id
			},
			$invoice->{bill_to_id}
		);

		return ($person->{complete_name}, $person->{line1}, $person->{line2}, $person->{city},
			$person->{state}, $person->{zip});
	}
	else
	{
		my $org = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_DYNAMICSQL,
			q{select name_primary, line1, line2, city, state, zip
				from Org_Address, Org
				where org_internal_id = ?
					and Org_Address.parent_id = Org.org_internal_id
			}, $invoice->{bill_to_id}
		);

		return ($org->{name_primary}, $org->{line1}, $org->{line2}, $org->{city}, $org->{state},
			$org->{zip});
	}
}

sub getName
{
	my ($entity) = @_;

	my $firstName = $entity->getFirstName();
	my $middleName = $entity->getMiddleInitial() ? "@{[$entity->getMiddleInitial()]}." : undef;
	my $lastName = $entity->getLastName();

	return $middleName ? "$firstName $middleName $lastName" : "$firstName $lastName";
}

sub findOutStandingClaims
{
	return $STMTMGR_SCHEDULING->getSingleValueList($page, STMTMGRFLAG_DYNAMICSQL,
		qq{
			SELECT
			 invoice.invoice_id
			FROM
			 Invoice_Billing,
			 Invoice
			WHERE
			 invoice.invoice_status > 3
			 AND invoice.invoice_status < 15
			 AND invoice.balance > 0
			 AND invoice_billing.bill_id = invoice.billing_id
			 AND invoice_billing.bill_party_type != 3
			 AND invoice_billing.bill_to_id IS NOT NULL
			 AND invoice.invoice_date <= trunc(sysdate) - ?
			ORDER BY
			invoice.invoice_id
		}, $daysBack
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
