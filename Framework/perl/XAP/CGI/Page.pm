##############################################################################
package XAP::CGI::Page;
##############################################################################

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use XAP::Component;
use XAP::Component::Controller;
use Security::AccessControl;
use Set::IntSpan;

use vars qw(@ISA $VERSION %ENV $AUTOLOAD);

@ISA = qw(CGI);
$VERSION = '1.0';

use constant SESSIONSTATUS_TIMEOUT => -1;
use constant SESSIONSTATUS_NONE    =>  0;
use constant SESSIONSTATUS_ACTIVE  =>  1;
use constant SESSIONSTATUS_LOGIN   =>  2;
use constant SESSIONSTATUS_ERROR   =>  3;

use enum qw(BITMASK:CGIPAGEFLAG_ HAVEERRORS HAVEDEBUGSTMTS ISREDIRECT ADDCOOKIES HAVEVIRTUALCHILDPATH);
use enum qw(BITMASK:CGIPAGEDEBUGFLAG_ SHOWCOMPONENTS SHOWSESSION SHOWURLPARAMS SHOWFIELDS SHOWSQL SHOWENVIRONMENT SHOWRELOAD);

use constant CGIPAGEFLAGS_DEFAULT => 0;
use constant CGIPAGEDEBUGFLAGS_DEFAULT => 0;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new();  # <-- NOTE: not passing anything into CGI::new on purpose
	my %params = @_;

	$self->{page_errors} = [];
	$self->{page_debug} = [];
	$self->{page_paramErrors} = [];
	$self->{page_cookies} = [];
	$self->{page_validationErrorsList} = [];
	$self->{page_validationErrorsMap} = {};
	$self->{page_controller} = exists $params{controller} ? $params{controller} : undef; # should be a XAP::Component::Controller object
	$self->{page_flags} = exists $params{flags} ? $params{flags} : CGIPAGEFLAGS_DEFAULT;
	$self->{page_session} = undef;
	$self->{page_redirect} = undef;
	$self->{page_components} = [];
	$self->{page_debug_flags} = CGIPAGEDEBUGFLAGS_DEFAULT;

	# do session management stuff
	$self->{sess_status} = SESSIONSTATUS_NONE;
	$self->{sess_errorCode} = 0;
	$self->{sess_errorMsg} = '';
	$self->{sess_permissions} = undef;

	# make sure this is the last statement (in lieu of a return statement)
    $self;
}

# get or set an arbitrary "global page property"
sub property
{
	my $self = shift;

	$self->{$_[0]} = $_[1] if defined $_[1];
	return $self->{$_[0]};
}

# --- flag-management functions ----------------------------------------------
#
#   $self->updateFlag($mask, $onOff) -- either turn on or turn off $mask
#   $self->setFlag($mask) -- turn on $mask
#   $self->clearFlag($mask) -- turn off $mask
#   $self->flagIsSet($mask) -- return true if any $mask are set

sub flagsAsStr
{
	my $str = unpack("B32", pack("N", $_[0]->{page_flags}));
	$str =~ s/^0+(?=\d)// if $_[1]; # otherwise you'll get leading zeros
	return $str;
}

sub updateFlag
{
	if($_[2])
	{
		$_[0]->{page_flags} |= $_[1];
	}
	else
	{
		$_[0]->{page_flags} &= ~$_[1];
	}
}

sub setFlag
{
	$_[0]->{page_flags} |= $_[1];
}

sub clearFlag
{
	$_[0]->{page_flags} &= ~$_[1];
}

sub flagIsSet
{
	return $_[0]->{page_flags} & $_[1];
}

sub getFlags
{
	return $_[0]->{page_flags};
}

sub isPopup
{
	return 0;
}

#-----------------------------------------------------------------------------
# UTILITY ROUTINES FOR CGI::VALIDATOR and CGI::DIALOG FIELD/ERROR MANAGEMENT
#-----------------------------------------------------------------------------

sub URL
{
	CGI::param(@_);
}

#
# * fieldPName is the real name that a validated field is stored in param as
# * field is just like CGI::param except it mangles the name first
#
sub fieldPName
{
	return "_f_$_[1]";
}

sub field
{
	my ($self, $suffix) = (shift, shift);
	if(wantarray())
	{
		my @array = $self->param("_f_$suffix", @_);
		return @array;
	}
	return $self->param("_f_$suffix", @_);
}

sub fields
{
	my $self = shift;
	if(ref $_[0] eq 'HASH')
	{
		my $fieldData = $_[0];
		foreach (keys %{$fieldData})
		{
			$self->param("_f_$_", $fieldData->{$_});
		}
	}
	else
	{
		my @fieldValues = ();
		foreach (@_)
		{
			push(@fieldValues, $self->field($_));
		}
		return @fieldValues;
	}
}

