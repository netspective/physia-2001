##############################################################################
package App::Dialog::InvoiceWorklist::TransferAccount;
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

%RESOURCE_MAP = ('transfer-collection' => {heading => 'Transfer Invoice',  _arl => ['person_id','invoice_id'],},);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'transfer-invoice', heading => 'Transfer Invoice');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'person_id', caption => 'Person ID', type => 'text', options => FLDFLAG_READONLY),
			new App::Dialog::Field::Person::ID(name => 'transfer_id', caption =>'Transfer To', options => FLDFLAG_REQUIRED, hints => 'Collector to Transfer Account'),			
			new CGI::Dialog::Field(name => 'detail', caption => 'Reason For Transfer', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'date_data_b', caption => 'Date', type => 'date'),	
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Transfer Account  to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
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
	unless ($page->param('invoice_id'))
	{
		my $fieldPerson = $self->getField('person_id');
		$fieldPerson->invalidate($page,"Make sure you are a collector for this account." );
	}
	$fieldTrans->invalidate($page,"Unable to transfer account to self") if $page->field('transfer_id') eq $page->session('user_id');
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	$command = 'update';
	my $new_owner = $page->field('transfer_id');
	my $old_owner = $page->session('user_id');
	my $transStatus =  App::Universal::TRANSSTATUS_ACTIVE;
	
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
        
        #Move copy of collection record to new collector 
        #If new collector does not have this invoice on the worklist
        $STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'moveCollectionRecord',$page->param('invoice_id'),$page->session('person_id'),$page->session('org_internal_id'),$page->field('transfer_id'))
        	unless $STMTMGR_WORKLIST_COLLECTION->getSingleValue($page,STMTMGRFLAG_NONE,'isOnCollectionWorklist',$page->param('invoice_id'),$page->field('transfer_id'),$page->session('org_internal_id'));	                
        	
  	#Update responisble_id on collector records to new collector
        $STMTMGR_WORKLIST_COLLECTION->execute($page,STMTMGRFLAG_NONE,'transferCollection',$page->param('invoice_id'),$page->session('person_id'),$page->session('org_internal_id'),$page->field('transfer_id'));

	$self->handlePostExecute($page, $command, $flags );	
	return "\uTransfer completed.";
}


1;
