##############################################################################
package App::Data::Manipulate;
##############################################################################

use strict;
use Carp;

use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(DATAMANIPFLAG_VERBOSE DATAMANIPFLAG_SHOWPROGRESS);

use enum qw(BITMASK:DATAMANIPFLAG_ VERBOSE SHOWPROGRESS);

sub new
{
	my ($class, %params) = @_;

	$params{errors} = [];

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

sub setupFlags
{
	my $flags = $_[1];
	$flags |= DATAMANIPFLAG_SHOWPROGRESS if $flags & DATAMANIPFLAG_VERBOSE;
	return $flags;
}

sub reportMsg
{
	print STDOUT "\r$_[1]\n";
}

sub updateMsg
{
	print STDOUT "\r$_[1]";
}

#
# THE FOLLOWING ARE SIMPLE FUNCTIONS, NOT METHODS
#
sub trim
{
	my $str = shift;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}

1;