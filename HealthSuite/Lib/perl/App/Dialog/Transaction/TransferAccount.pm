##############################################################################
package App::Dialog::Transaction::TransferAccount;
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
use App::Statements::Worklist::WorklistCollection;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;

%RESOURCE_MAP = ('transfer-account' => {transType => $ACCOUNT_OWNER, heading => 'Transfer Account',  _arl => ['person_id','trans_id'], _arl_modify => ['trans_id'] ,
			_idSynonym => [
																
			] },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'transfer-account', heading => 'Transfer Account');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'person_id', caption => 'Person ID', type => 'memo', options => FLDFLAG_READONLY),
			new App::Dialog::Field::Person::ID(name => 'transfer_id', caption =>'Transfer To', options => FLDFLAG_REQUIRED, hints => 'Collector to Transfer Account'),			
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Transfer Account  '#field.trans_subtype#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;	
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	$command = 'update';
	my $new_owner = $page->field('transfer_id');
	$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'TranCollectionById', $page->param('person_id'),$page->session('user_id'),$new_owner);
	$page->schemaAction(   'Transaction', $command,                        
		                trans_owner_id => $page->param('person_id') || undef,
		                provider_id => $page->session('user_id') ||undef,
		                trans_owner_type => 0, 		                
		                caption =>'Transfer Account',
		                trans_subtype =>'Account Transfered',
		                trans_status =>2,
		                trans_status_reason =>"Account Transfered to $new_owner",
		                trans_id =>$page->param('trans_id'),
		                _debug => 0
		                );		
	#Remove Reck Date for collection
	$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'delReckDateById',$page->param('person_id'),$page->session('user_id'));
	
	#Transfer notes to new collector	                
	$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'TranAccountNotesById',$new_owner,$page->session('user_id'),$page->param('person_id'));	
	$self->handlePostExecute($page, $command, $flags);
	return "\uTransfer completed.";
}


1;