##############################################################################
package App::Component::SDE::PageInfo;
##############################################################################

use strict;
use CGI::Component;
use Data::Publish;

use vars qw(@ISA %DEFNS);

@ISA   = qw(CGI::Component);

sub init
{
	my ($self) = @_;

	die 'source is required' unless $self->{source};
	$self->{publishDefn} =
	{
		style => 'panel.static',
		width => '100%',
		frame =>
		{
			heading => $self->{heading},
			headColor => 'beige',
			borderColor => 'beige',
			contentColor => 'lightyellow',
		},
		columnDefn => [
			{ head => 'Variable', dataFmt => '#0#:', dAlign => 'RIGHT' },
			{ head => 'Value' },
			],
	};
}

sub prepareData_paramsnofields
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort $page->param())
	{
		next if m/^_f_/;
		my @vals = $page->param($_);
		push(@$data, [$_, join(', ', @vals)]);
	}
	return $data;
}

sub prepareData_paramsandfields
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort $page->param())
	{
		my @vals = $page->param($_);
		push(@$data, [$_, join(', ', @vals)]);
	}
	return $data;
}

sub prepareData_fields
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort $page->param())
	{
		next unless m/^_f_/;
		my @vals = $page->param($_);
		push(@$data, [$_, join(', ', @vals)]);
	}
	return $data;
}

sub prepareData_session
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort keys %{$page->{session}})
	{
		my @vals = $page->session($_);
		push(@$data, [$_, join(', ', @vals)]);
	}
	return $data;
}

sub prepareData_cookies
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort $page->cookie())
	{
		my @vals = $page->cookie($_);
		push(@$data, [$_, join(', ', @vals)]);
	}
	return $data;
}

sub prepareData_env
{
	my ($self, $page) = @_;

	my $data = [];
	foreach(sort keys %ENV)
	{
		push(@$data, [$_, $ENV{$_}]);
	}
	return $data;
}

sub prepareData_components
{
	my ($self, $page) = @_;

	my $data = [];
	if(my $components = $page->{components})
	{
		foreach (@$components)
		{
			if($_->[0] == App::Universal::COMPONENTTYPE_STATEMENT)
			{
				push(@$data, [$_->[1], "<a href='/sde/stmgr/@{[ $_->[2]->{id} ]}/@{[ $_->[3] ]}'>@{[ $_->[2]->{id} ]}</a>"]);
			}
			else
			{
				my $object = "@{[$_->[2]]}";
				$object =~ s/=.*$//;
				push(@$data, [$_->[1], $object]);
			}
		}
	}
	return $data;
}

sub getHtml
{
	my ($self, $page) = @_;

	my $data = [];
	if(my $method = $self->can("prepareData_" . $self->{source}))
	{
		$data = $self->$method($page);
	}

	return createHtmlFromData($page, $self->{flags}, $data, $self->{publishDefn});
}

# create instances that will auto-register themselves
new App::Component::SDE::PageInfo(
		id => 'sde-page-params-no-fields',
		heading => 'CGI Parameters (no fields)',
		source => 'paramsnofields',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-params-and-fields',
		heading => 'CGI Parameters (and fields)',
		source => 'paramsandfields',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-fields',
		heading => 'Dialog Fields',
		source => 'fields',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-session',
		heading => 'Session Data',
		source => 'session',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-cookies',
		heading => 'Cookies',
		source => 'cookies',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-env',
		heading => 'Environment',
		source => 'env',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-components',
		heading => 'Components on this page',
		source => 'components',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-debug',
		heading => 'Debugging Statements',
		source => 'debug',
	);

new App::Component::SDE::PageInfo(
		id => 'sde-page-status',
		heading => 'Status Panel',
		source => 'status',
	);

1;
