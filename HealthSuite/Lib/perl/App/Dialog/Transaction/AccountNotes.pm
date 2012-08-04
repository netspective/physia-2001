##############################################################################
package App::Dialog::Transaction::AccountNotes;
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
use App::Dialog::Field::Person;
use vars qw(@ISA %RESOURCE_MAP);
my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;

@ISA = qw(CGI::Dialog);



%RESOURCE_MAP=('account-notes' => { transType => 9500, heading => '$Command Account Notes'
			,  _arl => ['person_id'], _arl_modify => ['trans_id'] ,
                          _idSynonym => [ 'trans-' . '9500' ]},
                          );


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'account-notes', heading => '$Command Account Notes');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Person::ID(types => ['Patient'],name => 'person_id', caption => 'Person ID', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'detail', caption => 'Notes', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'trans_begin_stamp', caption => 'Date', type => 'date'),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Account Notes '#field.trans_subtype#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));
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
	                       trans_owner_id => $page->param('person_id') || undef,
	                        provider_id => $page->session('user_id') ||undef,
	                        trans_owner_type => 0,
	                        caption =>'Account Notes',
	                        trans_type => $ACCOUNT_NOTES,
	                        trans_begin_stamp => $page->field('trans_begin_stamp')||undef,
	                        detail => $page->field('detail') || undef,
	                        trans_status => $transStatus,
	                        _debug => 0
	                );

	$self->handlePostExecute($page, $command, $flags );
	return "\u$command completed.";
}


1;
