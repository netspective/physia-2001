##############################################################################
package App::Utilities::Invoice;
##############################################################################

use strict;
use Exporter;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Transaction;
use App::Statements::Insurance;
use App::Statements::Scheduling;
use App::Universal;

use Date::Calc qw(:all);
use Date::Manip;

use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(
	addHistoryItem
	addBatchPaymentAttr
	changeInvoiceStatus
	placeOnHold
	voidInvoice
	voidInvoiceItem
	reopenInsuranceClaim
	deleteHmoCapWriteoff
	checkEventStatus
	handleDataStorage
);


sub addHistoryItem
{
	my ($page, $invoiceId, %data) = @_;
	return unless defined $invoiceId;

	$data{value_date} = UnixDate('today', $page->defaultUnixDateFormat()) unless exists $data{value_date};
	$page->schemaAction('Invoice_History', 'add', parent_id => $invoiceId, %data	);
	return;
}

sub addBatchPaymentAttr
{
	my ($page, $invoiceId, %data) = @_;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	$page->schemaAction('Invoice_Attribute', 'add', parent_id => $invoiceId, item_name => 'Invoice/Payment/Batch ID', 
		value_type => defined $textValueType ? $textValueType : undef, %data);

	return;
}

sub changeInvoiceStatus
{
	my ($page, $invoiceId, $status) = @_;

	$page->schemaAction('Invoice', 'update', invoice_id => $invoiceId, invoice_status => defined $status ? $status : undef, _debug => 0);
	return;
}

sub placeOnHold
{
	my ($page, $invoiceId, $beenTransferred) = @_;

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	#Delete auto writeoffs only if the claim was just submitted then placed on hold. Do not want to delete for other statuses passed submitted 
	#because at that point resubmission or submission to next payer may take place (so you don't want to change writeoff data).
	if($invoice->{invoice_status} == App::Universal::INVOICESTATUS_SUBMITTED)
	{
		deleteHmoCapWriteoff($page, $invoiceId);
	}

	#this attribute tells if a claim has been transferred or not. this is used in page/invoice to determine which functions/choose actions, etc. are allowed.
	my $transferred = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Transferred');
	my $transCommand = $transferred->{item_id} ? 'update' : 'add';
	unless($transferred->{value_int} == 1)
	{
		$page->schemaAction(
			'Invoice_Attribute', $transCommand,
			item_id => $transferred->{item_id} || undef,
			parent_id => $invoiceId,
			item_name => 'Invoice/Transferred',
			value_type => App::Universal::ATTRTYPE_BOOLEAN,
			value_int => $beenTransferred || undef,
			_debug => 0
		);
	}

	#update claim status and remove data storage flag.
	$page->schemaAction('Invoice', 'update', invoice_id => $invoiceId, invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
		flags => $invoice->{flags} &~ App::Universal::INVOICEFLAG_DATASTOREATTR,);

	addHistoryItem($page, $invoiceId, value_text => 'On Hold', value_textB => $page->field('reason') || undef);
}

sub voidInvoice
{
	my ($page, $invoiceId) = @_;
	return unless defined $invoiceId;

	my $sessUser = $page->session('user_id');

	my $lineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $item (@{$lineItems})
	{
		my $itemType = $item->{item_type};
		next if $itemType == App::Universal::INVOICEITEMTYPE_ADJUST;
		next if $itemType == App::Universal::INVOICEITEMTYPE_VOID;
		next if $item->{data_text_b} eq 'void';

		voidInvoiceItem($page, $item->{item_id});
	}

	changeInvoiceStatus($page, $invoiceId, App::Universal::INVOICESTATUS_VOID);


	#CREATE NEW VOID TRANSACTION FOR VOIDED CLAIM
	my $transType = App::Universal::TRANSTYPEACTION_VOID;
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	$page->schemaAction(
		'Transaction', 'add',
		parent_trans_id => $page->field('trans_id') || undef,
		parent_event_id => $page->field('parent_event_id') || undef,
		trans_type => defined $transType ? $transType : undef,
		trans_status => defined $transStatus ? $transStatus : undef,
		trans_status_reason => "Claim $invoiceId has been voided by $sessUser",
		_debug => 0
	);

	addHistoryItem($page, $invoiceId, value_text => 'Voided claim');
}

sub voidInvoiceItem
{
	my ($page, $itemId) = @_;

	my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);
	my $invoiceId = $invItem->{parent_id};

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

	addHistoryItem($page, $invoiceId, value_text => "Voided $cptCode");
}

sub reopenInsuranceClaim
{
	my ($page, $invoiceId) = @_;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	#select parent invoices (ex. secondary, tertiary) where $invoiceId is the child (ex. primary)
	my $parentInvoices = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selParentInvoices', $invoiceId);
	my @parentUrls;
	my $parentStatus;
	my @parentInvoiceIds = ($parentInvoices->{parent1}, $parentInvoices->{parent2}, $parentInvoices->{parent3});
	for (my $line = 1; $line <= 3; $line++)
	{
		my $parentId = $parentInvoiceIds[$line-1];
		next unless defined $parentId;

		#next if one of the parents is already voided
		$parentStatus = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceStatus', $parentId);
		next if $parentStatus == App::Universal::INVOICESTATUS_VOID;

		#reverse balance transfer if parent has one
		reverseBalanceTransfer($page, $parentId);

		#reverse payments rcvd from child
		my $payRcvdFromChild = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTransferredPaymentsFromChild', $parentId);
		my $adjCount = scalar(@{$payRcvdFromChild});
		my $itemId = $page->schemaAction('Invoice_Item', 'add', parent_id => $parentId, item_type => App::Universal::INVOICEITEMTYPE_ADJUST, _debug => 0) if $adjCount > 0;
		my $adjItemId;
		my $batchInfo;
		foreach my $payment (@{$payRcvdFromChild})
		{
			$adjItemId = $page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				adjustment_type => App::Universal::ADJUSTMENTTYPE_REVERSE_PAYMENT,
				adjustment_amount => $payment->{net_adjust},
				parent_id => $itemId,
				pay_date => $todaysDate,
				data_num_a => defined $payment->{data_num_a} ? $payment->{data_num_a} : undef,
				_debug => 0
			);

			$batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selBatchPaymentAttr', $parentId, $payment->{adjustment_id});
			addBatchPaymentAttr($page, $parentId, value_text => $batchInfo->{value_text} || undef, value_int => $adjItemId, value_date => $todaysDate);
		}

		addHistoryItem($page, $parentId, value_text => "Claim <A HREF='/invoice/$invoiceId/summary'>$invoiceId</A> was reopened.");

		#void parent
		voidInvoice($page, $parentId);

		push(@parentUrls, "<A HREF='/invoice/$parentId/summary'>$parentId</A>");
	}


	#reopen old invoice, add adjustment invoice item and adjustment to reverse the transfer to next payer (which was the carry over of the balance), add batch attr for adj, add history items
	placeOnHold($page, $invoiceId, 1);


	#reverse the transfer adjustment
	reverseBalanceTransfer($page, $invoiceId);


	#add history indicating child was reopened and which parent claims were voided
	@parentUrls = join(', ', @parentUrls);
	addHistoryItem($page, $invoiceId, value_text => "Claim reopened. Claim(s) @parentUrls were voided.");
}