sub paramValidationError
{
	my ($self, $param) = (shift, shift);

	push(@{$self->{page_validationErrorsList}}, @_);
	push(@{$self->{page_validationErrorsMap}->{$param}}, @_);
}

sub validationMessages
{
	my ($self, $param) = @_;
	if($param)
	{
		my $errorMap = $self->{page_validationErrorsMap};
		return exists $errorMap->{$param} ?
			@{$errorMap->{$param}} :
			();
	}
	else
	{
		return @{$self->{page_validationErrorsList}};
	}
}

sub haveValidationErrors
{
	return scalar(@{$_[0]->{page_validationErrorsList}}) > 0 ? 1 : 0;
}

#-----------------------------------------------------------------------------
# URL PARAMS/HIDDEN FORM FIELDS MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub setVirtualChildPath
{
	my $self = shift;
	my @children = @_;

	return unless @children;

	$self->{page_flags} |= CGIPAGEFLAG_HAVEVIRTUALCHILDPATH;
	$self->{page_virtChildPathItemsCount} = scalar(@children);
	$self->{page_virtChildPathItems} = \@children;
}

sub getActiveURL
{
	my ($self, $flags) = @_;
	return $self->{mainComponent}->getURL($self);
}

#
# get current URL parameters and allow replacements
#
sub getParamsForUrl
{
	my $self = shift;
	my %replaceParams = @_;
	my %cgiParams = ();

    my ($param, @value, $var);
    my $pNum = 0;
    foreach $param ($self->param)
	{
		# don't put session variables or dialog field values in the self reference
		next if $param =~ m/^_f_/ || $param =~ m/^page_/;  # don't put field or page variables in the URL
		next if exists $replaceParams{$param};

		$pNum++;
		#$cgiParams{$param} = "$param=" . $self->escape($self->param($param));
		@value = $self->param($param);
		foreach (@value)
		{
			$cgiParams{$param} = "$param=" . $self->escape($_);
		#	push(@cgiParams, "$param=" . $self->escape($_));
		}
    }

	my @cgiParams = values %cgiParams;

    foreach (sort keys %replaceParams)
    {
		push(@cgiParams, "$_=" . $self->escape($replaceParams{$_})) if defined $replaceParams{$_};
	}

	join('&', @cgiParams);
}

sub selfRef
{
	# return a url with reference to self + all CGI params - session params
	my $self = shift;
	$self->url() . '?' . $self->getParamsForUrl(@_);
}

sub selfHiddenFormFields
{
	my $self = shift;
	my %replaceParams = @_;
	my @hiddens = ();

    my ($param, @value, $var);
    my $pNum = 0;
    foreach $param ($self->param)
	{
		# don't put session or form field variables in the self reference
		next if $param =~ m/^_f_/;
		next if exists $replaceParams{$param};

		$pNum++;
		@value = $self->param($param);
		foreach (@value)
		{
			push(@hiddens, qq{<INPUT TYPE="HIDDEN" NAME="$param" VALUE="$_">});
		}
    }

    foreach (sort keys %replaceParams)
    {
		push(@hiddens, qq{<INPUT TYPE="HIDDEN" NAME="$_" VALUE="$replaceParams{$_}">}) if defined $replaceParams{$_};
	}

	join("\n", @hiddens);
}

#-----------------------------------------------------------------------------
# PAGE CONTENT MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub addError
{
	my $self = shift;
	$self->{page_flags} |= CGIPAGEFLAG_HAVEERRORS;
	push(@{$self->{page_errors}}, @_);
}

sub addComponent
{
	my $self = shift;
	my XAP::Component $component = shift;
	
	push(@{$self->{page_components}}, $component);
}

sub haveErrors
{
	return shift->{page_flags} & CGIPAGEFLAG_HAVEERRORS;
}

sub addCookie
{
	my $self = shift;
	$self->{page_flags} |= CGIPAGEFLAG_ADDCOOKIES;
	push(@{$self->{page_cookies}}, $self->cookie(@_));
}

sub redirect
{
	my ($self, $redirect, $acceptDup) = @_;

	if(my $curRedirect = $self->{page_redirect})
	{
		unless(($curRedirect eq $redirect) || (defined $acceptDup && ($acceptDup == 1)))
		{
			my ($package, $filename, $line, $subroutine) = caller();
		    $self->addError(qq{
				Duplicate call to CGI::Page::redirect detected in $filename line $line.
				Current value is '$curRedirect', new value is '$redirect'.
				Pass \$acceptDup == 1 to accept	the duplicate.
			});
			return '';
		}
	}

	$self->{page_redirect} = $redirect;
	$self->{page_flags} |= CGIPAGEFLAG_ISREDIRECT;
	return '';
}

