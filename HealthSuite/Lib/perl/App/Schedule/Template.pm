##############################################################################
package App::Schedule::Template;
##############################################################################

use strict;
use Date::Calc qw(:all);
use Date::Manip;
use Set::IntSpan;

sub new
{
	my $type = shift;
	my %params = @_;

	$params{effective_begin_date} = $params{effective_begin_date} || [];
	$params{effective_end_date} = $params{effective_end_date} || [];

	return bless \%params, $type;
}

sub findTemplateDays {
	my ($self, $search_duration, @search_begin_date) = @_;

	my $months = $self->{months};
	my $days_of_week = $self->{days_of_week};
	my $days_of_month = $self->{days_of_month};
	
	@{$self->{effective_end_date}} = Add_Delta_Days(@{$self->{effective_end_date}}, 1);

	my $setofDays = new Set::IntSpan;

	my @effective_search_begin_date = laterDate(@search_begin_date, @{$self->{effective_begin_date}});
	my @search_end_date = Add_Delta_Days(@search_begin_date, $search_duration);

	@search_end_date = earlierDate(@search_end_date, @{$self->{effective_end_date}});
	$search_duration = Delta_Days(@effective_search_begin_date, @search_end_date);

	my $sortedMonths = join(',', sort {$a <=> $b} split(/\s*,\s*/, $months));
	my $month_spec_set = new Set::IntSpan("$sortedMonths");

	my $sortedDays = join(',', sort {$a <=> $b} split(/\s*,\s*/, $days_of_week));
	my $dow_spec_set   = new Set::IntSpan("$sortedDays");

	#my $dom_spec_set   = new Set::IntSpan("$days_of_month");
	my $dom_spec_set = new Set::IntSpan ();
	for my $item (sort {$a <=> $b} split(/\s*,\s*/, App::Dialog::Template::cleanup($days_of_month) ))
	{
		$dom_spec_set = $dom_spec_set->union($item);
	}

	for (my $d=0; $d<$search_duration; $d++){
		my @date = Add_Delta_Days(@effective_search_begin_date, $d);

		my $day  = $date[2];
		my $mon  = $date[1];
		my $year = $date[0];
		my $dayOfWeek = Date_DayOfWeek($mon,$day,$year)%7 +1;

		my $boolM = $month_spec_set->empty || $month_spec_set->member($mon);
		my $boolW = $dow_spec_set->empty || $dow_spec_set->member($dayOfWeek);
		my $boolD = $dom_spec_set->empty || $dom_spec_set->member($day);

		if ($boolM && $boolW && $boolD) {
			$setofDays->insert(Date_to_Days(@date));
		}
	}
	return $setofDays;
}

sub laterDate
{
	my ($y1,$m1,$d1, $y2,$m2,$d2) = @_;

	if (Date_to_Days($y1,$m1,$d1) > Date_to_Days($y2,$m2,$d2)) {
		return ($y1,$m1,$d1);
	} else {
		return ($y2,$m2,$d2);
	}
}

sub earlierDate
{
	my ($y1,$m1,$d1, $y2,$m2,$d2) = @_;

	if (Date_to_Days($y1,$m1,$d1) < Date_to_Days($y2,$m2,$d2)) {
			return ($y1,$m1,$d1);
		} else {
			return ($y2,$m2,$d2);
	}
}

1;
