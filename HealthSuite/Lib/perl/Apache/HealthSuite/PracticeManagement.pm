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

	return DECLINED if ($ENV{REQUEST_URI} =~ /\.pdf$/);
	
	eval {
		my $arl;
		$arl = $1 if $ENV{REQUEST_URI} =~ /^\/?(.*)$/;
		$arl = "search" unless $arl;
		App::ResourceDirectory::handleARL($arl);
		return OK;
	};

	if ($@)
	{
		my $msg = "<h1>Perl Runtime Errors:</h1><font color=red>$@</font>";
		my $user = getpwuid($>) || '';
		$r->content_type('text/html');
		$r->send_http_header();
		if ($DEBUG)
		{	
			$r->print($msg);
		}
		else
		{
			$r->print('<h1>Error</h1><p>An application error has occured, please contact support if the problem persists.</p>');
		}
		unless ($ENV{HS_NOERROREMAIL})
		{
			open SENDMAIL, '|/usr/sbin/sendmail -t';
			print SENDMAIL "to: $user\n";
			print SENDMAIL "from: $user\n";
			print SENDMAIL "subject: Application Error\n";
			print SENDMAIL "content-type: text/html\n";
			print SENDMAIL "\n";
			print SENDMAIL $msg;
			close SENDMAIL;
		}
		return OK;
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