sub getHttpHeader
{
	my $self = shift;

	#if($self->{page_redirect})
	#{
	#	$self->addDebugStmt("Redirect Before: $self->{page_redirect}");
	#	$self->addDebugStmt("Redirect After: " . $self->replaceRedirectVars($self->{page_redirect}));
	#}

	my $pageFlags = $self->{page_flags};
	my %HEADER = (-expires => '-1d');
	$HEADER{-cookie} = $self->{page_cookies} if $pageFlags & CGIPAGEFLAG_ADDCOOKIES;

	if(($pageFlags & CGIPAGEFLAG_ISREDIRECT) && ! ($pageFlags & CGIPAGEFLAG_HAVEERRORS))
	{
		return $self->header(%HEADER, -location => $self->{page_redirect});
	}

	my XAP::Component $component = $self->{mainComponent};
	my $html = $self->header(%HEADER);
	
	$html .= '<ol><b>Page Errors</b><hr size="1" color="red"><code><li>' . join('<li>', @{$self->{page_errors}}) . '</code></ol>' if $pageFlags & CGIPAGEFLAG_HAVEERRORS;
	$html .= '<ol><b>Component Errors</b><hr size="1" color="red"><code><li>' . join('<li>', @{$component->{errors}}) . '</code></ol>' if $component && $component->{errors};
	$html .= '<ol><b>Component Warnings</b><hr size="1" color="silver"><code><li>' . join('<li>', @{$component->{warnings}}) . '</code></ol>' if $component && $component->{warnings};
	$html .= '<ol><b>Debug Statements</b><hr size="1" color="silver"><code><li>' . join('<li>', @{$self->{page_debug}}) . '</code></ol>' if $pageFlags & CGIPAGEFLAG_HAVEDEBUGSTMTS;

	return $html;
}

#-----------------------------------------------------------------------------
# DEBUGGING ROUTINES
#-----------------------------------------------------------------------------

use constant PARAMNAME_DEBUGFLAGS => '_debug';

sub setDebugFlags
{
	my ($self, $flags) = @_;
	
	$self->{page_session}->{debugFlags} = $flags if $self->{page_session};
	return $self->{page_debug_flags} = $flags;
}

sub debugShowComponents
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 'c') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWCOMPONENTS);
}

sub debugShowSession
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 's') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWSESSION);
}

sub debugShowURLParams
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 'u') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWURLPARAMS);
}

sub debugShowSQL
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 'q') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWSQL);
}

sub debugShowEnvironment
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 'e') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWENVIRONMENT);
}

sub debugShowReload
{
	my $self = shift;
	return (index($self->param(PARAMNAME_DEBUGFLAGS), 'r') >= 0) || ($self->{page_debug_flags} & CGIPAGEDEBUGFLAG_SHOWRELOAD);
}

sub addDebugStmt
{
	my $self = shift;
	$self->{page_flags} |= CGIPAGEFLAG_HAVEDEBUGSTMTS;
	push(@{$self->{page_debug}}, @_);
}

sub dumpParams
{
	my ($self, $withEnvironment) = @_;
	$withEnvironment = 0 if ! defined $withEnvironment;

	$self->addDebugStmt("<h3>CGI Parameters</h3>");
	foreach (sort $self->param())
	{
		my @vals = $self->param($_);
		$self->addDebugStmt("$_: <b>" . join(', ', @vals) . "</b>");
	}

	if($withEnvironment)
	{
		$self->addDebugStmt("<h3>Environment Variables</h3>");
		foreach (sort keys %ENV)
		{
			$self->addDebugStmt("$_: <b>".$ENV{$_}."</b>");
		}
	}
}

sub dumpSession
{
	my ($self) = @_;

	$self->addDebugStmt("<h3>Session variables</h3>");
	foreach (sort keys %{$self->{page_session}})
	{
		my @vals = $self->session($_);
		$self->addDebugStmt("$_: <b>" . join(', ', @vals) . "</b>");
	}
}

sub dumpCookies
{
	my ($self) = @_;

	$self->addDebugStmt("<h3>Cookies</h3>");
	foreach (sort $self->cookie())
	{
		$self->addDebugStmt("$_: <b>".$self->cookie($_)."</b>");
	}
}

#-----------------------------------------------------------------------------
# SESSION MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

#
# the session method adds/updates session variables
# it is used just like the param and field methods
#
sub session
{
	my ($self, $key, $value) = @_;
	my ($pkg, $file, $line) = caller(1);
	$self->{page_session}->{$key} = $value if defined $value;
	return $self->{page_session}->{$key};
}

