##############################################################################
package App::Dialog::ReferralPPMSWorklist::TransferReferral;
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
use App::Statements::ReferralPPMS;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

%RESOURCE_MAP = ('transfer-referral' => 
					{heading => 'Transfer Referral',  
					_arl => ['person_id','referral_id','requester_id'],
					},
				);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'transfer-referral', heading => 'Transfer Referral');


	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'referral_id', caption => 'Referral ID', options => FLDFLAG_READONLY),	
			new App::Dialog::Field::Person::ID(incSimpleName=>1,name => 'person_id', caption => 'Patient ID', type => 'text', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'requester_id', caption => 'Requesting Physician', options => FLDFLAG_READONLY),	
			new App::Dialog::Field::Person::ID(incSimpleName=>1, name => 'transfer_id', caption =>'Transfer To', types => ['Staff'], options => FLDFLAG_REQUIRED, hints => 'Person to Transfer Referral'),
			new CGI::Dialog::Field(name => 'detail', caption => 'Reason For Transfer', type => 'memo', options => FLDFLAG_REQUIRED),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Person_referral',
			key => "#param.referral_id#",
			data => "Transferred Referral to <a href='/person/#field.transfer_id#/profile'>#field.transfer_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));
	$page->field('referral_id',$page->param('referral_id'));
	$page->field('requester_id',$page->param('requester_id'));
	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;	
}

sub customValidate
{
	my ($self, $page) = @_;;	
	my $fieldTrans = $self->getField('transfer_id');
#	unless ($page->param('invoice_id'))
#	{
#		my $fieldPerson = $self->getField('person_id');
#		$fieldPerson->invalidate($page,"Make sure you are a collector for this account." );
#	}
	$fieldTrans->invalidate($page,"Unable to transfer referral to self") if $page->field('transfer_id') eq $page->session('user_id');
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;	
	$command = 'update';
	my $transStatus =  App::Universal::TRANSSTATUS_ACTIVE;
	
	#Create Note for Referral Transfer
	my $trans_id = $page->schemaAction
	(
		'Person_Referral_Note','add',                  
		person_id => $page->session('user_id') ||undef,
		org_internal_id => $page->session('org_internal_id') ||undef,
		referral_id => $page->field('referral_id'),
		note => "Referral Transferred to @{[$page->field('transfer_id')]} - Reason: " . $page->field('detail'),
		note_date => $page->getDate(),
	);
        
	#Make copy of referral record for new user
	#If new user does not have this referral on the worklist
	$STMTMGR_REFERRAL_PPMS->execute($page,STMTMGRFLAG_NONE,'copyReferral',$page->param('referral_id'),$page->session('user_id'),$page->field('transfer_id'));
	
	#Update user_id, referrral_status of referral records
	$STMTMGR_REFERRAL_PPMS->execute($page,STMTMGRFLAG_NONE,'transferReferral',$page->param('referral_id'));

	$self->handlePostExecute($page, $command, $flags );	
	return "\uTransfer completed.";
}


1;
