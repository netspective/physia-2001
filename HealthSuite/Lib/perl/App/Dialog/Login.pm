##############################################################################
package App::Dialog::Login;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use CGI::ImageManager;
use App::Universal;
use Date::Manip;
use SDE::CVS ('$Id: Login.pm,v 1.19 2000-11-01 19:53:33 radha_kotagiri Exp $', '$Name:  $');
use App::Configuration;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;
use vars qw(%RESOURCE_MAP $CVS);
%RESOURCE_MAP = (
	'login' => {},
);

use base qw(CGI::Dialog);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'login', heading => 'Please Login', );

	$self->addContent(
		new CGI::Dialog::Field(
			name => 'person_id', caption => 'User ID',
			onValidate => \&validateUser, onValidateData => $self,
			options => FLDFLAG_REQUIRED | FLDFLAG_NOBRCAPTION | FLDFLAG_UPPERCASE | FLDFLAG_PERSIST | FLDFLAG_HOME,
		),
		new CGI::Dialog::Field(
			name => 'password', caption => 'Password', type => 'password',
			onValidate => \&validatePassword, onValidateData => $self,
			options => FLDFLAG_REQUIRED | FLDFLAG_HOME,
		),
		new CGI::Dialog::Field(
			name => 'clear_sessions', caption => 'Logout of all active sessions', type => 'bool', style => 'check',
			options => FLDFLAG_INVISIBLE
		),
		new CGI::Dialog::Field(name => 'start_sep', type => 'separator'),
		new CGI::Dialog::Field(caption => 'Start Page',
			name => 'nextaction_redirecturl',
			type => 'select',
			selOptions => 'Worklist:/worklist;Home:/home;Main Menu:/menu;Schedule:/schedule',
			options => FLDFLAG_PERSIST
		),
		new CGI::Dialog::Field(caption => 'Time Zone',
			name => 'timezone',
			type => 'select',
			selOptions => 'GMT:GMT;US-Atlantic:AST4ADT;US-Eastern:EST5EDT;US-Central:CST6CDT;US-Mountain:MST7MDT;US-Pacific:PST8PDT',
			defaultValue => 'CST6CDT',
			options => FLDFLAG_PERSIST
		),

	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub validateUser
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;

	return $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selPersonCategoryExists', $value) ?
		() : ("$dialogItem->{caption} '$value' cannot login.");
}

