##############################################################################
package Apache::HealthSuite::PracticeManagement::PerlHandler;
##############################################################################

use strict;
use Apache;
use Apache::Constants qw(:common);
use CGI qw(:standard);
use App::ResourceDirectory;

sub handler
{
	my $r = shift;
	my $DEBUG = ref($r) && $r->dir_config("StatINC_Debug");
	$DEBUG = (! $DEBUG) || (lc($DEBUG) eq 'off') ? 0 : 1;

	eval {
		my $arl;
		$arl = $1 if $ENV{REQUEST_URI} =~ /^\/?(.*)$/;
		$arl = "search" unless $arl;
		App::ResourceDirectory::handleARL($arl);
		return OK;
	};

	if ($@ && $DEBUG)
	{
		$r->content_type('text/html');
    		$r->send_http_header();
    		$r->print("<h1>Perl Runtime Errors:</h1><font color=red>$@</font>");
	}
}


##############################################################################
package Apache::HealthSuite::PracticeManagement::PerlChildInitHandler;
##############################################################################

use strict;
use App::Component::News;
use CGI::Page;

sub handler
{
	# Pre-fetch iSyndicate news articles
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

	# Pre-connect to the database
	my $page = new CGI::Page;
}


1;

