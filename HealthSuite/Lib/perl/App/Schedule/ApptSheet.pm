##############################################################################
package App::Schedule::ApptSheet;
##############################################################################

use strict;
use App::Schedule::Analyze;
use App::Schedule::Template;
use App::Schedule::Slot;
use App::Schedule::Utilities;
use Set::IntSpan;
use Date::Calc qw(:all);

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Org;

use enum qw(BITMASK:APPTSHEET_ HEADER BODY CUSTOMIZE BOOKCOUNT TEMPLATE);
use constant APPTSHEET_ALL => APPTSHEET_HEADER|APPTSHEET_BODY|APPTSHEET_CUSTOMIZE|APPTSHEET_BOOKCOUNT|APPTSHEET_TEMPLATE;

use Exporter;
use vars qw(@EXPORT @ISA);

@ISA = qw(Exporter);

my $negTemplateColor = 'firebrick';
my $posTemplateColor = 'lightgreen';
my $halfPosTemplateColor = 'lightcyan';
my $halfNegTemplateColor = 'lightpink';
my $columnWidth = 160;
my $hourWidth = '1%';

use vars qw(@PATIENT_TYPES @VISIT_TYPES @DAYS_OF_WEEK @MONTHS);
@PATIENT_TYPES = ();
@VISIT_TYPES   = ();
@DAYS_OF_WEEK  = ();
@MONTHS        = ();

@EXPORT = qw(APPTSHEET_HEADER APPTSHEET_BODY APPTSHEET_CUSTOMIZE APPTSHEET_BOOKCOUNT
	APPTSHEET_TEMPLATE APPTSHEET_ALL);

sub new
{
	my $self = shift;
	my %params = @_;

	$params{inputSpec} = $params{inputSpec} || {};

	$params{pos_slots}    = {};
	$params{neg_slots}    = {};
	$params{event_slots}  = {};

	$params{posMinuteSet} = {};
	$params{negMinuteSet} = {};

	return bless \%params, $self;
}

sub init
{
	my ($self, $page) = @_;
	my $patientTypes = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selPatientTypes');
	for (@$patientTypes)
	{
		my $id = $_->{id};
		$PATIENT_TYPES[$id] = $_->{caption};
	}

	#my $visitTypes = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selVisitTypes');
	#for (@$visitTypes)
	#{
	#	my $id = $_->{id};
	#	$VISIT_TYPES[$id] = $_->{caption};
	#}

	@DAYS_OF_WEEK = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
	@MONTHS = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
}

sub getHtml
{
	my ($self, $page, $startHour, $endHour, $flags) = @_;

	$self->init($page) unless @PATIENT_TYPES;

	my @apptSheet = ();
	my $html = $self->addStyle($page);

	$self->findSlots($page);

	return $html unless (@{$self->{inputSpec}});

	my $tableWidth = $columnWidth * (@{$self->{inputSpec}});
	# Now draw the Appt Sheet
	$html .= "<table border=0 cellspacing=1 cellpadding=0 bgcolor=white width=$tableWidth>";

	if ($flags & APPTSHEET_HEADER)
	{
		$self->buildHeader($page, \@apptSheet, $flags);

		my ($resource, $facility) = $self->getResource_Facility($page, 0);
		if ($page->param('view') =~ /week/i) {
			$html .= qq{
				<tr>
					<th colspan=7 align=left>
					<font size=2 face="Tahoma">
					$resource -- $facility
					</th>
				</tr>
			};
		}

		$html .= 	"<tr>";
		for my $col (0..(@{$self->{inputSpec}}-1))
		{
			$html .= $apptSheet[0][$col];
		}
		$html .= "</tr>";
	}

	if ($flags & APPTSHEET_BODY)
	{
		$self->buildRows($page, \@apptSheet, $startHour, $endHour);

		for my $row ($startHour..$endHour)
		{
			$html .= 	"<tr>";
			for my $col (0..(@{$self->{inputSpec}}-1))
			{
				$html .= $apptSheet[$row][$col];
			}
			$html .= 	"</tr>";
		}
	}

	if ($flags & APPTSHEET_TEMPLATE)
		{
			my $templateRow = $endHour +1;
			$self->buildTemplateRow($page, \@apptSheet, $templateRow);
			my $colSpan = (@{$self->{inputSpec}})*2;

			$html .= 	"<tr bgcolor=lightyellow>";
			for my $col (0..(@{$self->{inputSpec}}-1))
			{
				my $resource_id = $self->{inputSpec}[$col][1];
				my $facility_id = $self->{inputSpec}[$col][2];
				$html .= qq{
					<td colspan=2 align=center>
						<font face="Tahoma,Arial,Helvetica" size=2>
							<img src='/resources/icons/arrow_right_red.gif'>
							<a class=topnav href="javascript:location.href='/schedule/dlg-add-template/$resource_id/$facility_id';">Add Template</a>
						</font>
					</TD>
				};
			}
			$html .= 	"</tr>";

			$html .= 	"<tr>";
			for my $col (0..(@{$self->{inputSpec}}-1))
			{
				$html .= $apptSheet[$templateRow][$col];
			}
			$html .= 	"</tr>";
	}

	$html .= "</table>";

	return $html;
}

