#
# persistent.pl
#
# Startup file for Velocity Engine persistent Perl mode.
# Add modules here that need to run only at persistent
# Perl startup.
#
# Revision $Revision: 1.1 $
#

use subs 'exit';
sub exit { die "\n"; }

*CORE::GLOBAL::exit = *::exit;

BEGIN {
    $ENV{GATEWAY_INTERFACE} = "CGI-Perl";
    foreach my $dir (@INC) {
       $dir =~ s/.*perl5/$ENV{VE_HOME}\/perl5/;
    }
}

# The Apache::DBI modules sets up persistent database connections
# for improved performance.  You may comment out this line if you
# are not accessing DBI based databases from your Perl code.
use Apache::DBI;

# add packages that would like to remain in memory here:
use CGI;
use CGI::VEP;
use Socket;

package Embed::Persistent;

# strict mode causes Perl to display error messages whenever
# variables are not properly scoped with the 'my' keyword.
# You can comment the below line, but the persistent Perl
# interpreter may leak memory as a result.
use strict;

# requires some globals
use vars qw(%Cache $level %global $callpkg);
$level = 0;

# save main
foreach my $key (keys %main::) {
    $global{$key} = 1;
}

# CGI-Compatible Mode
sub cgi_mode {
    my($filename, $package, $sub) = @_;
    my(%inc, $key);

    if ($level == 1) {
	# save current %INC
	if ($package eq "") {
	    foreach $key (keys %INC) {
		$inc{"$key"} = 1;
	    }
	}
    }

    my $eval;
    
    if ($sub eq "") {
        # most cases
	$eval = qq {
	    package main;
	    no strict;
	    sub handler$level {
		do "$filename"; 
	        die "\$@" if (\$@);
	    }
        };
    } else {
        # vepload called
	if ($level == 1) {
	    $eval = qq { package main; no strict; \&CGI::VEP::init(\*CGI, \*COOKIE, \*QUERY, \*FILENAMES); sub handler$level { $sub; }
	    };
	} else {
	    $eval = qq {
		package main; no strict; sub handler$level { $sub; }
	    };
	}
    }
            
    eval "$eval";
    eval qq {main::handler$level();} if (!$@);

    undef &{"main::handler$level"};

    if ($level == 1) {

	# restore INC
	if ($package eq "") {
	    foreach $key (keys %INC) {
		delete $INC{"$key"} if (substr($key,-2,2) ne "pm" && $inc{"$key"} != 1);
	    }
	}

	# restore main
        FreeGlobals("main", 1);

	if ($package ne "") {
            FreeGlobals($package, 1);
	}
    }
}

# import_funcs import export
# takes import functions and copies them to export namespace
sub import_funcs {
    my($import, $export) = @_;
    my($key, $val);
    no strict 'refs';

    while (($key,$val) = each(%{*{"$import\::"}})) {
	if ($key eq "handler") { next; }
	local(*ENTRY) = $val;
        if (defined $val && defined *ENTRY{CODE} ) {
	   *{"$export\::$key"} = *{"$import\::$key"};
	}
    }
}

# Embedded Mode
# you can choose to completely pre-compile and cache VEP
# pages by calling cached_embed_mode, or call cgi_mode to
# cache only the perl modules loaded by those VEP pages.
# The default is cgi_mode, in order to conserve memory.

sub cached_embed_mode {
    my ($filename, $package, $sub) = @_;
    my ($mtime) = -M $filename;

    if ($level == 1) {
	$callpkg = $package;
    }

    $package = "$callpkg\::$package";

    if ($sub ne "") {
	#wrap the code into a subroutine inside our unique package
	my $eval;
	if ($level == 1) {
	    $eval = qq { package $callpkg; use CGI::VEP; no strict; *vepload = *::vepload; *exit = *::exit; sub $package\::handler { \&CGI::VEP::init(\*CGI, \*COOKIE, \*QUERY, \*FILENAMES); $sub; }
            };
	} else {
	    $eval = qq{ package $callpkg; no strict; sub $package\::handler {$sub; }
	    }
	}
        eval $eval;
    }
    eval qq "$package" . "::handler();" if (!$@);
    $Cache{$package}{mtime} = $mtime if (!$@);

    if ($level == 1) {
	FreeGlobals($callpkg, 0);
	FreeGlobals("CGI::VEP", 1);
    }
}

