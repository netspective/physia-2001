##############################################################################
package App::Dialog::Template;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;
use App::Dialog::Field::RovingResource;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Transaction;
use Date::Manip;
use App::Schedule::Utilities;
use Set::IntSpan;

use constant NEXTACTION_COPYASNEW => "/schedule/template/add/,%field.template_id%";
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'template' => {
		_arl_modify => ['template_id'],
		_arl_add => ['resource_id', 'facility_id'],
	},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'template', heading => '$Command Template');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $physField = new App::Dialog::Field::Person::ID(name => 'r_ids',
		caption => 'Resource(s)',
		type => 'not_an_identifier', # to disable type identifier
		types => ['Physician'],
		hints => 'Template applies to these Resource(s) and/or Roving Physician(s)',
		size => 70,
		maxLength => 255,
		findPopupAppendValue => ',',
		options => FLDFLAG_REQUIRED,
	);
	$physField->clearFlag(FLDFLAG_IDENTIFIER); # because we can have roving resources, too.

	$self->addContent(

		new CGI::Dialog::Field(name => 'template_id',
			caption => 'Template ID',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD
		),

		new CGI::Dialog::Field::Duration(name => 'effective',
			caption => 'Effective Dates',
		),

		new CGI::Dialog::Field::TableColumn(column => 'Sch_Template.caption',
			caption => 'Caption',
			schema => $schema,
			options => FLDFLAG_REQUIRED
		),

		$physField,

		new App::Dialog::Field::RovingResource(physician_field => '_f_r_ids',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
			appendMode => 1,
		),

		new CGI::Dialog::MultiField (caption => 'Facility/Type/Status',
			fields => [
				new App::Dialog::Field::OrgType(
					caption => 'Facility',
					types => qq{'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'},
					name => 'facility_id'),

				new CGI::Dialog::Field(name => 'available',
					type => 'select',
					selOptions => 'Available:1;Not Available:0',
					hints => 'Available',
					options => FLDFLAG_REQUIRED),

				new CGI::Dialog::Field(name => 'status',
					type => 'select',
					selOptions => 'Active:1;Not Active:0',
					hints => 'Status',
					options => FLDFLAG_REQUIRED),
			]),

		new CGI::Dialog::Field(name => 'patient_types',
			caption => 'Patient Type(s)',
			enum => 'Appt_Attendee_Type',
			style => 'multicheck',
		),

		new CGI::Dialog::Field(caption => 'Appointment Type(s)',
			name => 'appt_types',
			style => 'multidual',
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'sel_AllApptTypes',
			fKeyStmtBindSession => ['org_internal_id'],
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			size => 5,
			multiDualCaptionLeft => 'Available Appt Types',
			multiDualCaptionRight => 'Selected Appt Types',
		),

		new CGI::Dialog::Subhead(heading => ''),
		new CGI::Dialog::Field::Duration(name => 'duration',
			caption => 'Start / End Time',
			type => 'time',
			options => FLDFLAG_REQUIRED,
		),

		new CGI::Dialog::Field(name => 'days_of_week',
			caption => 'Days',
			choiceDelim =>',',
			selOptions => "Sun:1,Mon:2,Tue:3,Wed:4,Thu:5,Fri:6,Sat:7",
			type => 'select',
			style => 'multicheck',
		),

		new CGI::Dialog::Field(name => 'months',
			caption => 'Months',
			choiceDelim =>',',
			selOptions => "Jan:1,Feb:2,Mar:3,Apr:4,May:5,Jun:6,Jul:7,Aug:8,Sep:9,Oct:10,Nov:11,Dec:12",
			type => 'select',
			style => 'multicheck',
		),

		new CGI::Dialog::Field(name => 'days_of_month',
			caption => 'Days of Month',
			type => 'text',
			hints => 'eg. 1,3,5-10,25-30',
			size => '32',
			regExpValidate => '[0123456789,-]',
		),

		new CGI::Dialog::Subhead(heading => ''),
		new CGI::Dialog::MultiField(caption => 'Remarks / Preferences',
			fields => [
				new CGI::Dialog::Field::TableColumn(column => 'Sch_Template.remarks',
					caption => 'Remarks',
					schema => $schema,
				),
				new CGI::Dialog::Field::TableColumn(column => 'Sch_Template.preferences',
					caption => 'Preferences',
					schema => $schema,
				),
			]),
	);

	#$self->addFooter(new CGI::Dialog::Buttons);

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_update => [
			['', '', 1],
			['Copy as New Template', NEXTACTION_COPYASNEW],
		],
		cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	if ($page->param('template_id'))
	{
		$self->populateData_update($page, $command, $activeExecMode, $flags);
	}
	else
	{
		my $startDate = $page->getDate();
		$page->field('effective_begin_date', $startDate);
		$page->field('r_ids', $page->param('resource_id'));
		$page->field('facility_id', $page->param('facility_id'));
		$page->field('duration_begin_time', '08:00 AM');
		$page->field('duration_end_time', '08:00 PM');
	}
}

