##############################################################################
package App::Component::News;
##############################################################################

use strict;
use CGI::Component;
use LWP::Simple;
use HTML::TokeParser;
use Data::Publish;

use vars qw(@ISA %NEWS %DEFNS);

@ISA   = qw(CGI::Component);
%NEWS  = ();

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

	my $newsData = undef;
	my $source = $self->{source};
	unless($newsData = $NEWS{$source})
	{
		$newsData = [];
		my $origHtml = get("http://headlines.isyndicate.com/pages/physia/$source.html");

		my $p = HTML::TokeParser->new(\$origHtml);
		while (my $token = $p->get_tag("a"))
		{
			my $url = $token->[1]{href} || "-";
			my $text = $p->get_trimmed_text("/a");
			next if $text =~ m/iSyndicate/i;
			push(@$newsData, [$url, $text]);
		}
		$NEWS{$source} = $newsData;
	}

	return createHtmlFromData($page, $self->{flags}, $newsData, $self->{publishDefn});
}

# create instances that will auto-register themselves
new App::Component::News(
		id => 'news-top',
		heading => 'Top News',
		source => 'topnews',
	);

new App::Component::News(
		id => 'news-health',
		heading => 'Health News',
		source => 'healthnews',
	);

1;