##############################################################################
package XAP::Apache::PerlHandler;
##############################################################################

use strict;
use Apache;
use Apache::Constants qw(:common);
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

use XAP::Component;
use XAP::Component::FileType::All;
use XAP::Component::File::Path;
use XAP::CGI::Page;

sub handler
{
	my $r = shift;
	my $DEBUG = ref($r) && $r->dir_config("StatINC_Debug");
	$DEBUG = (! $DEBUG) || (lc($DEBUG) eq 'off') ? 0 : 1;

	unless($ROOT_COMPONENT)
	{
		$ROOT_COMPONENT = new XAP::Component::File::Path(
					id => $ENV{XAP_ROOT_ID} || '',
					url => $ENV{XAP_ROOT_URL} || '/',
					heading => $ENV{XAP_ROOT_HEADING} || 'Root',
					caption => $ENV{XAP_ROOT_CAPTION} || 'Root',
					icon => $ENV{XAP_ROOT_ICON} || '/resources/icons/home-sm.gif',
					flags => COMPFLAG_PRINTERRORS,
					srcFile => $ENV{XAP_ROOT_PATH},
				);
		$ROOT_COMPONENT->readEntries();
	}
		
	eval
	{
		XAP::Component->processPage($ENV{REQUEST_URI} || '/', new XAP::CGI::Page);
		return OK;
	};
	
	if ($@)
	{
		my $msg = "<h1>Perl Runtime Errors:</h1><font color=red>$@</font>";
		my $user = getpwuid($>) || '';
		$r->content_type('text/html');
		$r->send_http_header();
		$r->print($msg);
		return OK;
	}
}

1;