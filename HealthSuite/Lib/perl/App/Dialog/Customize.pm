##############################################################################
package App::Dialog::Customize;
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

use vars qw(@ISA);
use Date::Manip;

@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'customize', heading => '$Command Schedule Preference');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field(type => 'hidden', name => 'item_id'),

		new CGI::Dialog::Field(name => 'column',
			caption => 'Column',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD
		),

		new App::Dialog::Field::Person::ID(name => 'resource_id',
			caption => 'Resource ID',
			#idEntryStyle => 1,
			size => 25,
			maxLength => 64,
			types => ['Physician'],
			hints => 'Enter Resource ID or select a Roving Physician',
			options => FLDFLAG_REQUIRED
		),

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
			types => ['Facility'],
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

	#$page->dumpParams();

	if ($command eq 'update') {
		my @column = ($page->param('selDate'), $page->param('resource_id'), $page->param('facility_id'));
		my @inputSpec = (\@column);

		my $apptSheet = new App::Schedule::ApptSheet (inputSpec => \@inputSpec);
		my $apptSheetHtml = $apptSheet->getHtml($page, APPTSHEET_STARTTIME, APPTSHEET_ENDTIME,
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
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $userID = $page->session('user_id');
	my $column = $page->param('column');

	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selColumnPreference', $userID, $column);

	$page->field('column', $column+1);
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

	if ($command eq 'add') {
		$colNumber = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE, 'selNumPreferences', $userID);
	} else {
		$colNumber = $page->param('column');
	}

	if ($page->field('remove_column'))
	{
		my $newItemID = $page->schemaAction(
			'Person_Attribute', 'remove',
			item_id => $page->field('item_id'),
			_debug => 1
		);

		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updSchedulingPref', $userID, $column);
	}
	else
	{
		my $newItemID = $page->schemaAction(
		'Person_Attribute', $command,
			item_id => $command eq 'add' ? undef : $page->field('item_id'),
			value_text  => $page->field('resource_id'),
			value_textB => $page->field('facility_id') || undef,
			value_int   => $colNumber,
			value_intB  => $page->field('date_offset'),
			parent_id   => $userID,
			item_name   => 'Preference/Schedule/DayView/Column',
			_debug => 0
		);
	}

	#$page->redirect("/schedule");
	$self->handlePostExecute($page, $command, $flags);

}

1;
