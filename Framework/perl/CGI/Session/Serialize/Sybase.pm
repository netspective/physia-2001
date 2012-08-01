#############################################################################
#
# Apache::Session::Serialize::Sybase
# Serializes session objects using Storable and packing into Sybase format
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Modified from Apache::Session::Serialize::Storable by Chris Winters (chris@cwinters.com)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Serialize::Sybase;

use strict;
use vars qw( $VERSION );

use Apache::Session::Serialize::Storable;

$VERSION = '1.00';

# Modify the storable-serialized data to work with sybase
sub serialize {
    my $session = shift;
	Apache::Session::Serialize::Storable::serialize( $session );    # sets $session->{serialized}
    $session->{serialized} = unpack('H*', $session->{serialized} );
}

# Modify the data from sybase to work with storable so it can thaw properly
sub unserialize {
    my $session = shift;
    $session->{serialized} = pack('H*', $session->{serialized} );
	Apache::Session::Serialize::Storable::unserialize( $session );  # sets $session->{data}
}

1;

