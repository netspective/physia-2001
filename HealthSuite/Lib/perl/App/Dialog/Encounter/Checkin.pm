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
use vars qw(@ISA @CHANGELOG);
use DBI::StatementManager;
use App::Statements::Scheduling;

use Date::Manip;
use Devel::ChangeLog;
@ISA = qw(App::Dialog::Encounter);

sub initialize
{
	my $self = shift;

	$self->heading('Check-In');

	$self->SUPER::initialize();

	$self->addFooter(new CGI::Dialog::Buttons);
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
	$self->updateFieldFlags('checkout_stamp', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('claim_diags', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_heading', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('procedures_list', FLDFLAG_INVISIBLE, 1);
	$self->setFieldFlags('attendee_id', FLDFLAG_READONLY);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	## First, update original event record to checkin status, and any changes
	#my $timeStamp = $page->getTimeStamp();
	my $eventStatus = App::Universal::EVENTSTATUS_INPROGRESS;
	if ($page->schemaAction(
			'Event', 'update',
			event_id => $page->field('event_id') || undef,
			event_status => defined $eventStatus ? $eventStatus : undef,
			checkin_stamp => $page->field('checkin_stamp') || undef,
			checkin_by_id => $page->session('user_id'),
			remarks => $page->field('remarks') || undef,
			event_type => $page->field('appt_type') || undef,
			subject => $page->field('subject') || undef,
			duration => $page->field('duration') || undef,
			facility_id => $page->field('service_facility_id') || undef,
			_debug => 0
		) == 0)
		{
			$page->addDebugStmt('Fatal Check-in Error.<br>Event not updated; Transaction not created; Invoice not created; Copay not recorded.');
			return 0;
		}

	# Add Trans and Invoice info
	App::Dialog::Encounter::addTransactionAndInvoice($self, $page, $command, $flags);
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#

use constant CHECKIN_DIALOG => 'Dialog/Checkin';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/27/2000', 'MAF',
		CHECKIN_DIALOG,
		'Added Authorization pane to supplementaryHtml.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/28/2000', 'MAF',
		CHECKIN_DIALOG,
		'Changed sub new to sub initialize. Updated makeStateChanges accordingly.'],
);

1;