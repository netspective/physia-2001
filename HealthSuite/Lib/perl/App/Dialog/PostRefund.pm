##############################################################################
package App::Dialog::PostRefund;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Invoice;
use App::Dialog::Field::BatchDateID;
use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
'postrefund' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'adjustment', heading => 'Post Refund');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',listInvoiceFieldName=>'list_invoices'),		
		new App::Dialog::Field::CreditInvoices(name =>'credit_invoices_list'),
		new CGI::Dialog::Field(type => 'hidden', name => 'list_invoices'),
	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postrefund '#param.item_id#' claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub customValidate
{
	my ($self, $page) = @_;
	my $lineCount = $page->param('_f_line_count');
	my $list='';
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $refundAmt = 0 - $page->param("_f_invoice_$line\_refund");
		next if $refundAmt eq '';
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");	
		$list .= $invoiceId.",";		
	}
	$page->field('list_invoices',$list);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	$command = 'add';

	my $todaysDate = $page->getDate();
	my $itemType = App::Universal::INVOICEITEMTYPE_ADJUST;
	my $historyValueType = App::Universal::ATTRTYPE_HISTORY;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;
	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');

	#apply refund
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $refundAmt = 0 - $page->param("_f_invoice_$line\_refund");
		next if $refundAmt == 0;
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");

		my $invoiceBalance = $page->param("_f_invoice_$line\_invoice_balance");
		if($invoiceBalance == 0)
		{
			$page->schemaAction(
				'Invoice', 'update',
				invoice_id => $invoiceId || undef,
				invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
				flags => 0,
				_debug => 0
			);

			$page->schemaAction(
				'Invoice_Attribute', 'add',
				parent_id => $invoiceId || undef,
				item_name => 'Invoice/History/Item',
				value_type => defined $historyValueType ? $historyValueType : undef,
				value_text => 'Reopened due to refund',
				value_date => $todaysDate,
				_debug => 0
			);
		}


		my $totalAdjustForItemAndItemAdjust = $refundAmt;
		my $itemBalance = $totalAdjustForItemAndItemAdjust;	# because this is a "dummy" item that is made for the sole purpose of applying a general
															# payment, there is no charge and the balance should be negative.
		my $itemId = $page->schemaAction(
				'Invoice_Item', 'add',
				parent_id => $invoiceId,
				item_type => defined $itemType ? $itemType : undef,
				total_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
				_debug => 0
			);




		# Create adjustment for the item

		my $adjType = App::Universal::ADJUSTMENTTYPE_REFUND;
		my $comments = $page->param("_f_invoice_$line\_comments");
		my $refundToId = $page->param("_f_invoice_$line\_refund_to_id");
		my $refundToType = $page->param("_f_invoice_$line\_refund_to_type") eq 'person' ? App::Universal::ENTITYTYPE_PERSON : App::Universal::ENTITYTYPE_ORG;
		my $adjItemId = $page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				adjustment_type => defined $adjType ? $adjType : undef,
				adjustment_amount => defined $refundAmt ? $refundAmt : undef,
				parent_id => $itemId || undef,
				refund_to_type => defined $refundToType ? $refundToType : undef,
				refund_to_id => $refundToId || undef,
				pay_date => $todaysDate || undef,
				comments => $comments || undef,
				_debug => 0
			);



		#Add batch attribute
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/Payment/Batch ID',
			value_type => defined $textValueType ? $textValueType : undef,
			value_text => $batchId || undef,
			value_date => $batchDate || undef,
			value_int => $adjItemId || undef,
			_debug => 0
		);


		#Create history attribute for this adjustment
		$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId || undef,
			item_name => 'Invoice/History/Item',
			value_type => defined $historyValueType ? $historyValueType : undef,
			value_text => "Refunded \$$refundAmt to $refundToId",
			value_textB => $comments || undef,
			value_date => $todaysDate,
			_debug => 0
		);
	}


	my $personId = $page->param('person_id');
	$page->redirect("/person/$personId/account");
}

1;
