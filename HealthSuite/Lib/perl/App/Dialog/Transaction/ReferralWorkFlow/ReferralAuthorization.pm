##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::ReferralAuthorization;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use vars qw(@ISA);

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
		new App::Dialog::Field::Person::ID(caption =>'Authorized By ', name => 'provider_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::MultiField(caption => 'Authorization #/Date', name => 'auth_num_date',
		fields => [
				new CGI::Dialog::Field(caption => 'Authorization #',  name => 'auth_num', options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(caption => 'Authorization Date',  type => 'date', name => 'auth_date', options => FLDFLAG_REQUIRED),
			]),
		new CGI::Dialog::Field(caption => 'Coordinator',  name => 'coordinator'),
		new CGI::Dialog::Field(caption => 'Units Authorized',  name => 'data_num_a', size => '4'),
		new CGI::Dialog::MultiField(caption =>'Service Begin/End Date',name => 'begin_end_date',
			fields => [
					new CGI::Dialog::Field(caption => 'Begin Date',  type => 'date', name => 'begin_date'),
					new CGI::Dialog::Field(caption => 'End Date',  type => 'date', name => 'end_date')

				]),

		#new App::Dialog::Field::Person::ID(caption =>'Referral ID ', name => 'consult_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(caption => 'Charge (POS Rate)', name => 'charge', size => '7'),

		new CGI::Dialog::MultiField(caption => '%age Usual/Actual', name => 'percent_actual',
			fields => [
					new CGI::Dialog::Field(caption => 'usual %',  name => 'percent_usual', size => '3'),
					new CGI::Dialog::Field(caption => 'actual %', name => 'percent_actual', size => '3')
				]),

		new CGI::Dialog::Field(name => 'service_comments', caption => 'Service Comments', type => 'memo'),
		new CGI::Dialog::Field(name => 'units_comments', caption => 'Units Comments', type => 'memo'),
		new CGI::Dialog::Field(name => 'followup_comments', caption => 'Follow Up Comments', type => 'memo')
	)
}

sub __getSupplementaryHtml
{
	my ($self, $page, $command) = @_;
	my $personId = $page->param('person_id');

	$page->param('person_id', $personId);

	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
				#component.stpd-person.contactMethodsAndAddresses#<BR>
				#component.stpd-person.extendedHealthCoverage#<BR>
				#component.stpd-person.careProviders#<BR>
		});

	return $self->SUPER::getSupplementaryHtml($page, $command);
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
	my $transId = $page->param('parent_trans_id');
	my $personId = $page->param('person_id');



	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);
	#my $contactInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonData', $personId);


	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPrimaryPhysicianOrProvider', $personId);
	$page->field('provider_id', $physicianData->{'value_text'});


}
sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	# all of the Person::* panes expect a person_id parameter
	# -- we can use field('attendee_id') because it was created in populateData

		my $transId = $page->param('parent_trans_id');

		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
			<table cellpadding=10>
				<tr align=right  valign=centre>

				<td>
					<b style="font-size:8pt; font-family:Tahoma">Referral Information</b>
					@{[ $STMTMGR_COMPONENT_PERSON->createHtml($page, STMTMGRFLAG_NONE, 'sel_referral',
						[$transId]) ]}
				</td>

				</tr>
			</table>
			#component.stpd-person.extendedHealthCoverage#<BR>
			#component.stpd-person.contactMethodsAndAddresses#<BR>
		    });

	return $self->SUPER::getSupplementaryHtml($page, $command);
}



sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#my $transaction = $self->{transaction};
	my $transId = $page->param('parent_trans_id');
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;



		 $page->schemaAction(
				'Transaction',
				$command,
				parent_trans_id => $transId || undef,
				trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
				trans_owner_id => $page->param('person_id'),
				trans_type => $transType || undef,
				trans_begin_stamp => $page->field('begin_date') || undef,
				trans_end_stamp => $page->field('end_date') || undef,
				related_data => $page->field('service_comments') || undef,
				data_num_a => $page->field('auth_num') || undef,
				data_num_b => $page->field('percent_usual') || undef,
				data_num_c => $page->field('percent_actual') || undef,
				trans_status_reason => $page->field('payer') || undef,
				provider_id => $page->field('provider_id') || undef,
				care_provider_id => $page->field('referral_id') || undef,
				#consult_id => $page->field('referral_id') || undef,
				detail => $page->field('units_comments') || undef,
				caption => $page->field('followup_comments') || undef,
				_debug => 0
		);


	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}

1;
