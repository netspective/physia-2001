##############################################################################
package App::Dialog::Transaction::CloseAccount;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::Worklist::WorklistCollection;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;

%RESOURCE_MAP=('close-account' => { transType => $ACCOUNT_OWNER, heading => 'Close Account',  _arl => ['person_id','trans_id'], _arl_modify => ['trans_id'] ,
				     _idSynonym => [
															"trans-$ACCOUNT_OWNER"												
														] },
	);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-account', heading => 'Close Account');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'person_id', caption => 'Person ID', type => 'text', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(type => 'select',
							style => 'radio',
							selOptions => 'Retain Notes;Delete Notes',
							caption => 'notes: ',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'notes',
				defaultValue => 'Retain Notes'),
																	
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Accout Notes '#field.trans_subtype#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
	#$STMTMGR_TRANSACTION->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selTransactionById', $transId);
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	
	$command = 'update';
	my $new_owner = $page->field('transfer_id');
	my $closed_by = $page->session('user_id');
	my $del_notes  = $page->field('notes') eq 'Retain Notes' ? 0 : 1;	
	my $transType = App::Universal::TRANSTYPE_ACCOUNTRECKDATE;		
	$page->schemaAction(   'Transaction', $command,                        
				trans_owner_id => $page->param('person_id') || undef,
			                provider_id => $page->session('user_id') ||undef,
			                trans_owner_type => 0, 
			                 caption =>'Close Account',
			                trans_subtype =>'Account Closed',
			                trans_status_reason =>"Account Closed by $closed_by",
			                trans_type => $ACCOUNT_OWNER,                        		                                                            
			                trans_id=>$page->param('trans_id'),
			                _debug => 0
	       );		
	$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'delAccountNotesById',$page->session('user_id'),$page->param('person_id')) if $del_notes;
	$self->handlePostExecute($page, $command, $flags );
	return "\u$command completed.";
}


use constant ALERT_DIALOG => 'Dialog/Pane/Alert';


1;