sub findMaxTemplates
{
	my ($self, $page, $available, $slotHash) = @_;
	my $colTemplates = 0;
	my $maxNumTemplates = 0;

	for my $col (0..(@{$self->{inputSpec}}-1))
	{
		my $slot = $slotHash->{$col}[0];
		$colTemplates = @{$slot->{attributes}->{templates}} if defined $slot->{attributes}->{templates};
		$maxNumTemplates = $colTemplates if $colTemplates > $maxNumTemplates;
	}
	return $maxNumTemplates;
}

sub buildTemplateRow
{
	my ($self, $page, $apptSheetRef, $row) = @_;
	my $hourbgColor = '#eeeeee';

	my $numPosTemplates = $self->findMaxTemplates($page, 1, $self->{pos_slots});
	my $numNegTemplates = $self->findMaxTemplates($page, 0, $self->{neg_slots});

	for my $col (0..(@{$self->{inputSpec}}-1))
	{
		$apptSheetRef->[$row][$col] = qq{
			<td colspan=2 valign=center width=$columnWidth>
				<table>
		};

		my $templateHtml = $self->getTemplateData($page, $numPosTemplates, 1, $self->{pos_slots}->{$col}[0]);
		$apptSheetRef->[$row][$col] .= qq{
			<tr>
				<td valign=center align=center width=$hourWidth bgcolor=$hourbgColor rowspan=1>
					<font size=2 color=gray face='arial,helvetica'>
					<b>P</b>
				</td>
				<td>
					<table border=0 cellspacing=0 cellpadding=1 width=100% align=left>
						$templateHtml
					</table>
				</td>
			</tr>
		};

		$templateHtml = $self->getTemplateData($page, $numNegTemplates, 0, $self->{neg_slots}->{$col}[0]);
		$apptSheetRef->[$row][$col] .= qq{
			<tr>
				<td valign=center align=center width=$hourWidth bgcolor=$hourbgColor rowspan=1>
					<font size=2 color=gray face='arial,helvetica'>
					<b>N</b>
				</td>
				<td>
					<table border=0 cellspacing=0 cellpadding=1 width=100% align=left>
						$templateHtml
					</table>
				</td>
			</tr>
		};

		$apptSheetRef->[$row][$col] .= qq{
				</table>
			</td>
		};
	}
}

