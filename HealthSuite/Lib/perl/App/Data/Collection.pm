##############################################################################
package App::Data::Collection;
##############################################################################

use strict;
use Carp;
use DBI;

sub new
{
	my ($class, %params) = @_;

	# if data is an ARRAY ref, it is a list of arrays (that have the data)
	# if data is a HASH ref, it is a hash whose keys are names of tables
	#    and the values are a list of data rows for that table
	#
	$params{data} = [];
	$params{errors} = [];
	$params{statistics} = [];

	my $self = bless \%params, $class;
	$self;
}

sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub abstract
{
	my ($pkg, $file, $line, $method) = caller(1);
	confess("$method is an abstract method");
}

sub abstractMsg
{
	my ($pkg, $file, $line, $method) = caller(1);
	return "$method is a virtual method; please override with specific behavior";
}

sub addError
{
	my ($self, $message) = @_;
	my ($pkg, $file, $line, $method) = caller(0);
	push(@{$self->{errors}}, "$message at $file line $line.");
}

sub haveErrors
{
	return scalar(@{$_[0]->{errors}});
}

sub printErrors
{
	print STDERR join("\n", @{$_[0]->{errors}});
}

sub printDataSamples
{
	my ($self, $count) = @_;
	$count ||= 25;

	my $rowIdx = 0;
	foreach (@{$self->{data}})
	{
		print STDOUT join(",", @$_) . "\n";

		$rowIdx++;
		last if $rowIdx > $count;
	}
}

sub getStatistics
{
	return $_[0]->{statistics};
}

sub addStatistic
{
	my ($self, $name, $value) = @_;
	push(@{$self->{statistics}}, [$name, $value]);
}

sub clearData
{
	$_[0]->{data} = [];
	return $_[0]->{data};
}

sub getDataRows
{
	return $_[0]->{data};
}

1;
