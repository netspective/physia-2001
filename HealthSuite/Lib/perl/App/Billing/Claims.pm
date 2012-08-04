##############################################################################
package App::Billing::Claims;
##############################################################################


use strict;
BEGIN(use App::Billing::Claim);

sub new
{
	my ($type, %params) = @_;

	$params{claims} = [];
	$params{count} = 0;
	return bless \%params, $type; #binding the param hash with class reference
}

sub getCount
{
	my ($self) = @_;
	return $self->{count};
}


#
# add one or more claims to the list
#

sub addClaim
{
	my $self = shift;

	my $claimListRef = $self->{claims};
	foreach (@_)
	{
		die 'only App::Billing::Claim objects are allowed here'
			unless $_->isa('App::Billing::Claim');

			push(@{$claimListRef}, $_);
		}
}

#
# get either one or more claims or the entire list (if no $claimIdx is given)
#

sub getClaim
{
	my $self = shift;

		my $claimListRef = $self->{claims};
		my $claims = $self->{claims};
		if ($_[0] ne undef)
		{ 
			$claims= [];
			foreach (@_)
			{
				push(@$claims, $claimListRef->[$_[0]]);
			}
		}	
		return $claims;
	
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
		my $claimListRef = $self->{claims};
		foreach my $claim (@$claimListRef)
		{
			$stats->{count}++;
		}
	}
	else
	{
		foreach my $claimIdx (@_)
		{
			$stats->{count}++;
		}
	}
	return $stats;
}

1;
