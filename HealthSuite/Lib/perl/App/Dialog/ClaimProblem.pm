##############################################################################
package App::Dialog::ClaimProblem;
##############################################################################

use DBI::StatementManager;
use App::Statements::Invoice;
use strict;
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
	my ($self, $command) = CGI::Dialog::new(@_, id => 'problem', heading => 'Report Problem with this Claim');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(
			caption => 'Problem',
			name => 'problem',
			type => 'select',
			selOptions => "Patient to Subscriber relationship is invalid;Patient's social security number is invalid;
							Patient's sex does not match ICD9 or CPT;No group number;Invalid CPT;Incomplete ICD9 (missing 5th digit)",
			options => FLDFLAG_REQUIRED),
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

	$page->schemaAction(
			'Invoice_Attribute', $command,
			parent_id => $invoiceId,
			item_name => 'Invoice/Problem',
			value_type => App::Universal::ATTRTYPE_TEXT,
			value_text => $page->field('problem') || undef,
			_debug => 0
	);

	#$page->redirect("/invoice/$invoiceId/summary");
	$self->handlePostExecute($page, $command, $flags);

}

use constant CLAIMPROBLEM_DIALOG => 'Dialog/ClaimProblem';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/10/2000', 'MAF',
		CLAIMPROBLEM_DIALOG,
		'Created new dialog for reporting problems with claims.'],
);

1;