sub validatePassword
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;
	my $personId = uc($page->field('person_id'));
	my $orgId = uc($page->field('org_id'));
	my $orgIntId = uc($dialog->{org_internal_id});
	#my $info = $orgIntId ?
	#	$STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selLoginOrg', $personId, $orgIntId) :
	#	$STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selLogin', $personId);
	my $info = $STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selLoginAnyOrg', $personId);

	if($info)
	{
		return ("Invalid password specified for User ID $info->[0]\@$info->[1]") if $info->[2] ne $value;

		if(my $loginCount = $info->[3])
		{
			if($page->field('clear_sessions'))
			{
				$orgId ?
					$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updSessionsTimeoutOrg', $personId, $orgIntId) :
					$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updSessionsTimeout', $personId);
			}

			my $sessions = $orgIntId ?
				$STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSessionsOrg', $personId, $orgIntId) :
				$STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSessions', $personId);

			if(scalar(@$sessions) >= $loginCount)
			{
				my @errors = ("Maximum logins for $info->[0]\@$info->[1] exceeded (only $info->[3] allowed).");
				foreach (@$sessions)
				{
					push(@errors, "You have an active session at $_->{remote_host} (started $_->{first_access}, last used $_->{last_access}).")
				}
				$dialog->clearFieldFlags('clear_sessions', FLDFLAG_INVISIBLE);
				return @errors;
			}
			return ();
		}
		else
		{
			return ("Your account is disabled at this time (no logins are allowed).");
		}
	}
	else
	{
		return ("$personId is not allowed to login (no password specified in system for given Organization ID).");
	}
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$page->setFlag(App::Page::PAGEFLAG_IGNORE_BODYHEAD | App::Page::PAGEFLAG_IGNORE_BODYFOOT);
	$page->property('login_status', App::Page::LOGINSTATUS_DIALOG);
	$self->setFieldFlags('clear_sessions', FLDFLAG_INVISIBLE);

	#
	# show the "start" selection box if the destination page is the home page or the
	# logout page
	#
	my $hideStartInfo = 0;
	if($page->param('arl'))
	{
		my $resource = $page->param('arl_resource');
		$hideStartInfo = 1 unless($resource eq 'logout' || $resource eq 'search');
	}
	$self->updateFieldFlags('start_sep', FLDFLAG_INVISIBLE, $hideStartInfo);
	$self->updateFieldFlags('nextaction_redirecturl', FLDFLAG_INVISIBLE, $hideStartInfo);
	$page->field('nextaction_redirecturl', '/' . $page->param('arl')) if $hideStartInfo;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $personId = $page->field('person_id');
	my ($validOrgs, $defaultOrg, $defaultOrgIntId) = $self->getOrgProfile($page, $personId);
	my $categories = $STMTMGR_PERSON->getSingleValueList($page, STMTMGRFLAG_NONE, 'selCategory', $personId, $defaultOrgIntId);
	my $personFlags = App::Universal::PERSONFLAG_ISPATIENT;

	foreach (@$categories)
	{
		$personFlags |= App::Universal::PERSONFLAG_ISPATIENT if uc($_) eq 'PATIENT';
		$personFlags |= App::Universal::PERSONFLAG_ISPHYSICIAN if uc($_) eq 'PHYSICIAN';
		$personFlags |= App::Universal::PERSONFLAG_ISNURSE if uc($_) eq 'NURSE';
		$personFlags |= App::Universal::PERSONFLAG_ISADMINISTRATOR if $_ eq 'ADMINISTRATOR';
		$personFlags |= App::Universal::PERSONFLAG_ISCAREPROVIDER if $_ =~ /^(Physician|Nurse)$/i;
		$personFlags |= App::Universal::PERSONFLAG_ISSTAFF if $_ =~ /^(Physician|Nurse|Staff|Administrator)$/i;
	}

	my $timezone = $page->field('timezone');
	$ENV{TZ} = $timezone;
	`date` =~ /.*\d\d:\d\d:\d\d\s(.*?)\s.*/;
	my $TZ = $1;
	my $hackTZ = $TZ;
	$hackTZ =~ s/(.).(.)/$1D$2/;

	my $now = ParseDate('today');
	my $gmtTime = Date_ConvTZ($now, 'GMT', $hackTZ);
	my $gmtDayOffset = Delta_Format(DateCalc($gmtTime, $now), 10, '%dt');

	$page->createSession($personId, $defaultOrgIntId, {
		org_id => $defaultOrg, categories => $categories, personFlags => $personFlags,
		timezone => $timezone, TZ => $TZ, GMT_DAYOFFSET => $gmtDayOffset,
		validOrgs => join(',',@$validOrgs), defaultOrg => $defaultOrg,
	});

	$page->property('login_status', App::Page::LOGINSTATUS_SUCCESS);
	$page->clearFlag(App::Page::PAGEFLAG_IGNORE_BODYHEAD | App::Page::PAGEFLAG_IGNORE_BODYFOOT);

	$self->handlePostExecute($page, $command, $flags);
	return 'Welcome to Physia.com, ' . $page->session('user_id');
}

sub getOrgProfile
{
	my ($self, $page, $personId) = @_;

	my $orgs = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selValidOrgs', $personId);
	my $defaultOrg = $orgs->[0]->{org_id};
	my $defaultOrgIntId = $orgs->[0]->{org_internal_id};
	if (my $cookieOrg = $page->cookie('defaultOrg'))
	{
		if (my ($cookieOrgIntId) = map {$_->{org_internal_id}} grep {$_->{org_id} eq $cookieOrg} @$orgs)
		{
			$defaultOrg = $cookieOrg;
			$defaultOrgIntId = $cookieOrgIntId;
		}
		# else there not a member of the cookie's defaultOrg, keep the default instead
	}
	return ([map {$_->{org_id}} @$orgs], $defaultOrg, $defaultOrgIntId);
}

