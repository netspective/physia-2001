##############################################################################
package App::Dialog::Transaction::ReckDate;
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
my $ACCOUNT_RECK_DATE = App::Universal::TRANSTYPE_ACCOUNTRECKDATE;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ('reck-date' => {transType => $ACCOUNT_RECK_DATE, heading => 'Account Reck Date',  _arl => ['person_id','trans_id'], _arl_modify => ['trans_id'] ,
				 _idSynonym => [
					 	"trans-$ACCOUNT_RECK_DATE"												
						] },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'account-reck-date', heading => 'Account Reck Date');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'person_id', caption => 'Person ID', type => 'memo', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'reckdate', caption => 'Reck Date',futureOnly => 1, type => 'date',options=>FLDFLAG_REQUIRED ,defaultValue => ''),																
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'transaction',
			key => "#param.person_id#",
			data => "Reck Date'#field.trans_subtype#' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));		
	my $transId = $page->param('trans_id');
	
	my $reck_date = 
			$STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReckInfoById', 
	   		$transId) if defined $transId && $transId gt '';		   			
	   		
	$page->field('reckdate',$reck_date->{'trans_begin_stamp'});
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;	
}

sub execute
{
	my $transType = App::Universal::TRANSTYPE_ACCOUNTRECKDATE;
	my ($self, $page, $command,$flags) = @_;	
	$command = 'add';
	$command ='update'if defined  $page->param('trans_id');	
	    my $trans_id = $page->schemaAction(
	                        'Transaction', $command,                        
	                        trans_owner_id => $page->param('person_id') || undef,
	                        provider_id => $page->session('user_id') ||undef,
	                        trans_owner_type => 0, 
	                        trans_status =>$ACTIVE,
	                        trans_subtype=>'Reck Date',
	                        caption =>'Account Reck Date',
	                        trans_type => $ACCOUNT_RECK_DATE,                        
	                        trans_begin_stamp => $page->field('reckdate')||undef,	                                      
	                        trans_id => $page->param('trans_id') ||undef,
	                     
	                );
			
	$self->handlePostExecute($page, $command, $flags );
	return "\uTransfer completed.";
}



1;