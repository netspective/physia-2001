##############################################################################
package Apache::HealthSuite::PracticeManagement::PerlHandler;
##############################################################################

use strict;
use Apache;
use Apache::Constants qw(:common);
use CGI qw(:standard);
use App::ResourceDirectory;
use CGI::Carp qw(fatalsToBrowser);

sub handler
{
	my $r = shift;
	my $DEBUG = ref($r) && $r->dir_config("StatINC_Debug");
	$DEBUG = (! $DEBUG) || (lc($DEBUG) eq 'off') ? 0 : 1;

	eval {
		my $arl;
		$arl = $1 if $ENV{REQUEST_URI} =~ /^\/?(.*)$/;
		#$arl = "search" unless $arl;
		App::ResourceDirectory::handleARL($arl);
		return OK;
	};

	if ($@ && $DEBUG)
	{
		my $msg = "<h1>Perl Runtime Errors:</h1><font color=red>$@</font>";
		$r->content_type('text/html');
   		$r->send_http_header();
   		$r->print($msg);
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
	warn ("$$ BEGIN Fetching news articles\n");
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
	warn ("$$ DONE Fetching news articles\n");

	# Pre-connect to the database
	warn ("$$ BEGIN Pre-Connecting to the database\n");
	my $page = new CGI::Page;
	warn ("$$ END Pre-Connecting to the database\n");
}


1;

