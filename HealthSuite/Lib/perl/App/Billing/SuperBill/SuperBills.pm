##############################################################################
package App::Billing::SuperBill::SuperBills;
##############################################################################


use strict;
BEGIN(use App::Billing::SuperBill::SuperBill);

sub new
{
	my ($type, %params) = @_;

	$params{superBills} = [];
	$params{count} = 0;
	return bless \%params, $type; #binding the param hash with class reference
}

sub getCount
{
	my ($self) = @_;
	return $self->{count};
}


#
# add one or more superbills to the list
#

sub addSuperBill
{
	my $self = shift;

	my $superBillsRef = $self->{superBills};
	foreach (@_)
	{
		die 'only App::Billing::SuperBill::SuperBill objects are allowed here'
			unless $_->isa('App::Billing::SuperBill::SuperBill');

			push(@{$superBillsRef}, $_);
		}
}

#
# get either one or more superbills or the entire list (if no $superBillIdx is given)
#

sub getSuperBill
{
	my $self = shift;

		my $superBillsRef = $self->{superBills};
		my $superBills = $self->{superBills};
		if ($_[0] ne undef)
		{
			$superBills = [];
			foreach (@_)
			{
				push(@$superBills, $superBillsRef->[$_[0]]);
			}
		}
		return $superBills;

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
		my $superBillsRef = $self->{superBills};
		foreach my $superBill (@$superBillsRef)
		{
			$stats->{count}++;
		}
	}
	else
	{
		foreach my $superBillIdx (@_)
		{
			$stats->{count}++;
		}
	}
	return $stats;
}

1;
