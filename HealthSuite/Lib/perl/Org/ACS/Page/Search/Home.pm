##############################################################################
package Org::ACS::Page::Search::Home;
##############################################################################

use strict;
use App::Page::Search::Home;
use CGI::ImageManager;
use vars qw(@ISA);
@ISA = qw(App::Page::Search::Home);

sub prepare_page_content_header
{
	my $self = shift;
	$self->{page_heading} = 'ACS Main Menu';
	App::Page::Search::prepare_page_content_header($self, @_);
}

sub prepare
{
	my $self = shift;
	my $sessionUser = $self->session('user_id');
	$self->addContent(qq{
		<center>
		<table border="0" cellspacing="0" cellpadding="5" align="center"><tr valign="top"><td>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				$IMAGETAGS{'images/page-icons/person'}
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>Patients</b></font>
			</td></tr><tr><td colspan="2">
				@{[ getImageTag('design/bar', { height => "1", width => "100%", }) ]}<br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/patient">Patients</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new <a href="/org/#session.org_id#/dlg-add-patient">Patient</a>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				$IMAGETAGS{'images/page-icons/org'}
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Providers</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/directory">Providers</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/org/#session.org_id#/dlg-add-org-dir-entry">Provider Directory Entry</a>
				</font>
			</td></tr>

			</table>
			<p>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				$IMAGETAGS{'images/page-icons/worklist-referral'}
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>Referrals</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%></td></tr>
			<tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/worklist/referral">Service Request Worklist</a>,
					<a href="/worklist/referral?user=physician">Everybody Referral Followup Worklist</a>,
					<a href="/worklist/referral?user=$sessionUser">Personal Referral Followup Worklist</a>,
					<a href="/org/#session.org_id#/dlg-add-referral-intake">Intake Coordinator's Referral Followup Worklist</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/org/#session.org_id#/dlg-add-referral-person">Service Request</a>
				</font>
			</td></tr></table>
		</center>
	});

	return 1;
}

1;
