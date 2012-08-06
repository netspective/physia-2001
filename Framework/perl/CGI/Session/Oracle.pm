#############################################################################
#
# CGI::Session::Oracle
# This file is derived from Apache::Session source
# Apache persistent user sessions in a Oracle database
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package CGI::Session::Oracle;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.01';
@ISA = qw(Apache::Session);

use Apache::Session;
use CGI::Session::Lock::Null;
use CGI::Session::Store::Oracle;
use CGI::Session::Generate::MD5;
use CGI::Session::Serialize::Base64;

sub populate {
    my $self = shift;

    $self->{object_store} = new CGI::Session::Store::Oracle $self;
    $self->{lock_manager} = new CGI::Session::Lock::Null $self;
    $self->{generate}     = \&CGI::Session::Generate::MD5::generate;
    $self->{validate}     = \&CGI::Session::Generate::MD5::validate;
    $self->{serialize}    = \&CGI::Session::Serialize::Base64::serialize;
    $self->{unserialize}  = \&CGI::Session::Serialize::Base64::unserialize;

    return $self;
}

1;