sub sessionStatus
{
	my $self = shift;
	$self->{sess_status} = $_[0] if defined $_[0];
	return $self->{sess_status};
}

sub setupACL
{
	my $self = shift;
	my ($dbh, $session) = ($self->{db}, $self->{page_session});

    # TODO: Update this select once the PERSON_ORG_CATEGORY table is removed.
    my $getRolesSth = $dbh->prepare(qq{
                select role_name
                from role_name, person_org_role
                where person_id = :1 and org_internal_id = :2 and
                role_name.role_name_id = person_org_role.role_name_id
                UNION
				select category as role_name from person_org_category
				where person_id = :1 and org_internal_id = :2
                });
	my $roles = ($session->{aclRoleNames} = []);
	#$getRolesSth->execute($session->{user_id}, $session->{org_internal_id}, $session->{user_id}, $session->{org_internal_id});
	$getRolesSth->execute($session->{user_id}, $session->{org_internal_id});
	while(my $row = $getRolesSth->fetch())
	{
		push(@$roles, $row->[0]);
	}
	$getRolesSth->finish();

    my $permissions = new Set::IntSpan;

	my $permIds = $self->getACL()->{permissionIds};
    my $getPermsSth = $dbh->prepare(qq{
                select rp.role_activity_id, rp.permission_name
				from person_org_role por, role_permission rp
				where rp.role_activity_id = ? and por.person_id = ? and por.org_internal_id = ? and
                por.role_name_id = rp.role_name_id and por.org_internal_id = rp.org_internal_id
                });
    for my $activity (0, 1)
    {
		$getPermsSth->execute($activity, $session->{user_id}, $session->{org_internal_id});
		while(my $row = $getPermsSth->fetch())
		{
			if(my $permInfo = $permIds->{$row->[1]})
			{
				# if activity type is 0 or null, we're granting otherwise we're revoking
				$permissions = $row->[0] ?
					$permissions->diff($permInfo->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]) :
					$permissions->union($permInfo->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]);
			};
		}
		$getPermsSth->finish();
	}
	$session->{aclPermissions} = $permissions;
}

#-----------------------------------------------------------------------------
# ACL/PERMISSION MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

#
# return TRUE if the current user has any one of the permissions passed in
# (pass in as many permissions as needed)
#
sub hasPermission
{
	my $self = shift;
	return 0 unless $self->{sess_permissions};

	my $disableSecurity = 0;

	if (defined ($ENV{HS_NOSECURITY}))
	{
		if ( ($ENV{HS_NOSECURITY} ? 1 : 0) )
		{
			$disableSecurity = 1;
		}
	}

	if ($disableSecurity)
	{
		#$self->addContent('<h2><blink>Role-based permissions have been disabled.</blink></h2>');
		return 1;
	}

	my $permIds = $self->getACL()->{permissionIds};
	foreach (@_)
	{
		if(my $permInfo = $permIds->{$_})
		{
			return 1 if $self->{sess_permissions}->member($permInfo->[Security::AccessControl::PERMISSIONINFOIDX_LISTINDEX]);
		}
	}

	return 0;
}

#-----------------------------------------------------------------------------
# accessor methods for current controller object
#-----------------------------------------------------------------------------

sub getDate { shift->{page_controller}->getDate(@_); }
sub getTimeStamp { shift->{page_controller}->getTimeStamp(@_); }
sub defaultUnixDateFormat { shift->{page_controller}->defaultUnixDateFormat(@_); }
sub defaultUnixStampFormat { shift->{page_controller}->defaultUnixStampFormat(@_); }

sub executeSql { shift->{page_controller}->executeSql(@_); }
sub beginUnitWork { shift->{page_controller}->beginUnitWork(@_); }
sub endUnitWork { shift->{page_controller}->endUnitWork(@_); }
sub unitWork { shift->{page_controller}->unitWork(@_); }
sub storeSql { shift->{page_controller}->storeSql(@_); }

sub getSchema { shift->{page_controller}->getSchema(@_); }
sub getDbh { shift->{page_controller}->getDbh(@_); }
sub loadSchema { shift->{page_controller}->loadSchema(@_); }
sub schemaAction { shift->{page_controller}->schemaAction(@_); }
sub schemaGetSingleRec { shift->{page_controller}->schemaGetSingleRec(@_); }
sub schemaRecExists { shift->{page_controller}->schemaRecExists(@_); }

sub getSqlLog { shift->{page_controller}->getSqlLog(@_); }
sub clearSqlLog { shift->{page_controller}->clearSqlLog(@_); }

sub getACL { shift->{page_controller}->getACL(@_); }

1;
