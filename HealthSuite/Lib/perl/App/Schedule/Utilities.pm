##############################################################################
package App::Schedule::Utilities;
##############################################################################

use strict;

use Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);

use enum qw(BITMASK:TIME_ H24 H12 ONLY);
@EXPORT = qw (
	Trim
	Days_to_Date
	PrintSlots
	minute_set_2_string
	hhmm2Time
	TIME_H24
	TIME_H12
	TIME_ONLY
	minuteSet_dayTime
	hhmm2minutes
	hhmmAM2minutes
	minutes2Time
	time2hhmm
	stamp2minutes
	cleanup
	validateDate
	convertStamp
	convertTime
	convertStamp2Stamp
);

use constant BASE_TZ => 'GMT';

use Date::Calc qw(:all);
use Date::Manip;
use App::Schedule::Slot;

use DBI::StatementManager;
use App::Statements::Scheduling;

sub convertStamp
{
	my ($hhmm, $yyyy, $mm, $dd, $fromTZ, $toTZ) = @_;
	
	my $stamp = ParseDate(sprintf("%04d%02d%02d%02d:%02d", $yyyy, $mm, $dd, 
		substr($hhmm, 0, 2), substr($hhmm, 2, 2) ));
	my $convStamp = Date_ConvTZ($stamp, $fromTZ, $toTZ);
	return (UnixDate($convStamp, '%H%M'), split(/,/, UnixDate($convStamp, '%Y,%m,%d')));
}

sub convertStamp2Stamp
{
	my ($stamp, $fromTZ, $toTZ) = @_;
	
	$stamp =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)\s(.*)/;
	my ($mm, $dd, $yyyy, $time) = ($1, $2, $3, $4);
	
	my $hhmm = time2hhmm(split(/\s/, $time));
	my $fromStamp = ParseDate(sprintf("%04d%02d%02d%02d:%02d", $yyyy, $mm, $dd, 
		substr($hhmm, 0, 2), substr($hhmm, 2, 2) ));
	my $convStamp = Date_ConvTZ($fromStamp, $fromTZ, $toTZ);
	return (UnixDate($convStamp, '%m/%d/%Y %I:%M %p') );
}

sub convertTime
{
	my ($time, $fromTZ, $toTZ, $flag) = @_;
	
	return undef unless $time;

	my $hhmm = ($flag & TIME_H24) ? $time : time2hhmm(split(/\s/, $time));
	my $stamp = ParseDate(sprintf("%04d%02d%02d%02d:%02d", 2000, 01, 01, 
		substr($hhmm, 0, 2), substr($hhmm, 2, 2) ));
	my $convStamp = Date_ConvTZ($stamp, $fromTZ, $toTZ);
	return (UnixDate($convStamp, '%I:%M %p'));
}

sub validateDate
{
	my ($date) = @_;

	return ($date !~ /(\d\d)\/(\d\d)\/(\d\d\d\d)/) ? undef : $3 <= 1000 ? undef :
		ParseDate($date) ? $date : undef;
}

sub cleanup
{
	my ($string) = @_;

	my $cleanString = $string;

	$cleanString =~ s/\s*//g;
	$cleanString =~ s/,,+/,/g;
	$cleanString =~ s/\-\-+/\-/g;

	while ($cleanString =~ /^,+/ || $cleanString =~ /^\-+/
		|| $cleanString =~ /,+$/  || $cleanString =~ /\-+$/)
	{
		$cleanString =~ s/^\-+//g;
		$cleanString =~ s/\-+$//g;

		$cleanString =~ s/^,+//g;
		$cleanString =~ s/,+$//g;
	}

	return $cleanString;
}

sub stamp2minutes
{
	my ($stamp) = @_;
	my ($day, $time);
	
	if ($stamp =~ /\d\d\/\d\d\/\d\d\d\d/)
	{
		($day, $time) = split(/\s/, $stamp);
	}
	else
	{
		$day = UnixDate('today', '%m/%d/%Y');
		$time = $stamp;
		$time =~ s/.*(\d\d:\d\d..).*/$1/;
	}
	
	my $dayMinutes = (Date_to_Days(Decode_Date_US($day))) * 24 * 60;
	my $minutes    = hhmmAM2minutes($time);
	
	return $dayMinutes + $minutes;
}

sub time2hhmm
{
	my ($time, $am) = @_;

	my $hour = substr($time, 0, 2);
	my $minu = substr($time, 3, 2);
	$hour += 12 if ($am =~ /p/i && $hour < 12);
	$hour = 0 if ($am =~ /a/i && $hour == 12);

	return $hour . $minu;
}

