##############################################################################
package App::Dialog::Encounter::Checkout;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Transaction;
use App::Statements::Invoice;
use App::Statements::Org;

use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Encounter;
use App::Dialog::Field::Person;
use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);

%RESOURCE_MAP = (
	'checkout' => {
		_arl => ['event_id'] 
		},
	);

use Date::Manip;

@ISA = qw(App::Dialog::Encounter);

use constant NEXTACTION_CLAIMSUMM => "/invoice/%param.invoice_id%/summary";
use constant NEXTACTION_PATIENTACCT => "/person/%field.attendee_id%/account";
use constant NEXTACTION_PRINTRECEIPT => "/";
use constant NEXTACTION_APPOINTMENTS => "/schedule";
use constant NEXTACTION_WORKLIST => "/worklist";


sub initialize
{
	my $self = shift;

	$self->heading('Check Out');

	$self->SUPER::initialize();
	$self->{activityLog} =
			{
				scope =>'person',
				key => "#field.person_id#",
				data => "Check-out <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a> (Check-out Time: #field.checkout_stamp#)"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions => [
							['Go to Claim Summary', NEXTACTION_CLAIMSUMM],
							['Go to Patient Account', NEXTACTION_PATIENTACCT],
							#['Print Patient Receipt', NEXTACTION_PRINTRECEIPT],
							['Go to Appointments', NEXTACTION_APPOINTMENTS],
							['Return to Work List', NEXTACTION_WORKLIST],
							],
						cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	# all of the Person::* panes expect a person_id parameter
	# -- we can use field('attendee_id') because it was created in populateData
	if(my $personId = $page->field('attendee_id'))
	{
		$page->param('person_id', $personId);

		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
							#component.stpd-person.contactMethodsAndAddresses#<BR>
							#component.stpd-person.extendedHealthCoverage#<BR>
							#component.stpd-person.careProviders#<BR>
							#component.stpd-person.authorization#<BR>
			});
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('checkin_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('confirmed_info', FLDFLAG_INVISIBLE, 1);

	$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $eventId = $page->field('event_id');
	
	my $returnUrl = $page->field('dupCheckin_returnUrl');
	my ($status, $person, $stamp) = $self->checkEventStatus($page, $eventId);

	if ($status eq 'out')
	{
		return (qq{
			<b style="color:red">This patient has been checked-$status by $person at $stamp.</b>
			Click <a href='javascript:location.href="$returnUrl"'>here</a> to go back.		
		});

	}

	my $orgIntId = undef;
	if ($page->field('service_facility_id'))
	{
		$orgIntId = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->field('service_facility_id'));
	}


	## First, update original event record to CHECKOUT status, and any changes
	#my $checkOutStamp = $page->getTimeStamp();
	my $eventStatus = App::Universal::EVENTSTATUS_COMPLETE;
	if ($page->schemaAction(
			'Event', 'update',
			event_id => $eventId || undef,
			event_status => $eventStatus,
			checkout_stamp => $page->field('checkout_stamp'),
			checkout_by_id => $page->session('user_id'),
			remarks => $page->field('remarks') || undef,
			event_type => $page->field('appt_type') || 100,
			subject => $page->field('subject') || undef,
			duration => $page->field('duration') || 10,
			facility_id => $orgIntId,
			_debug => 0
		) == 0)
		{
			$page->addDebugStmt('Fatal Check Out Error.<br>Event not updated; Copay not recorded.');
			return 0;
		}


	my $invoiceId = $page->param('invoice_id');
	my $copay = $page->field('copay');
	if(! $invoiceId)
	{
		App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
	}
	elsif($invoiceId)
	{
		App::Dialog::Encounter::handlePayers($self, $page, 'update', $flags);
	}
	#elsif($copay eq '' || $copay == 0)
	#{
	#	App::Dialog::Encounter::payCopay($self, $page, $command, $flags, $invoiceId);
	#}
	#else
	#{
	#	$self->handlePostExecute($page, $command, $flags, "/invoice/$invoiceId");
	#}
}

1;