sub reverseBalanceTransfer
{
	my ($page, $invoiceId) = @_;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());

	my $transferCount = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selNextPayerTransferCount', $invoiceId);
	my $reverseTransferCount = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selReverseNextPayerTransferCount', $invoiceId);
	return if $transferCount == $reverseTransferCount;

	my $transferToPayerAdj = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selLatestNextPayerTransferByInvoiceId', $invoiceId);
	return unless $transferToPayerAdj->{adjustment_id};

	my $itemId = $page->schemaAction('Invoice_Item', 'add', parent_id => $invoiceId, item_type => App::Universal::INVOICEITEMTYPE_ADJUST, _debug => 0);
	my $adjItemId = $page->schemaAction(
		'Invoice_Item_Adjust', 'add',
		adjustment_type => App::Universal::ADJUSTMENTTYPE_REVERSE_TRANSNEXTPAYER,
		adjustment_amount => $transferToPayerAdj->{net_adjust},
		parent_id => $itemId,
		pay_date => $todaysDate,
		_debug => 0
	);

	my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');
	addBatchPaymentAttr($page, $invoiceId, value_text => $batchInfo->{value_text} || undef, value_int => $adjItemId, value_date => $todaysDate);

	return 1;
}

sub deleteHmoCapWriteoff
{
	my ($page, $invoiceId) = @_;

	my $items = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $item (@{$items})
	{
		$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delAutoWriteoffAdjustmentsForItem', $item->{item_id});
	}
}

sub checkEventStatus
{
	my ($page, $eventId) = @_;

	my $checkStatus = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
	'sel_eventInfo', $page->session('GMT_DAYOFFSET'), $eventId);

	my ($status, $person, $stamp);

	if ($checkStatus->{event_status} == 2) {
	$status = 'out';
	$person = $checkStatus->{checkout_by_id};
	$stamp  = $checkStatus->{checkout_stamp};
	} elsif ($checkStatus->{event_status} == 1) {
	$status = 'in';
	$person = $checkStatus->{checkin_by_id};
	$stamp  = $checkStatus->{checkin_stamp};
	} elsif ($checkStatus->{event_status} == 3) {
	$status = $checkStatus->{discard_type} . '-ed';
	$person = $checkStatus->{discard_by_id};
	$stamp  = $checkStatus->{discard_stamp};
	}

	return ($status, $person, $stamp);
}

#############################################################################################
#CLAIM DATA CONVERSION TO INVOICE TABLES FUNCTIONS
#############################################################################################

sub handleDataStorage
{
	my ($page, $invoiceId, $submitFlag, $printFlag) = @_;
	my $command = 'add';

	#if submitFlag == 1 (App::Universal::SUBMIT_PAYER), submitting to carrier
	#if submitFlag == 2 (App::Universal::RESUBMIT_SAMEPAYER), resubmitting to same carrier
	#if submitFlag == 3 (App::Universal::RESUBMIT_NEXTPAYER), resubmitting to next payer in invoice_billing

	if($submitFlag == App::Universal::RESUBMIT_NEXTPAYER)
	{
		$invoiceId = copyInvoiceForNextPayer($page, $command, $invoiceId);
	}

	if($submitFlag)
	{
		submitClaim($page, $invoiceId, $submitFlag, $printFlag);
	}

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $mainTransData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selTransactionById', $invoice->{main_transaction});

	my $claimType = $invoice->{invoice_subtype};
	my $invoiceType = $invoice->{invoice_type};

	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delPostSubmitAttributes', $invoiceId);
	$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delPostSubmitAddresses', $invoiceId);

	updateParentEvent($page, $command, $invoiceId, $invoice, $mainTransData);
	storeFacilityInfo($page, $command, $invoiceId, $invoice, $mainTransData);
	storeAuthorizations($page, $command, $invoiceId, $invoice, $mainTransData);
	storePatientInfo($page, $command, $invoiceId, $invoice, $mainTransData);
	storePatientEmployment($page, $command, $invoiceId, $invoice, $mainTransData);
	storeServiceProviderInfo($page, $command, $invoiceId, $invoice, $mainTransData);
	storeProviderInfo($page, $command, $invoiceId, $invoice, $mainTransData);

	if($claimType != App::Universal::CLAIMTYPE_SELFPAY)
	{
		storeInsuranceInfo($page, $command, $invoiceId, $invoice, $mainTransData);
	}

	if($claimType == App::Universal::CLAIMTYPE_HMO)
	{
		hmoCapWriteoff($page, $command, $invoiceId, $invoice, $mainTransData);
	}

	createActiveProbTrans($page, $command, $invoiceId, $invoice, $mainTransData);

	#set data storage flag
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId,
		flags => $invoice->{flags} | App::Universal::INVOICEFLAG_DATASTOREATTR,
		_debug => 0
	);

	return $invoiceId;
}

sub submitClaim
{
	my ($page, $invoiceId, $submitFlag, $printFlag) = @_;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $sessUserId = $page->session('user_id');

	my $invStat = $submitFlag == App::Universal::RESUBMIT_SAMEPAYER ? App::Universal::INVOICESTATUS_APPEALED : App::Universal::INVOICESTATUS_SUBMITTED;
	$invStat = $printFlag ? App::Universal::INVOICESTATUS_PAPERCLAIMPRINTED : $invStat;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId,
		invoice_status => $invStat,
		submitter_id => $sessUserId,
		submit_date => $todaysDate || undef,
		_debug => 0
	);

	# create invoice history item for invoice status
	my $action = $submitFlag == App::Universal::RESUBMIT_SAMEPAYER ? 'Resubmitted' : 'Submitted';
	$action = $printFlag ? 'HCFA Printed' : $action;
	addHistoryItem($page, $invoiceId, value_text => $action);
	
	my $actionType = $submitFlag == App::Universal::RESUBMIT_SAMEPAYER ? $App::Universal::DIALOG_COMMAND_ACTIVITY_MAP{resubmit} :
		$App::Universal::DIALOG_COMMAND_ACTIVITY_MAP{submit};

	$page->recordActivity(App::Universal::ACTIVITY_TYPE_RECORD, $actionType, 'invoice', $invoiceId, 
		undef," invoice <a href='/invoice/$invoiceId/summary'>$invoiceId</a>", 
		$sessUserId);
}

