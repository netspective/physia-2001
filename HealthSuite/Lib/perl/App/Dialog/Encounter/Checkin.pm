##############################################################################
package App::Dialog::Encounter::Checkin;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Encounter;
use App::Dialog::Field::Person;
use App::Universal;
use App::Schedule::Utilities;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'checkin' => {
		_arl => ['event_id']
		},
	);

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Component::Scheduling;
use App::Statements::Org;
use Date::Manip;

use base qw(App::Dialog::Encounter);

use constant NEXTACTION_POSTPAYMENT => "/person/%field.attendee_id%/dlg-add-postpersonalpayment";
use constant NEXTACTION_PATIENTWORKLIST => "/worklist/patientflow";
use constant NEXTACTION_PRINTENCOUNTERFORM => "/person/%field.attendee_id%/dlg-add-printsuperbill/%field.parent_event_id%";

sub initialize
{
	my $self = shift;

	$self->heading('Check-In');

	$self->SUPER::initialize();

	$self->{activityLog} =
	{
		scope =>'person',
		key => "#field.person_id#",
		data => "Checkin <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a><br>(Appt Time: #field.start_time#)"
	};

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions => [
							['Return to Previous Screen', '', 1],
							['Go to Patient Flow Work List', NEXTACTION_PATIENTWORKLIST],
							['Post Payment for this Patient', NEXTACTION_POSTPAYMENT],
							['Print Encounter Form for this Patient', NEXTACTION_PRINTENCOUNTERFORM],
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
	$self->updateFieldFlags('batch_fields', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('checkout_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('hosp_org_fields', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('resub_number', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('on_hold', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_heading', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_list', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);

	#$page->session('dupCheckin_returnUrl', $page->referer());
}

sub handle_page
{
	my ($self, $page, $command) = @_;
	
	my $eventId = $page->field('parent_event_id') || $page->param('event_id');
	my $returnUrl = $self->getReferer($page);
	my ($status, $person, $stamp) = $self->checkEventStatus($page, $eventId);
	
	if ($status =~ /in|out/i) 
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
	else
	{
		$self->SUPER::handle_page($page, $command);
	}
}

sub customValidate
{
	my ($self, $page) = @_;
	$self->SUPER::customValidate($page);

	my $eventId = $page->field('parent_event_id') || $page->param('event_id');
	my $confirmYes = $page->field('confirmed_info') eq 'Yes' ? 1 : 0;
	my $patientId = $page->field('attendee_id');
	my $claimType = $page->field('claim_type');
	
	if ($confirmYes && $claimType != App::Universal::CLAIMTYPE_SELFPAY && $claimType != App::Universal::CLAIMTYPE_CLIENT)
	{
		my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
			'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

		my $verifyFlags = $eventAttribute->{value_intb};
		unless ($verifyFlags & App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE)
		{
			my $field = $self->getField('confirmed_info');
			$field->invalidate($page, qq{Insurance Verification is incomplete.
				Click here to <a href='/person/$patientId/dlg-verify-insurance-records/$eventId'>
					Verify Insurance</a>
			});
		}
	}
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	#$page->beginUnitWork("Unable to checkin patient");

	my $eventId = $page->field('parent_event_id') || $page->param('event_id');
	my $eventStatus = App::Universal::EVENTSTATUS_INPROGRESS;

	if ($page->schemaAction(
			'Event', 'update',
			event_id => $eventId || undef,
			event_status => $eventStatus,
			checkin_stamp => $page->field('checkin_stamp'),
			checkin_by_id => $page->session('user_id'),
			remarks => $page->field('remarks') || undef,
			subject => $page->field('subject'),
			facility_id => $page->field('service_facility_id'),
			_debug => 0
		) == 0)
	{
		$page->addDebugStmt('Fatal Check-in Error.<br>Event not updated; Transaction not created; Invoice not created; Copay not recorded.');
		return 0;
	}

	my $confirmed = $page->field('confirmed_info') eq 'Yes' ? 1 : 0;
	
	my $eventAttribute = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'sel_EventAttribute', $eventId, App::Universal::EVENTATTRTYPE_APPOINTMENT);

	my $itemId = $eventAttribute->{item_id};
	my $verifyFlags = $eventAttribute->{value_intb};
	
	$verifyFlags &= ~App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE;
	
	$verifyFlags |= App::Component::WorkList::PatientFlow::VERIFYFLAG_INSURANCE_COMPLETE 
		if $confirmed;
		
	$page->schemaAction(
		'Event_Attribute', 'update',
		item_id => $itemId,
		value_intB => $verifyFlags,
	);

	# Add Trans and Invoice info
	App::Dialog::Encounter::handlePayers($self, $page, $command, $flags);
	#$page->endUnitWork();
}

1;
