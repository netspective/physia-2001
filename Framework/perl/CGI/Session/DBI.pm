##############################################################################
package CGI::Session::DBI;
##############################################################################

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.00';
@ISA = qw(Apache::Session);

use Apache::Session;
use CGI::Session::DBIStore;
use Apache::Session::NullLocker;

sub get_object_store
{
    my $self = shift;

    return new CGI::Session::DBIStore $self;
}

sub get_lock_manager
{
    my $self = shift;

    return new Apache::Session::NullLocker $self;
}

1;