# Persistent Mode
sub persistent_mode {
    my ($filename, $package, $sub) = @_;
    my ($mtime) = -M $filename;

    # check to see if we have already loaded this package
    if (LoadedPackage($filename, $package) == 0) {
	if ($sub eq "") {
	    local *FH;
	    if (!open(FH, $filename)) {
		return;
	    }
	    local($/) = undef;
	    $sub = <FH>;
	    close FH;
	    #$sub = $1 if ($sub =~/^(.*)$/s);    # uncomment to untaint
	}

	#wrap the code into a subroutine inside our unique package
	my $eval;
	if ($ENV{VE_PERSISTENT} == 0) {
	    $eval = qq{ package $package; no strict; *vepload = *::vepload; sub handler {$sub; }
            };
	} else {
	    $eval = qq{ package $package; *vepload = *::vepload; sub handler {$sub; }
            };
	}
        eval $eval;
    }
    eval "$package" . "::handler();" if (!$@);

    if ($level == 1) {
	if ($ENV{VE_PERSISTENT} == 0) {
	    FreeGlobals($package, 1);
	}
    }

    $Cache{$package}{mtime} = $mtime if (!$@);
}

# LoadedPackage
# returns 1 if package found in Cache
# return 0 otherwise 
sub LoadedPackage {
    my($filename, $pkg) = @_;
    my $mtime = -M $filename;
    my $package;

    if ($ENV{VE_EMBED} == 0) {
        $package = $pkg;
    } else {
        if ($level == 0) {
           $package = "$pkg\::$pkg";
        } else {
           $package = "$callpkg\::$pkg";
        }
    }

    if(defined $Cache{$package}{mtime}
	   &&
	   $Cache{$package}{mtime} <= $mtime) {
	return 1;
    } else {
	return 0;
    }
}

# FreeGlobals
# removes all scalars, arrays, hashes, file handles from package
# leaves variables starting with '__html_' and functions alone
sub FreeGlobals {
    my($pack, $flag) = @_ ;
    my($key,$val,$num,@todo,$tmp);
    {
	no strict 'refs';
	$pack =~ s/\//::/g;
	$pack =~ s/\.[^\.]*$//;
	while (($key,$val) = each(%{*{"$pack\::"}})) {
	    next if ($pack eq "main" && $global{$key} == 1);
	    next if (
		$key eq "ISA"
		|| $key eq "EXPORT"
		|| $key eq "EXPORT_OK"
		|| $key eq "EXPORT_FAIL"
		|| $key eq "EXPORT_TAGS");

	    local(*ENTRY) = $val;

	    #### SCALAR ####
	    if (defined $val && defined *ENTRY{SCALAR}) {
	        undef ${"$pack\::$key"} if ($flag || substr($key, 0, 7) ne "__html_");
	    }
	    #### ARRAY ####
	    if (defined $val && defined *ENTRY{ARRAY}) {
		undef @{"$pack\::$key"};
	    }
	    #### HASH ####
	    if (defined $val && defined *ENTRY{HASH} && $key !~ /::/) {
		undef %{"$pack\::$key"};
	    }
	    #### PACKAGE ####
#	    if (defined $val && defined *ENTRY{HASH} && $key =~ /::/) {
#		$key =~ s/:://;
#		FreeGlobals("$pack\::$key");
#	    }
	    #### FUNCTION ####
#	    if (defined $val && defined *ENTRY{CODE} ) {
#	        undef &{"$pack\::$key"} if ($flag);
#	    }
	    #### IO #### had to change after 5.003_10
	    if (defined $val && defined *ENTRY{IO}){ # fileno and telldir...
		my($file) = "$pack\::$key";
		close($file);
	    }
	}
    }
}


