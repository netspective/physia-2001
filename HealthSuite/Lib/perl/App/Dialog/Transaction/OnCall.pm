##############################################################################
package App::Dialog::Transaction::OnCall;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Association;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;
use constant MAXID => 25;

use App::Universal;
use Date::Manip;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'on-call' => {
		heading => '$Command On Call Note',
		_arl => ['person_id', 'trans_id'],
		_idSynonym => 'On-call'
	},
);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'on-call', heading => 'On Call Note');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;


	$self->addContent(

		new App::Dialog::Field::Person::ID(caption => 'Patient ID', name => 'person_id', readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, options => FLDFLAG_REQUIRED, types => ['Patient']),
		new App::Dialog::Field::Person::ID(caption=>'On Call Physician ID', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE, name => 'physician_id', types => ['Physician', 'Referring-Doctor'], options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::ID(caption=>"Patient's Regular Physician ID", name => 'reg_physician_id', options => FLDFLAG_REQUIRED, types => ['Physician', 'Referring-Doctor']),
		new CGI::Dialog::Field(name => 'begin_stamp', caption => 'Date and Time of encounter' , type => 'stamp', futureOnly => 0, options => FLDFLAG_READONLY),

		new CGI::Dialog::Field(caption => 'Reason',
			name => 'reason',
			type => 'select',
			selOptions => 'Needs refill;Problem with medication;Having pain',
			options => FLDFLAG_PREPENDBLANK,
			),
		new CGI::Dialog::Field(type => 'memo', caption => 'Other Reason', name => 'other_reason'),


		new CGI::Dialog::Field(caption => 'Action',
			name => 'action',
			type => 'select',
			selOptions => 'Call Office in AM;Follow up in office on (date or day of week);Go to ER;Stop present medications;Take Over the Counter Medication',
			options => FLDFLAG_PREPENDBLANK,
			),
		new CGI::Dialog::Field(type => 'memo', caption => 'Other Action/Detail', name => 'other_action'),
	);

	$self->{activityLog} = {
		scope =>'person',
		key => "#field.person_id#",
		data => "\u$command oncall notes for '#field.person_id#' <a href='/person/#field.person_id#/profile'>#field.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
		#component.stpe-person.activeMedications#<BR>
	});
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_ADD_DATAENTRY_INITIAL;

	$page->field('person_id', $page->param('person_id'));
	$page->field('physician_id', $page->session('user_id'));

	my $timeStamp = $page->getTimeStamp();
	$page->field('begin_stamp', $page->getTimeStamp());
}

sub execute
{
	my ($self, $page, $command, $flags, $member) = @_;

	$page->schemaAction(
		'Transaction', $command,
		trans_type => App::Universal::TRANSTYPEACTION_ONCALL,
		trans_status => App::Universal::TRANSSTATUS_NOTREAD,
		trans_owner_id => $page->field('reg_physician_id') || undef,
		trans_owner_type => App::Universal::ENTITYTYPE_PERSON,
		receiver_id => $page->field('person_id') || undef,
		receiver_type => App::Universal::ENTITYTYPE_PERSON,
		care_provider_id => $page->field('physician_id') || undef,
		trans_begin_stamp => $page->field('begin_stamp') || undef,
		caption => $page->field('reason') || undef,
		detail => $page->field('action') || undef,
		data_text_a => $page->field('other_reason') || undef,
		data_text_b => $page->field('other_action') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