sub populateData_update
{	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $gmtDayOffset = $page->session('GMT_DAYOFFSET');
	my $templateID = $page->param('template_id');
	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 
		'selPopulateTemplateDialog', $gmtDayOffset, $templateID);

  $page->field('days_of_week', split(',', $page->field('days_of_week')));
  $page->field('months', split(',', $page->field('months')));
  $page->field('patient_types', split(',', $page->field('patient_types')));
  $page->field('appt_types', split(',', $page->field('appt_types')));
}

sub customValidate
{
	my ($self, $page) = @_;

	my $beginTime = App::Schedule::Utilities::hhmmAM2minutes($page->field('duration_begin_time'));
	my $endTime   = App::Schedule::Utilities::hhmmAM2minutes($page->field('duration_end_time'));

	my $field = $self->getField('duration')->{fields}->[0];
	$field->invalidate($page, qq{Start Time must be earlier than End Time.})
		if $beginTime >= $endTime;

	$field = $self->getField('days_of_month');

	for (split(/\s*,\s*/, cleanup($page->field('days_of_month'))))
	{
		if (/\-/)
		{
			my ($low, $high) = split(/\s*\-\s*/);
			$field->invalidate($page, qq{Bad range '$_'})
				if $low >= $high || !$low || !$high || $low < 1 || $low > 31 || $high < 1 || $high > 31;
			next;
		}

		$field->invalidate($page, qq{Bad Day of Month '$_'}) if /.*\D.*/ || $_ > 31 || $_ < 1;
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my ($months, $daysOfWeek);

	my $templateID = $page->field('template_id');
	my $timeStamp = $page->getTimeStamp();
	my @dow = $page->field('days_of_week');

	my $dom_spec_set = new Set::IntSpan ();
	for my $item (sort {$a <=> $b} split(/\s*,\s*/, cleanup($page->field('days_of_month')) ))
	{
		$dom_spec_set = $dom_spec_set->union($item);
	}

	my $days_of_month;
	$days_of_month = $dom_spec_set->run_list() unless $dom_spec_set->empty();

	my $newTemplateID = $page->schemaAction(
	'Sch_Template', $command,
	template_id => $command eq 'add' ? undef :$templateID,
	effective_begin_date => $page->field('effective_begin_date') || undef,
	effective_end_date => $page->field('effective_end_date') || undef,
	start_time => $page->field('duration_begin_time') || undef,
	end_time => $page->field('duration_end_time') || undef,
	caption => $page->field('caption'),
	r_ids => cleanup($page->field('r_ids')),
	facility_id => $page->field('facility_id'),
	available => $page->field('available'),
	status => $page->field('status'),
	remarks => $page->field('remarks') || undef,
	preferences => $page->field('preferences') || undef,
	days_of_week => join(',',  $page->field('days_of_week')) || undef,
	days_of_month => $days_of_month || undef,
	months => join(',',$page->field('months')) || undef,
	patient_types => join(',',$page->field('patient_types')) || undef,
	appt_types => join(',', $page->field('appt_types')) || undef,
	owner_org_id => $page->session('org_internal_id'),
	_debug => 0,
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