sub copyInvoiceForNextPayer
{
	my ($page, $command, $oldInvoiceId) = @_;
	my $oldInvoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $oldInvoiceId);
	my $prevClaimOrder = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceOrder', $oldInvoiceId);

	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('user_id');
	my $timeStamp = $page->getTimeStamp();
	my $todaysDate = $page->getDate();
	my $entityTypePerson = App::Universal::ENTITYTYPE_PERSON;
	my $entityTypeOrg = App::Universal::ENTITYTYPE_ORG;

	my @claimDiags = split(/\s*,\s*/, $oldInvoiceInfo->{claim_diags});
	my $invoiceType = $oldInvoiceInfo->{invoice_type};
	my $newInvoiceId = $page->schemaAction(
		'Invoice', 'add',
		invoice_type => defined $invoiceType ? $invoiceType : undef,
		#invoice_subtype => defined $claimType ? $claimType : undef,
		#invoice_status => defined $submitted ? $submitted : undef,
		invoice_date => $todaysDate || undef,
		main_transaction => $oldInvoiceInfo->{main_transaction} || undef,
		submitter_id => $oldInvoiceInfo->{submitter_id} || undef,
		claim_diags => join(', ', @claimDiags) || undef,
		owner_type => defined $entityTypeOrg ? $entityTypeOrg : undef,
		owner_id => $oldInvoiceInfo->{owner_id} || undef,
		client_type => defined $entityTypePerson ? $entityTypePerson : undef,
		client_id => $oldInvoiceInfo->{client_id} || undef,
		#billing_id => $oldInvoiceInfo->{billing_id} || undef,
		_debug => 0
	);


	#copy all attributes except history items
	my $attributes = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllAttributesExclHistoryAndTransferred', $oldInvoiceId);
	foreach my $attr (@{$attributes})
	{
		my $valueType = $attr->{value_type};
		my $itemType = $attr->{item_type};
		my $valueInt = $attr->{value_int};
		my $valueIntB = $attr->{value_intb};
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $newInvoiceId,
			item_type => defined $itemType ? $itemType : undef,
			item_name => $attr->{item_name} || undef,
			value_type => defined $valueType ? $valueType : undef,
			value_text => $attr->{value_text} || undef,
			value_textB => $attr->{value_textb} || undef,
			value_int => defined $valueInt ? $valueInt : undef,
			value_intB => defined $valueIntB ? $valueIntB : undef,
			value_float => $attr->{value_float} || undef,
			value_floatB => $attr->{value_floatb} || undef,
			value_date => $attr->{value_date} || undef,
			value_dateEnd => $attr->{value_dateend} || undef,
			value_dateA => $attr->{value_datea} || undef,
			value_dateB => $attr->{value_dateb} || undef,
			value_block => $attr->{value_block} || undef,
			_debug => 0
		);
	}


	my $lineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $oldInvoiceId);
	foreach my $item (@{$lineItems})
	{
		my $adjustments = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selItemAdjustmentsByItemParent', $item->{item_id});
		my $isCarryoverItem;
		foreach my $adjust (@{$adjustments})
		{
			next unless $adjust->{adjustment_type} == App::Universal::ADJUSTMENTTYPE_TRANSFERNEXTPAYER
				|| $adjust->{adjustment_type} == App::Universal::ADJUSTMENTTYPE_REVERSE_TRANSNEXTPAYER
				|| $adjust->{adjustment_type} == App::Universal::ADJUSTMENTTYPE_REVERSE_PAYMENT;

			$isCarryoverItem = 1;
		}
		next if $isCarryoverItem;

		my $itemType = $item->{item_type};
		my $emg = $item->{emergency};
		my $newItemId = $page->schemaAction(
			'Invoice_Item', 'add',
			parent_id => $newInvoiceId || undef,
			flags => $item->{flags} || undef,
			service_begin_date => $item->{service_begin_date} || undef,
			service_end_date => $item->{service_end_date} || undef,
			hcfa_service_place => defined $item->{hcfa_service_place} ? $item->{hcfa_service_place} : undef,
			hcfa_service_type => defined $item->{hcfa_service_type} ? $item->{hcfa_service_type} : undef,
			modifier => $item->{modifier} || undef,
			quantity => $item->{quantity} || undef,
			emergency => defined $emg ? $emg : undef,
			item_type => defined $itemType ? $itemType : undef,
			code => $item->{code} || undef,
			code_type => $item->{code_type} || undef,
			caption => $item->{caption} || undef,
			comments =>  $item->{comments} || undef,
			unit_cost => $item->{unit_cost} || undef,
			rel_diags => $item->{rel_diags} || undef,
			parent_code => $item->{parent_code} || undef,
			data_text_a => $item->{data_text_a} || undef,
			data_text_c => $item->{data_text_c} || undef,
			data_num_a => $item->{data_num_a} || undef,
			data_num_b => $item->{data_num_b} || undef,
			extended_cost => $item->{extended_cost} || undef,
			_debug => 0
		);

		my $newAdjId;
		foreach my $adjust (@{$adjustments})
		{
			my $adjType = App::Universal::ADJUSTMENTTYPE_TRANSFER_PAYMENT;
			my $payType = $adjust->{pay_type};
			my $payMethod = $adjust->{pay_method};
			my $payerType = $adjust->{payer_type};
			my $writeoffCode = $adjust->{writeoff_code};
			my $dataNumA = $adjust->{data_num_a} ne '' ? $adjust->{data_num_a} : $prevClaimOrder;
			$newAdjId = $page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				adjustment_type => defined $adjType ? $adjType : undef,
				adjustment_amount => $adjust->{adjustment_amount} || undef,
				parent_id => $newItemId || undef,
				plan_allow => $adjust->{plan_allow} || undef,
				plan_paid => $adjust->{plan_paid} || undef,
				pay_date => $todaysDate,
				pay_type => defined $payType ? $payType : undef,
				pay_method => defined $payMethod ? $payMethod : undef,
				pay_ref => $adjust->{pay_ref} || undef,
				payer_type => defined $payerType ? $payerType : undef,
				payer_id => $adjust->{payer_id} || undef,
				writeoff_code => defined $writeoffCode ? $writeoffCode : 'NULL',
				writeoff_amount => $adjust->{writeoff_amount} || undef,
				comments => $adjust->{comments} || undef,
				data_text_a => $adjust->{data_text_a} || undef,			#this field is used for authorization reference/code
				data_date_a => $adjust->{data_date_a} || undef,			#this is used for credit card exp date
				data_num_a => defined $dataNumA ? $dataNumA : undef,	#this indicates which child claim the adjustment was transferred from (ex. 1=primary, 2=secondary, etc.)
				_debug => 0
			);

			my $batchPayment = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $newInvoiceId, 'Invoice/Payment/Batch ID');
			foreach my $batch (@{$batchPayment})
			{
				if($batch->{value_int} == $adjust->{adjustment_id})
				{
					$page->schemaAction(
						'Invoice_Attribute', 'update',
						item_id => $batch->{item_id},
						value_int => $newAdjId,
						_debug => 0
					);
				}
			}
		}
	}


	#copy old invoice's billing records
	my $billingInfo = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceBillingRecs', $oldInvoiceId);
	my $billId;
	my $newPayerBillId;
	my $newInsIntId;
	my $billSeq;
	my $billPartyType;
	my $billStatus;
	my $oldPayerSeq;
	foreach my $billingRec (@{$billingInfo})
	{
		$billSeq = $billingRec->{bill_sequence};
		$billPartyType = $billingRec->{bill_party_type};
		$billStatus = $billingRec->{bill_status};
		if($billingRec->{bill_id} == $oldInvoiceInfo->{billing_id})
		{
			$oldPayerSeq = $billSeq;
			$billStatus = 'inactive';
		}

		$billId = $page->schemaAction(
			'Invoice_Billing', 'add',
			invoice_id => $newInvoiceId || undef,
			invoice_item_id => $billingRec->{invoice_item_id} || undef,
			assoc_bill_id => $billingRec->{assoc_bill_id} || undef,
			bill_sequence => defined $billSeq ? $billSeq : undef,
			bill_party_type => defined $billPartyType ? $billPartyType : undef,
			bill_to_id => $billingRec->{bill_to_id} || undef,
			bill_ins_id => $billingRec->{bill_ins_id} || undef,
			bill_amount => $billingRec->{bill_amount} || undef,
			bill_pct => $billingRec->{bill_pct} || undef,
			bill_date => $billingRec->{bill_date} || undef,
			bill_status => $billStatus || undef,
			bill_result => $billingRec->{bill_result} || undef,
			_debug => 0
		);

		if($billSeq == $oldPayerSeq + 1)
		{
			$newPayerBillId = $billId;
			$newInsIntId = $billingRec->{bill_ins_id};
		}
	}


	#update the new invoice with its new billing id and claim type
	my $claimType = $newInsIntId ? $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInsType', $newInsIntId) : 0;
	my $invoiceStatus = $claimType == App::Universal::CLAIMTYPE_SELFPAY ? App::Universal::INVOICESTATUS_CREATED : App::Universal::INVOICESTATUS_SUBMITTED;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $newInvoiceId || undef,
		invoice_status => defined $invoiceStatus ? $invoiceStatus : undef,
		invoice_subtype => defined $claimType ? $claimType : undef,
		billing_id => $newPayerBillId,
	);


	#update the submission order attribute for the new invoice
	my $submitOrder = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $newInvoiceId, 'Submission Order');
	$page->schemaAction(
		'Invoice_Attribute', 'update',
		item_id => $submitOrder->{item_id},
		value_int => $submitOrder->{value_int} + 1,
		_debug => 0
	);

	#update the patient control number attribute for the new invoice
	my $patientControlNo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $newInvoiceId, 'Patient/Control Number');
	$page->schemaAction(
		'Invoice_Attribute', 'update',
		item_id => $patientControlNo->{item_id},
		value_text => $newInvoiceId,
		_debug => 0
	);

	#add new history items for the new invoice
	addHistoryItem($page, $newInvoiceId, value_text => 'Created claim');
	addHistoryItem($page, $newInvoiceId, value_text => "This invoice is a resubmitted copy of invoice <A HREF='/invoice/$oldInvoiceId/summary'>$oldInvoiceId</A>");


	#close old invoice, add adjustment invoice item and adjustment to zero out balance (which is the carry over of the balance), add batch attr for adj, add history items
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $oldInvoiceId || undef,
		parent_invoice_id => $newInvoiceId || undef,
		invoice_status => App::Universal::INVOICESTATUS_CLOSED,
	);

	my $itemId = $page->schemaAction('Invoice_Item', 'add', parent_id => $oldInvoiceId, item_type => App::Universal::INVOICEITEMTYPE_ADJUST, _debug => 0);
	my $adjItemId = $page->schemaAction(
		'Invoice_Item_Adjust', 'add',
		adjustment_type => App::Universal::ADJUSTMENTTYPE_TRANSFERNEXTPAYER,
		adjustment_amount => defined $oldInvoiceInfo->{balance} ? $oldInvoiceInfo->{balance} : undef,
		parent_id => $itemId || undef,
		pay_date => $todaysDate || undef,
		_debug => 0
	);

	my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $oldInvoiceId, 'Invoice/Creation/Batch ID');
	addBatchPaymentAttr($page, $oldInvoiceId, value_text => $batchInfo->{value_text} || undef, value_int => $adjItemId, value_date => $todaysDate);
	addHistoryItem($page, $oldInvoiceId, value_text => "The remaining balance has been carried over to claim <A HREF='/invoice/$newInvoiceId/summary'>$newInvoiceId</A>");
	addHistoryItem($page, $oldInvoiceId, value_text => 'Closed');

	return $newInvoiceId;
}

