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
use App::Schedule::Utilities;
use Date::Manip;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'checkout' => {
		_arl => ['event_id']
		},
	);

use base qw(App::Dialog::Encounter);

use constant NEXTACTION_CLAIMSUMM => "/invoice/%param.invoice_id%/summary";
use constant NEXTACTION_PATIENTACCT => "/person/%field.attendee_id%/account";
use constant NEXTACTION_POSTTRANSFER => "/person/%field.attendee_id%/dlg-add-posttransfer";
use constant NEXTACTION_PRINTRECEIPT => "/";
use constant NEXTACTION_APPOINTMENTS => "/schedule";
use constant NEXTACTION_WORKLIST => "/worklist";
use constant NEXTACTION_FOLLOWUPAPPT => "/worklist/patientflow/dlg-add-appointment/%field.attendee_id%/%field.care_provider_id%/%field.service_facility_id%//1/%field.appt_type%";

sub initialize
{
	my $self = shift;

	$self->heading('Check Out');

	$self->SUPER::initialize();
	$self->{activityLog} =
			{
				scope =>'person',
				action => $App::Universal::DIALOG_COMMAND_ACTIVITY_MAP{'add'},
				key => "#field.person_id#",
				data => qq{Check-out <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a>
					<br>(Appt Time: #field.start_time#)
			}
	};

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions => [
			['Return to Previous Screen', '', 1],
			['Go to Work List', NEXTACTION_WORKLIST],
			['Go to Claim Summary', NEXTACTION_CLAIMSUMM],
			['Go to Patient Account', NEXTACTION_PATIENTACCT],
			['Post Transfer for this Patient', NEXTACTION_POSTTRANSFER],
			['Go to Appointments', NEXTACTION_APPOINTMENTS],
			['Schedule Follow-up Appointment', NEXTACTION_FOLLOWUPAPPT],
		],
		cancelUrl => $self->{cancelUrl} || undef)
	);

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
					#component.stpd-person.accountPanel#<BR>
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
	$self->updateFieldFlags('hosp_org_fields', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('on_hold', FLDFLAG_INVISIBLE, 1);

	$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);
}

sub handle_page
{
	my ($self, $page, $command) = @_;
	
	my $eventId = $page->field('parent_event_id') || $page->param('event_id');

	my $returnUrl = $self->getReferer($page);
	my ($status, $person, $stamp) = $self->checkEventStatus($page, $eventId);

	if ($status eq 'out') 
	{
		$page->addContent(qq{
			<font face=Verdana size=3>
			This Patient was checked-$status by <b>$person</b> on <b>$stamp</b>.<br>
			Click <a href='$returnUrl'>here</a> to go back.
			</font>
		});
	}
	elsif ($status =~ /ed$/) 
	{
		$page->addContent(qq{
			<font face=Verdana size=3>
			This Appointment was $status by <b>$person</b> on <b>$stamp</b>. <br>
			Click <a href='$returnUrl'>here</a> to go back.
			</font>
		});
	}
	elsif (my $claim = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE, 
		'sel_voidInvoice', $page->session('GMT_DAYOFFSET'), $eventId))
	{
		$page->addContent(qq{
			<font face=Verdana size=3>
			Claim <b>$claim->{invoice_id}</b> was Voided by <b>$claim->{cr_user_id}</b>
			on <b>$claim->{void_stamp}</b>. <br>
			Click <a href='$returnUrl'>here</a> to go back.
			</font>
		});
	}
	elsif ($status ne 'in')
	{
		$page->addContent(qq{
			<font face=Verdana size=3>
			This Patient has NOT been checked-in.  Please check-in patient before check-out.<br>
			Click here to <a href='/schedule/apptsheet/encounterCheckin/$eventId'><b>Check-In</b></a> patient.
			</font>
		});
	}
	else 
	{
		$self->SUPER::handle_page($page, $command);
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#$page->beginUnitWork("Unable to checkout patient");

	my $eventId = $page->field('parent_event_id') || $page->param('event_id');
	my $eventStatus = App::Universal::EVENTSTATUS_COMPLETE;
	
	if ($page->schemaAction(
			'Event', 'update',
			event_id => $eventId || undef,
			event_status => $eventStatus,
			checkout_stamp => $page->field('checkout_stamp'),
			checkout_by_id => $page->session('user_id'),
			remarks => $page->field('remarks') || undef,
			subject => $page->field('subject'),
			facility_id => $page->field('service_facility_id'),
			_debug => 0
		) == 0)
	{
		$page->addDebugStmt('Fatal Check Out Error.<br>Event not updated; Copay not recorded.');
		return 0;
	}

	my $invoiceId = $page->param('invoice_id');
	my $copay = $page->field('copay');

	$page->param('encounterDialog', 'checkout');
	if(! $invoiceId)
	{
		App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);

		#$page->endUnitWork();
	}
	elsif($invoiceId)
	{
		App::Dialog::Encounter::handlePayers($self, $page, 'update', $flags);

		#$page->endUnitWork();
	}
}

1;
