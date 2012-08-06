##############################################################################
package App::Dialog::PostBatchPayment;
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
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'batch' => {heading => '$Command Batch'},
);

sub new
{
	my $self = CGI::Dialog::new(@_);

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'User ID', name => 'user_id', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(caption => 'Batch ID', name => 'batch_id', size => 12, options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(type => 'date', caption => 'Batch Date', name => 'batch_date', options => FLDFLAG_REQUIRED),
		#new CGI::Dialog::Field(type => 'select', selOptions => 'Insurance Payments:insurance;Personal Payments:personal', caption => 'Batch Type', name => 'batch_type'),
		new CGI::Dialog::Field(type => 'select',  name => 'batch_type',
				selOptions => 'Insurance Payments:insurance;Personal Payments:personal',
				caption => 'Batch Type',
				options => FLDFLAG_REQUIRED | FLDFLAG_PREPENDBLANK,
				onChangeJS => qq{showFieldsOnValues(event, ['insurance'], ['sel_invoice_id']); showFieldsOnValues(event, ['personal'], ['payer_id']); },),
		new CGI::Dialog::Field(caption => 'Invoice ID', name => 'sel_invoice_id', findPopup => '/lookup/claim',),# options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::ID(caption => 'Patient/Person ID', name => 'payer_id', ),#options => FLDFLAG_REQUIRED),

	);

	$self->addPostHtml(qq{
		<script language="JavaScript1.2">
		<!--
		if (opObj = eval('document.all._f_batch_type'))
		{
			if (opObj.selectedIndex == 0)
			{
				setIdDisplay('payer_id', 'none');
				setIdDisplay('sel_invoice_id', 'none');
			}
			if (opObj.selectedIndex == 1)
				setIdDisplay('payer_id', 'none');
			if (opObj.selectedIndex == 2)
				setIdDisplay('sel_invoice_id', 'none');
		}
		// -->
		</script>
	});


	$self->{activityLog} =
	{
		scope =>'invoice',
		key => "#field.sel_invoice_id#",
		data => "postbatchpayment to claim <a href='/invoice/#field.sel_invoice_id#/summary'>#field.sel_invoice_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $sessUser = $page->session('user_id');
	$page->field('user_id', $sessUser);

	return unless $flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL;

	$page->field('batch_id', $page->session('batch_id')) if $page->field('batch_id') eq '';

	my $batchType = $page->param('_p_batch_type');
	$page->field('batch_type', $batchType);

	#my $batchId = $page->param('_p_batch_id');
	#$page->field('batch_id', $batchId);
}

sub customValidate
{
	my ($self, $page) = @_;

	if($page->field('batch_type') eq 'insurance')
	{
		my $getInvoiceIdField = $self->getField('sel_invoice_id');
		my $invoiceId = $page->field('sel_invoice_id');
		unless($invoiceId)
		{
			$getInvoiceIdField->invalidate($page, 'Invoice ID is required. Cannot be blank.');
		}

		if(my $invoiceInfo = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId))
		{
			if($invoiceInfo->{invoice_subtype} == App::Universal::CLAIMTYPE_SELFPAY)
			{
				$getInvoiceIdField->invalidate($page, "Claim $invoiceId is 'Self-Pay'. Cannot apply insurance payment to this claim.");
			}
		}
		else
		{
			$getInvoiceIdField->invalidate($page, "Claim $invoiceId does not exist.");
		}
	}
	else
	{
		my $getPayerIdField = $self->getField('payer_id');
		my $payerId = $page->field('payer_id');
		unless($payerId)
		{
			$getPayerIdField->invalidate($page, 'Payer ID is required. Cannot be blank.');
		}
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $batchId = $page->field('batch_id');
	my $batchDate = $page->field('batch_date');
	my $batchType = $page->field('batch_type');
	my $invoiceId = $page->field('sel_invoice_id');
	my $payerId = $page->field('payer_id');
	my $sessOrg = $page->session('org_id');

	$page->session('batch_id', $batchId);

	if($batchType eq 'personal')
	{
		$page->param('_dialogreturnurl', "/org/$sessOrg/dlg-add-postpersonalpayment?_p_batch_id=$batchId&_p_batch_date=$batchDate&_payer_id=$payerId");
	}
	elsif($batchType eq 'insurance')
	{
		$page->param('_dialogreturnurl', "/org/$sessOrg/dlg-add-postinvoicepayment?paidBy=insurance&_p_batch_id=$batchId&_p_batch_date=$batchDate&_sel_invoice_id=$invoiceId");
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
