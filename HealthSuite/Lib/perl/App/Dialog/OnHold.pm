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
use App::Dialog::Field::Invoice;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

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

	$page->schemaAction(
			'Invoice', 'update',
			invoice_id => $invoiceId,
			invoice_status => App::Universal::INVOICESTATUS_ONHOLD,
			_debug => 0
		);

	$page->schemaAction(
			'Invoice_Attribute', 'add',
			parent_id => $invoiceId,
			item_name => 'Invoice/History/Item',
			value_type => App::Universal::ATTRTYPE_HISTORY,
			value_text => 'On Hold',
			value_textB => $page->field('reason') || undef,
			value_date => $todaysDate,
			_debug => 0
	);

	#$page->redirect("/invoice/$invoiceId/summary");
	$self->handlePostExecute($page, $command, $flags);

}

use constant ONHOLD_DIALOG => 'Dialog/OnHold';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/10/2000', 'MAF',
		ONHOLD_DIALOG,
		'Created new dialog for placing claim on hold.'],
);

1;