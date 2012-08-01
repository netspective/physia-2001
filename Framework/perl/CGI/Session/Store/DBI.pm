#############################################################################
#
# CGI::Session::Store::DBI
# A base class for the MySQL, Postgres, and other DBI stores
# Copyright(c) 2000, 2004 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package CGI::Session::Store::DBI;

use strict;
use DBI;
use Storable qw(nfreeze thaw);
use vars qw($VERSION);


$VERSION = '1.02';

$CGI::Session::Store::DBI::TableName = "person_session";

sub new {
    my $class = shift;

    return bless { table_name => $CGI::Session::Store::DBI::TableName }, $class;
}

sub insert {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{insert_sth}) {
        $self->{insert_sth} = 
            $self->{dbh}->prepare_cached(qq{
             INSERT INTO $self->{'table_name'} (session_id, status, person_id, remote_host, remote_addr, first_access, last_access, session_data_size, session_data) VALUES (?,?,?,?,?,sysdate,sysdate,?,?)});
	$self->{updateorg_sth} =
            $self->{dbh}->prepare(qq{
                update person_session set org_internal_id = ? where session_id = ?});

    }

    my $insertSth = $self->{insert_sth};
    my $updateOrgSth = $self->{updateorg_sth};

    my $args = $session->{args};
    my $sessData = $session->{data};
    my $serialized = nfreeze $sessData;

    # assign some default items to both the session object and the database bind column
    #
    my $sessionId = $sessData->{_session_id};
    $insertSth->bind_param(1, $sessionId);
    $insertSth->bind_param(2, $sessData->{status} = ($args->{status} || 0));
    $insertSth->bind_param(3, $sessData->{person_id} = $args->{person_id});
    $insertSth->bind_param(4, $sessData->{remote_host} = $args->{remote_host});
    $insertSth->bind_param(5, $sessData->{remote_addr} = $args->{remote_addr});
    $self->{insert_sth}->bind_param(6, length $session->{serialized});
    $self->{insert_sth}->bind_param(7, $session->{serialized});

    $insertSth->execute;
    $insertSth->finish;

    if($sessData->{org_internal_id} = $args->{org_internal_id})
        {
            $updateOrgSth->bind_param(1, $args->{org_internal_id});
            $updateOrgSth->bind_param(2, $sessionId);
            $updateOrgSth->execute;
            $updateOrgSth->finish;          
        }

    
}

sub update {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{update_sth}) {
        $self->{update_sth} = 
            $self->{dbh}->prepare_cached(qq{
             UPDATE $self->{'table_name'} SET status = ?, session_data_size = ?, session_data = ?, last_access = sysdate WHERE session_id = ?});

    }

    my $sth = $self->{update_sth};
    my $sessData = $session->{data};
    my $serialized = nfreeze $sessData;

    $sth->bind_param(1, $sessData->{_LOGOUT} ? 1 : 0);
    $self->{update_sth}->bind_param(2, length $session->{serialized});  
    $self->{update_sth}->bind_param(3, $session->{serialized});
    $sth->bind_param(4, $sessData->{_session_id});
    $sth->execute;
    $sth->finish;

}

sub materialize {
    my $self    = shift;
    my $session = shift;

    my $args    = $session->{args};
    my $sessionId = $session->{data}->{_session_id};

    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{materialize_sth}) {
        $self->{materialize_sth} = 
            $self->{dbh}->prepare_cached(qq{
	     SELECT person_id, remote_addr, first_access, last_access, sysdate - last_access as last_access_delta, session_data FROM $self->{'table_name'} WHERE session_id = ?});

    }
   
    my $materializeSth = $self->{materialize_sth};

    $materializeSth->bind_param(1, $sessionId);
    $materializeSth->execute;

    my $results = $self->{materialize_sth}->fetchrow_arrayref;

    if (!(defined $results)) {
        die "Object does not exist in the data store";
    }

    $self->{materialize_sth}->finish;
    $session->{serialized} = $results->[0];
}

sub remove {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);
    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{remove_sth}) {
        $self->{remove_sth} = 
            $self->{dbh}->prepare_cached(qq{
                DELETE FROM $self->{'table_name'} WHERE session_id = ?});
    }

    $self->{remove_sth}->bind_param(1, $session->{data}->{_session_id});
    
    $self->{remove_sth}->execute;
    $self->{remove_sth}->finish;
}

1;