sub handle_page
{
	my ($self, $page, $command) = @_;

	# first "run" the dialog and get the flags to see what happened
	my $dlgHtml = $self->getHtml($page, $command);
	my $dlgFlags = $page->property(&CGI::Dialog::PAGEPROPNAME_FLAGS . '_' . $self->id());
	my $configGroup = $CONFDATA_SERVER->name_Group();
	my $tagName = ($CVS->Name() || 'Development') . ' Code';

	# if we executed the dialog (performed some action), then we
	# want to leave because execute should have setup the redirect already
	if($dlgFlags & &CGI::Dialog::DLGFLAG_EXECUTE)
	{
		$page->addContent($dlgHtml);
	}
	else
	{
		$page->addContent(qq{
			<center>
				<table width="600" cellspacing="10" border="0"><tr><td colspan="2" align="center">
					$IMAGETAGS{'images/welcome'}
				</td></tr><tr valign="top"><td colspan="2" align="center">
					$dlgHtml
				</td><td>
					<font face="Verdana,Arial,Helvetica" size="2" color="#333333">
						@{[ $page->{sessErrorMsg} ? qq{<font color="darkred"><b>Please Note</b></font><br>$page->{sessErrorMsg}} : '' ]}
					</font>
				</td></tr><tr><td colspan="2">
					<br>
					<a href="https://digitalid.verisign.com/as2/1940859b9af71702c65fb7f216fe0090" target="new">@{[ getImageTag('icons/verisignsealwhite', { align => 'left' }) ]}</a>
					<font face="Verdana,Arial,Helvetica" size="2" color="#777777">
						<p>In order to assure that your data is secure,
						please be sure to logout of the system when you're done. In addition to
						logging out, please close all your browser windows after you log out.</p>
						<p><b>If you do not logout and close your browser when you're done,
						<font color="red">others will be able to see, modify,
						and potentially delete your data.</font></b></p>
						<p>All of the work you perform during this session is tracked
						and audited for security and authenticity purposes.<br><br></p>
					</font>
				<!--
				</td></tr><tr><td align="center" valign="top" width="50%">
					<font face="Verdana,Arial,Helvetica" size="1" color="#777777">Powered by:</font><br>
				</td><td align="center" valign="top" width="50%">
					<font face="Verdana,Arial,Helvetica" size="1" color="#777777">Secured by:</font><br>
				</td></tr><tr><td align="center" valign="top" width="50%">
					<table align="center" border="0" cellspacing="0" cellpadding="0"><tr><td align="center" valign="middle" width="33%">
						<a href="http://www.physia.com/">$IMAGETAGS{'icons/ihos1'}</a>
					</td><td align="center" valign="middle" width="33%">
						<a href="http://www.oracle.com/">$IMAGETAGS{'icons/oracle_logo'}</a>
					</td><td align="center" valign="middle" width="33%">
						<a href="http://www.sun.com/">$IMAGETAGS{'icons/sun_logo'}</a><br>
					</td></tr></table>
				</td><td align="center" valign="top" width="50%">
					<a href="https://digitalid.verisign.com/as2/1940859b9af71702c65fb7f216fe0090" target="new">@{[ getImageTag('icons/verisignsealwhite', { width => 49, height => 51 }) ]}</a><br>
				-->
				</td></tr><tr><td colspan="2" align="center">
					<font face="Verdana,Arial,Helvetica" size="1" color="#777777">
						<p>
						<!--
							<a href="/public/privacy">Privacy Statement</a>
							|
							<a href="/public/security">Security Statement</a>
							<br>
						-->
						<br>
						Copyright \&copy; 2000 <a href="http://www.physia.com/">Physia Corp</a> - All Rights Reserved.<br>
						Various Trademarks Held By Their Respective Owners.<br>
						<br>
						[ \u$configGroup Database / $tagName ]
						</p>
					</font>
				</td></tr></table>
			</center>
			});
	}
}

1;
