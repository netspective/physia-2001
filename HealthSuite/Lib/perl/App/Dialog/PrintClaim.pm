##############################################################################
package App::Dialog::PrintClaim;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP );
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP  = (
	'printclaim' => {
		_arl_add => ['invoice_id'] },
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'printclaim', heading => 'View/Print Claim');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(type => 'select', selOptions => 'View claim;Print Claim', caption => 'I intend to', name => 'action', options => FLDFLAG_REQUIRED),
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

	my $action = $page->field('action');
	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => $action || undef,
			#value_textB => $page->field('reason') || undef,
			value_date => $todaysDate,
			_debug => 0
	);

	if($action eq 'View claim')
	{
		$page->redirect("/invoice/$invoiceId/1500");
	}
	else
	{
		$page->redirect("/invoice-f/$invoiceId/1500pdfplain");
	}
}

1;