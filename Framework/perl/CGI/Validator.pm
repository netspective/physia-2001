##############################################################################
package CGI::Validator;
##############################################################################

use strict;
use CGI::Validator::Field;

sub new
{
	my $type = shift;

	my $instance = bless
	{
		content => [],
	}, $type;

	return $instance;
}

sub needsValidation
{
	my ($self, $page) = @_;

	my $needsValCount = 0;
	foreach (@{$self->{content}})
	{
		$needsValCount++ if $_->needsValidation($page, $self);
	}
	return $needsValCount;
}

sub addFields
{
	my $self = shift;
	foreach (@_)
	{
		push(@{$self->{content}}, $_) if ref $_ && $_->isa('CGI::Validator::Field');
	}
}

sub populateValues
{
	my ($self, $page) = @_;
	foreach (@{$self->{content}})
	{
		next if ! $_;
		$_->populateValue($page, $self);
	}
	return 1;
}

sub isValid
{
	my ($self, $page) = @_;

	# just cycle through all the rules and let them validate themselves
	foreach (@{$self->{content}})
	{
		$_->isValid($page, $self) if $_->needsValidation($page, $self);
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

1;