##############################################################################
package App::Billing::Claim::Entity;
##############################################################################

use strict;

sub new
{
	my ($type, %params) = @_;
	return bless \%params, $type;
}

sub convertDateToCCYYMMDD
{
	my ($self, $date) = @_;
	my $monthSequence =
	{
		JAN => '01', FEB => '02', MAR => '03', APR => '04',
		MAY => '05', JUN => '06', JUL => '07', AUG => '08',
		SEP => '09', OCT => '10', NOV => '11',	DEC => '12'
	};
	$date =~ s/-//g;
	if(length($date) == 7)
	{
		return '19'. substr($date,5,2) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
	elsif(length($date) == 9)
	{
		return substr($date,5,4) . $monthSequence->{uc(substr($date,2,3))} . substr($date,0,2);
	}
}

1;
