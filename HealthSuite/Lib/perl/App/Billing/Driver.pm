##############################################################################
package App::Billing::Driver;
##############################################################################

#
# this is the base class, made up mostly of abstract methods that describes
# how any billing data driver (input or output) should operate
#
# any methods needed by all drivers should be placed in here
#

use strict;
use Carp;

sub new
{
	my ($type, %params) = @_;

	$params{errors} = [];
	$params{warnings} = [];

	return bless \%params, $type;
}

sub UNIVERSAL::abstract
{
	my ($pkg, $file, $line, $method) = caller(1);
	confess("$method is an abstract method");
}

sub UNIVERSAL::abstractMsg
{
	my ($pkg, $file, $line, $method) = caller(1);
	return "$method is a virtual method; please override with specific behavior";
}

# read/write a generic property for this class
#
sub property
{
	my ($self, $name, $value) = @_;
	$self->{$name} = $value if defined $value;
	return $self->{$name};
}

sub getId
{
	$_[0]->abstract();
	# THIS METHOD IS NOW REQUIRED TO BE OVERIDDEN IN ANY DERIVED CLASS
	#return 'base';
}

sub getName
{
	$_[0]->abstract();
	# THIS METHOD IS NOW REQUIRED TO BE OVERIDDEN IN ANY DERIVED CLASS
	#return 'Base Input Class';
}

sub addError
{
	my ($self, $facility, $id, $msg, $claim) = @_;
	my $info = [$facility, $id, $msg];
	
	if(defined $claim && $claim->isa('App::Billing::Claim'))
	{
		$claim->addError($facility, $id, $msg);
     		# push(@$info, $claim->getId());
	}
	push(@{$self->{errors}}, $info);
}

sub haveErrors
{
	my $self = shift;
	my $err = $self->{errors};	

	return $#$err >= 0 ? 1 : 0;
}

sub getErrors
{
	return $_[0]->{errors};
}

sub getError
{
	my ($self, $errorIdx) = @_;
	my $info = $self->{errors}->[$errorIdx];

	return @$info if wantarray();

	my $invoiceId = scalar(@$info) == 4 ? " ($info->[3])" : '';
	return "$info->[0]-$info->[1]: $info->[2]";
}

sub addWarning
{
	my ($self, $facility, $id, $msg, $claim) = @_;
	my $info = [$facility, $id, $msg];
	if(defined $claim && $claim->isa('App::Billing::Claim'))
	{
		$claim->addWarning($facility, $id, $msg);
		push(@$info, $claim->getId());
	}
	push(@{$self->{warnings}}, $info);
}

sub haveWarnings
{
	return scalar($_[0]->{warnings}) > 0 ? 1 : 0;
}

sub getWarnings
{
	return $_[0]->{warnings};
}

sub getWarning
{
	my ($self, $warningIdx) = @_;
	my $info = $self->{warnings}->[$warningIdx];

	return @$info if wantarray();

	my $invoiceId = scalar(@$info) == 4 ? " ($info->[3])" : '';
	return "$info->[0]-$info->[1]: $info->[2]$invoiceId";
}

sub registerValidators
{
	# my ($self, $validators) = @_;
	#
	# this method should call $validators->register(new App::Billing::Validator::XXX);
	# -- if there are no validators in a particular
	#
}

1;
