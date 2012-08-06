############################################################################
#
# Apache::Session::Lock::File
# flock(2) locking for Apache::Session
# Copyright(c) 1998, 1999, 2000, 2004 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Lock::File;

use strict;

use Fcntl qw(:flock);
use Symbol;
use vars qw($VERSION);

$VERSION = '1.04';

$Apache::Session::Lock::File::LockDirectory = '/tmp';

sub new {
    my $class = shift;
    
    return bless { read => 0, write => 0, opened => 0, id => 0 }, $class;
}

sub acquire_read_lock  {
    if ($^O eq 'MSWin32' or $^O eq 'cygwin') {
        #Windows cannot escalate lock, so all locks will be exclusive
        return &acquire_write_lock;
    }
    #Works for acquire_read_lock => acquire_write_lock => release_all_locks
    #This hack does not support release_read_lock
    #Changed by Alexandr Ciornii, 2006-06-21

    my $self    = shift;
    my $session = shift;
    
    return if $self->{read};
    #does not support release_read_lock

    if (!$self->{opened}) {
        my $fh = Symbol::gensym();
        
        my $LockDirectory = $session->{args}->{LockDirectory} || 
            $Apache::Session::Lock::File::LockDirectory;
            
        open($fh, "+>".$LockDirectory."/Apache-Session-".$session->{data}->{_session_id}.".lock") || die "Could not open file (".$LockDirectory."/Apache-Session-".$session->{data}->{_session_id}.".lock) for writing: $!";

        $self->{fh} = $fh;
        $self->{opened} = 1;
    }
        
    if (!$self->{write}) {
     #acquiring read lock, when write lock is in effect will clear write lock
     flock($self->{fh}, LOCK_SH) || die "Cannot lock: $!";
    }

    $self->{read} = 1;
}

sub acquire_write_lock {
    my $self    = shift;
    my $session = shift;

    return if $self->{write};
    
    if (!$self->{opened}) {
        my $fh = Symbol::gensym();
        
        my $LockDirectory = $session->{args}->{LockDirectory} || 
            $Apache::Session::Lock::File::LockDirectory;
            
        open($fh, "+>".$LockDirectory."/Apache-Session-".$session->{data}->{_session_id}.".lock") || die "Could not open file (".$LockDirectory."/Apache-Session-".$session->{data}->{_session_id}.".lock) for writing: $!";

        $self->{fh} = $fh;
        $self->{opened} = 1;
    }
    
    flock($self->{fh}, LOCK_EX) || die "Cannot lock: $!";
    $self->{write} = 1;
}

sub release_read_lock  {
    if ($^O eq 'MSWin32' or $^O eq 'cygwin') {
        die "release_read_lock is not supported on Win32 or Cygwin";
    }
    my $self    = shift;
    my $session = shift;
    
    die "No read lock to release in release_read_lock" unless $self->{read};
    
    if (!$self->{write}) {
        flock($self->{fh}, LOCK_UN) || die "Cannot unlock: $!";
        close $self->{fh} || die "Could no close file: $!";
        $self->{opened} = 0;
    }
    
    $self->{read} = 0;
}

sub release_write_lock {
    my $self    = shift;
    my $session = shift;
    
    die "No write lock acquired" unless $self->{write};
    
    if ($self->{read}) {
        flock($self->{fh}, LOCK_SH) || die "Cannot lock: $!";
    }
    else {
        flock($self->{fh}, LOCK_UN) || die "Cannot unlock: $!";
        close $self->{fh} || die "Could not close file: $!";
        $self->{opened} = 0;
    }
    
    $self->{write} = 0;
}

sub release_all_locks  {
    my $self    = shift;
    my $session = shift;

    if ($self->{opened}) {
        flock($self->{fh}, LOCK_UN) || die "Cannot unlock: $!";
        close $self->{fh} || die "Could not close file: $!";
    }
    
    $self->{opened} = 0;
    $self->{read}   = 0;
    $self->{write}  = 0;
}

sub DESTROY {
    my $self = shift;
    
    $self->release_all_locks;
}

sub clean {
    my $self = shift;
    my $dir  = shift;
    my $time = shift;

    my $now = time();
    
    opendir(DIR, $dir) || die "Could not open directory $dir: $!";
    my @files = readdir(DIR);
    foreach my $file (@files) {
        if ($file =~ /^Apache-Session.*\.lock$/) {
            if ($now - (stat($dir.'/'.$file))[8] >= $time) {
              if ($^O eq 'MSWin32') {
                #Windows cannot unlink open file
                unlink($dir.'/'.$file) || next;
              } else {
                open(FH, "+>$dir/".$file) || next;
                flock(FH, LOCK_EX) || next;
                unlink($dir.'/'.$file) || next;
                flock(FH, LOCK_UN);
                close(FH);
              }
            }
        }
    }
    closedir(DIR);
}

1;

