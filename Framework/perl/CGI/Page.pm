##############################################################################
package CGI::Page;
##############################################################################

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session::DBI;
use File::Spec;
use Date::Manip;
use Schema::API;
use App::Configuration;
use Security::AccessControl;
use Set::IntSpan;

use vars qw(@ISA $VERSION %ENV);

@ISA = qw(CGI);
$VERSION = '1.1';

use constant SESSION_TIMEOUT_SECS       => 1800;

use constant SESSIONTYPE_TIMEOUT        => -1;
use constant SESSIONTYPE_NOTSECURE      =>  0;
use constant SESSIONTYPE_SECURE         =>  1;
use constant SESSIONTYPE_SIMULATESECURE =>  2;
use constant SESSIONTYPE_SESSIONERROR   =>  3;

use constant SESSIONID_COOKIENAME       => 'SESSION_ID_0001';
use constant SESSIONID_FIELDNAME        => '_session_id';

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new();  # <-- NOTE: not passing anything into CGI::new on purpose
	my %params = @_;

	$self->{page_errors} = [];
	$self->{page_debug} = [];
	$self->{page_paramErrors} = [];
	$self->{page_head} = [];
	$self->{page_content} = [];
	$self->{page_cookies} = [];
	$self->{page_printed} = 0;
	$self->{page_validationErrorsList} = [];
	$self->{page_validationErrorsMap} = {};

	# load database stuff
	$self->{dbConnectKey} = $params{dbConnectKey} || $CONFDATA_SERVER->db_ConnectKey;
	$self->{schemaSQLPath} = $params{schemaSQLPath} || $CONFDATA_SERVER->path_SchemaSQL;
	$self->{schemaFile} = $params{schemaFile} || $CONFDATA_SERVER->file_SchemaDefn;
	$self->{schema} = undef;
	$self->{db} = undef;
	$self->{schemaFlags} = DEFAULT_SCHEMAAPIFLAGS;
	$self->loadSchema();

	#Unit Of Work variables
	$self->{sqlUnitWork} = undef;
	$self->{valUnitWork} = undef;
	$self->{sqlMsg} = undef;
	$self->{sqlDump} = undef;
	$self->{errUnitWork} = [];
	$self->{cntUnitWork} = 0;

	# setup default formats, can be overriden for each organization
	$self->{defaultUnixDateFormat} = '%m/%d/%Y';
	$self->{defaultUnixStampFormat} = '%m/%d/%Y %I:%M %p';
	$self->{defaultSQLDateFormat} = 'MM/DD/YYYY';
	$self->{defaultSQLStampFormat} = 'MM/DD/YYYY HH12:MI AM';

	# do session management stuff
	$self->{sessStatus} = SESSIONTYPE_NOTSECURE;
	$self->{sessTimeoutSecs} = exists $params{sessTimeoutSecs} ? $params{sessTimeoutSecs} : SESSION_TIMEOUT_SECS;
	$self->{sessErrorCode} = 0;
	$self->{sessErrorMsg} = '';

	# setup access-control
	$self->{aclFile} = $params{aclFile} || $CONFDATA_SERVER->file_AccessControlDefn;
	$self->{acl} = new Security::AccessControl(xmlFile => $self->{aclFile});
	$self->{permissions} = new Set::IntSpan;

	$self->{flags} = exists $params{flags} ? $params{flags} : 0;

	# make sure this is the last statement (in lieu of a return statement)
    $self;
}

sub abort
{
	# this doesn't work yet, but need to find a way to make it work
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
	my $str = unpack("B32", pack("N", $_[0]->{flags}));
	$str =~ s/^0+(?=\d)// if $_[1]; # otherwise you'll get leading zeros
	return $str;
}

sub updateFlag
{
	if($_[2])
	{
		$_[0]->{flags} |= $_[1];
	}
	else
	{
		$_[0]->{flags} &= ~$_[1];
	}
}

sub setFlag
{
	$_[0]->{flags} |= $_[1];
}

sub clearFlag
{
	$_[0]->{flags} &= ~$_[1];
}

sub flagIsSet
{
	return $_[0]->{flags} & $_[1];
}

sub getFlags
{
	return $_[0]->{flags};
}

#-----------------------------------------------------------------------------
# UTILITY ROUTINES FOR CGI::VALIDATOR and CGI::DIALOG FIELD/ERROR MANAGEMENT
#-----------------------------------------------------------------------------

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
		next if $param =~ m/^_f_/ || $param =~ m/^arl_/;  # don't put field or ARL variables in the URL
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

sub addHead
{
	my $self = shift;
	push(@{$self->{page_head}}, @_);
}

