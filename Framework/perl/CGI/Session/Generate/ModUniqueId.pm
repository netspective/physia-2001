package Apache::Session::Generate::ModUniqueId;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

sub generate {
    my $session = shift;
    unless (exists $ENV{UNIQUE_ID}) {
	require Carp;
	Carp::croak('Can\'t get UNIQUE_ID env variable. Make sure mod_unique_id is enabled.');
    }
    $session->{data}->{_session_id} = $ENV{UNIQUE_ID};
}

sub validate {
    my $session = shift;
    $session->{data}->{_session_id} =~ /^[A-Za-z0-9@\-]+$/
	or die "invalid session id: $session->{data}->{_session_id}.";
}

1;