sub getTemplateData
{
	my ($self, $page, $numRows, $available, $slot) = @_;
	my $html = "";

	my $rowsPrinted = 0;
	my $templatesRef = $slot->{attributes}->{templates};

	for my $t (@{$templatesRef})
	{
		if ($t->{available} == $available)
		{
			my $templateID = $t->{template_id};
			my $templateTime = hhmm2Time($t->{start_time}) . " - " . hhmm2Time($t->{end_time});

			my @patientTypes;
			if (defined $t->{patient_types}) {
				for (split(/,/, $t->{patient_types})) {
					push(@patientTypes, $PATIENT_TYPES[$_]);
				}
			} else {
				@patientTypes = "All";
			}

			my @apptTypes;
			if (defined $t->{appt_types}) {

				for (split(/,/, $t->{appt_types})) {
					my $apptType = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
						'selApptTypeById', $_);

					push(@apptTypes, $apptType->{caption});
				}
			} else {
				@apptTypes = "All";
			}

			my @daysOfWeek;
			if ($t->{days_of_week}) {
				for (split(/,/, $t->{days_of_week})) {
					push(@daysOfWeek, $DAYS_OF_WEEK[$_ -1]);
				}
			} else {
				@daysOfWeek = "All";
			}

			my @months;
			if ($t->{months}) {
				for (split(/,/, $t->{months})) {
					push(@months, $MONTHS[$_ -1]);
				}
			} else {
				@months = "All";
			}

			$t->{facility_id} = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE,
				'selId', $t->{facility_id});

			my $templateTitle = "Template $t->{template_id} -- $t->{caption}\n";
			$templateTitle .= "Facility ID: $t->{facility_id} \n";
			$templateTitle .= "Days of Week: @{[ join(', ', @daysOfWeek) ]} \n";
			$templateTitle .= "Days of Month:  @{[ $t->{days_of_month} || 'All' ]} \n";
			$templateTitle .= "Months:  @{[ join(', ', @months) ]} \n";
			$templateTitle .= "Patient Types:  @{[ join(', ', @patientTypes) ]} \n";
			$templateTitle .= "Appt Types:  @{[ join(' / ', @apptTypes) ]}";

			my $updateHref = qq{javascript:location.href = '/schedule/dlg-update-template/$templateID'};

			$html .= qq {
				<tr><td align=center><font size=2 face='Lucida,Arial,Helvetica'>
					<a href="$updateHref" class="person" title="$templateTitle"> <nobr>$templateTime</nobr>
				</td></tr>
			};

			$rowsPrinted++;
		}
	}

	for ($rowsPrinted..($numRows-1)) {
		$html .= qq{<tr><td>&nbsp</td></tr>};
	}

	return $html;
}

sub buildHeader
{
	my ($self, $page, $apptSheetRef, $flags) = @_;

	my $width = $columnWidth;

	for my $col (0..(@{$self->{inputSpec}}-1))
	{
		my $selDate = $self->{inputSpec}[$col][0];
		my @date = Decode_Date_US($selDate);
		my $dateString = Day_of_Week_Abbreviation(Day_of_Week(@date)) . sprintf(" %02d/%02d/%04d", $date[1],$date[2],$date[0]) ;
		my $resource_id = $self->{inputSpec}[$col][1];
		my $facility_id = $self->{inputSpec}[$col][2];
		my $org_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $facility_id);

		my ($resource, $facility) = $self->getResource_Facility($page, $col);

		my $altView = ($page->param('view') =~ /week/i) ? 'Day' : 'Week';

		my $dashDate = $selDate; $dashDate =~ s/\//\-/g;

		my $arl = "/schedule/apptsheet/view/$altView,$dashDate,$resource_id,$facility_id";
		$dashDate = $selDate; $dashDate =~ s/\//\-/g;
		my $numBooks = @{$self->{event_slots}->{$col}};

		$apptSheetRef->[0][$col] = qq{
			<td colspan=2 bgcolor='#dddddd' valign='center'>
				<table width='100%' cellspacing=0 cellpadding=0 border=0 noshade>
					<tr>
						<td align='center'>
							<font size=2 face='Arial,Helvetica' color=black>
								<nobr>$dateString</nobr>
							</font>
						</td>
					</tr>
					<tr>
		};

		if ($page->param('view') !~ /week/i) {
			$apptSheetRef->[0][$col] .= qq{
						<td align='center'>
							<font size=2 face='Arial Narrow,Arial,Helvetica' color=black>
								<nobr><b>$resource</b></nobr>
							</font>
						</td>
					</tr>
					<tr>
						<td align='center'>
							<font size=2 face='Arial,Helvetica' color=black>
								<nobr>$facility</nobr>
							</font>
						</td>
					</tr>
			}
		}

		my $customizeOption = ($page->param('view') =~ /week/i) ? '' :
			"<option value='/schedule/apptsheet/customize/update/$col,$resource_id,$dashDate,$facility_id'>Customize</option>";

		if ($flags & APPTSHEET_CUSTOMIZE) {
			$apptSheetRef->[0][$col] .= qq{
					<tr bgcolor=lightyellow>
						<td align='center'>
							<select onChange='location.href=this.value'>
								<option value='#'>Choose Action</option>
								<option value='$arl'>$altView View</option>
								<option value='/schedule/dlg-add-appointment//$resource_id/$facility_id/'>Add Appointment</option>
								<option value='/search/apptslot/$resource_id,$facility_id,$dashDate/1'>Find Slot</option>
								<option value='/schedule/dlg-add-template/$resource_id/$facility_id'>Add Template</option>
								<option value='/search/template//$resource_id/$org_id'>View Templates</option>
								<option value='/lookup/appointment/$resource_id/$org_id/0/$dashDate/$dashDate'>Print Schedule</option>
								$customizeOption
							</select>
						</td>
					</tr>
			};
		}

		if ($flags & APPTSHEET_BOOKCOUNT) {
			$apptSheetRef->[0][$col] .= qq{
					<tr bgcolor=navy>
						<td align='center'><font face='arial,helvetica' size=1 color=yellow>
							<b><nobr>$numBooks &nbsp;&nbsp;&nbsp; B O O K E D</nobr></b>
						</td>
					</tr>
			};
		}

		$apptSheetRef->[0][$col] .= qq{
				</table>
			</td>
		};
	}
}

