##############################################################################
package App::Component::SDE::PageInfo;
##############################################################################

use strict;
use CGI::Component;
use Data::Publish;
use Security::AccessControl;

use vars qw(@ISA %DEFNS %RESOURCE_MAP);
@ISA = qw(CGI::Component);

%RESOURCE_MAP = (
	'sde-page-params-no-fields' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'CGI Parameters (no fields)',
			source => 'paramsnofields',
			),
		},
	'sde-page-params-and-fields' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'CGI Parameters (and fields)',
			source => 'paramsandfields',
			),
		},
	'sde-page-fields' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Dialog Fields',
			source => 'fields',
			),
		},
	'sde-page-session' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Session Data',
			source => 'session',
			),
		},
	'sde-page-cookies' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Cookies',
			source => 'cookies',
			),
		},
	'sde-page-env' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Environment',
			source => 'env',
			),
		},
	'sde-page-components' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Components on this page',
			source => 'components',
			),
		},
	'sde-page-debug' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Debugging Statements',
			source => 'debug',
			),
		},
	'sde-page-status' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Status Panel',
			source => 'status',
			),
		},
	'sde-page-acl' => {
		_class => new App::Component::SDE::PageInfo(
			heading => 'Access Control List',
			source => 'acl',
			),
		},
	);

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
				push(@$data, [$_->[1], "<a href='/sde/stmgrs/@{[ $_->[2]->{id} ]}/@{[ $_->[3] ]}'>@{[ $_->[2]->{id} ]}</a>"]);
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

sub prepareData_acl
{
	my ($self, $page) = @_;

	my $acl = $page->{acl};	
	my $allPerms = '';
	foreach my $item (sort keys %{$acl->{permissionIds}})
	{
		my $allowed = $page->hasPermission($item) ? '(allowed)' : '';
		$allPerms .= ($allowed ? '<FONT COLOR=green>' : '') . "$item: " . $acl->{permissionIds}->{$item}->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]->run_list() . " $allowed" . ($allowed ? '</FONT>' : '') . " <BR>";
	}

	my $userRoles = $page->session('aclRoleNames');
	my $data =
		[
			['User Roles', ref $userRoles eq 'ARRAY' ? join(', ', @{$userRoles}) : '(none)'],
			['User Permissions', $page->{permissions}->run_list()],
			['ACL File(s)', join(', ', $acl->{sourceFiles}->{primary}, @{$acl->{sourceFiles}->{includes}})],
			['All Permissions', $allPerms],
		];
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

1;
