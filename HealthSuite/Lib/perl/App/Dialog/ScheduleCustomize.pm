##############################################################################
package App::Dialog::ScheduleCustomize;
##############################################################################

use strict;
use Carp;

use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;
use App::Dialog::Field::Organization;
use App::Dialog::Field::RovingResource;

use App::Schedule::ApptSheet;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Org;

use vars qw(@ISA %RESOURCE_MAP);
use Date::Manip;

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'customize' => {},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'customize', heading => '$Command Schedule Preference');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	
	my $physField = new App::Dialog::Field::Person::ID(caption => 'Physician ID',
		name => 'resource_id',
		types => ['Physician'],
		hints => 'Physician ID or select a Roving Physician',
		options => FLDFLAG_REQUIRED,
		size => 32,
		maxLength => 64,
	);
	$physField->clearFlag(FLDFLAG_IDENTIFIER); # because we can have roving resources, too.

	$self->addContent(

		new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),

		new CGI::Dialog::Field(name => 'column',
			caption => 'Column',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD
		),

		$physField,
		
		new App::Dialog::Field::RovingResource(physician_field => '_f_resource_id',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
		),

		new App::Dialog::Field::Organization::ID(name => 'facility_id',
			caption => 'Facility',
			#types => ['Facility'],
		),

		new CGI::Dialog::Field(name => 'date_offset',
			caption => 'Relative Date',
			choiceDelim =>',',
			selOptions => "Selected Date -3:-3,Selected Date -2:-2,Selected Date -1:-1,Selected Date:0,Selected Date +1:1,Selected Date +2:2,Selected Date +3:3",
			type => 'select',
		),

		new CGI::Dialog::Field(name => 'remove_column',
			type => 'bool',
			style => 'check',
			defaultValue => 0,
			caption => 'Remove this column',
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD
		),

		new CGI::Dialog::Subhead(heading => ''),
		
		new CGI::Dialog::MultiField (caption => 'Appt Sheet Start/End Hours',
			fields => [		
				new CGI::Dialog::Field(caption => 'Start Hour',
					type => 'integer',
					size => 2,
					options => FLDFLAG_REQUIRED,
					hints => 'The starting Appointment Sheet time',
					name => 'start_hour',
					defaultValue => 6,
					minValue => 0,
					maxValue => 23,
					onBlurJS => qq{validateHours(this.form)},
				),

				new CGI::Dialog::Field(caption => 'End Hour',
					type => 'integer',
					size => 2,
					options => FLDFLAG_REQUIRED,
					hints => 'The starting Appointment Sheet time',
					name => 'end_hour',
					defaultValue => 21,
					minValue => 0,
					maxValue => 23,
					onBlurJS => qq{validateHours(this.form)},
				),
			],
		),
		
		new CGI::Dialog::Field(type => 'hidden', name => 'have_pref', defaultValue => 0,),	

	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

###############################
# getSupplementaryHtml
###############################

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	my $apptsheetTimes = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selApptSheetTimes', $page->session('user_id'));

	my ($apptSheetStartTime, $apptSheetEndTime);

	if(defined $apptsheetTimes->{start_time})
	{
		$apptSheetStartTime = $apptsheetTimes->{start_time};
		$apptSheetEndTime   = $apptsheetTimes->{end_time};
	}
	else
	{
		$apptSheetStartTime = 6;
		$apptSheetEndTime   = 21;
	}	

	if ($command eq 'update') {
		my @column = ($page->param('selDate'), $page->param('resource_id'), $page->param('facility_id'));
		my @inputSpec = (\@column);

		my $apptSheet = new App::Schedule::ApptSheet (inputSpec => \@inputSpec);
		my $apptSheetHtml = $apptSheet->getHtml($page, $apptSheetStartTime, $apptSheetEndTime,
			APPTSHEET_HEADER|APPTSHEET_BODY|APPTSHEET_BOOKCOUNT);

		return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, $apptSheetHtml);
	}
	return $self->SUPER::getSupplementaryHtml($page, $command);
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

	$page->field('date_offset', 0);
	$self->populateHourFields($page);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $userID = $page->session('user_id');
	my $column = $page->param('column');

	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 
		'selColumnPreference', $userID, $column, $page->session('org_internal_id'));
	
	$page->field('column', $column+1);
	$self->populateHourFields($page);
}

sub populateHourFields
{
	my ($self, $page) = @_;
	
	my $pref = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE, 'selApptSheetTimes', 
		$page->session('user_id'));
		
	$page->field('start_hour', $pref->{start_time} || 6);
	$page->field('end_hour', $pref->{end_time} || 21);
	$page->field('have_pref', 1) if defined $pref->{start_time};
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $userID = $page->session('user_id');
	my $column = $page->param('column');
	my $colNumber;
	my $orgInternalId = $page->session('org_internal_id');

	if ($command eq 'add') {
		$colNumber = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE, 
			'selNumPreferences', $userID, $orgInternalId);
	} else {
		$colNumber = $page->param('column');
	}

	if ($page->field('remove_column'))
	{
		my $newItemID = $page->schemaAction(
			'Person_Attribute', 'remove',
			item_id => $page->field('item_id'),
			_debug => 0
		);

		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updSchedulingPref', $userID, 
			$column, $orgInternalId);
	}
	else
	{
		my $facility_internal_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE,
			'selOrgId', $orgInternalId, $page->field('facility_id'));
		
		my $newItemID = $page->schemaAction(
		'Person_Attribute', $command,
			item_id => $command eq 'add' ? undef : $page->field('item_id'),
			value_text  => $page->field('resource_id'),
			value_textB => $facility_internal_id || undef,
			value_int   => $colNumber,
			value_intB  => $page->field('date_offset'),
			parent_id   => $userID,
			item_name   => 'Preference/Schedule/DayView/Column',
			parent_org_id => $orgInternalId,
			_debug => 0
		);
	}
	
	if ($page->field('have_pref'))
	{
		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_DEBUG, 'updApptSheetTimesPref', 
			$page->field('start_hour'), $page->field('end_hour'), $userID );
	}
	else
	{
		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_DEBUG, 'insApptSheetTimesPref', 
			$userID, $page->field('start_hour'), $page->field('end_hour') );
	}
	
	$self->handlePostExecute($page, $command, $flags);

}

1;
