##############################################################################
package App::Dialog::ReferralPPMSWorklist::ReferralNotes;
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
use App::Dialog::Field::Person;
use vars qw(@ISA %RESOURCE_MAP);
my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP=('referral-notes' => { heading => '$Command Referral Notes',
						_arl_add => ['person_id','referral_id', 'requester_id'], 
						_arl_modify => ['referral_note_id','person_id','referral_id', 'requester_id'] ,
						},
						);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'referral-notes', heading => '$Command Referral Notes');

	my $schema = $self->{schema};
	my $pane = $self->{pane};
	my $transaction = $self->{transaction};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new CGI::Dialog::Field(name => 'referral_id', caption => 'Referral ID', options => FLDFLAG_READONLY),
			new App::Dialog::Field::Person::ID(name => 'person_id', caption => 'Patient ID',  options => FLDFLAG_READONLY),
			new CGI::Dialog::Field(name => 'requester_id', caption => 'Requesting Physician', options => FLDFLAG_READONLY),	
			new CGI::Dialog::Field(name => 'note', caption => 'Notes', type => 'memo', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(name => 'note_date', caption => 'Date', type => 'date'),
		);
		$self->{activityLog} =
		{
			level => 1,
			scope =>'Person_referral',
			key => "#param.referral_id#",
			data => "Referral Note Added by <a href='/person/#session.user_id#/profile'>#session.user_id#</a>"
		};
		$self->addFooter(new CGI::Dialog::Buttons);
		return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	$page->field('referral_id',$page->param('referral_id'));
	$page->field('person_id',$page->param('person_id'));
	$page->field('requester_id',$page->param('requester_id'));

}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $noteId = $page->param('referral_note_id');
	$command = $command eq 'remove' ? 'update' : $command;

	my $trans_id = $page->schemaAction(
	                        'Person_Referral_Note', $command,
	                        referral_note_id => $noteId || undef,
							referral_id => $page->param('referral_id'),
							person_id => $page->session('user_id') || undef,
	                        org_internal_id => $page->session('org_internal_id') ||undef,
	                        note_date => $page->field('note_date')||undef,
	                        note => $page->field('note') || undef,
	                        _debug => 0
	                );

	$self->handlePostExecute($page, $command, $flags);
	return "\u$command referral note completed.";
}

1;
