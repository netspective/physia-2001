##############################################################################
package App::Dialog::PostGeneralPayment;
##############################################################################

use strict;
use Carp;

use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Catalog;
use App::Statements::Insurance;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Dialog::Field::Invoice;
use App::Universal;
use App::Dialog::Field::BatchDateID;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'postpersonalpayment' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, heading => 'Add Personal Payment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'list_invoices'),
		new App::Dialog::Field::BatchDateID(caption => 'Batch ID Date', name => 'batch_fields',listInvoiceFieldName=>'list_invoices'),

		new App::Dialog::Field::Person::ID(caption => 'Patient/Person Id', name => 'payer_id', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(type => 'currency',
					caption => 'Total Payment Received',
					name => 'total_amount',
					options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(
					name => 'pay_type',
					caption => 'Payment Type', 
					enum => 'Payment_Type', 
					fKeyWhere => "group_name is NULL or group_name = 'personal'"),

		new CGI::Dialog::MultiField(caption =>'Payment Method/Check Number', name => 'pay_method_fields',
			fields => [
				new CGI::Dialog::Field::TableColumn(
							schema => $schema,
							column => 'Invoice_Item_Adjust.pay_method'),
				new CGI::Dialog::Field(caption => 'Check Number', name => 'pay_ref'),
				]),

		new CGI::Dialog::Field(caption => 'Authorization/Reference Number', name => 'auth_ref'),


		new CGI::Dialog::Subhead(heading => 'Outstanding Invoices', name => 'outstanding_heading'),
		new App::Dialog::Field::OutstandingInvoices(name =>'outstanding_invoices_list'),

	);
	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#param.invoice_id#",
		data => "postpayment '#param.item_id#' claim <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	#make payment fields and list of invoices invisible unless person id exists
	$self->setFieldFlags('payer_id', FLDFLAG_READONLY, 1);
	unless(my $personId = $page->param('person_id') || $page->field('payer_id'))
	{
		$self->updateFieldFlags('payer_id', FLDFLAG_READONLY, 0);
		$self->setFieldFlags('batch_fields', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('total_amount', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('pay_type', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('pay_method_fields', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('auth_ref', FLDFLAG_INVISIBLE, 1);	
		$self->setFieldFlags('outstanding_heading', FLDFLAG_INVISIBLE, 1);
		$self->setFieldFlags('outstanding_invoices_list', FLDFLAG_INVISIBLE, 1);

	}

	my $batchId = $page->param('_p_batch_id') || $page->field('batch_id');
	my $batchDate = $page->param('_p_batch_date') || $page->field('batch_date');
	if( $batchId && $batchDate )
	{
#		$self->setFieldFlags('batch_fields', FLDFLAG_READONLY, 1);
	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	if(my $batchId = $page->param('_p_batch_id'))
	{
		my $batchDate = $page->param('_p_batch_date');
		$page->field('batch_id', $batchId);
		$page->field('batch_date', $batchDate);
	}

	my $personId = $page->param('person_id');
	$page->field('payer_id', $personId);
}

sub customValidate
{
	my ($self, $page) = @_;
	my $lineCount = $page->param('_f_line_count');
	my $list='';
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		my $payAmt = $page->param("_f_invoice_$line\_payment");
		my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");
		next if $payAmt eq '';		
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
	my $payerType = App::Universal::ENTITYTYPE_PERSON;
	my $adjType = App::Universal::ADJUSTMENTTYPE_PAYMENT;
	my $textValueType = App::Universal::ATTRTYPE_TEXT;

	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $payerId = $page->field('payer_id');
	my $payMethod = $page->field('pay_method');
	my $payType = $page->field('pay_type');
	my $payRef = $page->field('pay_ref');
	my $authRef = $page->field('auth_ref');

	if($page->field('total_amount') > 0)
	{
		my $lineCount = $page->param('_f_line_count');
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			my $payAmt = $page->param("_f_invoice_$line\_payment");
			next if $payAmt eq '';

			my $totalAdjustForItemAndItemAdjust = 0 - $payAmt;

			my $invoiceId = $page->param("_f_invoice_$line\_invoice_id");

			#my $itemBalance = $totalAdjustForItemAndItemAdjust;	# because this is a "dummy" item that is made for the sole purpose of applying a general
																# payment, there is no charge and the balance should be negative.
			my $itemId = $page->schemaAction(
				'Invoice_Item', 'add',
				parent_id => $invoiceId,
				item_type => defined $itemType ? $itemType : undef,
				#total_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
				#balance => defined $itemBalance ? $itemBalance : undef,
				_debug => 0
			);




			# Create adjustment for the item
			my $comments = $page->param("_f_invoice_$line\_comments");
			my $adjItemId = $page->schemaAction(
				'Invoice_Item_Adjust', 'add',
				adjustment_type => defined $adjType ? $adjType : undef,
				adjustment_amount => defined $payAmt ? $payAmt : undef,
				parent_id => $itemId || undef,
				pay_date => $todaysDate || undef,
				pay_method => defined $payMethod ? $payMethod : undef,
				pay_ref => $payRef || undef,
				payer_type => $payerType || 0,
				payer_id => $payerId || undef,
				#net_adjust => defined $totalAdjustForItemAndItemAdjust ? $totalAdjustForItemAndItemAdjust : undef,
				data_text_a => $authRef || undef,
				pay_type => defined $payType ? $payType : undef,
				comments => $comments || undef,
				_debug => 0
			);

			#Update the invoice

			my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);
			my $invoiceBalance = $invoice->{total_cost} + ($invoice->{total_adjust} + (0 - $payAmt));
			$page->schemaAction(
				'Invoice', 'update',
				invoice_id => $invoiceId || undef,
				invoice_status => $invoiceBalance == 0 ? App::Universal::INVOICESTATUS_CLOSED : App::Universal::INVOICESTATUS_PAYAPPLIED,
				#total_adjust => defined $totalAdjustForInvoice ? $totalAdjustForInvoice : undef,
				#balance => defined $invoiceBalance ? $invoiceBalance : undef,
				_debug => 0
			);


			#Create history attribute for this adjustment
			$page->schemaAction(
				'Invoice_Attribute', 'add',
				parent_id => $invoiceId || undef,
				item_name => 'Invoice/History/Item',
				value_type => defined $historyValueType ? $historyValueType : undef,
				value_text => "Personal payment made by $payerId",
				value_textB => $comments || undef,
				value_date => $todaysDate,
				_debug => 0
			);

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

			if($invoiceBalance == 0)
			{
				$page->schemaAction(
					'Invoice_Attribute', 'add',
					parent_id => $invoiceId || undef,
					item_name => 'Invoice/History/Item',
					value_type => defined $historyValueType ? $historyValueType : undef,
					value_text => 'Closed',
					value_date => $todaysDate,
					_debug => 0
				);
				
				App::Dialog::Procedure::execAction_submit($page, 'add', $invoiceId);
			}
		}
	}
	
	$page->redirect("/person/$payerId/account");
}

1;
