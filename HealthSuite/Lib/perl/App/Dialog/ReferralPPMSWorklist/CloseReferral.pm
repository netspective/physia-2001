##############################################################################
package App::Dialog::ReferralPPMSWorklist::CloseReferral;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use App::Universal;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Transaction;
use App::Statements::ReferralPPMS;

use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;

%RESOURCE_MAP=(
	'close-referral' => {
		heading => 'Close Referral',
		_arl => ['person_id','referral_id','requester_id'],
		},
	);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'close-referral', heading => 'Close Referral');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'referral_id', caption => 'Referral ID', type => 'text', options => FLDFLAG_READONLY),
			new App::Dialog::Field::Person::ID(name => 'person_id', caption => 'Person ID', type => 'text', options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'requester_id', caption => 'Requesting Physician', options => FLDFLAG_READONLY),	
#			new CGI::Dialog::Field(type => 'select',
#							style => 'radio',
#							selOptions => 'Retain Notes:0;Delete Notes:1',
#							caption => 'Notes: ',
#							preHtml => "<B><FONT COLOR=DARKRED>",
#							postHtml => "</FONT></B>",
#							name => 'notes',
#				defaultValue => '0',),

		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Person_referral',
			key => "#param.referral_id#",		
			data => "Referral closed by <a href='/person/#session.user_id#/profile'>#session.user_id#</a>"
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

sub execute
{
	my ($self, $page, $command,$flags) = @_;

	#
	my $dataReferrral = $STMTMGR_REFERRAL_PPMS->execute($page,STMTMGRFLAG_NONE,'closeReferralById',$page->param('referral_id'));

	#Mark notes records inactive for current user
#	$STMTMGR_REFERRAL_PPMS->execute($page,STMTMGRFLAG_NONE,'delReferralNotes',$page->session('user_id'),$page->param('person_id')) if $page->field('notes');
	$self->handlePostExecute($page, $command, $flags );
	return "\u$command completed.";
}

use constant ALERT_DIALOG => 'Dialog/Pane/Alert';

1;
