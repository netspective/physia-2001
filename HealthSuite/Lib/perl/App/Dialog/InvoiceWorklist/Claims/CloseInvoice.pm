##############################################################################
package App::Dialog::InvoiceWorklist::Claims::CloseInvoice;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;

use App::Statements::Worklist::Claim;
use App::Statements::Invoice;
use Date::Manip;
use vars qw(%RESOURCE_MAP);

use base qw(CGI::Dialog);

%RESOURCE_MAP=(
	'close-claims-wl-invoice' => {
		_arl => ['invoice_id'],
	},
);

my $CLOSED_STATUS = 'CLOSED';
my $WORKLIST_TYPE = 'CLAIMS';

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-claims-wl-invoice', heading => 'Close Invoice');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Date',
			name => 'date',
			options => FLDFLAG_READONLY,
		),
		new CGI::Dialog::Field(caption => 'Invoice ID',
			name => 'invoice_id',
			options => FLDFLAG_READONLY,
		),
		new CGI::Dialog::Field(caption => 'User ID',
			name => 'user_id',
			options => FLDFLAG_READONLY,
		),
		new CGI::Dialog::Field(caption => 'Comments',
			name => 'comments',
			type => 'memo',
		),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'invoice_worklist',
		key => "#field.invoice_id#",
		data => "Close Claims Work List Invoice <a href='/invoice/#field.invoice_id#/history'> #field.invoice_id# </a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	$page->field('invoice_id', $page->param('invoice_id'));
	$page->field('user_id', $page->session('user_id'));
	$page->field('date', $page->getDate());
}

sub handle_page
{
	my ($self, $page, $command) = @_;

	my $invWorklist = $STMTMGR_WORKLIST_CLAIM->getRowAsHash($page, STMTMGRFLAG_CACHE,
		'sel_invoice_worklist_item', $page->param('invoice_id'), $WORKLIST_TYPE, $CLOSED_STATUS);

	if (defined $invWorklist)
	{
		$page->addContent(qq{
			<font face=Verdana size=3>
			Invoice <b>$invWorklist->{invoice_id}</b> was closed on $invWorklist->{close_date} by
			$invWorklist->{responsible_id}.  Click <a href="javascript:history.back()" ><b>here</b></a> to go back.
		});
	}
	else
	{
		$self->SUPER::handle_page($page, $command);
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $invoiceId = $page->field('invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);

	$page->schemaAction(
		'Invoice_Worklist', 'add',
		invoice_worklist_id => undef,
		responsible_id => $page->field('user_id'),
		person_id => $invoice->{client_id} || undef,
		org_internal_id => $page->session('org_internal_id'),
		invoice_id => $invoiceId,
		parent_invoice_id => $invoice->{parent_invoice_id} || undef,
		data_date_a => $page->field('date'),
		worklist_status => $CLOSED_STATUS,
		worklist_type => $WORKLIST_TYPE,
		comments => $page->field('comments') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
