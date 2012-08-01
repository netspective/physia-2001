#############################################################################
#
# Apache::Session::Serialize::UUEncode
# Serializes session objects using Storable and pack
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Serialize::UUEncode;

use strict;
use vars qw($VERSION);
use Storable qw(nfreeze thaw);

$VERSION = '1.01';

sub serialize {
    my $session = shift;
    
    $session->{serialized} = pack("u", nfreeze($session->{data}));
}

sub unserialize {
    my $session = shift;
    
    my $data = thaw(unpack("u", $session->{serialized}));
    die "Session could not be unserialized" unless defined $data;
    #Storable can return undef or die for different errors
    $session->{data} = $data;
}

1;

