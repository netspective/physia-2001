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
	$page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $invoiceId,
			item_type => App::Universal::INVOICEITEMTYPE_VOID,
			#item_subtype => $invItem->{item_subtype} || undef,			#not used
			parent_item_id => $itemId || undef,
			#item_group => $invItem->{item_group} || undef,				#not used
			#item_group_pos => $invItem->{item_group_pos} || undef,		#not used
			hcfa_service_place => defined $invItem->{hcfa_service_place} ? $invItem->{hcfa_service_place} : undef,
			hcfa_service_type => defined $invItem->{hcfa_service_type} ? $invItem->{hcfa_service_type} : undef,
			#other_service_place => $invItem->{other_service_place} || undef,	#not used
			service_begin_date => $invItem->{service_begin_date} || undef,
			service_end_date => $invItem->{service_end_date} || undef,
			flags => $invItem->{flags} || undef,
			emergency => defined $emg ? $emg : undef,
			caption => $invItem->{caption} || undef,
			code => $cptCode || undef,
			code_type => $invItem->{code_type} || undef,
			modifier => $invItem->{modifier} || undef,
			#other_modifier => $invItem->{other_modifier} || undef,		#not used
			unit_cost => $invItem->{unit_cost} || undef,
			quantity => $invItem->{quantity} || undef,
			extended_cost => defined $extCost ? $extCost : undef,
			#writeoff_code => $invItem->{writeoff_code} || undef,		#not used
			#writeoff_amount => $invItem->{writeoff_amount} || undef,	#not used
			rel_diags => $invItem->{rel_diags} || undef,
			#total_adjust =>											#set by trigger
			#balance =>												#set by trigger
			parent_code => $invItem->{parent_code} || undef,
			comments => $invItem->{comments} || undef,
			data_text_a => $invItem->{data_text_a} || undef,				#data_text_a stores the diag code pointers
			#data_text_b => $invItem->{data_text_b} || undef,				#data_text_b indicates item has been voided but is not set here because this is the void copy of the voided item
			data_text_c => $invItem->{data_text_c} || undef,				#data_text_c indicates this procedure comes from an explosion (misc) code
			data_num_a => $invItem->{data_num_a} || undef,				#data_num_a indicates that this item is FFS (null if it isn't)
			data_num_b => $invItem->{data_num_b} || undef,				#data_num_b indicates that this item was suppressed
			#data_num_c => $invItem->{data_num_c} || undef,				#data_num_c is not being used
			#data_flag_a => $invItem->{data_flag_a} || undef,				#data_flag_a is not being used
			#data_flag_b => $invItem->{data_flag_b} || undef,				#data_flag_b is not being used
			#data_flag_c => $invItem->{data_flag_c} || undef,				#data_flag_c is not being used
			#data_date_a => $invItem->{data_date_a} || undef,			#data_date_a is not being used
			#data_date_b => $invItem->{data_date_b} || undef,			#data_date_b is not being used
			#data_date_c => $invItem->{data_date_c} || undef,			#data_date_c is not being used
			_debug => 0
		);

	$page->schemaAction('Invoice_Item', 'update', item_id => $itemId, data_text_b => 'void');	#data_text_b indicates this item has been voided

	addHistoryItem($page, $invoiceId, value_text => "Voided $cptCode", value_date => $todaysDate);
}

1;