sub addContent
{
	my $self = shift;
	push(@{$self->{page_content}}, @_);
}

sub addError
{
	my $self = shift;
	push(@{$self->{page_errors}}, @_);
}

sub haveErrors
{
	return scalar(@{shift->{page_errors}});
}

sub addCookie
{
	my $self = shift;
	push(@{$self->{page_cookies}}, $self->cookie(@_));
}

sub addCookies
{
	my $self = shift;
	push(@{$self->{page_cookies}}, @_);
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
	return '';
}

sub replaceRedirectVars
{
	my ($self, $src) = @_;

	#
	# do replacements for %session.xxx%, %param.xxx% or %field.xxx% or
	# any other page method that returns a single value
	#
	$src =~ s/\%(\w+)\.?([\w\-\.]*)\%/
		if(my $method = $self->can($1))
		{
			&$method($self, $2);
		}
		else
		{
			"method '$1' not found in $self";
		}
		/ge;
	return $src;
}


# replaceVars - does replacements for #pageMethod.argument# style templates
#
# This includes #session.xxx#, #param.xxx# #property.xxx# #field.xxx# and
# any other page method that returns a single value and takes 0 or 1 parameter
#
# NOTE: FOR PERFORMANCE, A COPY OF THIS SUBSTITION ALSO EXISTS IN DBI::StatementManager
#       SO, IF YOU UPDATE THE REGEXP, DO IT THERE, TOO!
#
# It can be called with a reference to a scalar string or a scalar string.  It will return
# the string in the same type it was called with.  It is preferred to call using
# scalar references for performance and memory
sub replaceVars
{
	my ($self, $src) = @_;
	my $data = ref($src) ? $src : \$src;
	my $count = 1;
	while($count)
	{
		$count = ($$data =~ s/\#(\w+)\.?([\w\-\.]*)\#/
			if(my $method = $self->can($1))
			{
				&$method($self, $2);
			}
			else
			{
				"method '$1' not found in $self";
			}
			/ge);
	}
	return ref($src) ? $data : $$data;
}

sub send_http_header
{
	my $self = shift;

	#if($self->{page_redirect})
	#{
	#	$self->addDebugStmt("Redirect Before: $self->{page_redirect}");
	#	$self->addDebugStmt("Redirect After: " . $self->replaceRedirectVars($self->{page_redirect}));
	#}

	my %HEADER = (-expires => '-1d');
	$HEADER{-cookie} = $self->{page_cookies} if scalar(@{$self->{page_cookies}});

	if(exists $self->{page_redirect} && ! $self->haveErrors() && !($self->{schemaFlags} & SCHEMAAPIFLAG_LOGSQL))
	{
		print $self->header(%HEADER, -location => $self->replaceRedirectVars($self->{page_redirect}));
		return 0;
	}

	print $self->header(%HEADER);
	return 1;
}

sub printContents
{
	my $self = shift;
	$self->send_http_header();
	print @{$self->{page_head}};
	print @{$self->{page_content}};
}

#-----------------------------------------------------------------------------
# DEBUGGING ROUTINES
#-----------------------------------------------------------------------------

