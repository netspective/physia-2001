##############################################################################
package App::Dialog::StatusChanger;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Utilities::Invoice;

use vars qw(@ISA %RESOURCE_MAP );
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP  = (
	'change-status' => {
		_arl_add => ['invoice_id'] },
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'change-status', heading => 'Change Claim Status');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(caption => 'Invoice ID', name => 'invoice_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(
				caption => 'Change invoice to status:',
				name => 'status',
				fKeyStmtMgr => $STMTMGR_INVOICE,
				fKeyStmt => 'selStatusList',
				fKeyDisplayCol => 1,
				fKeyValueCol => 0,
				options => FLDFLAG_REQUIRED),
		);

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $invoiceId = $page->param('invoice_id');
	$page->field('invoice_id', $invoiceId);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->field('invoice_id');
	changeInvoiceStatus($page, $invoiceId, $page->field('status'));

	$page->redirect("/invoice/$invoiceId/summary");
}

1;