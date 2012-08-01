#############################################################################
#
# Apache::Session::Generate::MD5;
# Generates session identifier tokens using MD5
# Copyright(c) 2000, 2001 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package CGI::Session::Generate::MD5;

use strict;
use vars qw($VERSION);
use Digest::MD5;

$VERSION = '2.12';

sub generate {
    my $session = shift;
    #Reduce the digest length instead of changing db data field size at various places.
    my $length = 16;
    
    if (exists $session->{args}->{IDLength}) {
        $length = $session->{args}->{IDLength};
    }
    
    $session->{data}->{_session_id} = 
        substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0, $length);
    

}

sub validate {
    #This routine checks to ensure that the session ID is in the form
    #we expect.  This must be called before we start diddling around
    #in the database or the disk.

    my $session = shift;
    
    if ($session->{data}->{_session_id} =~ /^([a-fA-F0-9]+)$/) {
        $session->{data}->{_session_id} = $1;
    } else {
        die "Invalid session ID: ".$session->{data}->{_session_id};
    }
}

1;

