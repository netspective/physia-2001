##############################################################################
package App::Dialog::Transaction::ClaimNotes;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
my $CLAIM_NOTES = App::Universal::TRANSTYPEACTION_NOTES;

@ISA = qw(CGI::Dialog);



%RESOURCE_MAP=('claim-notes' => { transType => 9010, heading => '$Command Claim Notes'
			,  _arl => ['invoice_id'], _arl_modify => ['trans_id'] ,
                          _idSynonym => [ 'trans-' . '9010' ]},
                          );


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'claim-notes', heading => '$Command Claim Notes');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'invoice_id', caption => 'Invoice ID', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'detail', caption => 'Notes', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'trans_begin_stamp', caption => 'Date', type => 'date'),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.invoice_id#",
			data => "Claim Notes '#field.trans_subtype#' to <a href='/invoice/#param.invoice_id#/summary'>#param.invoice_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('invoice_id',$page->param('invoice_id'));
	my $transId = $page->param('trans_id');
	$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId) if $transId;
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

}

sub execute
{
	my ($self, $page, $command,$flags) = @_;
	my $transStatus = $command eq 'remove' ? App::Universal::TRANSSTATUS_INACTIVE : App::Universal::TRANSSTATUS_ACTIVE;
	my $transId = $page->param('trans_id');
	$command = $command eq 'remove' ? 'update' : $command;

	my $trans_id = $page->schemaAction(
			'Transaction', $command,
			trans_id => $transId || undef,
			trans_owner_id => $page->session('org_internal_id') || undef,
			trans_invoice_id => $page->field('invoice_id') || undef,
			initiator_id => $page->session('user_id') ||undef,
			trans_owner_type => App::Universal::ENTITYTYPE_ORG,
			caption =>'Claim Notes',
			trans_type => $CLAIM_NOTES,
			trans_begin_stamp => $page->field('trans_begin_stamp')||undef,
			detail => $page->field('detail') || undef,
			trans_status => $transStatus,
			_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags );
	return "\u$command completed.";
}


1;
