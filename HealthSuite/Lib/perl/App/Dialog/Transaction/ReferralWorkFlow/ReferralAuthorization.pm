##############################################################################
package App::Dialog::Transaction::ReferralWorkFlow::ReferralAuthorization;
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
		new App::Dialog::Field::Person::ID(caption =>'Authorized By ', name => 'provider_id', options => FLDFLAG_REQUIRED),
		new CGI::Dialog::MultiField(caption => 'Authorization #/Date', name => 'auth_num_date',
		fields => [
				new CGI::Dialog::Field(caption => 'Authorization #',  name => 'auth_num', options => FLDFLAG_REQUIRED),
				new CGI::Dialog::Field(caption => 'Authorization Date',  type => 'date', name => 'auth_date', options => FLDFLAG_REQUIRED),
			]),

		new CGI::Dialog::Field(caption => 'Coordinator',  name => 'coordinator'),
		new CGI::Dialog::Field(caption => 'Units Authorized',  name => 'quantity', size => '4'),

		new CGI::Dialog::MultiField(caption =>'Service Begin/End Date',name => 'begin_end_date',
			fields => [
					new CGI::Dialog::Field(caption => 'Begin Date',  type => 'date', name => 'begin_date'),
					new CGI::Dialog::Field(caption => 'End Date',  type => 'date', name => 'end_date')

				]),

		new CGI::Dialog::Field(caption => 'Charge (POS Rate)', name => 'charge', size => '7'),

		new CGI::Dialog::MultiField(caption => '%age Usual/Actual', name => 'percent_actual',
			fields => [
					new CGI::Dialog::Field(caption => 'usual %',  name => 'percent_usual', size => '3'),
					new CGI::Dialog::Field(caption => 'actual %', name => 'percent_actual', size => '3')
				]),

		new CGI::Dialog::Field(name => 'service_comments', caption => 'Service Comments', type => 'memo'),
		new CGI::Dialog::Field(name => 'units_comments', caption => 'Units Comments', type => 'memo'),
		new CGI::Dialog::Field(name => 'followup_comments', caption => 'Follow Up Comments', type => 'memo'),
		new CGI::Dialog::Field(type => 'select',
						style => 'radio',
						selOptions => 'Pending;Authorized;Denied;Suspended;Started;Completed',
						caption => 'Authorization Status',
						postHtml => "</FONT></B>",
						name => 'status',
						defaultValue => 'Pending'),
	)
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

	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPrimaryPhysicianOrProvider', $personId);
	$page->field('provider_id', $page->session('person_id'));


}

sub getSupplementaryHtml
{
	return ('special', '');
}

sub handle_page_supplType_special
{
	my ($self, $page, $command, $dlgHtml) = @_;

	$page->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD COLSPAN=2>
					<b style="font-size:8pt; font-family:Tahoma">Referral Information</b>
					@{[ $STMTMGR_COMPONENT_PERSON->createHtml($page, STMTMGRFLAG_NONE, 'sel_referral',
						[$page->param('parent_trans_id')]) ]}
				</TD>
			</TR>
			<TR><TD COLSPAN=2>&nbsp;</TD></TR>
			<TR VALIGN=TOP>
				<TD>$dlgHtml</TD>
				<TD>
					#component.stpd-person.extendedHealthCoverage#<BR>
					#component.stpd-person.contactMethodsAndAddresses#
				</TD>
			</TR>
		</TABLE>
	});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#my $transaction = $self->{transaction};
	my $transId = $page->param('parent_trans_id');
	my $transStatus = App::Universal::TRANSSTATUS_ACTIVE;
	my $transOwnerType = App::Universal::ENTITYTYPE_PERSON;
	my $transType = App::Universal::TRANSTYPEPROC_REFERRAL_AUTHORIZATION;
	my $previousChildRecs = $STMTMGR_TRANSACTION->recordExists($page,STMTMGRFLAG_NONE, 'selByParentTransId', $transId);
	$STMTMGR_TRANSACTION->execute($page,STMTMGRFLAG_NONE, 'selUpdateTransStatus', $transId) if ($previousChildRecs == 1);

	my $personId = $page->param('person_id');
	my $getPerson = $STMTMGR_TRANSACTION->getRowAsHash($page,STMTMGRFLAG_NONE, 'selByTransId', $transId);
	my $referredTo = $getPerson->{'care_provider_id'};
	my $referredBy = $getPerson->{'provider_id'};

	my $referredToData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $referredTo);
	my $referredToMail = $referredToData->{'value_text'};

	my $referredByData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $referredBy);
	my $referredByMail = $referredByData->{'value_text'};

	my $patientData = $STMTMGR_PERSON->getRowAsHash($page,STMTMGRFLAG_NONE, 'selPrimaryMail', $personId);
	my $patientMail = $patientData->{'value_text'};

	#$page->addDebugStmt("PATIENT, RefferedBy, ReferredTo: $patientMail , $referredByMail, $referredToMail");

	$page->schemaAction(
			'Transaction',
			$command,
			parent_trans_id => $transId || undef,
			trans_owner_type => defined $transOwnerType ? $transOwnerType : undef,
			trans_owner_id => $page->param('person_id'),
			trans_type => $transType || undef,
			trans_status => $transStatus || undef,
			provider_id => $page->field('provider_id') || undef,
			auth_date => $page->field('auth_date') || undef,
			data_num_a => $page->field('auth_num') || undef,
			data_text_a =>$page->field('coordinator') || undef,
			quantity => $page->field('quantity') || undef,
			trans_begin_stamp => $page->field('begin_date') || undef,
			trans_end_stamp => $page->field('end_date') || undef,
			unit_cost => $page->field('charge') || undef,
			related_data => $page->field('service_comments') || undef,
			data_num_b => $page->field('percent_usual') || undef,
			data_num_c => $page->field('percent_actual') || undef,
			detail => $page->field('units_comments') || undef,
			caption => $page->field('followup_comments') || undef,
			display_summary => $page->field('service_comments') || undef,
			trans_status_reason => $page->field('status') || undef,
			_debug => 0
		);

	$page->param('_dialogreturnurl', "/worklist/referral");
	$self->handlePostExecute($page, $command, $flags);

	my %mail;

	$patientMail = 'radha_kotagiri@physia.com';
	$referredByMail = 'radha_kotagiri@physia.com';
	$referredToMail = 'radha_kotagiri@physia.com';

	my $strFrom = 'lloyd_brodsky@physia.com';

	if ($patientMail ne '')
	{
		%mail =
			(To => $patientMail,
			From => $strFrom,
			Subject => 'Your doctor\' referral has been just processed',
			Message => "http://tokyo.physia.com:8515/person/$personId/dlg-add-trans-6010/$transId"
			);
		sendmail(%mail) or die $Mail::Sendmail::error;
	}

	if ($referredByMail ne '')
	{
		%mail =
			(To => $referredByMail,
			From => $strFrom,
			Subject => 'Your doctor\' referral has been just processed',
			Message => "http://tokyo.physia.com:8515/person/RHACKETT01/dlg-add-trans-6010/$transId"
			);
		sendmail(%mail) or die $Mail::Sendmail::error;
	}

	if ($referredToMail ne '')
	{
		%mail =
			(To => $referredToMail,
			From => $strFrom,
			Subject => 'Your doctor\' referral has been just processed',
			Message => "http://tokyo.physia.com:8515/person/RHACKETT01/dlg-add-trans-6010/$transId"
			);
		sendmail(%mail) or die $Mail::Sendmail::error;
	}

	return "\u$command completed.";
}

1;
