##############################################################################
package App::Dialog::OnHold;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::InvoiceUtilities;
use App::Dialog::Field::Invoice;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP );
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP  = (
	'claim-hold' => {
		_arl_add => ['invoice_id'] },
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'onhold', heading => 'Place Claim On Hold');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Reason', name => 'reason', type => 'memo', cols => 25, rows => 4, options => FLDFLAG_REQUIRED),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $todaysDate = UnixDate('today', $page->defaultUnixDateFormat());
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInvoice', $invoiceId);

	#Delete auto writeoffs only if the claim was just submitted then placed on hold. Do not want to delete for other statuses passed submitted 
	#because at that point resubmission or submission to next payer may take place (so you don't want to change writeoff data).
	my $attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;
	if($invoice->{flags} & $attrDataFlag && $invoice->{invoice_status} == App::Universal::INVOICESTATUS_SUBMITTED)
	{
		my $items = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceItems', $invoiceId);
		foreach my $item (@{$items})
		{
			$STMTMGR_INVOICE->execute($page, STMTMGRFLAG_NONE, 'delAutoWriteoffAdjustmentsForItem', $item->{item_id});
		}
	}

	$page->schemaAction(
		'Invoice', 'update',
		invoice_id => $invoiceId,
		invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
		_debug => 0
	);


	## Add history item
	addHistoryItem($page, $invoiceId,
		value_text => 'On Hold',
		value_textB => $page->field('reason') || undef,
		value_date => $todaysDate,
	);


	$page->redirect("/invoice/$invoiceId/summary");
}

1;