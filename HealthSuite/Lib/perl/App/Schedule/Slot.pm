##############################################################################
package App::Schedule::Slot;
##############################################################################

use strict;
use Date::Calc qw(:all);
use App::Schedule::Utilities;

sub new
{
	my $type = shift;
	my %params = @_;

	$params{day} = $params{day} || undef;
	$params{minute_set} = $params{minute_set} || undef;

	$params{attributes} = $params{attributes} || {};

	return bless \%params, $type;
}

sub defaultRowRptFormat
{
	my ($self) = @_;

	my @date = App::Schedule::Utilities::Days_to_Date($self->{day});
	my $day = sprintf("%02d/%02d/%04d", $date[1], $date[2], $date[0]);
	my $time = App::Schedule::Utilities::minutes2Time($self->{minute_set}->min);

	return (
		$self->{attributes}->{patient_complete_name},
		"$day $time",
		$self->{attributes}->{resource_id},
		$self->{attributes}->{patient_type},
		$self->{attributes}->{subject},
		$self->{attributes}->{event_type},
		$self->{attributes}->{appt_status},
		$self->{attributes}->{facility_id},
		$self->{attributes}->{remarks},
		$self->{attributes}->{event_id},
		$self->{attributes}->{scheduled_by_id},
		$self->{attributes}->{scheduled_stamp},
		$self->{attributes}->{patient_id},
		'TBD',
	);
}

1;
