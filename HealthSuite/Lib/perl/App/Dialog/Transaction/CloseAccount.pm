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
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

%RESOURCE_MAP=(
	'close-account' => {
		transType => $ACCOUNT_OWNER,
		heading => 'Close Account',
		_arl => ['person_id','trans_id'],
		_arl_modify => ['trans_id'] ,
		_idSynonym => ["trans-$ACCOUNT_OWNER"]
		},
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
							selOptions => 'Retain Notes:0;Delete Notes:1',
							caption => 'notes: ',
							preHtml => "<B><FONT COLOR=DARKRED>",
							postHtml => "</FONT></B>",
							name => 'notes',
				defaultValue => '0',),
																	
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
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	
	$command = 'update';
	my $closed_by = $page->session('user_id');
	my $del_notes  = $page->field('notes');
	my $close_msg = "Account Closed by $closed_by";
	my $first =1;
	my $dataInvoice = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,STMTMGRFLAG_NONE,'selCloseInvoiceByID',$page->param('trans_id'));
	my $invoiceID = $dataInvoice->{trans_invoice_id};
	if ($page->param('trans_id'))
	{
		$page->beginUnitWork();
		#Mark record as inactive
		$page->schemaAction
			(
			'Transaction', 'update',                        
			trans_id =>$page->param('trans_id'),
			trans_status => $INACTIVE	,			
			trans_subtype => 'Account Closed',			
			);
		#Obtain account/invoice information for collectors that
		#transferd there account to this user
		my $transferData = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selAccountTransferIdById',$page->param('person_id'),$page->session('user_id'),$invoiceID);                	
		foreach my $data (@$transferData)         
		{
			#Mark account inactive 
			$page->schemaAction
				(
				'Transaction', 'update',                        
				trans_id =>$data->{trans_id},
				trans_status => $INACTIVE,	,			
				trans_subtype => 'Account Closed',			
				);                	
			#Mark notes records as inactive for anyone that transfer the account to this user
			$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'delAccountNotesById',$data->{'provider_id'},$page->param('person_id')) if $page->field('notes');
		}
		#Mark notes records inactive for current collector
		$STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'delAccountNotesById',$page->session('user_id'),$page->param('person_id')) if $page->field('notes'); 
		$page->endUnitWork();
	}
	$self->handlePostExecute($page, $command, $flags );		
	return "\u$command completed.";
}


use constant ALERT_DIALOG => 'Dialog/Pane/Alert';


1;
