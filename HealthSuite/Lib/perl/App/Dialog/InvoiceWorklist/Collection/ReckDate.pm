##############################################################################
package App::Dialog::InvoiceWorklist::Collection::ReckDate;
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
#use App::Dialog::Field::Scheduling;
use App::Statements::Worklist::WorklistCollection;
use vars qw(@ISA %RESOURCE_MAP);
my $ACCOUNT_RECK_DATE = App::Universal::TRANSTYPE_ACCOUNTRECKDATE;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ('collection-reck-date' => {
heading => 'Collection Reck Date',  _arl => ['person_id','invoice_worklist_id'],
						 },);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'collection-reck-date', heading => 'Collection Reck Date');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Person::ID(types => ['Patient'],name => 'person_id', caption => 'Person ID',  options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'invoice_id', caption => 'Invoice ID', options => FLDFLAG_READONLY),			
			new CGI::Dialog::Field(name => 'reckdate', caption => 'Reck Date',futureOnly => 1, type => 'date',options=>FLDFLAG_REQUIRED ,defaultValue => ''),																
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Invoice_Worklist',
			key => "#param.person_id#",
			type=> 1,
			data => "Reck Date add on collector #session.person_id# invoice : #field.invoice_id#"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;	
	$page->field('person_id',$page->param('person_id'));		

	my $invoiceWorklistID = $page->param('invoice_worklist_id')||undef;
	
	my $reck_date = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReckDataById', 
	   		$invoiceWorklistID) if $invoiceWorklistID;		   			
	   		
	$page->field('reckdate',$reck_date->{'reck_date'});	
	$page->field('invoice_id',$reck_date->{'invoice_id'});		
}

sub customValidate
{
	my ($self, $page) = @_;;	
	unless ($page->param('invoice_worklist_id'))
	{
		my $fieldPerson = $self->getField('person_id');
		$fieldPerson->invalidate($page,"Unable to set reck date for the Invoice" );
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	$page->schemaAction(
	                       'Invoice_Worklist', 'update',                                               
	                       reck_date => $page->field('reckdate'),
	                       invoice_worklist_id => $page->param('invoice_worklist_id'),	                     
	               );
			
	$self->handlePostExecute($page, $command, $flags );
}



1;