sub hmoCapWriteoff
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $writeoffCode = App::Universal::ADJUSTWRITEOFF_CONTRACTAGREEMENT;

	#delete existing auto writeoffs before re-adding
	my $items = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $item (@{$items})
	{
		$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delAutoWriteoffAdjustmentsForItem', $item->{item_id});
	}

	#get creation batch id and use it as the payment batch id for the auto writeoffs
	my $batchInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Invoice/Creation/Batch ID');

	my $totalAdjForItems = 0;
	my $procItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	foreach my $proc (@{$procItems})
	{
		next if $proc->{item_type} == App::Universal::INVOICEITEMTYPE_ADJUST || $proc->{item_type} == App::Universal::INVOICEITEMTYPE_COPAY
			|| $proc->{item_type} == App::Universal::INVOICEITEMTYPE_DEDUCTIBLE || $proc->{item_type} == App::Universal::INVOICEITEMTYPE_VOID;
		next if $proc->{data_num_a};			#data_num_a indicates that this item is FFS (null if it isn't)
		next if $proc->{data_text_b} eq 'void';	#data_text_b indicates that this item has been voided
		next if $proc->{balance} <= 0;

		my $writeoffAmt = $proc->{balance};
		my $itemId = $proc->{item_id};
		my $adjItemId = $page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			parent_id => $itemId || undef,
			adjustment_type => App::Universal::ADJUSTMENTTYPE_AUTOINSWRITEOFF,
			pay_date => $todaysDate,
			writeoff_code => defined $writeoffCode ? $writeoffCode : undef,
			writeoff_amount => defined $writeoffAmt ? $writeoffAmt : undef,
			comments => 'Writeoff auto-generated by system',
			_debug => 0
		);

		addBatchPaymentAttr($page, $invoiceId, value_text => $batchInfo->{value_text} || undef, value_int => $adjItemId, value_date => $todaysDate);
	}


	## create invoice history for these adjustments
	addHistoryItem($page, $invoiceId, value_text => 'Auto-generated writeoffs for HMO Capitated claim');
}

sub updateParentEvent
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	my $eventId = $mainTransData->{parent_event_id};

	return unless $eventId;

	my $eventInfo = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE, 'selEventById', $eventId);
	if($eventInfo->{event_status} == App::Universal::EVENTSTATUS_INPROGRESS)
	{
		$page->schemaAction(
			'Event', 'update',
			event_id => $eventId || undef,
			event_status => App::Universal::EVENTSTATUS_COMPLETE,
			checkout_stamp => $page->getTimeStamp(),
			checkout_by_id => $page->session('user_id'),
			_debug => 0
		);
	}
}

