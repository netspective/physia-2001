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
use App::Utilities::Invoice;

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

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $invoiceId = $page->param('invoice_id');
	my $status = $STMTMGR_INVOICE->getSingleValue($page, STMTMGRFLAG_NONE, 'selInvoiceStatus', $invoiceId);

	if($status == App::Universal::INVOICESTATUS_CLOSED)
	{
		reopenInsuranceClaim($page, $invoiceId);
	}
	else
	{
		placeOnHold($page, $invoiceId, $page->param('transferred'));
	}

	$page->redirect("/invoice/$invoiceId/summary");
}

1;