# DeleteExportedFunctions
# deletes all functions that have been exported by a package
# useful for reloading packages if they've changed on disk
sub DeleteExportedFunctions {
    my($pack) = @_;
    my(@functions, $key, $val);

    $pack =~ s/\//::/g;
    $pack =~ s/\.[^\.]*$//;

    no strict 'refs';

    while (($key,$val) = each(%{*{"$pack\::"}})) {
	local(*ENTRY) = $val;
	#### FUNCTION ####
	if (defined $val && defined *ENTRY{CODE}) {
	    push(@functions, "&$key");
	}
    }

    my $any_export_var;
    $any_export_var = 1 if defined @{$pack . "::EXPORT"};
    $any_export_var = 1 if defined @{$pack . "::EXPORT_OK"};
    $any_export_var = 1 if defined %{$pack . "::EXPORT_TAGS"};
    $any_export_var = 1 if defined @{$pack . "::EXPORT_EXTRAS"};

    if( $any_export_var ) {
	my @names = (@{$pack . "::EXPORT"},
                     @{$pack . "::EXPORT_OK"},
                     @{$pack . "::EXPORT_EXTRAS"});
        foreach my $tagdata (values %{$pack . "::EXPORT_TAGS"}) {
            push @names, @$tagdata;
        }
        my %exported = map { $_ => 1 } @names;
        @functions = grep( $exported{$_}, @functions );
    }

    foreach $key (@functions) {
	$key = substr($key,1);
        undef &{"$pack\::$key"};
    }
}

# ReloadModules
# go through the INC list.  Make sure latest packages are loaded
sub ReloadModules {
    my ($module, $file);
    while (($module, $file) = each %INC) {
	my $ptime = -M $file;
	if (!defined $Cache{$file}{mtime}) {
	    # first time we've loaded, get mtime
	    $Cache{$file}{mtime} = $ptime;
	} elsif (defined($ptime) && $Cache{$file}{mtime} > $ptime) {
	    # reload this package
	    delete $INC{$module};
	    &DeleteExportedFunctions($module);
	    require $module;
	    $Cache{$file}{mtime} = $ptime;
	}
    }
    return $@;
}

# Check Modules
# check INC again, add timestamp for new modules
sub CheckModules {
    my ($module, $file);

    while (($module, $file) = each %INC) {
	if (!defined $Cache{$file}{mtime}) {
	    # first time we've loaded, get mtime
	    $Cache{$file}{mtime} = -M $file;
	}
    }
}


sub eval_file {
    my($filename, $package, $sub) = @_;
   
    # is this really necessary? seems like a leak.
    undef $_[0];
    undef $_[1];
    undef $_[2];

    $| = 0;	# don't ruin performance by entering line buffering mode

    $level++;

    if ($level == 1) {
	# reset CGI.pm globals, if loaded
	$CGI::DefaultClass->_reset_globals() if (defined($CGI::DefaultClass));
        &ReloadModules;
    }

    if ($ENV{VE_EMBED} == 1) {
	if (exists($ENV{CACHE_VEP_SCRIPTS})) {
	    cached_embed_mode($filename, $package, $sub);
	} else {
	    cgi_mode($filename, $package, $sub);
	}
    } elsif ($ENV{VE_PERSISTENT} == 0) {
	if (exists($ENV{CACHE_CGI_SCRIPTS})) {
	    persistent_mode($filename, $package, $sub);
	} else {
	    cgi_mode($filename, "", $sub);
	}
    } else {
	persistent_mode($filename, $package, $sub);
    }

    if ($level == 1) {
	&CheckModules;
    }

    if ($@ && $@ ne "\n") {
		my $msg = $@;
		
		# remove the initial characters from eval errors ([date] (eval x):)
		$msg =~ s!^\[.*?\] \(.*\): !!gm;
		
		# boldface the first message only (in case it's a confess)
		$msg =~ s!^(.*?) at (.*?) line (\d+)!<b>\1</b> at \2 line \3!;
		
		# highlight the filenames and line numbers
		$msg =~ s!at (.*?) line (\d+)!<font color=red>at <font color=blue>\1</font><font color=green> line \2</font></font>!gm;
		
		$msg = qq{
			<p>
				<font face="arial,helvetica" size=3>
				<font color=darkred><b>There are errors in <font color=blue>$filename</font></b></font>
				<hr size=1 color=silver>
				<font color=darkred>
				<pre>$msg</pre>
				</font>
				</font>
			</p>
		};
		print $msg;
        die "Errors";
    }

    $@ = undef;
  
    $level--;
}

1;