sub storeFacilityInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $credentialsValueType = App::Universal::ATTRTYPE_CREDENTIALS;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;

	##billing facility information
	my $billFacilityId = $mainTransData->{billing_facility_id};
	my $billingFacilityAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $billFacilityId, 'Billing');
	#my $billingFacilityPayAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $billFacilityId, 'Billing');
	my $billingFacilityInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billFacilityId);

	my $phoneNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Primary', $phoneValueType);
	my $employerNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Employer#', $credentialsValueType);
	my $stateNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'State#', $credentialsValueType);
	my $medicaidNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Medicaid#', $credentialsValueType);
	my $wrkCompNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Workers Comp#', $credentialsValueType);
	my $bcbsNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'BCBS#', $credentialsValueType);
	my $medicareNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Medicare#', $credentialsValueType);
	my $cliaNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'CLIA#', $credentialsValueType);
	my $rrMedicareNo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $billFacilityId, 'Railroad Medicare#', $credentialsValueType);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $billingFacilityInfo->{name_primary} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Tax ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $billingFacilityInfo->{tax_id} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Phone',
			value_type => defined $phoneValueType ? $phoneValueType : undef,
			value_text => $phoneNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Employer Number',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $employerNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/State',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $stateNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Medicaid',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $medicaidNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Workers Comp',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $wrkCompNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/BCBS',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $bcbsNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Medicare',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $medicareNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/CLIA',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $cliaNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Billing Facility/Railroad Medicare',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $rrMedicareNo->{value_text} || undef,
			value_textB => $billingFacilityInfo->{org_id} || undef,
			value_int => $billFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Billing',
			line1 => $billingFacilityAddr->{line1} || undef,
			line2 => $billingFacilityAddr->{line2} || undef,
			city => $billingFacilityAddr->{city} || undef,
			state => $billingFacilityAddr->{state} || undef,
			zip => $billingFacilityAddr->{zip} || undef,
			_debug => 0
		);



	##SERVICE FACILITY INFORMATION
	my $servFacilityId = $mainTransData->{service_facility_id};
	my $serviceFacilityAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $servFacilityId, 'Mailing');
	my $serviceFacilityInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $servFacilityId);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Facility/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $serviceFacilityInfo->{name_primary} || undef,
			value_textB => $serviceFacilityInfo->{org_id} || undef,
			value_int => $servFacilityId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Service',
			line1 => $serviceFacilityAddr->{line1} || undef,
			line2 => $serviceFacilityAddr->{line2} || undef,
			city => $serviceFacilityAddr->{city} || undef,
			state => $serviceFacilityAddr->{state} || undef,
			zip => $serviceFacilityAddr->{zip} || undef,
			_debug => 0
		);

	#store pay to org address
	#my $payToOrg = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceAttr', $invoiceId, 'Pay To Org/Name');
	#my $payToFacilityAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $payToOrg->{value_int}, 'Mailing');

	#$page->schemaAction(
	#		'Invoice_Address', $command,
	#		parent_id => $invoiceId,
	#		address_name => 'Pay To Org',
	#		line1 => $payToFacilityAddr->{line1},
	#		line2 => $payToFacilityAddr->{line2} || undef,
	#		city => $payToFacilityAddr->{city},
	#		state => $payToFacilityAddr->{state},
	#		zip => $payToFacilityAddr->{zip},
	#		_debug => 0
	#);
}

sub storeAuthorizations
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $boolValueType = App::Universal::ATTRTYPE_BOOLEAN;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());

	my $clientId = $invoice->{client_id};
	my $patSignature = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHPATIENTSIGN);
	my $provAssign = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN);
	my $infoRelease = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeByPersonAndValueType', $clientId, App::Universal::ATTRTYPE_AUTHINFORELEASE);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Patient/Signature',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $patSignature->{value_text} || undef,
			value_textB => $patSignature->{value_textb} || undef,
			value_date => $patSignature->{value_date} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Provider/Assign Indicator',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $provAssign->{value_text} || undef,
			value_textB => $provAssign->{value_textb} || undef,
			value_intB => 1,
			_debug => 0
		);

	my $infoRelIndctr = $infoRelease->{value_text} eq 'Yes' ? 1 : 0;
	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Information Release/Indicator',
			value_type => defined $boolValueType ? $boolValueType : undef,
			value_int => defined $infoRelIndctr ? $infoRelIndctr : undef,
			value_date => $infoRelease->{value_date} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId || undef,
			item_name => 'Provider/Signature/Date',
			value_type => defined $dateValueType ? $dateValueType : undef,
			value_date => $todaysDate || undef,
			value_intB => 1,
			_debug => 0
		);
}

sub storePatientInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;

	my $clientId = $invoice->{client_id};
	my $personData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $clientId);
	my $personPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $clientId);
	my $personAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $clientId);

	$page->schemaAction(
			'Invoice_Address', $command,
			parent_id => $invoiceId,
			address_name => 'Patient',
			line1 => $personAddr->{line1} || undef,
			line2 => $personAddr->{line2} || undef,
			city => $personAddr->{city} || undef,
			state => $personAddr->{state} || undef,
			zip => $personAddr->{zip} || undef,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{complete_name} || undef,
			value_textB => $clientId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_last} || undef,
			value_textB => $clientId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_first} || undef,
			value_textB => $clientId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{name_middle} || undef,
			value_textB => $clientId || undef,
			value_intB => 1,
			_debug => 0
		) if $personData->{name_middle} ne '';

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Account Number',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{person_ref} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Contact/Home Phone',
			value_type => defined $phoneValueType ? $phoneValueType : undef,
			value_text => $personPhone || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/Marital Status',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{marstat_caption} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/Gender',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $personData->{gender_caption} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Patient/Personal/DOB',
			value_type => defined $dateValueType ? $dateValueType : undef,
			value_date => $personData->{date_of_birth} || undef,
			value_intB => 1,
			_debug => 0
		);
}

sub storePatientEmployment
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	# a list of employment statuses:
	my $ftEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDFULL;	#220
	my $ptEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDPART;	#221
	my $selfEmployAttr = App::Universal::ATTRTYPE_SELFEMPLOYED;	#222
	my $retiredAttr = App::Universal::ATTRTYPE_RETIRED;			#223
	my $ftStudentAttr = App::Universal::ATTRTYPE_STUDENTFULL;		#224
	my $ptStudentAttr = App::Universal::ATTRTYPE_STUDENTPART;	#225
	my $unknownAttr = App::Universal::ATTRTYPE_EMPLOYUNKNOWN;	#226

	my $personEmployStat = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selEmploymentStatusCaption', $invoice->{client_id});
	foreach my $employStat (@{$personEmployStat})
	{
		my $valueType = $employStat->{value_type};

		my $status = '';
		$status = $employStat->{caption};
		$status = 'Retired' if $valueType == $retiredAttr;
		$status = 'Employed' if $valueType >= $ftEmployAttr && $valueType <= $selfEmployAttr;

		if($status eq 'Employed')
		{
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Patient/Employment/Status',
					value_type => defined $valueType ? $valueType : undef,
					value_text => $status || undef,
					value_intB => 1,
					_debug => 0
				);
		}
		elsif($status eq 'Student (Full-Time)' || $status eq 'Student (Part-Time)')
		{
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Patient/Student/Status',
					value_type => defined $valueType ? $valueType : undef,
					value_text => $status || undef,
					value_intB => 1,
					_debug => 0
				);
		}
	}
}

