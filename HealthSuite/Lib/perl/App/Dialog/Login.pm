##############################################################################
package App::Dialog::Login;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use vars qw(@ISA);

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Org;

@ISA = qw(CGI::Dialog);

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
				name => 'org_id', caption => 'Organization ID',
				onValidate => \&validateOrg, onValidateData => $self,
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
		new CGI::Dialog::Field(name => 'start_arl_use', type => 'hidden'),
		new CGI::Dialog::Field(caption => 'Start Page', name => 'start_arl', type => 'select', selOptions => 'Home:/person/$_f_person_id$/home;Search:/search;Schedule:/schedule', options => FLDFLAG_PERSIST),
	);
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub validateUser
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;

	return $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value) ?
		() : ("$dialogItem->{caption} '$value' not found.");
}

sub validateOrg
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;

	return () unless $value;
	return $STMTMGR_ORG->recordExists($page, STMTMGRFLAG_NONE,'selRegistry', $value) ?
		() : ("$dialogItem->{caption} '$value' not found.");
}

sub validatePassword
{
	my ($dialogItem, $page, $dialog, $value, $extraData) = @_;

	my $personId = uc($page->field('person_id'));
	my $orgId = uc($page->field('org_id'));
	my $info = $orgId ?
		$STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selLoginOrg', $personId, $orgId) :
		$STMTMGR_PERSON->getRowAsArray($page, STMTMGRFLAG_NONE, 'selLogin', $personId);

	if($info)
	{
		return ("Invalid password specified for User ID $info->[0]\@$info->[1]") if $info->[2] ne $value;

		if(my $loginCount = $info->[3])
		{
			if($page->field('clear_sessions'))
			{
				$orgId ?
					$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updSessionsTimeoutOrg', $personId, $orgId) :
					$STMTMGR_PERSON->execute($page, STMTMGRFLAG_NONE, 'updSessionsTimeout', $personId);
			}

			my $sessions = $orgId ?
				$STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selSessionsOrg', $personId, $orgId) :
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
	my $hideStartInfo = ($page->param('arl_resource') =~ m/^(search|logout)$/) ? 0 : 1;
	$self->updateFieldFlags('start_sep', FLDFLAG_INVISIBLE, $hideStartInfo);
	$self->updateFieldFlags('start_arl', FLDFLAG_INVISIBLE, $hideStartInfo);
	$page->field('start_arl_use', ! $hideStartInfo);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my ($personId, $orgId) = ($page->field('person_id'), $page->field('org_id'));
	my $categories = $STMTMGR_PERSON->getSingleValueList($page, STMTMGRFLAG_NONE, 'selCategory', $personId, $orgId);
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

	$page->createSession($personId, $orgId, { categories => $categories, personFlags => $personFlags });
	$page->property('login_status', App::Page::LOGINSTATUS_SUCCESS);
	$page->clearFlag(App::Page::PAGEFLAG_IGNORE_BODYHEAD | App::Page::PAGEFLAG_IGNORE_BODYFOOT);

	if($page->field('start_arl_use'))
	{
		my $arl = $page->field('start_arl');
		$arl =~ s/\$(\w+)\$/$page->param($1)/ge;
		$page->redirect($arl);
	}
	return 'Welcome to Physia.com, ' . $page->session('user_id');
}

sub handle_page
{
	my ($self, $page, $command) = @_;

	# first "run" the dialog and get the flags to see what happened
	my $dlgHtml = $self->getHtml($page, $command);
	my $dlgFlags = $page->property(CGI::Dialog::PAGEPROPNAME_FLAGS . '_' . $self->id());

	# if we executed the dialog (performed some action), then we
	# want to leave because execute should have setup the redirect already
	if($dlgFlags & CGI::Dialog::DLGFLAG_EXECUTE)
	{
		$page->addContent($dlgHtml);
	}
	else
	{
		$page->addContent(qq{
			<CENTER>
				<TABLE WIDTH=600 CELLSPACING=10>
					<TR>
						<TD COLSPAN=2>
							<IMG SRC='/resources/images/w_restinghands.gif'>
							<IMG SRC='/resources/images/Splash_ani.gif'>
						</TD>
					</TR>
					<TR VALIGN=TOP>
						<TD>$dlgHtml</TD>
						<TD>
							<FONT FACE="VERDANA,ARIAL,HELVETICA" SIZE=2 COLOR=333333>
								@{[$page->{sessErrorMsg} ? "<FONT COLOR=DARKRED><B>Please Note</B></FONT><BR>$page->{sessErrorMsg}" : '' ]}
							</FONT>
						</TD>
					</TR>
					<TR>
						<TD COLSPAN=2>
							<FONT FACE="VERDANA,ARIAL,HELVETICA" SIZE=2 COLOR=777777>
							In order to assure that your data is secure,
							please be sure to logout of the system when you're done. In addition to
							logging out, please close all your browser windows after you log out.
							<p>
							<b>If you do not logout and close your browser when you're done, <font color=red><u>others will be able to see, modify,
							and potentially delete your data</u>.</font></b>
							<p>
							All of the work you perform during this session is tracked
							and audited for security and authenticity purposes.
							</FONT>
						</TD>
					</TR>
				</TABLE>
			</CENTER>
			});
	}
}

1;