sub minuteSet_dayTime
{
	my ($run_list, $flag) = @_;

	return if $run_list eq '-';

	$flag = TIME_H12 unless $flag;
	my @items = split(/,/, $run_list);
	my $outputString = "";

	for (@items) {
		if (/-/) {
			my ($low, $high) = split(/-/, $_);
			my $day = int($low/24/60);
			$low -= $day*24*60;
			$high -= $day*24*60;

			$outputString .= ", $day: " . minutes2Time($low, $flag) . " - " . minutes2Time($high, $flag);
		} else {
			my $item = $_;
			my $day = int($item/24/60);
			$item -= $day;
			$outputString .= ", " . minutes2Time($item, $flag);
		}
	}

	$outputString =~ s/^\,//;
	return $outputString;
}

sub hhmm2minutes
{
	my ($hhmm) = @_;
	my $hour = substr($hhmm, 0, 2);
	my $minu = substr($hhmm, 2, 2);
	my $minutes = ($hour*60) + $minu;
	return $minutes;
}

sub hhmmAM2minutes
{
	my ($hhmm) = @_;

	my $hour = substr($hhmm, 0, 2);
	my $minu = substr($hhmm, 3, 2);
	my $am   = substr(Trim(substr($hhmm, 5, 3)), 0, 1);

	$hour += 12 if ($am =~ /p/i && $hour < 12);
	$hour = 0 if ($am =~ /a/i && $hour == 12);

	my $minutes = ($hour*60) + $minu;
	return $minutes;
}

sub Trim
{
	my ($trim) = @_;

	$trim =~ s/^\s*//g;
	$trim =~ s/\s*$//g;
	return $trim;
}

sub Days_to_Date {
	my ($canonical) = @_;
	return Add_Delta_Days(1,1,1, $canonical-1);
}

sub PrintSlots {
	my ($title, @slots) = @_;
	print "<br><b>These are $title slots</b><br>";
	for my $i (0..(@slots-1)) {
		print $i, " -- ", $slots[$i]->{day}, " -- ", Date_to_Text(Days_to_Date($slots[$i]->{day})),
			" -- ", minute_set_2_string($slots[$i]->{minute_set}->run_list),
			" -- ", $slots[$i]->{attributes}->{facility_id},
			" -- ", $slots[$i]->{attributes}->{resource_id}, "<br>";
	}
	print "<b>Done with $title slots</b><br>";
}

sub minute_set_2_string
{
	my ($run_list, $flag) = @_;

	$flag = TIME_H12 unless $flag;

	my @items = split(/,/, $run_list);
	my $outputString = "";

	for (@items) {
		if (/-/) {
			my ($low, $high) = split(/-/, $_);
			$outputString .= ", " . minutes2Time($low, $flag) . " - " . minutes2Time($high, $flag);
		} else {
			my $item = $_;
			$outputString .= ", " . minutes2Time($item, $flag);
		}
	}

	$outputString =~ s/^\,//;
	return $outputString;
}

sub minutes2Time
{
	my ($m, $flag) = @_;

	$flag = TIME_H12 unless $flag;
	my $hour = int($m/60);
	my $minu = $m % 60;

	return getTimeString($hour, $minu, $flag);
}

sub getTimeString
{
	my ($hour, $minu, $flag) = @_;
	my $apm = $hour<12 ? ' AM' : ' PM';

	my $timeString;

	SWITCH: {
		if ($flag & TIME_H24) {
			$timeString = sprintf ("%02d:%02d", $hour, $minu);
			last SWITCH;
		}
		if ($flag & TIME_H12) {
			$hour = (($hour % 12) == 0) ? 12 : $hour % 12;
			$timeString = sprintf ("%02d:%02d%s", $hour, $minu, $apm);
			last SWITCH;
		}
		if ($flag & TIME_ONLY) {
			$hour = (($hour % 12) == 0) ? 12 : $hour % 12;
			$timeString = sprintf ("%02d:%02d", $hour, $minu);
			last SWITCH;
		}
	}

	return $timeString;
}

sub hhmm2Time
{
	my ($hhmm, $flag) = @_;

	$flag = TIME_H12 unless $flag;
	my $hour = substr($hhmm,0,2);
	my $minu = substr($hhmm,2,2);

	return getTimeString($hour, $minu, $flag);
}

1;
