##############################################################################
package App::Page::Search::Auto;
##############################################################################

use strict;
use App::Page::Search;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/auto' => {},
	);

sub getForm
{
	return ('Lookup');
}

sub createRedirect_person
{
	my ($self, $prefix, $expression) = @_;

	return "$prefix/id/$expression" if $expression =~ m/^[A-Z0-9_\*]+$/;
	return "$prefix/dob/$expression" if $expression =~ m/^\d\d\-\d\d\-\d\d\d\d$/;
	return "$prefix/ssn/$expression" if $expression =~ m/^\d\d\d\-\d\d\-\d\d\d\d$/;
	return "$prefix/phone/$expression" if $expression =~ m/^\d\d\d\-\d\d\d\-\d\d\d\d$/;
	return "$prefix/lastname/$expression";
}

sub createRedirect_org
{
	my ($self, $prefix, $expression) = @_;

	return "$prefix/id/$expression" if $expression =~ m/^[A-Z0-9_\*]+$/;
	return "$prefix/primname/$expression";
}

sub prepare
{
	my $self = shift;
	my ($scope, $expression) = ($self->param('search_scope'), $self->param('search_expression'));

	my $prefix = "/search/$scope";
	$self->redirect($prefix) unless $expression;

	# replace any "/" characters with "_" so that we have good perl
	$scope =~ s/\//_/;
	if(my $method = $self->can("createRedirect_$scope"))
	{
		$self->redirect(&{$method}($self, $prefix, $expression),1);
	}
	else
	{
		$self->redirect($prefix);
		#$self->addContent("Unknown scope '$scope' ($expression).");
	}

	return 1;
}

1;
