############################################################################
#
# Apache::Session::Lock::Semaphore
# IPC Semaphore locking for Apache::Session
# Copyright(c) 1998, 1999, 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Lock::Semaphore;

use strict;
use Config;
use IPC::SysV qw(IPC_PRIVATE IPC_CREAT S_IRWXU SEM_UNDO);
use IPC::Semaphore;
use Carp qw/croak confess/;
use vars qw($VERSION);

$VERSION = '1.04';

BEGIN {

    if ($Config{'osname'} eq 'linux') {
        #More semaphores on Linux means less lock contention
        $Apache::Session::Lock::Semaphore::nsems = 32;
    } elsif ($Config{'osname'}=~/bsd/i) {
        $Apache::Session::Lock::Semaphore::nsems = 8; #copied from IPC::Semaphore/sem.t minus 1
    } else {
        $Apache::Session::Lock::Semaphore::nsems = 16;
    }
    
    $Apache::Session::Lock::Semaphore::sem_key = 31818;
}

sub new {
    return unless $Config{d_semget};
    return
        if $^O eq 'cygwin' && (!exists $ENV{'CYGWIN'} || $ENV{'CYGWIN'} !~ /server/i);
    #Modified by Alexandr Ciornii, 2007-03-12

    my $class   = shift;
    my $session = shift;
    
    my $nsems = $session->{args}->{NSems} ||
        $Apache::Session::Lock::Semaphore::nsems;
    
#    die "You shouldn't set session argument SemaphoreKey to undef"
#     if exists($session->{args}->{SemaphoreKey}) && 
#        !defined ($session->{args}->{SemaphoreKey});

    my $sem_key = #exists ($session->{args}->{SemaphoreKey})?
        $session->{args}->{SemaphoreKey} || 
        $Apache::Session::Lock::Semaphore::sem_key;

    return bless {read => 0, write => 0, sem => undef, nsems => $nsems, 
        read_sem => undef, sem_key => $sem_key}, $class;
}

sub acquire_read_lock  {
    my $self    = shift;
    my $session = shift;

    return if $self->{read};
    return if $self->{write};

    if (!$self->{sem}) {    
        $self->{sem} = IPC::Semaphore->new(
            defined($self->{sem_key})?$self->{sem_key}:IPC_PRIVATE, $self->{nsems},
            IPC_CREAT | S_IRWXU) || confess("Cannot create semaphore with key $self->{sem_key}; NSEMS: $self->{nsems}: $!");
    }
    
    if (!defined $self->{read_sem}) {
        #The number of semaphores (2^2-2^4, typically) is much less than
        #the potential number of session ids (2^128, typically), we need
        #to hash the session id to choose a semaphore.  This hash routine
        #was stolen from Kernighan's The Practice of Programming.

        my $read_sem = 0;
        foreach my $el (split(//, $session->{data}->{_session_id})) {
            $read_sem = 31 * $read_sem + ord($el);
        }
        $read_sem %= ($self->{nsems}/2);
        
        $self->{read_sem} = $read_sem;
    }    
    
    #The semaphore block is divided into two halves.  The lower half
    #holds the read semaphores, and the upper half holds the write
    #semaphores.  Thus we can do atomic upgrade of a read lock to a
    #write lock.
    
    $self->{sem}->op($self->{read_sem} + $self->{nsems}/2, 0, SEM_UNDO,
                     $self->{read_sem},                    1, SEM_UNDO);
    
    $self->{read} = 1;
}

sub acquire_write_lock {    
    my $self    = shift;
    my $session = shift;

    return if($self->{write});

    if (!$self->{sem}) {
        $self->{sem} = IPC::Semaphore->new(
            defined($self->{sem_key})?$self->{sem_key}:IPC_PRIVATE, $self->{nsems},
            IPC_CREAT | S_IRWXU) || confess "Cannot create semaphore with key $self->{sem_key}; NSEMS: $self->{nsems}: $!";
    }
    
    if (!defined $self->{read_sem}) {
        #The number of semaphores (2^2-2^4, typically) is much less than
        #the potential number of session ids (2^128, typically), we need 
        #to hash the session id to choose a semaphore.  This hash routine
        #was stolen from Kernighan's The Practice of Programming.

        my $read_sem = 0;
        foreach my $el (split(//, $session->{data}->{_session_id})) {
            $read_sem = 31 * $read_sem + ord($el);
        }
        $read_sem %= ($self->{nsems}/2);
        
        $self->{read_sem} = $read_sem;
    }    
    
    $self->release_read_lock($session) if $self->{read};

    $self->{sem}->op($self->{read_sem},                    0, SEM_UNDO,
                     $self->{read_sem} + $self->{nsems}/2, 0, SEM_UNDO,
                     $self->{read_sem} + $self->{nsems}/2, 1, SEM_UNDO);
    
    $self->{write} = 1;
}

sub release_read_lock  {
    my $self    = shift;

    my $session = shift;
    
    return unless $self->{read};

    $self->{sem}->op($self->{read_sem}, -1, SEM_UNDO);
    
    $self->{read} = 0;
}

sub release_write_lock {
    my $self    = shift;
    my $session = shift;
    
    return unless $self->{write};
    
    $self->{sem}->op($self->{read_sem} + $self->{nsems}/2, -1, SEM_UNDO);

    $self->{write} = 0;
}

sub release_all_locks  {
    my $self    = shift;
    my $session = shift;

    if($self->{read}) {
        $self->release_read_lock($session);
    }
    if($self->{write}) {
        $self->release_write_lock($session);
    }
    
    $self->{read}  = 0;
    $self->{write} = 0;
}

sub hash {
    my $key   = shift;
    my $nsems = shift;
    my $hash = 0;


}

sub remove {
    my $self    = shift;
    if ($self->{sem}) {    
        $self->{sem}->remove();
    }
}

1;

