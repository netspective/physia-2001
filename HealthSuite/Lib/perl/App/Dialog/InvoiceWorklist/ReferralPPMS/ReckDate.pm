##############################################################################
package App::Dialog::InvoiceWorklist::ReferralPPMS::ReckDate;
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

%RESOURCE_MAP = ('referral-reck-date' => {
					heading => 'Referral Reck Date',  _arl => ['person_id','referral_id'],
					},);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'referral-reck-date', heading => 'Referral Reck Date');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Person::ID(types => ['Patient'],name => 'person_id', caption => 'Person ID',  options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'referral_id', caption => 'Referral ID', options => FLDFLAG_READONLY),	
			new CGI::Dialog::Field(name => 'reckdate', caption => 'Reck Date',futureOnly => 1, type => 'date',options=>FLDFLAG_REQUIRED ,defaultValue => ''),
		);
#		$self->{activityLog} =
#		{
#			level => 1,
#			scope =>'Person_referral',
#			key => "#param.person_id#",
#			type=> 1,
#			data => "Reck Date added on referral #session.person_id# invoice : #field.referral_id#"
#		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;	
	$page->field('person_id',$page->param('person_id'));		
	$page->field('referral_id',$page->param('referral_id'));		

	my $referralID = $page->param('referral_id')||undef;
	
	my $reck_date = $STMTMGR_WORKLIST_COLLECTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReckDataById', 
	   		$referralID) if $referralID;		   			
	   		
	$page->field('reckdate',$reck_date->{'reck_date'});	
	$page->field('referral_id',$reck_date->{'referral_id'});		
}

sub customValidate
{
	my ($self, $page) = @_;;	
	unless ($page->param('referral_id'))
	{
#		my $fieldPerson = $self->getField('person_id');
#		$fieldPerson->invalidate($page,"Unable to set reck date for the Invoice" );
	}
}

sub execute
{
	my ($self, $page, $command,$flags) = @_;	
	$page->schemaAction(
	                       'Person_Referral', 'update',                                               
	                       reck_date => $page->field('reckdate'),
	                       referral_id => $page->param('referral_id'),
	               );
			
	$self->handlePostExecute($page, $command, $flags );
}

1;
