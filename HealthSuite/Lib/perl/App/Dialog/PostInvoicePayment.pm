##############################################################################
package App::Dialog::PostInvoicePayment;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Invoice;
use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'postinvoicepayment' => {},
	);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'postinvoicepayment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'orgpayer_internal_id'),
		new CGI::Dialog::Field(caption => 'Invoice ID', name => 'sel_invoice_id', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::MultiField(caption =>'Batch ID/Date', name => 'batch_fields',
			fields => [
				new CGI::Dialog::Field(caption => 'Batch ID', name => 'batch_id', size => 12),
				new CGI::Dialog::Field(type => 'date', caption => 'Batch Date', name => 'batch_date'),
			]),


		#fields for insurance payment

		new CGI::Dialog::Field::TableColumn(
							caption => 'Payer',
							schema => $schema,
							column => 'Invoice_Item_Adjust.payer_id',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
							options => FLDFLAG_REQUIRED),

		new CGI::Dialog::MultiField(caption => 'Check Amount/Number', name => 'check_fields',
			fields => [
					new CGI::Dialog::Field(caption => 'Check Amount', 
						name => 'check_amount',
						type => 'currency',
						options => FLDFLAG_REQUIRED,
					),
					new CGI::Dialog::Field::TableColumn(
						caption => 'Check Number/Pay Reference',
						schema => $schema,
						column => 'Invoice_Item_Adjust.pay_ref',
						type => 'text',
						readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
					]),

		
		#fields for personal payment

		new CGI::Dialog::Field(caption => 'Total Amount', 
			name => 'total_amount',
			type => 'currency',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field(
				name => 'pay_type',
				caption => 'Payment Type', 
				enum => 'Payment_Type'),

		new CGI::Dialog::MultiField(caption =>'Pay Method/Check No. or Auth. Code', name => 'pay_method_fields',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method'),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_ref',
							type => 'text')
						]),


		#list of items (used for both insurance and personal payments)

		new CGI::Dialog::Subhead(heading => 'Outstanding Items', name => 'outstanding_heading'),
		new App::Dialog::Field::OutstandingItems(name =>'outstanding_items_list'),
	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postinspayment claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $invoiceId = $page->param('invoice_id') || $page->field('sel_invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	my $paidBy = $page->param('paidBy');
	my $isPersonal = $paidBy eq 'personal';
	my $isInsurance = $paidBy eq 'insurance';

	$page->param('_p_batch_id') ? $self->heading('Add Batch Insurance Payments') : $self->heading("Add \u$paidBy Payment");

	if(! $invoiceId || $isInsurance && $invoiceInfo->{invoice_subtype} == App::Universal::CLAIMTYPE_SELFPAY)
	{
		if($invoiceId)
		{
			$self->getField('sel_invoice_id')->invalidate($page, "Claim $invoiceId is 'Self-Pay'. Cannot apply insurance payment to this claim.");
		}

		$self->updateFieldFlags('payer_id', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('total_amount', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('pay_type', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('check_fields', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->updateFieldFlags('outstanding_items_list', FLDFLAG_INVISIBLE, 1);
	}
	elsif($invoiceId)
	{
		$self->updateFieldFlags('sel_invoice_id', FLDFLAG_READONLY, 1);
		$self->updateFieldFlags('total_amount', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_type', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, $isInsurance);
		$self->updateFieldFlags('check_fields', FLDFLAG_INVISIBLE, $isPersonal);
	}

	my $batchId = $page->param('_p_batch_id') || $page->field('batch_id');
	my $batchDate = $page->param('_p_batch_date') || $page->field('batch_date');
	if( $batchId && $batchDate )
	{
		$self->setFieldFlags('batch_fields', FLDFLAG_READONLY, 1);
	}

	$self->getField('pay_type')->{fKeyWhere} = "group_name is NULL or group_name = '$paidBy'";
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $invoiceId = $page->param('invoice_id') || $page->field('sel_invoice_id');
	$page->field('sel_invoice_id', $invoiceId);
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	my $paidBy = $page->param('paidBy');
	if($paidBy eq 'insurance')
	{
		my $primaryPayer = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoiceBillingPrimary', $invoiceId);
		my $billToId = $primaryPayer->{bill_to_id};
		if($primaryPayer->{bill_party_type} == App::Universal::INVOICEBILLTYPE_THIRDPARTYINS || $primaryPayer->{bill_party_type} == App::Universal::INVOICEBILLTYPE_THIRDPARTYORG)
		{
			my $orgId = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selRegistry', $billToId);
			$page->field('payer_id', $orgId->{org_id});
			$page->field('orgpayer_internal_id', $billToId);
		}
	}
	elsif($paidBy eq 'personal')
	{	
		$page->field('payer_id', $invoiceInfo->{client_id});
	}

	if(my $batchId = $page->param('_p_batch_id'))
	{
		my $batchDate = $page->param('_p_batch_date');
		$page->field('batch_id', $batchId);
		$page->field('batch_date', $batchDate);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	my $batchIdField = $self->getField('batch_fields')->{fields}->[0];
	my $batchDateField = $self->getField('batch_fields')->{fields}->[1];
	unless($page->param('_p_batch_id') || $page->field('batch_id'))
	{
		$batchIdField->invalidate($page, "Please provide a '$batchIdField->{caption}'");
	}
	unless($page->param('_p_batch_date') || $page->field('batch_date'))
	{
		$batchDateField->invalidate($page, "Please provide a '$batchDateField->{caption}'");
	}

	my $invoiceId = $page->param('invoice_id') || $page->field('sel_invoice_id');
	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	#if($page->param('paidBy') eq 'insurance' && $invoiceInfo->{invoice_subtype} == App::Universal::CLAIMTYPE_SELFPAY)
	#{
	
	#}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $paidBy = $page->param('paidBy');
	my $invoiceId = $page->param('invoice_id') || $page->field('sel_invoice_id');

	my $todaysDate = $page->getDate();
	my $payerType = $paidBy eq 'insurance' ? App::Universal::ENTITYTYPE_ORG : App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $payMethod = $paidBy eq 'insurance' ? App::Universal::ADJUSTMENTPAYMETHOD_CHECK : $page->field('pay_method');
	my $payerId = $paidBy eq 'insurance' ? $page->field('orgpayer_internal_id') : $page->field('payer_id');
	my $payRef = $page->field('pay_ref');
	my $payType = $page->field('pay_type');


	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $planPaid = $page->param("_f_item_$line\_plan_paid");
		my $amtApplied = $page->param("_f_item_$line\_amount_applied");
		my $writeoffAmt = $page->param("_f_item_$line\_writeoff_amt");
		next if $planPaid eq '' && $writeoffAmt eq '' && $amtApplied eq '';


		# Update item
		my $totalAdjsMade = $planPaid + $amtApplied + $writeoffAmt;
		my $totalItemAdjust = $page->param("_f_item_$line\_item_existing_adjs") - $totalAdjsMade;
		my $itemBalance = $page->param("_f_item_$line\_item_balance") - $totalAdjsMade;
		my $itemId = $page->param("_f_item_$line\_item_id");
		$page->schemaAction(
			'Invoice_Item', 'update',
			item_id => $itemId,
			total_adjust => defined $totalItemAdjust ? $totalItemAdjust : undef,
			balance => defined $itemBalance ? $itemBalance : undef,
			_debug => 0
		);


		
		# Create adjustment for the item
		my $planAllow = $page->param("_f_item_$line\_plan_allow");
		my $writeoffCode = $page->param("_f_item_$line\_writeoff_code");
		$writeoffCode = $writeoffAmt eq '' || $writeoffCode == App::Universal::ADJUSTWRITEOFF_FAKE_NONE ? undef : $writeoffCode;

		my $netAdjust = 0 - $totalAdjsMade;
		my $comments = $page->param("_f_item_$line\_comments");
		my $adjItemId = $page->schemaAction(
			'Invoice_Item_Adjust', 'add',
			adjustment_type => defined $adjType ? $adjType : undef,
			adjustment_amount => defined $amtApplied ? $amtApplied : undef,
			parent_id => $itemId || undef,
			plan_allow => $planAllow || undef,
			plan_paid => $planPaid || undef,
			pay_date => $todaysDate,
			pay_type => defined $payType ? $payType : undef,
			pay_method => defined $payMethod ? $payMethod : undef,
			pay_ref => $payRef || undef,
			payer_type => defined $payerType ? $payerType : undef,
			payer_id => $payerId || undef,
			writeoff_code => defined $writeoffCode ? $writeoffCode : 'NULL',
			writeoff_amount => $writeoffAmt || undef,
			net_adjust => defined $netAdjust ? $netAdjust : undef,
			comments => $comments || undef,
			_debug => 0
		);


		#Create history attribute for this adjustment
		my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
		my $itemCPT = $page->param("_f_item_$line\_item_adjustments");
		my $payerIdDisplay = $page->field('payer_id');
		my $description = "\u$paidBy payment made by '$payerIdDisplay'";
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => $description,
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
		);

		#Create attribute for batchId
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/Payment/Batch ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $page->field('batch_id') || undef,
			value_date => $page->field('batch_date') || undef,
			value_int => $adjItemId || undef,
			_debug => 0
		);
	}



	#Update the invoice
	my $updatedLineItems = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
	my $totalAdjustForInvoice = 0;
	foreach my $item (@{$updatedLineItems})
	{
		$totalAdjustForInvoice += $item->{total_adjust};
	}

	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
	my $invoiceBalance = $invoice->{total_cost} + $totalAdjustForInvoice;
	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId || undef,
		total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
		balance => defined $invoiceBalance ? $invoiceBalance : undef,
		_debug => 0
	);


	$page->redirect("/invoice/$invoiceId/summary");
}

1;
