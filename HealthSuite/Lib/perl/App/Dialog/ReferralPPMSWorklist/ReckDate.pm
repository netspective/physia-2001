##############################################################################
package App::Dialog::ReferralPPMSWorklist::ReckDate;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use Date::Manip;
use App::Statements::ReferralPPMS;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = ('referral-reck-date' => {
					heading => 'Referral Recheck Date',  
					_arl => ['person_id','referral_id','requester_id'],
					},);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'referral-reck-date', heading => 'Referral Recheck Date');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'referral_id', caption => 'Referral ID', options => FLDFLAG_READONLY),	
			new App::Dialog::Field::Person::ID(name => 'person_id', caption => 'Patient ID',  options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'requester_id', caption => 'Requesting Physician', options => FLDFLAG_READONLY),	
			new App::Dialog::Field::Scheduling::Date(caption => 'Recheck Date', name => 'recheck_date', type => 'date', options => FLDFLAG_REQUIRED),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Person_referral',
			key => "#param.referral_id#",
			type=> 1,
			data => "Recheck Date update by <a href='/person/#session.user_id#/profile'>#session.user_id#</a>"
		};
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
	
	my $reck_date = $STMTMGR_REFERRAL_PPMS->getRowAsHash($page, STMTMGRFLAG_NONE, 'selReferralById', 
	   		$referralID) if $referralID;		   			
	   		
	$page->field('recheck_date',$reck_date->{'recheck_date'});	
	$page->field('referral_id',$reck_date->{'referral_id'});		
	$page->field('requester_id',$reck_date->{'requester_id'});		
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
	                       recheck_date => $page->field('recheck_date'),
	                       referral_id => $page->param('referral_id'),
	               );
			
	$self->handlePostExecute($page, $command, $flags );
}

1;
