##############################################################################
package InvoiceObject;
##############################################################################

sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}

1;

##############################################################################
package App::Utilities::Statement;
##############################################################################

use strict;

use DBI::StatementManager;
use App::Statements::BillingStatement;
use App::Statements::Invoice;


sub populateStatementsHash
{
	my ($page, $claims, $orgInternalId, $mday) = @_;
	my %statements = ();
	my $billingEvents;

	unless ($ENV{OVERRIDE_BILLING_CYCLE} eq 'YES')
	{
		# Get a list of billingEvents for this day of the month
		$mday ||= (localtime)[3];
		$billingEvents = $STMTMGR_STATEMENTS->getRowsAsHashList($page, STMTMGRFLAG_CACHE,
			'sel_daysBillingEvents', $orgInternalId, $mday);

		# Nothing to do if there are no billing events for today
		unless (@$billingEvents)
		{
			#warn "ABORTING: No billing events found for this day of the month '$mday'\n";
			return \%statements;
		}
	}

	for (@{$claims})
	{
		unless($_->{billing_facility_id})
		{
			print qq{Skipping Claim $_->{invoice_id}: Billing Facility ID '$_->{billing_facility_id}' is Invalid.\n};
			next;
		}
		my $key = $_->{statement_type} . '_' . $_->{billing_facility_id} . '_' .
			$_->{bill_to_id} . '_' . $_->{client_id};

		$statements{$key}->{billToId} = $_->{bill_to_id};
		$statements{$key}->{payToId} = $_->{billing_facility_id};
		$statements{$key}->{clientId} = $_->{client_id};

		$statements{$key}->{billingProviderId} = $_->{provider_id};
		$statements{$key}->{careProviderId} = $_->{care_provider_id};

		$statements{$key}->{billPartyType} = $_->{bill_party_type};
		$statements{$key}->{patientName} = $_->{patient_name};
		$statements{$key}->{patientLastName} = $_->{patient_name_last};
		$statements{$key}->{billingOrgId} = $_->{billing_org_id};

		my $balance = defined $_->{balance} ? $_->{balance} : 0;
		$statements{$key}->{balance} += $balance;

		if ($_->{invoice_id} < 0) # This is a Payment Plan
		{
			$statements{$key}->{paymentPlan} = - $_->{invoice_id};
			$statements{$key}->{amountDue} = $_->{total_cost};
			$_->{total_cost} = 0;
			$_->{invoice_id} = 'PP' . -($_->{invoice_id});
		}
		else
		{
			$statements{$key}->{amountDue} = $statements{$key}->{balance};
		}

		my $totalCost = defined $_->{total_cost} ? $_->{total_cost} : 0;
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
		
		changeInvoiceStatus($page, $_->{invoice_id}, App::Universal::INVOICESTATUS_AWAITCLIENTPAYMENT)
			unless ($statements{$key}->{paymentPlan} || $ENV{HTTP_USER_AGENT});
	}

	my @keys = sort keys %statements;

	for my $key (@keys)
	{
		unless (sendStatementToday($statements{$key}, $billingEvents, $orgInternalId))
		{
			# This statement doesn't get sent today
			delete $statements{$key};
			next;
		}

		unless ($statements{$key}->{paymentPlan} || $ENV{HTTP_USER_AGENT})
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
	}

	return \%statements;
}

sub sendStatementToday
{
	my ($stmt, $events, $orgInternalId) = @_;

	return 1 if $ENV{OVERRIDE_BILLING_CYCLE} eq 'YES';

	foreach my $event (@$events)
	{
		# Check org_internal_id of billing org
		next unless $orgInternalId == $event->{parent_id};

		# Check name
		next if uc(substr($stmt->{patientLastName}, 0, 1)) lt $event->{name_begin};
		next if uc(substr($stmt->{patientLastName}, 0, 1)) gt $event->{name_end};

		# Check balance
		next if $event->{balance_condition} > 0 && $stmt->{amountDue} < $event->{balance_criteria};
		next if $event->{balance_condition} < 0 && $stmt->{amountDue} > $event->{balance_criteria};
		next if $event->{balance_condition} == 0 && $stmt->{amountDue} != $event->{balance_criteria};

		# We have a winner
		#warn "Sending statement for billing org '$stmt->{payToId}' last name '$stmt->{patientLastName}' balance '\$$stmt->{amountDue}'\n";
		return 1;
	}

	# Bummer dude, no billing event matches this statement
	#warn "No billing event rule matched billing org '$stmt->{payToId}' last name '$stmt->{patientLastName}' balance '\$$stmt->{amountDue}'\n";
	return 0;
}

sub changeInvoiceStatus
{
	my ($page, $invoiceId, $status) = @_;

	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', 
		$invoiceId);
	
	return if $invoiceInfo->{invoice_status} == App::Universal::INVOICESTATUS_VOID
		|| $invoiceInfo->{invoice_status} == App::Universal::INVOICESTATUS_CLOSED;
	
	return $page->schemaAction(0, 'Invoice', 'update', 
		invoice_id => $invoiceId,
		invoice_status => $status,
	);
}

1;
