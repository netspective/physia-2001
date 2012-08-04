#############################################################################
#
# Apache::Session::Serialize::Base64
# Serializes session objects using Storable and MIME::Base64
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package CGI::Session::Serialize::Base64;

use strict;
use vars qw($VERSION);
use MIME::Base64;
use Storable qw(nfreeze thaw);

$VERSION = '1.01';

sub serialize {
    my $session = shift;
    
    $session->{serialized} = encode_base64(nfreeze($session->{data}));
}

sub unserialize {
    my $session = shift;
    
    my $data = thaw(decode_base64($session->{serialized}));
    die "Session could not be unserialized" unless defined $data;
    #Storable can return undef or die for different errors
    $session->{data} = $data;
}

1;

