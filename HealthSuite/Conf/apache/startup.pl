#!/usr/bin/perl -w

BEGIN {
	use Apache ();
}

print "Entering startup.pl\n";
use strict;
use CGI;
use CGI::Page;
use Apache::HealthSuite::PracticeManagement;

print "Caching iSyndacate News...";
use App::Component::News;
eval{
	my $news;
	$news = new App::Component::News(
			id => 'news-top',
			heading => 'Top News',
			source => 'topnews',
		);
	$news->getNews();
	$news = new App::Component::News(
			id => 'news-health',
			heading => 'Health News',
			source => 'healthnews',
		);
	$news->getNews();
};
print "done\n";

print "Connecting to Database...";
{
	my $page = new CGI::Page;
	$page = undef;
}
print "done\n";
print "Leaving startup.pl\n";

1;
