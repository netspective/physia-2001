##############################################################################
package App::Page::Search::ApptSlot;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);
use App::Schedule::Analyze;
use App::Schedule::Utilities;

use DBI::StatementManager;
use App::Statements::Scheduling;
use Devel::ChangeLog;

use CGI::Dialog;
use App::Dialog::Field::RovingResource;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/apptslot' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->params('_advanced', 1) if $pathItems->[0] eq 'apptslota';
	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';

	unless ($self->param('searchAgain')) {
		if ($pathItems->[1]) {
			my ($resource_ids, $facility_ids, $start_date, $appt_duration) = split(/,/, $pathItems->[1]);
			$start_date =~ s/\-/\//g;

			$self->param('resource_ids', $resource_ids) if $resource_ids;
			$self->param('facility_ids', $facility_ids) if $facility_ids;
			$self->param('start_date',  $start_date) if $start_date;
			$self->param('appt_duration',  $appt_duration || 10);
			$self->param('searchAgain', 1);
		}
	}

	$self->param('execute', 'Go') if $pathItems->[2];  # Auto-execute
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my $parallelSearchChecked = "checked" if $self->param('parallel_search');

	my $dialog = new CGI::Dialog(schema => $self->SUPER::getSchema());
	my $rovingPhysField = new App::Dialog::Field::RovingResource(
		physician_field => 'resource_ids',
		name => 'roving_physician',
		caption => 'Roving Physician',
		type => 'foreignKey',
		fKeyDisplayCol => 0,
		fKeyValueCol => 0,
		fKeyStmtMgr => $STMTMGR_SCHEDULING,
		fKeyStmt => 'selRovingPhysicianTypes',
		appendMode => 1,
	);

	my $rovingPhysFieldHtml = $rovingPhysField->getHtml($self, $dialog);

	return ('Find next available slot', qq{
	<CENTER>
		<nobr>
		<label for="parallel_search">Parallel Search</label>
		<input name='parallel_search' id="parallel_search" type=checkbox $parallelSearchChecked>

		Resource(s):
		<input name='resource_ids' id='resource_ids' size=30 maxlength=255 value="@{[$self->param('resource_ids')]}" title='Resource IDs'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.resource_ids, '/lookup/person/id', ',');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		&nbsp;

		Facility(s):
		<input name='facility_ids' id='facility_ids' size=20 maxlength=32 value="@{[$self->param('facility_ids')]}" title='Facility IDs'>
			<a href="javascript:doFindLookup(document.search_form, document.search_form.facility_ids, '/lookup/org/id', ',');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>
		</nobr>
		<br>
		<table>
			$rovingPhysFieldHtml
		</table>

		<nobr>
		Starting:
		<input name='start_date' id='start_date' size=10 maxlength=10 title='Start Date'
			value="@{[$self->param('start_date') || UnixDate ('today', '%m/%d/%Y')]}">
		Duration:
		<select name="appt_duration" style="color: darkred">
			<option value="10">10 minutes</option>
			<option value="15">15 minutes</option>
			<option value="20">20 minutes</option>
			<option value="30">30 minutes</option>
			<option value="45">45 minutes</option>
			<option value="60">1 hour</option>
		</select>
		Look Ahead:
		<select name="search_duration" style="color: navy">
			<option value="7" >1 week</option>
			<option value="14">2 weeks</option>
			<option value="21">3 weeks</option>
			<option value="30">1 month</option>
		</select>

		<br>
		<nobr>
		Patient Type:
		<select name="patient_type" style="color: navy">
			<option value="-1" >All</option>
			<option value="0" >New Patients</option>
			<option value="1" >Established Patients</option>
			<option value="2" >Temporary Patients</option>
		</select>
		Visit Type:
		<select name="visit_type" style="color: navy">
			<option value="-1" >All</option>
			<option value="2040" >Physical Exam</option>
			<option value="2050" >Executive Physical</option>
			<option value="2060" >Sports/School Physical</option>
			<option value="2070" >Regular Visit</option>
			<option value="2080" >Complicated Visit</option>
			<option value="2090" >Well Women Exam</option>
			<option value="2100" >Consultation</option>
			<option value="2110" >Injection Only</option>
			<option value="2120" >Procedure Visit</option>
			<option value="2130" >Workmans Comp Visit</option>
			<option value="2140" >Radiology Visit</option>
			<option value="2150" >Lab Visit</option>
			<option value="2160" >Counseling Visit</option>
			<option value="2170" >Physical Therapy</option>
			<option value="2180" >Special Visit</option>
		</select>
		</nobr>

		<script>
			setSelectedValue(document.search_form.appt_duration, '@{[ $self->param('appt_duration') || 10 ]}');
			setSelectedValue(document.search_form.search_duration, '@{[ $self->param('search_duration') || 7 ]}');
			setSelectedValue(document.search_form.patient_type, '@{[ $self->param('patient_type')]}');
			setSelectedValue(document.search_form.visit_type, '@{[ $self->param('visit_type')]}');
		</script>

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">
		<input type=submit name="execute" value="Go">
	</CENTER>
	});
}

