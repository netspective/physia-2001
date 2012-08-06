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

my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

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
			new CGI::Dialog::Field(name => 'person_id', caption => 'Person ID', type => 'text', options => FLDFLAG_READONLY),
			new App::Dialog::Field::Person::ID(name => 'transfer_id', caption =>'Transfer To', options => FLDFLAG_REQUIRED, hints => 'Collector to Transfer Account'),			
			new CGI::Dialog::Field(name => 'detail', caption => 'Reason For Transfer', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'trans_begin_stamp', caption => 'Date', type => 'date'),	
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

sub customValidate
{
	my ($self, $page) = @_;;	
	my $fieldTrans = $self->getField('transfer_id');
	unless ($page->param('trans_id'))
	{
		my $fieldPerson = $self->getField('person_id');
		$fieldPerson->invalidate($page,"Make sure you are a collector for this account.  Transfer account only from 'today' worklist"); 		
	}
	$fieldTrans->invalidate($page,"Unable to transfer account to self") if $page->field('transfer_id') eq $page->session('user_id');
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	$command = 'update';
	my $new_owner = $page->field('transfer_id');
	my $transStatus =  App::Universal::TRANSSTATUS_ACTIVE;	
	my $old_owner = $page->session('user_id');
	
	#Create Note for Account
	my $trans_id = $page->schemaAction
	(
		'Transaction','add',                  
		trans_id => undef,
		trans_owner_id => $page->param('person_id') || undef,
		provider_id => $page->session('user_id') ||undef,
		trans_owner_type => 0,                        
		caption =>'Account Notes',
		trans_type => $ACCOUNT_NOTES,                        
		trans_begin_stamp => $page->field('trans_begin_stamp')||undef,
		detail => $page->field('detail') || undef,     
		trans_status => $transStatus,             
	);
	my $new_msg = "Transfered From $old_owner";
	my $old_msg = "Account Transfered to $new_owner";
	
	#Get Invoice ID
	my $dataInvoice = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page,STMTMGRFLAG_NONE,'selCloseInvoiceByID',$page->param('trans_id'));
	my $invoiceID = $dataInvoice->{trans_invoice_id};	
	$page->beginUnitWork();
	
	#Create an attribute for the transaction/invoice record so we can track transfer history
	$page->schemaAction
		(
			'Trans_Attribute', 'add',
			parent_id =>$page->param('trans_id'),
			item_type =>1,
			item_name =>'Account/Transfer/Owner',
			value_type =>0,
			value_text =>$page->field('transfer_id'),
			value_textB =>$page->param('person_id'),
			);
	
	#Add records to the new collector if needed
	$page->schemaAction
		(   	'Transaction', 'add',                        
	                trans_owner_id =>$page->param('person_id'),
	                provider_id => $page->field('transfer_id') ,
	                trans_owner_type => 0, 
	                caption =>'Account Owner',
	                trans_subtype =>'Owner',
	                trans_status =>$ACTIVE,
	                trans_type => $ACCOUNT_OWNER,  
	                initiator_type =>0,
	                initiator_id =>$page->session('user_id'), 	
	                billing_facility_id => $page->session('org_internal_id'),
	                trans_status_reason =>$new_msg,
			data_num_a => $invoiceID ,		
			trans_invoice_id => $invoiceID 				
               	) unless $STMTMGR_WORKLIST_COLLECTION->getSingleValue($page,STMTMGRFLAG_NONE,'selCollectionRecordById',
               		$page->param('person_id'),$page->field('transfer_id'),$invoiceID) ;
               	
	#Mark record as transfered
	$page->schemaAction
		(
			'Transaction', 'update',                        
			trans_id =>$page->param('trans_id'),
			trans_subtype => 'Account Transfered',
			caption =>'Transfer Account',
			trans_status_reason => $old_msg,				
               	);
               	
        #Check if this invoice was transfer to this user, if is so set the transfer to new owner. 
        #So when new owner close the invoice all previous owner records will also close.
	my $transferData = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selAccountTransferIdById',$page->param('person_id'),$page->session('user_id'),$invoiceID);                	
	foreach my $data (@$transferData)
	{
		$page->schemaAction
		(
			'Trans_Attribute','update',
			item_id =>$data->{item_id},
			value_text =>$page->field('transfer_id')
		);
	}
	$page->endUnitWork();
	$self->handlePostExecute($page, $command, $flags );	
	return "\uTransfer completed.";
}


1;