sub addDebugStmt
{
	my $self = shift;
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
	foreach (sort keys %{$self->{session}})
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
# DATE/TIME MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub getDate
{
	my $self = shift;
	my $parse = shift || 'today';

	return UnixDate($parse, $self->{defaultUnixDateFormat});
}

sub getTimeStamp
{
	my $self = shift;
	my $parse = shift || 'now';

	return UnixDate($parse, $self->{defaultUnixStampFormat});
}

sub defaultUnixDateFormat
{
	return $_[0]->{defaultUnixDateFormat};
}

sub defaultUnixStampFormat
{
	return $_[0]->{defaultUnixStampFormat};
}

#-----------------------------------------------------------------------------
# DATABASE MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub getSchema {	$_[0]->{schema}; }

sub executeSql
{
	my ($self, $stmhdl) = @_;
	my $rc;
	eval
	{
		$rc = $stmhdl->execute(@{$self->{valUnitWork}});
	};
	if($@||!$rc)
	{
		$self->addError($self->{sqlMsg}) if $self->{sqlMsg} ;
		$self->addError(join ("<br>",$@,$self->{db}->errstr));
		$self->addError($self->{sqlDump});
		$@ = undef;
		return 0;
	}
	return $rc;
}

sub beginUnitWork
{
	my $self = shift;
	my $msg = shift;
	$self->{sqlMsg} = $msg  ? $msg : undef;
	$self->{sqlUnitWork}='BEGIN ';
	$self->{cntUnitWork}=0;
	$self->{errUnitWork}=[];
	$self->{valUnitWork}=undef;
	$self->{sqlDump}=undef;
	$self->{schemaFlags}|= SCHEMAAPIFLAG_UNITSQL;
	$self->{schemaFlags}&=~SCHEMAAPIFLAG_EXECSQL;
	return 1;
}

sub endUnitWork
{
	my $self = shift;
	$self->{sqlUnitWork}.= "END;  ";
	my $stmhdl = $self->prepareSql($self->{sqlUnitWork});
	$self->{schemaFlags}&= ~SCHEMAAPIFLAG_UNITSQL;
	$self->{sqlUnitWork}=undef;
	if (scalar(@{$self->{errUnitWork}}))
	{
		$self->addError($self->{sqlMsg}) if $self->{sqlMsg} ;
		$self->addError(join ("<br>",@{$self->{errUnitWork}}));
		return 0;
	}
	return $self->executeSql($stmhdl);
}


sub unitWork
{
	my $self = shift;
	return $self->{schemaFlags} & SCHEMAAPIFLAG_UNITSQL;
}

sub storeSql
{
	my ($self, $sql,$vals,$errors) = @_;
	my $out_vals = join ",",@{$vals};
	$self->{cntUnitWork}++;
	if(scalar(@{$errors}) > 0)
	{

		push(@{$self->{errUnitWork}},"<b> Unit Of Work Query $self->{cntUnitWork} error :</b> @{$errors} <br> $sql $out_vals");
	}
	$self->{sqlUnitWork}.= $sql . ";\n";
	$self->{sqlDump}.= "<b> Line $self->{cntUnitWork} </b>" . $sql .  "<BR> <font color=red>$out_vals</font> <BR>" ;
	push(@{$self->{valUnitWork}},@{$vals});
}

sub loadSchema
{
	my $self = shift;

	if($self->{schemaFile})
	{
		$self->{schema} = new Schema::API(xmlFile => $self->{schemaFile});
		$self->{schema}->connectDB($self->{dbConnectKey}) if $self->{dbConnectKey};
		$self->{db} = $self->{schema}->{dbh};
	}
}

sub schemaAction
{
	my $self = shift;
	return $self->{schema}->schemaAction($self, @_);
}


sub schemaGetSingleRec
{
	my ($self, $table, $destination, %data) = @_;

	if(my $table = $self->{schema}->getTable($table))
	{
		return $table->getSingleRec($self, \%data, $destination);
	}
	else
	{
		$self->addError("table $table not found in schemaGetSingleRec");
		return 0;
	}
}

sub schemaRecExists
{
	my ($self, $table, %data) = @_;
	if(my $table = $self->{schema}->getTable($table))
	{
		return $table->existsRec($self, \%data);
	}
	else
	{
		$self->addError("table $table not found in schemaRecExists");
		return 0;
	}
}

sub defaultSqlDateFormat
{
	return $_[0]->{defaultSQLDateFormat};
}

sub defaultSqlStampFormat
{
	return $_[0]->{defaultSQLStampFormat};
}

sub prepareSql
{
	my $self = shift;
	return $self->{db}->prepare(@_);
}

sub getSqlLog
{
	return $_[0]->{sqlLog};
}

sub clearSqlLog
{
	my $self = shift;
	$self->{sqlLog} = [];
	return $self->{sqlLog};
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
	$self->{session}->{$key} = $value if defined $value;
	return $self->{session}->{$key};
}

sub isSecure
{
	return ($_[0]->{sessStatus} == SESSIONTYPE_SECURE || $_[0]->{sessStatus} == SESSIONTYPE_SIMULATESECURE) ? 1 : 0;
}

sub sessionStatus
{
	my $self = shift;
	$self->{sessStatus} = $_[0] if defined $_[0];
	return $self->{sessStatus};
}

sub createSession
{
	my ($self, $userId, $orgIntId, $sessionVars) = @_;
	my %session;
	tie %session, 'CGI::Session::DBI', undef,
		{
			dbh => $self->{db},
			status => 0,
			person_id => $userId,
			org_internal_id => $orgIntId,
			remote_host => $self->remote_host(),
			remote_addr => $self->remote_addr(),
		};
	$self->{session} = \%session;
	$session{user_id} = $userId;
	$session{org_internal_id} = $orgIntId;
	$session{active_date} = UnixDate('today', '%m/%d/%Y');

	if(ref $sessionVars eq 'HASH')
	{
		foreach my $key (keys %$sessionVars)
		{
			$session{$key} = $sessionVars->{$key};
		}
	}

	$self->addCookie(-name => SESSIONID_COOKIENAME, -value => $self->{session}->{_session_id});
	return $self->{session}->{_session_id};
}

sub setupACL
{
	my $self = shift;
	my ($dbh, $session) = ($self->{db}, $self->{session});

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

	my $defaultPermissions = new Set::IntSpan;
	my $permIds = $self->{acl}->{permissionIds};
	#
	# see if there are default permissions assigned to a role in the XML file(s)
	#
	foreach(@$roles)
	{
		if(my $groupInfo = $permIds->{"group/$_"})
		{
			$defaultPermissions = $defaultPermissions->union($groupInfo->[Security::AccessControl::PERMISSIONINFOIDX_CHILDPERMISSIONS]);
		}
	}

    my $permissions = $defaultPermissions;
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

sub establishSession
{
	my $self = shift;

	#
	# see if we have an existing session
	#
	if(my $sessionKey = $self->cookie(SESSIONID_COOKIENAME))
	{
		eval
		{
			my %session;
			tie %session, 'CGI::Session::DBI', $sessionKey,
				{
					dbh => $self->{db},
					remote_addr => $self->remote_addr(),
					errorCode_ref => \$self->{sessErrorCode},
					errorMsg_ref => \$self->{sessErrorMsg},
					timeOutSeconds => $self->{sessTimeoutSecs},
				};
			$self->{session} = \%session;
			$self->setupACL() unless exists $session{aclPermissions};
			$self->{permissions} = $session{aclPermissions};
		};
		if($@)
		{
			# using errorCode_ref and errorMsg_ref, CGI::Session::DBI will fill the messages appropriately
			#$self->{sessError} = $@;
			#$self->addError('Session Error: ' . $@);
			$@ = undef;
			return $self->sessionStatus(SESSIONTYPE_SESSIONERROR);
		}
		else
		{
			# if we're being requested to logout, then don't be "secure"
			if($self->param('_logout'))
			{
				$self->addCookie(-name => SESSIONID_COOKIENAME, -value => '', -expires => '-1d');
				$self->{session}->{_LOGOUT} = 1;
				return $self->sessionStatus(SESSIONTYPE_NOTSECURE);
			}

			# see if we want to modify some per-session attributes
			if(defined $self->param('_debug_log_sa'))
			{
				$self->{session}->{'debug.logSchemaAction'} = $self->param('_debug_log_sa');
			}
			$self->{schemaFlags} |= SCHEMAAPIFLAG_LOGSQL if $self->{session}->{'debug.logSchemaAction'};

			# if we get to here, we're fine and secure
			return $self->sessionStatus(SESSIONTYPE_SECURE);
		}
	}

	#
	# if we get to here, there was either no existing session or
	# the session information was invalid (exception occurred)
	#
	return $self->sessionStatus(SESSIONTYPE_NOTSECURE);
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

	my $permIds = $self->{acl}->{permissionIds};
	foreach (@_)
	{
		if(my $permInfo = $permIds->{$_})
		{
			return 1 if $self->{permissions}->member($permInfo->[Security::AccessControl::PERMISSIONINFOIDX_LISTINDEX]);
		}
		else
		{
			$self->addError("Permission '$_' does not exist in the ACL.");
		}
	}

	return 0;
}

#-----------------------------------------------------------------------------
# Static methods
#-----------------------------------------------------------------------------

#
# return TRUE if the current user has any one of the permissions passed in
# (pass in as many permissions as needed)
#

use CGI::Cookie;

sub getActiveUser
{
	my %cookies = fetch CGI::Cookie;
	my $person_id;
	my $org_id;

	if(my $sessionCookie = $cookies{SESSIONID_COOKIENAME()})
	{
		my $schema = new Schema::API(xmlFile => $CONFDATA_SERVER->file_SchemaDefn);
		$schema->connectDB($CONFDATA_SERVER->db_ConnectKey);

		eval {
			my $sth = $schema->{dbh}->prepare(q{
				SELECT
					s.person_id AS person_id,
					o.org_id AS org_id
				FROM
					person_session s,
					org o
				WHERE
					s.org_internal_id = o.org_internal_id AND
					s.session_id = ? AND
					s.remote_host = ?
			});
			$sth->execute($sessionCookie->value(), $ENV{REMOTE_ADDR});
			my $session = $sth->fetchrow_hashref;
			$person_id = $session->{PERSON_ID};
			$org_id = $session->{ORG_ID};
		};
		if ($@)
		{
			# log the error but continue
			warn $@;
			undef $@;
		}
	}
	return wantarray ? ($person_id, $org_id) : $person_id;
}

1;