sub storeServiceProviderInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $licenseValueType = App::Universal::ATTRTYPE_LICENSE;
	my $sessOrgId = $page->session('org_id');
	my $providerId = $mainTransData->{care_provider_id};
	my $providerInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $providerId);

	my $servFacilityId = $mainTransData->{service_facility_id};
	my $serviceFacilityAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $servFacilityId, 'Mailing');
	my $providerStateLicense = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, $serviceFacilityAddr->{state}, $servFacilityId);
	my $stateLicense = $providerStateLicense->{value_text};
	my $state = $providerStateLicense->{item_name};
	if($stateLicense eq '')
	{
		$providerStateLicense = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, $serviceFacilityAddr->{state}, $sessOrgId);
		$stateLicense = $providerStateLicense->{value_text};
		$state = $providerStateLicense->{item_name};
	}

	my $providerSpecialty = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPhysicianSpecialtyByIdAndSequence', $providerId, 1);

	my $providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Tax ID', $servFacilityId);
	my $tax = $providerTaxId->{value_text};
	if($tax eq '')
	{
		$providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Tax ID', $sessOrgId);
		$tax = $providerTaxId->{value_text};
	}

	my $providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'UPIN', $servFacilityId);
	my $upin = $providerUpin->{value_text};
	if($upin eq '')
	{
		$providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'UPIN', $sessOrgId);
		$upin = $providerUpin->{value_text};
	}

	my $providerBcbs = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'BCBS', $servFacilityId);
	my $bcbs = $providerBcbs->{value_text};
	if($bcbs eq '')
	{
		$providerBcbs = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'BCBS', $sessOrgId);
		$bcbs = $providerBcbs->{value_text};
	}

	my $providerMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicare', $servFacilityId);
	my $medicare = $providerMedicare->{value_text};
	if($medicare eq '')
	{
		$providerMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicare', $sessOrgId);
		$medicare = $providerMedicare->{value_text};
	}

	my $providerMedicaid = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicaid', $servFacilityId);
	my $medicaid = $providerMedicaid->{value_text};
	if($medicaid eq '')
	{
		$providerMedicaid = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicaid', $sessOrgId);
		$medicaid = $providerMedicaid->{value_text};
	}

	my $providerChampus = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Champus', $servFacilityId);
	my $champus = $providerChampus->{value_text};
	if($champus eq '')
	{
		$providerChampus = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Champus', $sessOrgId);
		$champus = $providerChampus->{value_text};
	}

	my $providerWorkComp = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'WC#', $servFacilityId);
	my $wc = $providerWorkComp->{value_text};
	if($wc eq '')
	{
		$providerWorkComp = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'WC#', $sessOrgId);
		$wc = $providerWorkComp->{value_text};
	}

	my $providerEpsdt = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'EPSDT', $servFacilityId);
	my $epsdt = $providerEpsdt->{value_text};
	if($epsdt eq '')
	{
		$providerEpsdt = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'EPSDT', $sessOrgId);
		$epsdt = $providerEpsdt->{value_text};
	}

	my $providerRRMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Railroad Medicare', $servFacilityId);
	my $rrMedicare = $providerRRMedicare->{value_text};
	if($rrMedicare eq '')
	{
		$providerRRMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Railroad Medicare', $sessOrgId);
		$rrMedicare = $providerRRMedicare->{value_text};
	}


	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{complete_name} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_first} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_middle} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		) if $providerInfo->{name_middle} ne '';

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_last} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/State License',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $stateLicense || undef,
			value_textB => $state || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Specialty',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerSpecialty->{value_text} || undef,
			value_textB => $providerSpecialty->{value_textb} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Tax ID',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $tax || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/UPIN',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $upin || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/BCBS',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $bcbs || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Medicare',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $medicare || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Medicaid',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $medicaid || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Champus',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $champus || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Workers Comp',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $wc || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/EPSDT',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $epsdt || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Service Provider/Railroad Medicare',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $rrMedicare || undef,
			value_intB => 1,
			_debug => 0
		);
}

sub storeProviderInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $licenseValueType = App::Universal::ATTRTYPE_LICENSE;
	my $sessOrgId = $page->session('org_id');
	my $providerId = $mainTransData->{provider_id};
	my $servFacilityId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $mainTransData->{service_facility_id});

	my $providerInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $providerId);

	my $providerSpecialty = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPhysicianSpecialtyByIdAndSequence', $providerId, 1);

	my $providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Tax ID', $servFacilityId);
	my $tax = $providerTaxId->{value_text};
	if($tax eq '')
	{
		$providerTaxId = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Tax ID', $sessOrgId);
		$tax = $providerTaxId->{value_text};
	}

	my $providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'UPIN', $servFacilityId);
	my $upin = $providerUpin->{value_text};
	if($upin eq '')
	{
		$providerUpin = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'UPIN', $sessOrgId);
		$upin = $providerUpin->{value_text};
	}

	my $providerBcbs = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'BCBS', $servFacilityId);
	my $bcbs = $providerBcbs->{value_text};
	if($bcbs eq '')
	{
		$providerBcbs = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'BCBS', $sessOrgId);
		$bcbs = $providerBcbs->{value_text};
	}

	my $providerMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicare', $servFacilityId);
	my $medicare = $providerMedicare->{value_text};
	if($medicare eq '')
	{
		$providerMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicare', $sessOrgId);
		$medicare = $providerMedicare->{value_text};
	}

	my $providerMedicaid = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicaid', $servFacilityId);
	my $medicaid = $providerMedicaid->{value_text};
	if($medicaid eq '')
	{
		$providerMedicaid = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Medicaid', $sessOrgId);
		$medicaid = $providerMedicaid->{value_text};
	}

	my $providerChampus = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Champus', $servFacilityId);
	my $champus = $providerChampus->{value_text};
	if($champus eq '')
	{
		$providerChampus = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Champus', $sessOrgId);
		$champus = $providerChampus->{value_text};
	}

	my $providerWorkComp = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'WC#', $servFacilityId);
	my $wc = $providerWorkComp->{value_text};
	if($wc eq '')
	{
		$providerWorkComp = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'WC#', $sessOrgId);
		$wc = $providerWorkComp->{value_text};
	}

	my $providerEpsdt = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'EPSDT', $servFacilityId);
	my $epsdt = $providerEpsdt->{value_text};
	if($epsdt eq '')
	{
		$providerEpsdt = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'EPSDT', $sessOrgId);
		$epsdt = $providerEpsdt->{value_text};
	}

	my $providerRRMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Railroad Medicare', $servFacilityId);
	my $rrMedicare = $providerRRMedicare->{value_text};
	if($rrMedicare eq '')
	{
		$providerRRMedicare = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttrByItemNameParentNameSort', $providerId, 'Railroad Medicare', $sessOrgId);
		$rrMedicare = $providerRRMedicare->{value_text};
	}

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{complete_name} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/First',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_first} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/Middle',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_middle} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		) if $providerInfo->{name_middle} ne '';

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Name/Last',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerInfo->{name_last} || undef,
			value_textB => $providerId || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Specialty',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $providerSpecialty->{value_text} || undef,
			value_textB => $providerSpecialty->{value_textb} || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Tax ID',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $tax || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/UPIN',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $upin || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/BCBS',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $bcbs || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Medicare',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $medicare || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Medicaid',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $medicaid || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Champus',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $champus || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Workers Comp',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $wc || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/EPSDT',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $epsdt || undef,
			value_intB => 1,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Provider/Railroad Medicare',
			value_type => defined $licenseValueType ? $licenseValueType : undef,
			value_text => $rrMedicare || undef,
			value_intB => 1,
			_debug => 0
		);
}

