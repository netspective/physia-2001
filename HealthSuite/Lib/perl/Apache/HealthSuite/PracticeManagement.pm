package Apache::HealthSuite::PracticeManagement;

use strict;
use Apache::Constants qw(:common);
use CGI qw(:standard);
#use CGI::Carp qw(fatalsToBrowser);
use App::ResourceDirectory;
#use vars qw( %SIG );

#$SIG{__WARN__} = \&Carp::cluck;

sub handler {
	my $arl;
	
	$arl = $1 if $ENV{REQUEST_URI} =~ /^\/?(.*)$/;
	$arl = "search" unless $arl;
	App::ResourceDirectory::handleARL($arl);
	return OK;
}

1;

