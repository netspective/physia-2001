##############################################################################
package App::Dialog::InvoiceWorklist::Claims::ReckDate;
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
	'reckdate-claims-wl-invoice' => {
		_arl => ['invoice_id'],
	},
);

my $WORKLIST_TYPE = 'CLAIMS';
my $RECKDDATE_STATUS = 'RECK DATE';

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-claims-wl-invoice', heading => 'Reck Date');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!
	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Invoice ID',
			name => 'invoice_id',
			options => FLDFLAG_READONLY,
		),
		new CGI::Dialog::Field(caption => 'User ID',
			name => 'user_id',
			options => FLDFLAG_READONLY,
		),
		new App::Dialog::Field::Scheduling::Date(caption => 'Reck Date',
			name => 'reck_date',
			type => 'date',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Comments',
			name => 'comments',
			type => 'memo',
		),
		new CGI::Dialog::Field(type => 'hidden', name => 'owner_id'),
	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'invoice_worklist',
		key => "#field.invoice_id#",
		data => "ReckDate Claims Work List Invoice <a href='/invoice/#field.invoice_id#/history'> #field.invoice_id# </a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $userId = $page->session('user_id');

	my $invWorklist = $STMTMGR_WORKLIST_CLAIM->getRowAsHash($page, STMTMGRFLAG_CACHE,
		'sel_invoice_worklist_item_by_person', $page->param('invoice_id'), $WORKLIST_TYPE,
		$userId, $RECKDDATE_STATUS);

	$page->field('invoice_id', $page->param('invoice_id'));
	$page->field('user_id', $userId);
	$page->field('reck_date', $invWorklist->{formatted_reck_date});
	$page->field('comments', $invWorklist->{comments});
	$page->field('owner_id', $invWorklist->{owner_id});
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	my $invoiceId = $page->field('invoice_id');
	my $invoice = $STMTMGR_INVOICE->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selInvoice', $invoiceId);

	my $invWorklist = $STMTMGR_WORKLIST_CLAIM->getRowAsHash($page, STMTMGRFLAG_CACHE,
		'sel_invoice_worklist_item_by_person', $page->param('invoice_id'), $WORKLIST_TYPE,
		$page->session('user_id'), $RECKDDATE_STATUS);

	my $invoiceWorklistId = undef;
	if (defined $invWorklist)
	{
		$command = 'update';
		$invoiceWorklistId = $invWorklist->{invoice_worklist_id};
	}
	else
	{
		$command = 'add';
	}

	$page->schemaAction(
		'Invoice_Worklist', $command,
		invoice_worklist_id => $invoiceWorklistId,
		owner_id => $page->field('owner_id') || undef,
		responsible_id => $page->field('user_id'),
		person_id => $invoice->{client_id} || undef,
		org_internal_id => $page->session('org_internal_id'),
		invoice_id => $invoiceId,
		parent_invoice_id => $invoice->{parent_invoice_id} || undef,
		reck_date => $page->field('reck_date'),
		worklist_status => $RECKDDATE_STATUS,
		worklist_type => $WORKLIST_TYPE,
		comments => $page->field('comments') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
