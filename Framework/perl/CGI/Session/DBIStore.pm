##############################################################################
package CGI::Session::DBIStore;
##############################################################################

#
# THIS PACKAGE IS AN ARCHITECTURALLY DUPLICATE COPY OF Apache::Session::DBIStore
# except that the sessions table has been replaced by person_session and column
# names have been changed accordingly. Also, instead of accepting DBI paramters
# it expects a handle to an existing dbi object (dbh).
#

use strict;

use DBI;
use Storable qw(nfreeze thaw);

use vars qw($VERSION);
$VERSION = '1.00';

sub new
{
    my $class = shift;
    return bless {}, $class;
}

sub connection
{
    my $self    = shift;
    my $session = shift;

	my $dbh = $session->{args}->{dbh};
    $self->{dbh} = $dbh;
    $self->{disconnectdbh} = 0;
    $dbh->{LongReadLen} = 8192;
    $dbh->trace(1);

    return $dbh;
}

sub insert
{
    my $self    = shift;
    my $session = shift;

    unless(defined $self->{insert_sth})
    {
	    my $dbh = $self->{dbh} || $self->connection($session);
        $self->{insert_sth} =
            $dbh->prepare(qq{
                INSERT INTO person_session (session_id, status, person_id, remote_host, remote_addr, first_access, last_access, session_data_size, session_data) VALUES (?,?,?,?,?,sysdate,sysdate,?,?)});
        $self->{updateorg_sth} =
            $dbh->prepare(qq{
                update person_session set org_id = ? where session_id = ?});
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
    $insertSth->bind_param(6, length $serialized);
    $insertSth->bind_param(7, $serialized);
    $insertSth->execute;
    $insertSth->finish;

    if($sessData->{org_id} = $args->{org_id})
	{
		$updateOrgSth->bind_param(1, $args->{org_id});
		$updateOrgSth->bind_param(2, $sessionId);
	    $updateOrgSth->execute;
	    $updateOrgSth->finish;
	}
}

sub update
{
    my $self    = shift;
    my $session = shift;

    unless(defined $self->{update_sth})
    {
	    my $dbh = $self->{dbh} || $self->connection($session);
        $self->{update_sth} =
            $dbh->prepare(qq{
                UPDATE person_session SET status = ?, session_data_size = ?, session_data = ?, last_access = sysdate WHERE session_id = ?});
    }
    my $sth = $self->{update_sth};
    my $sessData = $session->{data};
    my $serialized = nfreeze $sessData;

    $sth->bind_param(1, $sessData->{_LOGOUT} ? 1 : 0);
    $sth->bind_param(2, length $serialized);
    $sth->bind_param(3, $serialized);
    $sth->bind_param(4, $sessData->{_session_id});
    $sth->execute;
    $sth->finish;
}

sub materialize
{
    my $self    = shift;
    my $session = shift;
    my $args    = $session->{args};
    my $sessionId = $session->{data}->{_session_id};

    unless(defined $self->{materialize_sth})
    {
	    my $dbh = $self->{dbh} || $self->connection($session);
        $self->{materialize_sth} =
            $dbh->prepare(qq{
                SELECT person_id, remote_addr, first_access, last_access, sysdate - last_access as last_access_delta, session_data FROM person_session WHERE session_id = ?});
        $self->{updateaccess_sth} =
            $dbh->prepare(qq{
                UPDATE person_session SET last_access = sysdate WHERE session_id = ?});
        $self->{updatetimeout_sth} =
            $dbh->prepare(qq{
                UPDATE person_session SET status = 4 WHERE session_id = ?});
    }
    my $materializeSth = $self->{materialize_sth};
    my $updateAccessSth = $self->{updateaccess_sth};

    $materializeSth->bind_param(1, $sessionId);
    $materializeSth->execute;

    my $results = $materializeSth->fetchrow_arrayref;
    ${$args->{errorCode_ref}} = '';
    ${$args->{errorMsg_ref}} = '';

    unless (defined $results)
    {
		${$args->{errorCode_ref}} = 'ID_NOT_FOUND';
		${$args->{errorMsg_ref}} = "Session ID '$sessionId' was not found.";
    }
    if($args->{verifyRemoteAddr})
    {
	    unless ($args->{remote_addr} eq $results->[1])
	    {
			${$args->{errorCode_ref}} = 'INVALID_ADDR';
			${$args->{errorMsg_ref}} = "Session ID '$sessionId' does not belong to your computer ($args->{remote_addr}).";
	    }
	}

    my $idleSeconds = $results->[4] * (24*3600);
    if(my $timeOutSeconds = $args->{timeOutSeconds})
    {
		unless($idleSeconds < $timeOutSeconds)
		{
			my $minutesIdle = int($idleSeconds / 60);
			my $minutesTO = int($timeOutSeconds / 60);

			my $timeoutSth = $self->{updatetimeout_sth};
		    $timeoutSth->bind_param(1, $sessionId);
		    $timeoutSth->execute;
		    $timeoutSth->finish;

			${$args->{errorCode_ref}} = "TIMEOUT-$timeOutSeconds-$idleSeconds";
			${$args->{errorMsg_ref}} = "You have been logged out of your session automatically because you have been inactive for $minutesIdle minutes (only up to $minutesTO minutes of idle time are allowed).";
		}
	}

    $materializeSth->finish;
	die ${$args->{errorMsg_ref}} if ${$args->{errorMsg_ref}};

    $updateAccessSth->bind_param(1, $sessionId);
    $updateAccessSth->execute;
    $updateAccessSth->finish;

    $session->{data} = thaw $results->[5];
    $session->{data}->{first_access} = $results->[2];
    $session->{data}->{last_access} = $results->[3];
    $session->{data}->{idle_seconds} = $idleSeconds;
}

sub remove
{
    my $self    = shift;
    my $session = shift;

    unless(defined $self->{remove_sth})
    {
	    my $dbh = $self->{dbh} || $self->connection($session);
        $self->{remove_sth} =
            $dbh->prepare(qq{
                DELETE FROM person_session WHERE session_id = ?});
    }
    my $sth = $self->{remove_sth};

    $sth->bind_param(1, $session->{data}->{_session_id});
    $sth->execute;
    $sth->finish;
}

sub DESTROY
{
    my $self = shift;
    if($self->{disconnectdbh} && $self->{dbh})
    {
        $self->{dbh}->disconnect;
    }
}

1;