sub storeInsuranceInfo
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');

	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $phoneValueType = App::Universal::ATTRTYPE_PHONE;
	my $dateValueType = App::Universal::ATTRTYPE_DATE;
	my $durationValueType = App::Universal::ATTRTYPE_DURATION;
	my $primaryIns = App::Universal::INSURANCE_PRIMARY;
	my $uniqPlan = App::Universal::RECORDTYPE_PERSONALCOVERAGE;

	my $ftEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDFULL;		#220
	my $ptEmployAttr = App::Universal::ATTRTYPE_EMPLOYEDPART;		#221
	my $selfEmployAttr = App::Universal::ATTRTYPE_SELFEMPLOYED;		#222
	my $retiredAttr = App::Universal::ATTRTYPE_RETIRED;				#223
	my $ftStudentAttr = App::Universal::ATTRTYPE_STUDENTFULL;			#224
	my $ptStudentAttr = App::Universal::ATTRTYPE_STUDENTPART;		#225
	my $unknownAttr = App::Universal::ATTRTYPE_EMPLOYUNKNOWN;		#226

	my $clientId = $invoice->{client_id};
	my $billingId = $invoice->{billing_id};
	my $payerBillSeq = '';
	my $order = '';
	my $partyType = '';
	my $insIntId = '';
	my $billId = '';
	my $primaryPayerBillSeq = '';
	my $invoicePayers = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selInvoiceBillingRecs', $invoiceId); #this query is ordered by bill_sequence
	foreach my $payer (@{$invoicePayers})
	{
		$partyType = $payer->{bill_party_type};
		$insIntId = $payer->{bill_ins_id};
		$billId = $payer->{bill_id};
		$payerBillSeq = $payer->{bill_sequence};

		next if $partyType == App::Universal::INVOICEBILLTYPE_CLIENT;	#don't want to continue because this type is a self-pay
		next if $payer->{bill_status} eq 'inactive';						#don't want to include payers that have been used already

		if($billId == $billingId)
		{
			$order = 'Primary';
			$primaryPayerBillSeq = $payerBillSeq;
		}

		$order = 'Secondary' if $payerBillSeq == $primaryPayerBillSeq + 1;
		$order = 'Tertiary' if $payerBillSeq == $primaryPayerBillSeq + 2;
		$order = 'Quaternary' if $payerBillSeq == $primaryPayerBillSeq + 3;


		if($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
		{
			my $thirdPartyInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceData', $insIntId);
			my $thirdPartyId = $thirdPartyInsur->{guarantor_id};

			my $thirdPartyInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $thirdPartyId);
			my $thirdPartyPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $insIntId);
			my $thirdPartyAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $thirdPartyId, 'Mailing');

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Org/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $thirdPartyInfo->{name_primary} || undef,
					value_textB => $thirdPartyInfo->{org_id} || undef,
					value_int => $thirdPartyId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Org/Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $thirdPartyPhone->{phone} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Third-Party',
					line1 => $thirdPartyAddr->{line1} || undef,
					line2 => $thirdPartyAddr->{line2} || undef,
					city => $thirdPartyAddr->{city} || undef,
					state => $thirdPartyAddr->{state} || undef,
					zip => $thirdPartyAddr->{zip} || undef,
					_debug => 0
				);

		}
		elsif($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON)
		{
			my $thirdPartyInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceData', $insIntId);
			my $thirdPartyId = $thirdPartyInsur->{guarantor_id};

			my $thirdPartyName = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selPersonSimpleNameById', $thirdPartyId);
			my $thirdPartyPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $insIntId);
			my $thirdPartyAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $thirdPartyId);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Person/Name',
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $thirdPartyName || undef,
					value_textB => $thirdPartyId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => 'Third-Party/Person/Phone',
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $thirdPartyPhone->{phone} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => 'Third-Party',
					line1 => $thirdPartyAddr->{line1} || undef,
					line2 => $thirdPartyAddr->{line2} || undef,
					city => $thirdPartyAddr->{city} || undef,
					state => $thirdPartyAddr->{state} || undef,
					zip => $thirdPartyAddr->{zip} || undef,
					_debug => 0
				);

		}
		elsif($partyType == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS)
		{
			my $personInsur = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceForInvoiceSubmit', $insIntId);
			my $insOrgId = $personInsur->{ins_org_id};
			my $parentInsId = $personInsur->{parent_ins_id};
			my $personInsurPlanOrProd = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceForInvoiceSubmit', $parentInsId);
			my $personInsurProduct = undef;
			if($personInsurPlanOrProd->{record_type} == App::Universal::RECORDTYPE_INSURANCEPLAN)
			{
				$personInsurProduct = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInsuranceForInvoiceSubmit', $personInsurPlanOrProd->{parent_ins_id});
			}

			#Basic Insurance Information --------------------
			my $insOrgInfo = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $insOrgId);
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Name",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insOrgInfo->{name_primary} || undef,
					value_textB => $insOrgInfo->{org_id} || undef,
					value_int => $insOrgId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Effective Dates",
					value_type => defined $durationValueType ? $durationValueType : undef,
					value_date => $personInsur->{coverage_begin_date} || undef,
					value_dateEnd => $personInsur->{coverage_end_date} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Type",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{claim_type} || undef,
					value_textB => $personInsur->{extra} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Group Number",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{plan_name} || $personInsur->{product_name} || $personInsur->{group_name} || undef,
					value_textB => $personInsur->{group_number} || $personInsur->{policy_number} || undef,
					value_intB => 1,
					_debug => 0
				);

			#HMO-PPO Indicator and BCBS Plan Code --------------------
			my $ppoHmo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'HMO-PPO/Indicator');
			my $bcbsCode = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'BCBS Plan Code');
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/HMO-PPO ID",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $ppoHmo->{value_text} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/BCBS Plan Code",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $bcbsCode->{value_text} || undef,
					value_intB => 1,
					_debug => 0
				);


			#E-Remitter Payer ID --------------------
			my $clearHouseId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selAttributeByItemNameAndValueTypeAndParent', $sessOrgIntId, 'Clearing House ID', $textValueType);
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/E-Remitter ID",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsurPlanOrProd->{remit_payer_id} || $personInsurProduct->{remit_payer_id},
					value_textB => $clearHouseId->{value_text},
					value_intB => 1,
					_debug => 0
				);


			#Payment Source --------------------
			my $claimType = $personInsur->{ins_type};
			my $paySource;
			$paySource = 'A' if $claimType == App::Universal::CLAIMTYPE_SELFPAY;
			$paySource = 'B' if $claimType == App::Universal::CLAIMTYPE_WORKERSCOMP;
			$paySource = 'C' if $claimType == App::Universal::CLAIMTYPE_MEDICARE;
			$paySource = 'D' if $claimType == App::Universal::CLAIMTYPE_MEDICAID;
			#$paySource = 'E' if $claimType == 'Other Federal Program';
			$paySource = 'F' if $claimType == App::Universal::CLAIMTYPE_INSURANCE || $claimType == App::Universal::CLAIMTYPE_RRMEDICARE;
			#$paySource = 'G' if $claimType == 'Blue Cross/Blue Shield';
			$paySource = 'H' if $claimType == App::Universal::CLAIMTYPE_CHAMPUS;
			$paySource = 'I' if $claimType == App::Universal::CLAIMTYPE_HMO || $claimType == App::Universal::CLAIMTYPE_HMO_NONCAP;
			#$paySource = 'J' if $claimType == 'Federal Employee’s Program (FEP)';
			#$paySource = 'K' if $claimType == 'Central Certification';
			#$paySource = 'L' if $claimType == 'Self Administered';
			#$paySource = 'M' if $claimType == 'Family or Friends';
			$paySource = 'N' if $claimType == App::Universal::CLAIMTYPE_POS || $claimType == App::Universal::CLAIMTYPE_MNGCARE;
			$paySource = 'P' if $claimType == App::Universal::CLAIMTYPE_BCBS;
			#$paySource = 'T' if $claimType == 'Title V';
			#$paySource = 'V' if $claimType == 'Veteran’s Administration Plan';
			$paySource = 'X' if $claimType == App::Universal::CLAIMTYPE_PPO;
			$paySource = 'Z' if $claimType == App::Universal::CLAIMTYPE_CLIENT || $claimType == App::Universal::CLAIMTYPE_CHAMPVA || $claimType == App::Universal::CLAIMTYPE_FECABLKLUNG;

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Payment Source",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $paySource || undef,
					value_intB => 1,
					_debug => 0
				);

			#Champus Information --------------------
			my $champusStatus = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Status');
			my $champusBranch = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Branch');
			my $champusGrade = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $parentInsId, 'Champus Grade');

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Champus Branch",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusBranch->{value_text} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Champus Status",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusStatus->{value_text} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Champus Grade",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $champusGrade->{value_text} || undef,
					value_intB => 1,
					_debug => 0
				);


			#Medigap Number  --------------------
			if($invoice->{invoice_subtype} == App::Universal::CLAIMTYPE_MEDICARE)
			{
				my $medigapNo = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $personInsurProduct->{ins_internal_id} || $personInsurPlanOrProd->{ins_internal_id}, 'Medigap/Number');
				$page->schemaAction(
						'Invoice_Attribute', $command,
						parent_id => $invoiceId,
						item_name => "Insurance/$order/Medigap",
						value_type => defined $textValueType ? $textValueType : undef,
						value_text => $medigapNo->{value_text} || undef,
						value_intB => 1,
						_debug => 0
					);
			}


			#Insurance Contact Info --------------------
			my $insOrgPhone = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsurancePayerPhone', $parentInsId);
			my $insOrgAddr = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceAddrWithOutColNameChanges', $parentInsId);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Phone",
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insOrgPhone->{phone} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => "$order Insurance",
					line1 => $insOrgAddr->{line1} || undef,
					line2 => $insOrgAddr->{line2} || undef,
					city => $insOrgAddr->{city} || undef,
					state => $insOrgAddr->{state} || undef,
					zip => $insOrgAddr->{zip} || undef,
					_debug => 0
				);

			#Relationship to Insured --------------------
			my $relToCode = $personInsur->{rel_to_insured};
			my $relToCaption = $STMTMGR_INSURANCE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInsuredRelationship', $relToCode);
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Patient-Insured/Relationship",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $relToCaption || undef,
					value_int => $relToCode || undef,
					value_intB => 1,
					_debug => 0
				);

			#Insured Information --------------------
			my $insuredData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personInsur->{insured_id});
			my $insuredId = $insuredData->{person_id};
			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Name",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{complete_name} || undef,
					value_textB => $insuredId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Name/Last",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_last} || undef,
					value_textB => $insuredId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Name/First",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_first} || undef,
					value_textB => $insuredId || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Name/Middle",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{name_middle} || undef,
					value_textB => $insuredId || undef,
					value_intB => 1,
					_debug => 0
				) if $insuredData->{name_middle} ne '';

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Personal/Marital Status",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{marstat_caption} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Personal/Gender",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{gender_caption} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Personal/DOB",
					value_type => defined $dateValueType ? $dateValueType : undef,
					value_date => $insuredData->{date_of_birth} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Personal/SSN",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $insuredData->{ssn} || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Member Number",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $personInsur->{member_number} || undef,
					value_intB => 1,
					_debug => 0
				);

			#Insured's Contact Information
			my $insuredPhone = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_CACHE, 'selHomePhone', $personInsur->{insured_id});
			my $insuredAddr = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selHomeAddress', $personInsur->{insured_id});

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Contact/Home Phone",
					value_type => defined $phoneValueType ? $phoneValueType : undef,
					value_text => $insuredPhone || undef,
					value_intB => 1,
					_debug => 0
				);

			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => "$order Insured",
					line1 => $insuredAddr->{line1} || undef,
					line2 => $insuredAddr->{line2} || undef,
					city => $insuredAddr->{city} || undef,
					state => $insuredAddr->{state} || undef,
					zip => $insuredAddr->{zip} || undef,
					_debug => 0
				);



			#Insured's Employment Info
			my $employerName = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgSimpleNameById', $personInsur->{employer_org_id});

			$page->schemaAction(
					'Invoice_Attribute', $command,
					parent_id => $invoiceId,
					item_name => "Insurance/$order/Insured/Employer/Name",
					value_type => defined $textValueType ? $textValueType : undef,
					value_text => $employerName || undef,
					value_intB => 1,
					_debug => 0
				);


			my $insuredEmployerAddr = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selOrgAddressByAddrName', $personInsur->{employer_org_id}, 'Mailing');
			$page->schemaAction(
					'Invoice_Address', $command,
					parent_id => $invoiceId,
					address_name => "$order Insured Employer",
					line1 => $insuredEmployerAddr->{line1} || undef,
					line2 => $insuredEmployerAddr->{line2} || undef,
					city => $insuredEmployerAddr->{city} || undef,
					state => $insuredEmployerAddr->{state} || undef,
					zip => $insuredEmployerAddr->{zip} || undef,
					_debug => 0
				);

		}
	}
}

