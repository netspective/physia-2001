##############################################################################
package App::InvoiceUtilities;
##############################################################################

use strict;
use Exporter;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Universal;

use Date::Calc qw(:all);
use Date::Manip;

use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(
	addHistoryItem
	voidInvoiceItem
);


sub addHistoryItem
{
	my ($page, $invoiceId, %data) = @_;

	$page->schemaAction('Invoice_History', 'add', parent_id => $invoiceId, %data	);
	return;
}

sub voidInvoiceItem
{
	my ($page, $invoiceId, $itemId) = @_;

	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);

	my $extCost = 0 - $invItem->{extended_cost};
	my $emg = $invItem->{emergency};
	my $cptCode = $invItem->{code};
	my $voidItemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_item_id => $itemId || undef,
			parent_id => $invoiceId,
			item_type => App::Universal::INVOICEITEMTYPE_VOID,
			flags => $invItem->{flags} || undef,
			code => $cptCode || undef,
			code_type => $invItem->{code_type} || undef,
			caption => $invItem->{caption} || undef,
			modifier => $invItem->{modifier} || undef,
			rel_diags => $invItem->{rel_diags} || undef,
			unit_cost => $invItem->{unit_cost} || undef,
			quantity => $invItem->{quantity} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			emergency => defined $emg ? $emg : undef,
			hcfa_service_place => defined $invItem->{hcfa_service_place} ? $invItem->{hcfa_service_place} : undef,
			hcfa_service_type => defined $invItem->{hcfa_service_type} ? $invItem->{hcfa_service_type} : undef,
			service_begin_date => $invItem->{service_begin_date} || undef,
			service_end_date => $invItem->{service_end_date} || undef,
			parent_code => $invItem->{parent_code} || undef,
			data_text_a => $invItem->{data_text_a} || undef,
			data_text_c => $invItem->{data_text_c} || undef,
			data_num_a => $invItem->{data_num_a} || undef,
			_debug => 0
		);

	$page->schemaAction('Invoice_Item', 'update', item_id => $itemId, data_text_b => 'void');

	addHistoryItem($page, $invoiceId, value_text => "Voided $cptCode", value_date => $todaysDate);
}

1;