sub execute
{
	my ($self) = @_;

	my @resource_ids = split(/,/, $self->param('resource_ids'));
	my @facility_ids = split(/,/, $self->param('facility_ids'));

	my @search_start_date = Decode_Date_US($self->param('start_date')) if $self->param('start_date');
	eval {check_date(@search_start_date);};
	@search_start_date = Today() if $@;

	my $patient_type = $self->param('patient_type') if defined $self->param('patient_type');
	my $visit_type = $self->param('visit_type') if defined $self->param('visit_type');

	my $sa = new App::Schedule::Analyze (
		resource_ids      => \@resource_ids,
		facility_ids      => \@facility_ids,
		search_start_date => \@search_start_date,
		search_duration   => $self->param('search_duration') || 7,
		patient_type      => $patient_type || -1,
		visit_type        => $visit_type || -1
	);

	my $flag = App::Schedule::Analyze::MULTIRESOURCESEARCH_SERIAL;
	$flag = App::Schedule::Analyze::MULTIRESOURCESEARCH_PARALLEL if defined $self->param('parallel_search');
	my @available_slots = $sa->findAvailSlots($self, $flag);
	my $slotsHtml = $self->getSlotsHtml($sa, @available_slots);
	$self->addContent($slotsHtml);
}

sub getSlotsHtml
{
	my ($self, $sa, @slots) = @_;

	my $html = qq{
		<style>
				a { text-decoration: none; }
				a { color: blue; }
				td { font-size: 9pt; font-family: Tahoma }
				th { font-size: 9pt; font-family: Tahoma }
				a:hover { color: red; }
		</style>
	};

	$html .= "<br>" if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	$html .= "<center> <table border=0 cellspacing=0 cellpadding=3>\n";

	if (@slots) {
		$html .= "<tr bgcolor=#eeeedd><th>Resource</th><th>Facility</th><th colspan=2>Day</th><th>Time Slot</th></tr>\n";
	} else {
		$html .= "<tr><td>No available slot found in this search period.</td></tr>\n";
	}

	my $found = 0;
	my $today = Date_to_Days(Today());

	my $dayPrinted = 0;

	for (@slots)
	{
		my $resource_id = $_->{resource_id};
		my $facility_id = $_->{facility_id};
		my @minute_ranges = split(/,/, $_->{minute_set}->run_list);

		for (@minute_ranges)
		{
			my ($low, $high) = split(/-/, $_);

			my $dayOffset = int($low/24/60);
			$low  -= $dayOffset*24*60;
			$high -= $dayOffset*24*60;

			my $day  = $dayOffset + Date_to_Days(@{$sa->{search_start_date}});

			next if ($high - $low) < $self->param('appt_duration');
			next if ($day < $today);

			$found = 1;

			my $timeString = minute_set_2_string("$low-$high", TIME_H12);
			my @date = Days_to_Date($day);

			my $dateString = sprintf ("%02d-%02d-%04d", $date[1],$date[2],$date[0]);
			my $fmtDate  = sprintf ("%02d/%02d/%04d", $date[1],$date[2],$date[0]);
			my $dow = sprintf ("%.3s", Day_of_Week_to_Text(Day_of_Week(@date)));

			my $resourceHref;
			my $facilityHref;

			if ($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
				$resourceHref = $resource_id;
				$resourceHref = join(',', @{$sa->{resource_ids}}) if $self->param('parallel_search');
				$facilityHref = $facility_id;
			} else {
				$resourceHref = qq{<a style="font-weight:bold" href="javascript:chooseItem('/search/apptslot/%itemValue%/1', '$resource_id,,$dateString', false);" >$resource_id </a>};
				$facilityHref = qq{<a href="javascript:chooseItem('/search/apptslot/%itemValue%/1', ',$facility_id,$dateString', false);" >$facility_id </a>};
				$resourceHref = join(',', @{$sa->{resource_ids}}) if $self->param('parallel_search');
			}

			if ($dayPrinted == $day) {
				$html .= "<tr><td>&nbsp</td><td>&nbsp</td><td>&nbsp</td><td>&nbsp</td>\n";

			} else {
				$html .= "<TR><TD COLSPAN=5><IMG SRC='/resources/design/bar.gif' WIDTH=100% HEIGHT=1></TD></TR>";
				$html .= "<tr><td>$resourceHref</td><td>$facilityHref</td><td align=right>";

				if (! $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
					$html .= "<a href='/schedule/apptsheet/$dateString'>$dow</a>";
				} else {
					$html .= "$dow";
				}

				$html .= "</td><td>$fmtDate</td>\n";
				$dayPrinted = $day;
			}

			my $startTime = $dateString . "_" . Trim(minute_set_2_string($low, TIME_H12));
			my $startTimeHref;

			if ($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP)) {
				$startTime =~ s/\_/ /g;
				$startTime =~ s/\-/\//g;
				$startTimeHref = qq{<a href="javascript:chooseItem('/schedule/appointment/add/%itemValue%', '$startTime', false);" >$timeString </a>};
			} else {
				$startTimeHref = qq{<a href="javascript:chooseItem('/schedule/appointment/add/%itemValue%', '$resource_id,$startTime', false);" >$timeString </a>};
			}

			$html .= "<td>$startTimeHref</td>\n";
			$html .= "</tr>\n";
		}
	}

	if (! $found && @slots) {
		$html .= "<tr><td>No available slot found meeting this appointment duration.</td></tr>";
	}

	$html .= "</table></center>";

	return $html;
}

1;
