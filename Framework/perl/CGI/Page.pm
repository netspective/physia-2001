##############################################################################
package CGI::Page;
##############################################################################

use strict;
use Carp;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session::DBI;
use File::Spec;
use Date::Manip;
use Schema::API;
use App::Configuration;
use Security::AccessControl;

use vars qw(@ISA $VERSION);

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
	$self->{sqlUnitWork}=undef;
	$self->{valUnitWork}=undef;
	$self->{errUnitWork}=[];
	$self->{cntUnitWork}=0;
	

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
			push(@hiddens, "<INPUT TYPE='HIDDEN' NAME='$param' VALUE='$_'>");
		}
    }

    foreach (sort keys %replaceParams)
    {
		push(@hiddens, "<INPUT TYPE='HIDDEN' NAME='$_' VALUE='$replaceParams{$_}'>") if defined $replaceParams{$_};
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
	$src =~ s/\%(\w+)\.(.*?)\%/
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

sub replaceVars
{
	my ($self, $src) = @_;

	#
	# do replacements for #session.xxx#, #param.xxx# or #field.xxx# or
	# any other page method that returns a single value
	#
	# NOTE: FOR PERFORMANCE, A COPY OF THIS SUBSTITION ALSO EXISTS IN DBI::StatementManager and
	#       App::Page. SO, IF YOU UPDATE THE REGEXP, DO IT THERE, TOO!
	#
	$src =~ s/\#(\w+)\.(.*?)\#/
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
		$self->addError(join ("<br>",$@,$self->{db}->errstr));
		return 0;
	}	
	return $rc;
}

sub beginUnitWork
{
	my $self = shift;
	$self->{sqlUnitWork}='BEGIN ';
	$self->{cntUnitWork}=0;
	$self->{errUnitWork}=[];
	$self->{valUnitWork}=undef;
	$self->{schemaFlags}|= SCHEMAAPIFLAG_UNITSQL;		
	$self->{schemaFlags}&=~SCHEMAAPIFLAG_EXECSQL;		
	return 1;	
}

sub endUnitWork
{
	my $self = shift;			
	$self->{sqlUnitWork}.= "END;  "; 	
	my $stmhdl = $self->prepareSql($self->{sqlUnitWork});	
	$self->{schemaFlags} = DEFAULT_SCHEMAAPIFLAGS;		
	$self->{sqlUnitWork}='';
	if (scalar(@{$self->{errUnitWork}}))
	{
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
	$self->{cntUnitWork}++;
	if(scalar(@{$errors}) > 0)
	{
		push(@{$self->{errUnitWork}},"<b> Unit Of Work Query $self->{cntUnitWork} error :</b> @{$errors}");			
	}
	$self->{sqlUnitWork}.= $sql . ";  "; 
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
	my ($self, $userId, $orgId, $sessionVars) = @_;
	my %session;
	tie %session, 'CGI::Session::DBI', undef,
		{
			dbh => $self->{db},
			status => 0,
			person_id => $userId,
			org_id => $orgId,
			remote_host => $self->remote_host(),
			remote_addr => $self->remote_addr(),
		};
	$self->{session} = \%session;
	$session{user_id} = $userId;
	$session{org_id} = $orgId;

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

sub establishSession
{
	my $self = shift;

	# right now only one machine will be "secure"
	#if($self->remote_addr() !~ /209\.207\.182\.[0-9]+/)
	#{
	#	$self->{session} =
	#	{
	#		user_id => 'SJONES',
	#		org_id  => 'CLMEDGRP',
	#	};
	#	return $self->sessionStatus(SESSIONTYPE_SIMULATESECURE);
	#}

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
		};
		if($@)
		{
			# using errorCode_ref and errorMsg_ref, CGI::Session::DBI will fill the messages appropriately
			#$self->{sessError} = $@;
			#$self->addError('Session Error: ' . $@);
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

sub permit
{
	my ($self, $permission) = @_;
	return 1 if $_[0]->{sessStatus} == SESSIONTYPE_SIMULATESECURE;

	my $acl = $self->{acl};
}

1;
