##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::ReferralEnquiry;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use vars qw(@ISA);
use Mail::Sendmail;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Transaction;
use App::Statements::Component::Person;

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	#my $self = CGI::Dialog::new(@_, id => 'referral-auth', heading => 'Add Referral Authorization');

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption =>'Authorization Number ', name => 'auth_ref', options => FLDFLAG_READONLY),
		new CGI::Dialog::Field(name => 'comments', caption => 'Comments', type => 'memo', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE),
	);

	$self->addFooter(new CGI::Dialog::Buttons);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL);
	my $personId = $page->param('person_id');
	my $transId = $page->param('parent_trans_id');
	my $authData = $STMTMGR_TRANSACTION->getRowAsHash($page, STMTMGRFLAG_NONE, 'selByTransId', $page->param('parent_trans_id'));
	$page->field('auth_ref', $authData->{'auth_ref'});
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $transId = $page->param('parent_trans_id');
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL_ENQUIRY;

	 $page->schemaAction(
			'Transaction',
			$command,
			parent_trans_id => $transId || undef,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $page->param('person_id'),
			trans_type => $transType || undef,
			trans_status => $transStatus || undef,
			auth_ref     => $page->field('auth_ref') || undef,
			related_data => $page->field('comments') || undef,
			_debug => 0
		);

	$page->param('_dialogreturnurl', "/worklist/referral?user=physician");
	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}

1;
