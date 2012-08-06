package Apache::Session::Generate::ModUsertrack;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use CGI::Cookie;
use constant MOD_PERL => exists $ENV{MOD_PERL};

sub generate {
    my $session = shift;

    my $name = $session->{args}->{ModUsertrackCookieName} || 'Apache';
    my %cookies = CGI::Cookie->fetch;

    if (!exists $cookies{$name} && MOD_PERL) {
	# no cookies, try to steal from notes
	require Apache;
	my $r = Apache->request;
	%cookies = CGI::Cookie->parse($r->notes('cookie'));
    }

    unless ($cookies{$name}) {
	# still bad luck
	require Carp;
	Carp::croak('no cookie found. Make sure mod_usertrack is enabled.');
    }
    $session->{data}->{_session_id} = $cookies{$name}->value;
}

sub validate {
    my $session = shift;

    # remote_host (or remote_addr) + int
    $session->{data}->{_session_id} =~ /^[\d\w\.]+\.\d+$/
	or die "invalid session id: $session->{data}->{_session_id}";
}

1;

