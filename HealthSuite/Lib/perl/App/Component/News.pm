##############################################################################
package App::Component::News;
##############################################################################

use strict;
use CGI::Component;
use LWP::UserAgent;
use HTML::TokeParser;
use Data::Publish;

use vars qw(@ISA %NEWS %DEFNS %RESOURCE_MAP);
@ISA   = qw(CGI::Component);
%NEWS  = ();

%RESOURCE_MAP = (
	'news-top' => {
		_class => new App::Component::News(heading => 'Top News', source => 'topnews'),
		},
	'news-health' => {
		_class => new App::Component::News(heading => 'Health News', source => 'healthnews'),
		},
	);

sub init
{
	my ($self) = @_;
	$self->{publishDefn} =
	{
		style => 'panel',
		width => '100%',
		frame =>
		{
			heading => $self->{heading},
		},
		columnDefn => [{ dataFmt => '<A HREF="#0#" TARGET="NEWS">#1#</A>' }],
		bullets => 1,
	};
	die 'source and heading are required' unless $self->{source} && $self->{heading};
}

sub getHtml
{
	my ($self, $page) = @_;
	return createHtmlFromData($page, $self->{flags}, $self->getNews(), $self->{publishDefn});
}

sub getNews
{
	my $self = shift;
	my $source = $self->{source};
	unless( defined $NEWS{$source} )
	{
		my $newsData = [];
		my $ua = new LWP::UserAgent;
		$ua->timeout(5);
		my $request = HTTP::Request->new('GET', "http://headlines.isyndicate.com/pages/physia/$source.html");
		my $response = $ua->request($request);
		if ($response->is_success)
		{
			my $origHtml = $response->content();
			my $p = HTML::TokeParser->new(\$origHtml);
			while (my $token = $p->get_tag("a"))
			{
				my $url = $token->[1]{href} || "-";
				my $text = $p->get_trimmed_text("/a");
				next if $text =~ m/iSyndicate/i;
				push(@$newsData, [$url, $text]);
			}
		}
		else
		{
			 warn "$$ Can't fetch news from isyndicate.com!\n"
		}
		$NEWS{$source} = $newsData;
	}
	return $NEWS{$source};
}

1;
