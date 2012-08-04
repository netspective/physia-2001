#############################################################################
# 
# Copy of Apache::Session
# CGI::Session::Store::Oracle
# Implements session object storage via Oracle
# Copyright(c) 1998, 1999, 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package CGI::Session::Store::Oracle;

use strict;

use DBI;
use CGI::Session::Store::DBI;

use vars qw(@ISA $VERSION);

@ISA = qw(CGI::Session::Store::DBI);
$VERSION = '1.01';

$CGI::Session::Store::Oracle::DataSource = undef;
$CGI::Session::Store::Oracle::UserName   = undef;
$CGI::Session::Store::Oracle::Password   = undef;


sub connection
{
    my $self    = shift;
    my $session = shift;

        my $dbh = $session->{args}->{dbh};
    $self->{dbh} = $dbh;
    $self->{disconnectdbh} = 0;
    $dbh->{LongReadLen} = 8192;
    $dbh->trace(2);

    return $dbh;
}

sub notused_old_connection {
    my $self    = shift;
    my $session = shift;
    
    return if (defined $self->{dbh});

    if (exists $session->{args}->{Handle}) {
        $self->{dbh} = $session->{args}->{Handle};
        $self->{commit} = $session->{args}->{Commit};
        return;
    }

    my $datasource = $session->{args}->{DataSource} || 
        $CGI::Session::Store::Oracle::DataSource;
    my $username = $session->{args}->{UserName} ||
        $CGI::Session::Store::Oracle::UserName;
    my $password = $session->{args}->{Password} ||
        $CGI::Session::Store::Oracle::Password;
        
    $self->{dbh} = DBI->connect(
        $datasource,
        $username,
        $password,
        { RaiseError => 1, AutoCommit => 0 }
    ) || die $DBI::errstr;

    
    #If we open the connection, we close the connection
    $self->{disconnect} = 1;
    
    #the programmer has to tell us what commit policy to use
    $self->{commit} = $session->{args}->{Commit};
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);
    #Have table name in just one place.
    $self->{'table_name'} = $CGI::Session::Store::DBI::TableName;

    local $self->{dbh}->{RaiseError}  = 1;
    local $self->{dbh}->{LongReadLen} = $session->{args}->{LongReadLen} || 8*2**10;
  
    if (!defined $self->{materialize_sth}) {
        $self->{materialize_sth} = 
            $self->{dbh}->prepare_cached(qq{
		SELECT person_id, remote_addr, first_access, last_access, sysdate - last_access as last_access_delta, session_data FROM $self->{'table_name'} WHERE session_id = ?});

        $self->{updateaccess_sth} =
            $self->{dbh}->prepare(qq{
                UPDATE $self->{'table_name'} SET last_access = sysdate WHERE session_id = ?});

        $self->{updatetimeout_sth} =
            $self->{dbh}->prepare(qq{
                UPDATE $self->{'table_name'} SET status = 4 WHERE session_id = ?});
    }
   
    $self->{materialize_sth}->bind_param(1, $session->{data}->{_session_id});
    $self->{materialize_sth}->execute;
    
    my $results = $self->{materialize_sth}->fetchrow_arrayref;

    if (!(defined $results)) {
        die "Object does not exist in the data store";
    }


    my $idleSeconds = $results->[4] * (24*3600);
    if(my $timeOutSeconds = $session->{args}->{timeOutSeconds})
    {
                unless($idleSeconds < $timeOutSeconds)
                {
                        my $minutesIdle = int($idleSeconds / 60);
                        my $minutesTO = int($timeOutSeconds / 60);

                        my $timeoutSth = $self->{updatetimeout_sth};
                    	$timeoutSth->bind_param(1, $session->{data}->{_session_id});
                    	$timeoutSth->execute;
                    	$timeoutSth->finish;

                        ${$session->{args}->{errorCode_ref}} = "TIMEOUT-$timeOutSeconds-$idleSeconds";
                        ${$session->{args}->{errorMsg_ref}} = "You have been logged out of your session automatically because you have been inactive for $minutesIdle minutes (only up to $minutesTO minutes of idle time are allowed).";
                }
        }

    $self->{materialize_sth}->finish;
    $session->{serialized} = $results->[5];
    $session->{data}->{first_access} = $results->[2];
    $session->{data}->{last_access} = $results->[3];
    $session->{data}->{idle_seconds} = $idleSeconds;


    $self->{updateaccess_sth}->bind_param(1, $session->{data}->{_session_id});
    $self->{updateaccess_sth}->execute;
    $self->{updateaccess_sth}->finish;
   
}

sub DESTROY {
    my $self = shift;

    if ($self->{commit}) {
        $self->{dbh}->commit;
    }
    
    if ($self->{disconnect}) {
        $self->{dbh}->disconnect;
    }
}

1;

