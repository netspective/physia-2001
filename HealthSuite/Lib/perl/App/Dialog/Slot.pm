##############################################################################
package App::Dialog::Slot;
##############################################################################

use strict;
use Carp;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;
#use Date::Manip;
use Date::Calc qw(:all);
use App::Schedule::Analyze;
use App::Schedule::Slot;
use App::Schedule::Utilities;
use DBI::StatementManager;
use App::Statements::Scheduling;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'slot', heading => 'Find Available Slot');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new App::Dialog::Field::Person::ID(caption => 'Physician',
			name => 'resource_id', types => ['Physician'], options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Facility',
			#type => 'foreignKey',
			name => 'facility_id',
			#fKeyTable => 'org o, org_category oc',
			#fKeySelCols => "distinct o.ORG_ID, o.NAME_PRIMARY",	
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selFacilityList',	
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,			
			#fKeyWhere => "o.ORG_ID = oc.PARENT_ID and UPPER(oc.MEMBER_NAME) in ('FACILITY','CLINIC')",
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Search From Date',
			name => 'start_date',
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Duration',
			#type => 'foreignKey',
			name => 'duration',
			#fKeyTable => 'appt_duration',
			#fKeySelCols => "id, caption",
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selApptDuration',	
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			#fKeyWhere => "",
			options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(caption => 'Search Through Next',
			name => 'search_next', type => 'select', selOptions => '1 week:7;2 weeks:14;3 weeks:21;1 month:30',
			value => '7', options => FLDFLAG_REQUIRED),

		new CGI::Dialog::Field(name => 'patient_types',
			caption => 'Limit Attendees',
			enum => 'Appt_Attendee_Type',
			style => 'multicheck',
		),

		new CGI::Dialog::Field(name => 'visit_types',
			caption => 'Limit Trans',
			choiceDelim =>',',
			selOptions => "Test1:0,Test2:1,Test3:2",
			type => 'select',
			style => 'multicheck',
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

###############################
# populateData function
###############################

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	# set appt date/time based on value passed in, or use 'now' from getTimeStamp fcn
	my $startDate = $page->getDate($page->param('_start_date'));
	$page->field('resource_id', $page->param('_resource_id'));
	$page->field('facility_id', $page->param('_facility_id'));
	$page->field('start_date', $startDate);
	$page->field('duration', $page->param('_duration'));
	$page->field('search_next', $page->param('_search_next'));

	$page->field('patient_types', split(',', $page->param('_patient_types')));
  $page->field('visit_types', split(',', $page->param('_visit_types')));
}

sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	my $showResults = $page->param('_showResults');
	my $supHtml = undef;

	my @resource = ($page->field('resource_id') || 'dummy');
	my @date = Decode_Date_US($page->field('start_date'));
	eval {check_date(@date);};
	@date = Today() if $@;

	my $patient_types = $page->param('_patient_types');
	my $visit_types = $page->param('_visit_types');

	my $sa = new App::Schedule::Analyze (
		resource_ids      => \@resource,
		search_start_date => \@date,
		search_duration   => $page->field('search_next'),
		facility_id       => $page->field('facility_id') || undef,
		patient_types     => $patient_types || undef,
		visit_types       => $visit_types || undef
	);

	if ($showResults)
	{
		my @available_slots = $sa->findAvailSlots($page);
		$supHtml = $self->getSlotsHtml($page, @available_slots);
	}
	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_BOTTOM, $supHtml);
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	# Redirect to self, with showResults param set to true
	$page->param('_showResults', '1');
	$page->param('_facility_id', $page->field('facility_id'));
	$page->param('_resource_id', $page->field('resource_id'));
	$page->param('_start_date', $page->field('start_date'));
	$page->param('_duration', $page->field('duration'));
	$page->param('_search_next', $page->field('search_next'));
	$page->param('_patient_types', join(',',$page->field('patient_types')));
	$page->param('_visit_types', join(',',$page->field('visit_types')));

	return $self->getSupplementaryHtml($page, $command);
	#$page->redirect($page->selfRef($page));
}

###############################
# display function
###############################

sub getSlotsHtml
{
	my ($self, $page, @slots) = @_;

	my $html = qq{
		<style>
			a { text-decoration: none; }
			a { color: blue; }
			a:hover { color: red; }
		</style>
	};

	$html .= "<center> <table border=0 cellspacing=0 cellpadding=3>\n";

	if (@slots) {
		$html .= "<tr bgcolor=lightsteelblue><th colspan=2>Day</th><th>Time Slot</th></tr>\n";
	} else {
		$html .= "<tr><td>No available slot found in this search period.</td></tr>\n";
	}

	my ($bgColor, $bgColor1, $bgColor2) = ('beige', 'beige', 'lightyellow');
	my $font = qq{<font face='Tahoma,Arial' size=2>};
	my $found = 0;

	my $today = Date_to_Days(Today());

	for my $i (0..(@slots-1)) {

		my @minute_ranges = split(/,/, $slots[$i]->{minute_set}->run_list);
		my $printDayAlready = 0;

		for (@minute_ranges)
		{
			$bgColor = $bgColor eq $bgColor1 ? $bgColor2 : $bgColor1;

			my $set = new Set::IntSpan($_);
			next if ($set->max - $set->min) < $page->field('duration');
			next if ($slots[$i]->{day} == $today);
			$found = 1;

			my $timeString = minute_set_2_string($_, TIME_H12);
			my @date = Days_to_Date($slots[$i]->{day});
			my $dateString = sprintf ("%02d/%02d/%04d", $date[1],$date[2],$date[0]);
			my $dow = sprintf ("%.3s", Day_of_Week_to_Text(Day_of_Week(@date)));

			if ($printDayAlready) {
				$bgColor = $bgColor eq $bgColor1 ? $bgColor2 : $bgColor1;
				$html .= "<tr bgcolor=$bgColor><td>&nbsp</td><td>&nbsp</td>\n";

			} else {

				$html .= "<tr bgcolor=$bgColor><td align=right>$font $dow</td><td>$font $dateString</td>\n";
				$printDayAlready = 1;
			}

			my $field = $page->param('_field');
			my $startTime = $dateString . " ". minute_set_2_string($set->min, TIME_H12);
			my $startTimeHref = qq{<a href="javascript:opener.document.dialog.$field.value='$startTime'; window.close();" >$timeString </a>};

			$html .= "<td>$font $startTimeHref</td>\n";
			$html .= "</tr>\n";
		}
	}

	if (! $found && @slots) {
		$html .= "<tr><td>No available slot found meeting this appointment duration.</td></tr>";
	}

	$html .= "</table></center>";

	return $html;
}

use constant SLOT_DIALOG => 'Dialog/SLOT';
@CHANGELOG =
(	
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/17/2000', 'RK',
		SLOT_DIALOG,
		'Replaced fkeyxxx select in the dialog with Sql statement from Statement Manager.'],
);
1;