sub createActiveProbTrans
{
	my ($page, $command, $invoiceId, $invoice, $mainTransData) = @_;

	my $personValueType = App::Universal::ENTITYTYPE_PERSON;
	my $transStatActive = App::Universal::TRANSSTATUS_ACTIVE;
	my $todaysStamp = $page->getTimeStamp();

	my @icdCodes = split(/\s*,\s*/, $invoice->{claim_diags});
	foreach my $icdCode (@icdCodes)
	{
		$page->schemaAction(
				'Transaction', $command,
				trans_owner_type => defined $personValueType ? $personValueType : undef,
				trans_owner_id => $invoice->{client_id} || undef,
				parent_trans_id => $mainTransData->{trans_id} || undef,
				trans_type => App::Universal::TRANSTYPEDIAG_ICD,
				trans_status => defined $transStatActive ? $transStatActive : undef,
				init_onset_date => $mainTransData->{init_onset_date} || undef,
				curr_onset_date => $mainTransData->{curr_onset_date} || undef,
				billing_facility_id => $mainTransData->{billing_facility_id} || undef,
				service_facility_id => $mainTransData->{service_facility_id} || undef,
				code => $icdCode || undef,
				provider_id => $mainTransData->{provider_id} || undef,
				care_provider_id => $mainTransData->{care_provider_id} || undef,
				trans_begin_stamp => $todaysStamp || undef,
				_debug => 0
		);
	}
}


1;
