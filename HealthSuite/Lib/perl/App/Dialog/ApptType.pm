##############################################################################
package App::Dialog::ApptType;
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
use constant NEXTACTION_COPYASNEW => "/org/%session.org_id%/dlg-add-appttype/%field.appt_type_id%";
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'appttype' => { 
			_arl => ['appt_type_id'], 
		},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'template', heading => '$Command Appointment Type');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $r_ids_field = new App::Dialog::Field::Person::ID(caption => 'Resource ID(s)',
		name => 'r_ids',
		types => ['Physician'],
		hints => 'Appt Type applies to these Resource(s)',
		size => 40,
		maxLength => 255,
		findPopupAppendValue => ',',
		options => FLDFLAG_REQUIRED,
	);
	$r_ids_field->clearFlag(FLDFLAG_IDENTIFIER);

	my $rr_ids_field = new App::Dialog::Field::Person::ID(caption => 'Associated Resource(s)',
		name => 'rr_ids',
		hints => 'These Resources must also be available',
		types => ['Physician'],
		size => 40,
		maxLength => 255,
		findPopupAppendValue => ',',
	);
	$rr_ids_field->clearFlag(FLDFLAG_IDENTIFIER);

	$self->addContent(
		new CGI::Dialog::Field(name => 'appt_type_id',
			caption => 'Appointment Type ID',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD
		),
		
		$r_ids_field,
		
		new CGI::Dialog::Field::TableColumn(column => 'Appt_Type.caption',
			caption => 'Caption',
			schema => $schema,
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Appointment Duration',
			name => 'duration',
			type => 'integer',
			hints => 'Duration in Minutes',
			defaultValue => 10,
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::MultiField(
			fields => [			
				new CGI::Dialog::Field(caption => 'Lead Time',
					name => 'lead_time',
					type => 'integer',
					hints => 'minutes',
				),
				new CGI::Dialog::Field(caption => 'Lag Time (minutes)',
					name => 'lag_time',
					type => 'integer',
					hints => 'minutes',
				),
			],
		),
		new CGI::Dialog::Field(caption => 'Back To Back Appointment Allowed',
			name => 'back_to_back',
			type => 'bool',
			style => 'check',
			defaultValue => 1,
		),
		
		new CGI::Dialog::MultiField(name => 'simultaneous',		
			fields => [
				new CGI::Dialog::Field(caption => 'Multiple Simultaneous Appts Limits',
					name => 'num_sim',
					type => 'integer',
					hints => 'Max # simultaneous appointments',
				),
				new CGI::Dialog::Field(caption => 'Allowed',
					name => 'multiple',
					type => 'bool',
					style => 'check',
					defaultValue => 0,
				),
			],
		),

		new CGI::Dialog::MultiField(name => 'limits',
			fields => [
				new CGI::Dialog::Field(caption => 'AM Limits',
					name => 'am_limit',
					type => 'integer',
					hints => 'Max # appointments of this type during AM hours',
				),		
				new CGI::Dialog::Field(caption => 'PM Limits',
					name => 'pm_limit',
					type => 'integer',
					hints => 'Max # appointments of this type during PM hours',
				),
				new CGI::Dialog::Field(caption => 'All Day Limits',
					name => 'day_limit',
					type => 'integer',
					hints => 'Max # appointments of this type for entire day',
				),
			],
		),
		

		$rr_ids_field,

		new App::Dialog::Field::RovingResource(physician_field => '_f_rr_ids',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
			appendMode => 1,
		),

	);

	$self->addFooter(new CGI::Dialog::Buttons(
		nextActions_update => [
			['', '', 1],
			['Copy as New Appointment Type', NEXTACTION_COPYASNEW],
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
	if ($page->param('appt_type_id'))
	{
		$self->populateData_update($page, $command, $activeExecMode, $flags);
	}
}

sub populateData_update
{	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $apptTypeId = $page->param('appt_type_id');
	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE,
		'selPopulateApptTypeDialog', $apptTypeId);
	
	$page->field ('multiple', 1) if $page->field('num_sim') > 1;		
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $apptTypeId = $page->field('appt_type_id');
	my $timeStamp = $page->getTimeStamp();

	$page->field ('multiple', 1) if $page->field('num_sim') > 1;
	
	my $newApptTypeId = $page->schemaAction(
		'Appt_Type', $command,
		appt_type_id => $command eq 'add' ? undef : $apptTypeId,
		r_ids => $page->field ('r_ids'),
		caption => $page->field ('caption'),
		duration => $page->field('duration') || 10,
		lead_time => $page->field ('lead_time') || undef,
		lag_time => $page->field ('lag_time')  || undef,
		back_to_back => $page->field ('back_to_back') || 0,
		multiple => $page->field ('multiple') || 0,
		num_sim => $page->field ('num_sim') || undef,
		am_limit => $page->field ('am_limit') || undef,
		pm_limit => $page->field ('pm_limit') || undef,
		day_limit => $page->field ('day_limit') || undef,
		rr_ids => $page->field ('rr_ids') || undef,
		owner_org_id => $page->session('org_internal_id'),
		_debug => 0
	);

	$page->param('_dialogreturnurl', '/search/appttype/1/%field.r_ids%')
		if $command eq 'update' || ! $page->field('nextaction_redirecturl');
	$self->handlePostExecute($page, $command, $flags);
}

1;