sub buildRows
{
	my ($self, $page, $apptSheetRef, $startHour, $endHour) = @_;
	my ($bgColor, $bgColor1, $bgColor2, $hourColor) = ('white', 'white', '#eeeeee');

	for my $hour ($startHour..$endHour)
	{
		my $partialHour = (($hour*60)+1) . "-" . ((($hour+1)*60)-1);
		my $fullHour = ($hour*60) . "-" . (($hour+1)*60);

		my $maxAppts = $self->findMaxNumAppts($page, $hour);

		for my $col (0..(@{$self->{inputSpec}}-1))
		{
			my $hourbgColor = '#eeeeee';

			my @posSlots = @{$self->{pos_slots}->{$col}};
			my $posMinuteSet = $self->{posMinuteSet}->{$col};
			unless ($posMinuteSet->empty) {
				if ( $posMinuteSet->superset($fullHour) ) {
					$hourbgColor = $posTemplateColor;
				}	elsif (! $posMinuteSet->intersect($partialHour)->empty) {
					$hourbgColor = $halfPosTemplateColor;
				}
			}

			my @negSlots = @{$self->{neg_slots}->{$col}};
			my $negMinuteSet = $self->{negMinuteSet}->{$col};
			unless ($negMinuteSet->empty) {
				if ( $negMinuteSet->superset($fullHour) ) {
					$hourbgColor = $negTemplateColor;
				}	elsif (! $negMinuteSet->intersect($partialHour)->empty) {
					$hourbgColor = $halfNegTemplateColor;
				}
			}

			my $displayHour = ($hour % 12 == 0) ? 12 : $hour % 12;
			my $appointments = $self->getAppointments($page, $col, $hour, $maxAppts);

			my $resource_id = $self->{inputSpec}[$col][1];
			my $facility_id = $self->{inputSpec}[$col][2];
			my @date = Decode_Date_US($self->{inputSpec}[$col][0]);

			my $am = $hour >= 12 ? 'PM' : 'AM';
			my $hourAm = $hour == 12 ? $hour : $hour == 0 ? 12 : $hour % 12;

			my $start_stamp = sprintf ("%02d-%02d-%04d_%02d:00_%s", $date[1], $date[2], $date[0], $hourAm, $am);
			my $apptHref = "javascript:doActionPopup('/schedule/dlg-add-appointment//$resource_id/$facility_id/$start_stamp',null,'width=620,height=550,scrollbars,resizable');";

			$apptSheetRef->[$hour][$col] = qq{
				<td valign=center align=center rowspan=1 bgcolor=$hourbgColor width=$hourWidth >
					<font size=4 color=gray face='arial,helvetica'>
					<a class="hour" href="$apptHref" title="Click here to make an appointment in this time block">
						<b>$displayHour</b></a>
				</td>
				<td>
					<table border=0 cellspacing=0 cellpadding=1 bgColor=$bgColor height=100% width=100% align=left>
						$appointments
					</table>
				</td>
			}
		} # end for col

		$bgColor = $bgColor eq $bgColor2 ? $bgColor1 : $bgColor2;
	} # end for hour
}

sub findMaxNumAppts
{
	my ($self, $page, $hour) = @_;

	my $maxNumAppts = 0;
	my $numHourAppts = 0;

	my $start = $hour*60;
	my $end   = ($hour+1)*60 -1;
	my $range = new Set::IntSpan ($start . "-" . $end);

	for my $col (0..(@{$self->{inputSpec}}-1))
	{
		$numHourAppts = 0;

		my @slots = @{$self->{event_slots}->{$col}};
		for my $i (0..(@slots-1))
		{
			$numHourAppts++ if ($range->member($slots[$i]->{minute_set}->min));
		}
		$maxNumAppts = $numHourAppts if $numHourAppts > $maxNumAppts;
	}

	return $maxNumAppts;
}

