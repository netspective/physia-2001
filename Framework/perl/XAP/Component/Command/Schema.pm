##############################################################################
package XAP::Component::Command::Schema;
##############################################################################

use strict;
use XAP::Component;
use XAP::Component::Command;

use base qw(XAP::Component::Command);
use fields qw(action table params fields result);

XAP::Component->registerXMLTagClass('cmd-schema', __PACKAGE__);

sub init
{
	my XAP::Component::Command::Schema $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{action} = exists $params{action} ? $params{action} : undef;
	$self->{table} = exists $params{table} ? $params{table} : undef;
	$self->{result} = exists $params{result} ? $params{result} : undef;
	$self->{params} = exists $params{params} ? $params{params} : undef;
	$self->{fields} = exists $params{fields} ? $params{fields} : undef;
	
	$self;
}

sub applyXML
{
	my XAP::Component::Command::Schema $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	
	$self->{action} = $attrs->{action};
	$self->{table} = $attrs->{table};
	$self->{result} = $attrs->{result} ? $attrs->{result} : undef;
	$self->{params} = $attrs->{params} ? \split(',', $attrs->{params}) : undef;
	$self->{fields} = $attrs->{fields} ? \split(',', $attrs->{fields}) : undef;
	
	$self;
}

sub execute
{
	my XAP::Component::Command::Schema $self = shift;
	my ($page, $flags, $execParams) = @_;
	
	my $controller = $page->{page_controller};
	my $action = $controller->applyFilters($self->{action});
	my %params = ();
	if($self->{params})
	{
		foreach (split(/,/, $controller->applyFilters($self->{params})))
		{
			$params{$_} = $page->param($_);
		}
	}
	if($self->{fields})
	{
		foreach (split(/,/, $controller->applyFilters($self->{fields})))
		{
			$params{$_} = $page->param("_f_$_");
		}
	}

	if($self->{result})
	{
		$page->field($self->{result}, $controller->schemaAction($page, $controller->applyFilters($self->{table}), $controller->applyFilters($self->{action}), %params));
	}
	else
	{
		$controller->schemaAction($page, $controller->applyFilters($self->{table}), $controller->applyFilters($self->{action}), %params);
	}
	
	return '';
}

1;