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
		types => ['Physician'],
		hints => 'Resource(s) and/or select Roving Physician(s)',
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

		new CGI::Dialog::Field::TableColumn(column => 'Template.caption',
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
			caption => 'Patient Types',
			enum => 'Appt_Attendee_Type',
			style => 'multicheck',
		),

		new CGI::Dialog::Field(name => 'visit_types',
			caption => 'Visit Types',
			fKeyStmtMgr => $STMTMGR_TRANSACTION,
			fKeyStmt => 'selVisitType',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			type => 'select',
			style => 'multicheck',
		),

		new CGI::Dialog::Subhead(heading => ''),
		new CGI::Dialog::Field::Duration(name => 'duration',
			caption => 'Start / End Time',
			type => 'time',
			hints => '(Default to all day if time is not specified)',
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
		),

		new CGI::Dialog::Subhead(heading => ''),
		new CGI::Dialog::MultiField(caption => 'Remarks / Preferences',
			fields => [
				new CGI::Dialog::Field::TableColumn(column => 'Template.remarks',
					caption => 'Remarks',
					schema => $schema,
				),
				new CGI::Dialog::Field::TableColumn(column => 'Template.preferences',
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
		$page->field('duration_begin_time', '08:00 am');
		$page->field('duration_end_time', '08:00 pm');
	}
}

sub populateData_update
{	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $timeFormat = 'HH:MI AM';
	my $templateID = $page->param('template_id');
	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,'selPopulateTemplateDialog', $templateID);

  $page->field('days_of_week', split(',', $page->field('days_of_week')));
  $page->field('months', split(',', $page->field('months')));
  $page->field('patient_types', split(',', $page->field('patient_types')));
  $page->field('visit_types', split(',', $page->field('visit_types')));
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

	my $newTemplateID = $page->schemaAction(
	'Template', $command,
	template_id => $command eq 'add' ? undef :$templateID,
	effective_begin_date => $page->field('effective_begin_date') || undef,
	effective_end_date => $page->field('effective_end_date') || undef,
	start_time => $page->field ('duration_begin_time') || undef,
	end_time => $page->field ('duration_end_time') || undef,
	caption => $page->field ('caption'),
	r_ids => $page->field ('r_ids'),
	facility_id => $page->field ('facility_id'),
	available => $page->field ('available'),
	status => $page->field ('status'),
	remarks => $page->field('remarks') || undef,
	preferences => $page->field('preferences') || undef,
	days_of_week => join(',',  $page->field('days_of_week')) || undef,
	days_of_month => $page->field('days_of_month') || undef,
	months => join(',',$page->field('months')) || undef,
	patient_types => join(',',$page->field('patient_types')) || undef,
	visit_types => join(',',$page->field('visit_types')) || undef,
	owner_org_id => $page->session('org_internal_id'),
	_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
}

1;