sub getAppointments
{
	my ($self, $page, $col, $hour, $numRows) = @_;

	return qq{<tr><td>&nbsp</td><td>&nbsp</td></tr>} unless $numRows;

	my $date = $self->{inputSpec}[$col][0];
	my $resource_id  = $self->{inputSpec}[$col][1];
	my $facility_id  = $self->{inputSpec}[$col][2];

	$date =~ s/\//\-/g;

	my $html = "";
	my @slots = @{$self->{event_slots}->{$col}};
	my $rowsPrinted = 0;

	my $start = $hour*60;
	my $end   = ($hour+1)*60 -1;
	my $range = new Set::IntSpan ($start . "-" . $end);

	my $previousMinute;
	for my $i (0..(@slots-1))
	{
		if ($range->member($slots[$i]->{minute_set}->min))
		{
			my $time = minute_set_2_string($slots[$i]->{minute_set}->run_list, TIME_ONLY);
			my $startMinute = $time;
			$startMinute =~ s/-.*//;
			$startMinute =~ s/.*:/:/;

			if ($startMinute ne $previousMinute) {
				$previousMinute = $startMinute;
			} else {
				$startMinute = '&nbsp';
			}

			my $short_patient_name = ucfirst(lc($slots[$i]->{attributes}->{short_patient_name}));
			my $firstInit = $short_patient_name	=~ /(.)$/;
			my $u = uc($1);
			$short_patient_name =~ s/.$/$u/;

			my $patient_complete_name = $slots[$i]->{attributes}->{patient_complete_name};
			my $patient_id = $slots[$i]->{attributes}->{patient_id};
			my $event_id = $slots[$i]->{attributes}->{event_id};
			my $parent_id = $slots[$i]->{attributes}->{parent_id};

			my $title = "($patient_id) $patient_complete_name -- $time\n";
			$title .= "Facility ID:  $slots[$i]->{attributes}->{facility_id}\n";
			$title .= "$slots[$i]->{attributes}->{conflict}\n";
			$title .= "Patient Type:  $slots[$i]->{attributes}->{patient_type}\n";
			$title .= "Appointment Type:  $slots[$i]->{attributes}->{appt_type}";
			$title .= $slots[$i]->{attributes}->{appt_type_id} ?
				" ($slots[$i]->{attributes}->{appt_type_id})\n" : "None\n";
			$title .= "Reason for Visit:  $slots[$i]->{attributes}->{subject}\n";
			$title .= "Symptoms:  $slots[$i]->{attributes}->{remarks}\n";
			$title .= "$slots[$i]->{attributes}->{status}: ";
			$title .= " $slots[$i]->{attributes}->{checkinout_stamp}";

			$title .= "\nEvent ID:  $event_id";

			my $color = $slots[$i]->{attributes}->{conflict} ? "color=red" : "";

			my $javascript = "#";

			unless ($page->param('dialog')) {
				$javascript = "javascript:performAction('$patient_id','$event_id')";
			}

			my $wlHref;
			if ($slots[$i]->{attributes}->{conflict}) {
				my $org_id = $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selId', $facility_id);
				my $wl = $slots[$i]->{attributes}->{conflict} =~ /wait/i ? " [WL]" : " [OB]";
				$wlHref = qq{<a href="javascript:doActionPopup('/lookup/appointment/$resource_id/$org_id/5/$date/$date//$parent_id')"
					class='person'>$wl</a>};
			}

			$html .= qq{
				<tr>
					<td width=15%><font face='Lucida,arial,helvetica' size=2 $color>
						$startMinute</font>
					</td>
					<td align=left><font face='Lucida,arial,helvetica' size=2>
						<a href="$javascript" class='person' title='$title'>
							<nobr><b>$short_patient_name</b> $wlHref</nobr>
						</a></font>
					</td>
				</tr>
			};

			$rowsPrinted++;
		}
	}

	for ($rowsPrinted..($numRows-1)) {
		$html .= qq{<tr><td>&nbsp</td><td>&nbsp</td></tr>};
	}

	return $html;
}

