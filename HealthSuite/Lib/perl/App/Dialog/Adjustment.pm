##############################################################################
package App::Dialog::Adjustment;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
#use App::Dialog::Field::Adjustment;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'adjustment', heading => 'Make Adjustment');

	#my $id = $self->{'id'}; 	# id = 'insur_pay' | 'personal_pay'

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::MultiField(caption =>'Adjustment Type/Amount', name => 'adjust_info',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.adjustment_type',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.adjustment_amount',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::Field::TableColumn(
							caption => 'Adjustment Type',
							schema => $schema,
							column => 'Invoice_Item_Adjust.adjustment_type',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field::TableColumn(
							caption => 'Payer',
							schema => $schema,
							column => 'Invoice_Item_Adjust.payer_id',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::MultiField(caption =>'Plan Allow/Paid', name => 'plan_info',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.plan_allow',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.plan_paid',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::MultiField(caption =>'Pay Date/Type',
			fields => [
				new CGI::Dialog::Field(caption => 'Pay Date', name => 'pay_date', type => 'date', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_type',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::MultiField(caption =>'Pay Method/Check No. or Auth. Code',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_ref',
							type => 'text',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::MultiField(caption =>'Writeoff Amount/Code',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.writeoff_amount',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.writeoff_code',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE)
						]),

		new CGI::Dialog::Field::TableColumn(
							caption => 'Adjustment Codes',
							schema => $schema,
							column => 'Invoice_Item_Adjust.adjust_codes',
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

		new CGI::Dialog::Field(caption => 'Comments', name => 'comments', type => 'memo', cols => 25, rows => 4, readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),

	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "adjustment '#param.item_id#' to claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	my $payType = $page->param('payment');

	my $isPersonal = $payType eq 'personal';
	my $isInsurance = $payType eq 'insurance';

	$self->heading("Make \u$payType Payment");

	$self->updateFieldFlags('adjust_info', FLDFLAG_INVISIBLE, $isInsurance);
	$self->updateFieldFlags('plan_info', FLDFLAG_INVISIBLE, $isPersonal);
	$self->updateFieldFlags('adjust_codes', FLDFLAG_INVISIBLE, $isPersonal);
	$self->updateFieldFlags('adjustment_type', FLDFLAG_INVISIBLE, $isPersonal);
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id');

	my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page,STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);
	$page->param('payment') eq 'insurance' ? $page->field('payer_id', $invoiceInfo->{bill_to_id}) : $page->field('payer_id', $invoiceInfo->{client_id});


	return unless $itemId;


	my $indivItem = $STMTMGR_INVOICE->getRowAsHash($page,STMTMGRFLAG_NONE, 'selInvoiceItem', $itemId);

	my $adjustTotal = $indivItem->{total_adjust};

	my $font = "<font size=2 face='arial,helvetica'>";

	my $fromDate = $indivItem->{data_date_a};
	my $toDate = $indivItem->{data_date_b} eq $fromDate ? '' : "- $indivItem->{data_date_b}";
	my $emg = $indivItem->{data_text_a} == 1 ? 'Yes' : 'No';

	my $cptCaption = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selGenericCPTCode', $indivItem->{code});

	my $modCaption = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selModifierCode', $indivItem->{modifier});

	my $servPlaceCaption = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServicePlace', $indivItem->{data_num_a});
	my $servTypeCaption = $STMTMGR_CATALOG->getSingleValue($page, STMTMGRFLAG_CACHE, 'selGenericServiceType', $indivItem->{data_num_b});

	$self->addPreHtml(qq{
					<table cellspacing=0 border=0>
						<tr>
							<td align=right>$font Service:</td>
							<td>$font $fromDate $toDate ($servPlaceCaption, Type $indivItem->{data_num_b})</td>
						</tr>
						<tr>
							<td align=right>$font Diagnoses:</td>
							<td>$font $indivItem->{rel_diags}</td>
						</tr>
						<tr>
							<td align=right valign=top>$font Procedure:</td>
							<td>$font $indivItem->{code} - $cptCaption->{name} (Modf $modCaption), EMG: $emg</td>
						</tr>
						<tr>
							<td align=right>$font Charge:</td>
							<td>$font \$$indivItem->{extended_cost} (\$$indivItem->{unit_cost} * $indivItem->{quantity}),
								Adj: \$$adjustTotal
							</td>
						</tr>
						<tr>
							<td align=right>&nbsp;</td>
							<td>$font $indivItem->{data_text_b}</td>
						</tr>
					</table>
	});
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $itemId = $page->param('item_id') ne '' ? $page->param('item_id') : '';
	my $todaysDate = $page->getDate();
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;

	if($page->field('adjustment_amount') ne '' || $page->field('writeoff_amount') ne '' || $page->field('plan_paid') ne '')
	{
		if($itemId eq '')
		{
			## Create Invoice Item, with item type = 0 (INVOICE) if no item id was passed in
			## (adjustment is being made to entire claim)

			my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
			my $totalDummyItems = $STMTMGR_INVOICE->getRowCount($page, STMTMGRFLAG_NONE, 'selInvoiceItemCountByType', $invoiceId, $itemType);
			my $itemSeq = $totalDummyItems + 1;

			$itemId = $page->schemaAction(
					'Invoice_Item', 'add',
					parent_id => $invoiceId,
					item_type => $itemType,
					data_num_c => $itemSeq,
					_debug => 0
				);
		}




		#Create the adjustment for the item

		my $payerIs = $page->param('payment');

		my $payerId = $page->field('payer_id');
		my $payerType = App::Universal::ENTITYTYPE_PERSON if $payerIs eq 'personal';
		$payerType = App::Universal::ENTITYTYPE_ORG if $payerIs eq 'insurance';

		my $adjType = $page->field('adjustment_type');
		my $payType = $page->field('pay_type');
		my $payMethod = $page->field('pay_method');
		my $netAdjust = 0 - $page->field('adjustment_amount') - $page->field('plan_paid') - $page->field('writeoff_amount');

		$page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				adjustment_type => defined $adjType ? $adjType : undef,
				adjustment_amount => $page->field('adjustment_amount') || undef,
				parent_id => $itemId || undef,
				plan_allow => $page->field('plan_allow') || undef,
				plan_paid => $page->field('plan_paid') || undef,
				pay_date => $page->field('pay_date') || undef,
				pay_type => defined $payType ? $payType : undef,
				pay_method => defined $payMethod ? $payMethod : undef,
				pay_ref => $page->field('pay_ref') || undef,
				payer_type => defined $payerType ? $payerType : undef,
				payer_id => $payerId || undef,
				writeoff_code => $page->field('writeoff_code') || undef,
				writeoff_amount => $page->field('writeoff_amount') || undef,
				net_adjust => defined $netAdjust ? $netAdjust : undef,
				adjust_codes => $page->field('adjust_codes') || undef,
				comments => $page->field('comments') || undef,
				_debug => 0
			);




		#Update the item that was passed in or the dummy item just created

		my $invItem = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoiceItem', $itemId);

		my $totalAdjustForItem = $invItem->{total_adjust} + $netAdjust;
		my $balance = $invItem->{extended_cost} + $totalAdjustForItem;

		$page->schemaAction(
				'Invoice_Item', 'update',
				item_id => $itemId || undef,
				total_adjust => defined $totalAdjustForItem ? $totalAdjustForItem : undef,
				balance => defined $balance ? $balance : undef,
				_debug => 0
			);




		#Update the invoice

		my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);

		my $totalAdjustForInvoice = $invoice->{total_adjust} + $netAdjust;
		$balance = $invoice->{total_cost} + $totalAdjustForInvoice;

		$page->schemaAction(
				'Invoice', 'update',
				invoice_id => $invoiceId || undef,
				total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
				balance => defined $balance ? $balance : undef,
				_debug => 0
			);



		#Create history attribute for this adjustment

		$payerIs = "\u$payerIs";
		my $description = "$payerIs payment/adjustment made";

		$page->schemaAction(
				'Invoice_Attribute', 'add',
				parent_id => $invoiceId || undef,
				item_name => 'Invoice/History/Item',
				value_type => defined $historyValueType ? $historyValueType : undef,
				value_text => $description,
				value_textB => $page->field('comments') || undef,
				value_date => $todaysDate,
				_debug => 0
			);
	}

	$self->handlePostExecute($page, $command, $flags);

}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#
use constant ADJUST_DIALOG => 'Dialog/Adjustment';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '12/15/1999', 'MAF',
		ADJUST_DIALOG,
		'Fixed item_type of "dummy" invoice items.'],
);

1;
