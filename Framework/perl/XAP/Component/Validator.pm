##############################################################################
package XAP::Component::Validator;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use base qw(XAP::Component Exporter);
use fields qw(content);

sub init
{
	my XAP::Component::Validator $self = shift;
	$self->SUPER::init(@_);
	$self->{childCompList} = [];
}

sub needsValidation
{
	my XAP::Component::Validator $self = shift;
	my $page = shift;

	my $needsValCount = 0;
	foreach (@{$self->{childCompList}})
	{
		$needsValCount++ if $_->needsValidation($page, $self);
	}
	return $needsValCount;
}

sub addFields
{
	my XAP::Component::Validator $self = shift;

	foreach (@_)
	{
		push(@{$self->{childCompList}}, $_) if ref $_ && $_->isa('XAP::Component::Validator::Field');
	}
}

sub populateValues
{
	my XAP::Component::Validator $self = shift;
	my $page = shift;

	foreach (@{$self->{childCompList}})
	{
		next if ! $_;
		$_->populateValue($page, $self);
	}
	return 1;
}

sub isValid
{
	my XAP::Component::Validator $self = shift;
	my $page = shift;

	# just cycle through all the rules and let them validate themselves
	foreach (@{$self->{childCompList}})
	{
		$_->isValid($page, $self) if $_->needsValidation($page, $self);
	}

	# return TRUE if there were no errors, FALSE (0) if there were errors
	return $page->haveValidationErrors() ? 0 : 1;
}

1;