sub findSlots
{
	my ($self, $page) = @_;

	for my $col (0..(@{$self->{inputSpec}}-1))
	{
		my $resource_id  = $self->{inputSpec}[$col][1];
		my @resource_ids = ($resource_id);

		my $facility_id = $self->{inputSpec}[$col][2];
		my @facility_ids = ($facility_id);

		my @date = Decode_Date_US($self->{inputSpec}[$col][0]);
		eval {check_date(@date);};
		@date = Today() if $@;

		my $sa = new App::Schedule::Analyze (
			resource_ids      => \@resource_ids,
			facility_ids      => \@facility_ids,
			search_start_date => \@date,
			search_duration   => 1,
			patient_type      => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES,
			appt_type         => App::Schedule::Analyze::ANALYZE_ALLTEMPLATES
		);

		my $posDaysset = new Set::IntSpan;
		my $negDaysset = new Set::IntSpan;

		my @templates = $sa->getTemplates($page, $resource_id, $facility_id);
		$sa->findTemplateSlots($page, \@{$self->{pos_slots}->{$col}},
			\@{$self->{neg_slots}->{$col}}, \$posDaysset, \$negDaysset, @templates);

		$sa->findEventSlots($page, \@{$self->{event_slots}->{$col}}, $resource_id, $facility_id);

		$self->{posMinuteSet}->{$col} = new Set::IntSpan;
		for (@{$self->{pos_slots}->{$col}}) {
			$self->{posMinuteSet}->{$col} = $self->{posMinuteSet}->{$col}->union($_->{minute_set});
		}

		$self->{negMinuteSet}->{$col} = new Set::IntSpan;
		for (@{$self->{neg_slots}->{$col}}) {
			$self->{negMinuteSet}->{$col} = $self->{negMinuteSet}->{$col}->union($_->{minute_set});
		}
	}
}

sub addStyle
{
	my ($self, $page) = @_;
	return (qq{
		<style>
			a { text-decoration: none; }
			a.person { color: navy; }
			a.hour { color: darkgray; }
			a.customize { color: blue; }
			a:hover { color: red; }
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input  { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</style>
	});
}

sub getLegendHtml
{
	my ($self, $page) = @_;
	my $size = 1;
	my $font = qq{<font size=$size face="Arial Narrow">};

	my $html = qq{ <P>
		<table bgcolor='#dddddd' cellspacing=3 cellpadding=2>
			<tr>
				<th colspan=2>
					<font size=2 face="Arial">
					Legend
				</th>
			</tr>
			<tr>
				<td valign=center align=center bgcolor='#eeeeee' width='5%'>
					$font
					<a class="hour" href="#" title="Hour">	<b>Hour</b></a>
				</td>
				<td>
					$font
					<nobr>No Template Information</nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor=$posTemplateColor width='5%'>
					$font
					<a class="hour" href="#" title="Hour">	<b>Hour</b></a>
				</td>
				<td>
					$font
					<nobr>Positive Template Hours<nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor=$halfPosTemplateColor width='5%'>
					$font
					<a class="hour" href="#" title="Hour">	<b>Hour</b></a>
				</td>
				<td>
					$font
					<nobr>Partially Pos. Template Hours<nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor=$negTemplateColor width='5%'>
					$font
					<a class="hour" href="#" title="Hour">	<b>Hour</b></a>
				</td>
				<td>
					$font
					<nobr>Negative Template Hours<nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor=$halfNegTemplateColor width='5%'>
					$font
					<a class="hour" href="#" title="Hour">	<b>Hour</b></a>
				</td>
				<td>
					$font
					<nobr>Partially Neg. Template Hours<nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor='#eeeeee' width='5%'>
					$font
					<a class="hour" href="#" title="Positive Templates">	<b>P</b></a>
				</td>
				<td>
					$font
					<nobr>Matched Positive Templates<nobr>
				</td>
			</tr>
			<tr>
				<td valign=center align=center bgcolor='#eeeeee' width='5%'>
					$font
					<a class="hour" href="#" title="Negative Templates">	<b>N</b></a>
				</td>
				<td>
					$font
					<nobr>Matched Negative Templates<nobr>
				</td>
			</tr>
		</table>
	};

	return $html;
}

sub getResource_Facility
{
	my ($self, $page, $col) = @_;

	my $resource_id = $self->{inputSpec}[$col][1];
	my $facility_id = $self->{inputSpec}[$col][2];
	$facility_id =~ s/\s//g;

	my $resource = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE, 'selCompleteName', $resource_id);
	$resource = $resource_id unless $resource;
	my $facility = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE,
		'selFacilityName', $facility_id);

	$facility = ($facility_id ? "**Invalid**" : "All Facilities") unless $facility;

	return ($resource, $facility);
}

1;
