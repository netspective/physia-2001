##############################################################################
package App::Dialog::Assign;
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
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'assign' => {},	
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'assign', heading => 'Assign Resources');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field::Duration(name => 'effective',
			caption => 'Appointment Dates',
			options => FLDFLAG_REQUIRED
		),

		new App::Dialog::Field::RovingResource(physician_field => '_f_resource_id_from',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
		),

		new App::Dialog::Field::Person::ID(name => 'resource_id_from',
			caption => 'Resource ID (From)',
			types => ['Physician'],
			hints => 'Reassign Appointments From this Resource',
			size => 30,
			options => FLDFLAG_REQUIRED
		),

		new App::Dialog::Field::Person::ID(name => 'resource_id_to',
			caption => 'Resource ID (To)',
			types => ['Physician'],
			hints => 'To this Resource',
			size => 30,
			options => FLDFLAG_REQUIRED
		),

#		new CGI::Dialog::Field(name => 'facility_id',
#			caption => 'Facility',
#			fKeyStmtMgr => $STMTMGR_SCHEDULING,
#			fKeyStmt => 'selFacilityList',
#			fKeyDisplayCol => 1,
#			fKeyValueCol => 0,
#			options => FLDFLAG_REQUIRED),

		new App::Dialog::Field::Organization::ID(name => 'facility_id',
			caption => 'Facility',
			types => ['Facility'],
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons(
#		nextActions => [
#			['Return to Schedule Page', '/schedule'],
#			['Assign another Roving Resource', '/schedule/assign/'],
#		],
#		cancelUrl => $self->{cancelUrl} || undef
	));

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

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $beginDate = $page->param('fromDate') || UnixDate('today', '%m/%d/%Y');
	$beginDate =~ s/\-/\//g;
	my $endDate   = $page->param('toDate') || UnixDate('today', '%m/%d/%Y');
	$endDate =~ s/\-/\//g;

	$page->field('effective_begin_date', $beginDate);
	$page->field('effective_end_date', $endDate);
	$page->field('facility_id', $page->param('org_id') || $page->session('org_id'));
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $fromResourceID = $page->field('resource_id_from');
	my $toResourceID = $page->field('resource_id_to');

	my $startDate = $page->field('effective_begin_date');
	my $endDate = $page->field('effective_end_date');

	my $facility_id = $page->field('facility_id') || $page->session('org_id');

	$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_DEBUG, 'updAssignResource', $toResourceID,
		$fromResourceID, $startDate, $endDate, $facility_id);

	$self->handlePostExecute($page, $command, $flags);
}

1;
