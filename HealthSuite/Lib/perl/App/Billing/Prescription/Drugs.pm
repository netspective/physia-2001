##############################################################################
package App::Billing::Prescription::Drugs;
##############################################################################


use strict;
BEGIN(use App::Billing::Prescription::Drug);

sub new
{
	my ($type, %params) = @_;

	$params{drugs} = [];
	$params{count} = 0;
	return bless \%params, $type; #binding the param hash with class reference
}

sub getCount
{
	my ($self) = @_;
	return $self->{count};
}


#
# add one or more drugs to the list
#

sub addDrug
{
	my $self = shift;

	my $drugsRef = $self->{drugs};
	foreach (@_)
	{
		die 'only App::Billing::Prescription::Drug objects are allowed here'
			unless $_->isa('App::Billing::Prescription::Drug');

			push(@{$drugsRef}, $_);
		}
}

#
# get either one or more drugs or the entire list (if no $drugIdx is given)
#

sub getDrug
{
	my $self = shift;

		my $drugsRef = $self->{drugs};
		my $drugs = $self->{drugs};
		if ($_[0] ne undef)
		{
			$drugs = [];
			foreach (@_)
			{
				push(@$drugs, $drugsRef->[$_[0]]);
			}
		}
		return $drugs;

}

sub getStatistics
{
	my $self = shift;
	my $stats =
	{
		count => 0,
	};

	if(scalar(@_) == 0)
	{
		my $drugsRef = $self->{drugs};
		foreach my $drug (@$drugsRef)
		{
			$stats->{count}++;
		}
	}
	else
	{
		foreach my $drugIdx (@_)
		{
			$stats->{count}++;
		}
	}
	return $stats;
}

1;
