##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::ReferralPerson;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Transaction;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(App::Dialog::Transaction::ReferralWorkFlow);

%RESOURCE_MAP = ('referral-person' => {heading => '$Command Service Request',
				_arl => ['org_id'],
				_arl_modify => ['trans_id'],
				_idSynonym => 'trans-' . App::Universal::TRANSTYPEPROC_REFERRAL()},
		);

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize();
	$self->addContent(

		new CGI::Dialog::Subhead(heading => 'Patient Information', name => 'patient_info_heading'),
		new App::Dialog::Field::Person::ID(caption => 'Person/Patient ID',types => ['Patient'],	name => 'person_id', options => FLDFLAG_REQUIRED),
	);
	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
	return $self;
}



sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $transaction = $self->{transaction};
	my $orgId = $page->param('org_id');
	my $test = $page->param('_dialogreturnurl', "/org/$orgId/dlg-add-referral?_f_person_id=%field.person_id%");
	$self->handlePostExecute($page, $command, $flags);
}

1;
