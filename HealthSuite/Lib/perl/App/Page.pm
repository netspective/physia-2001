##############################################################################
package App::Page;
##############################################################################

# NOTE:
#   For some strange reason, when modifying this page and running through
#   Velocigen, perl gets caught in a "soft loop" taking forever to return.
#   The solution is to refresh, wait 6 seconds, refresh again, wait 5 seconds,
#   and then refresh again. The third refresh should "clear" the loop.
#

use strict;
use CGI::Page;
use CGI::ImageManager;
use App::Universal;
use App::Configuration;
use Date::Manip;
use IO::File;
use File::Spec;
use Time::HiRes qw(gettimeofday tv_interval);
use CGI::Carp;

use DBI::StatementManager;
use App::Statements::Page;
use App::Statements::Person;
use App::Statements::Component;
use Schema::API;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter CGI::Page);

use enum qw(BITMASK:PAGEFLAG_ ISDISABLED ISPOPUP ISADVANCED ISFRAMESET ISFRAMEHEAD ISFRAMEBODY ISHANDHELD IGNORE_BODYHEAD IGNORE_BODYFOOT CONTENTINPANES INCLUDEDEFAULTSCRIPTS RECORD_VIEWCOUNT);
use constant DEFAULT_OPTIONS => PAGEFLAG_INCLUDEDEFAULTSCRIPTS;

@EXPORT = qw(
	PAGEFLAG_ISDISABLED
	PAGEFLAG_ISPOPUP
	PAGEFLAG_ISADVANCED
	PAGEFLAG_ISFRAMESET
	PAGEFLAG_ISFRAMEHEAD
	PAGEFLAG_ISFRAMEBODY
	PAGEFLAG_ISHANDHELD
	PAGEFLAG_IGNORE_BODYHEAD
	PAGEFLAG_IGNORE_BODYFOOT
	PAGEFLAG_RECORD_VIEWCOUNT
	);

use enum qw(:THEMECOLOR_
	BKGND_PAGE BKGND_CHANNEL BKGND_CHANNELEDIT BKGND_TOOLS BKGND_BANNER BKGND_LOCATOR BKGND_HEADING
	FRAME_CHANNEL FRAME_CHANNELEDIT FRAME_TOOLS);

use enum qw(:THEMEFONTTAG_
    PLAIN_OPEN PLAIN_CLOSE
    CHANNEL_FRAME_OPEN CHANNEL_FRAME_CLOSE
    CHANNEL_BODY_OPEN CHANNEL_BODY_CLOSE
    CHANNEL_BODYS_OPEN CHANNEL_BODYS_CLOSE
    CHANNEL_HIGHL_OPEN CHANNEL_HIGHL_CLOSE
    TOOLS_FRAME_OPEN TOOLS_FRAME_CLOSE
    TOOLS_BODY_OPEN TOOLS_BODY_CLOSE
    TOOLS_HIGHL_OPEN TOOLS_HIGHL_CLOSE
    LOCATOR_OPEN LOCATOR_CLOSE
    LOCATOR_SELECTED_OPEN LOCATOR_SELECTED_CLOSE
    DATETIME_OPEN DATETIME_CLOSE
    HIGHLIGHTED_OPEN HIGHLIGHTED_CLOSE
    LINK_OPEN LINK_CLOSE
    VISITED_OPEN VISITED_CLOSE);

use enum qw(:LOGINSTATUS_ DIALOG SUCCESS FAILURE);

use constant MENU_APP_DEFAULT => [
	["Main Menu", '/menu'],
	["Work Lists", '/worklist'],
	["Schedule Desk", '/schedule'],
];

use constant MENU_APP_SUPPORT => [
	['System Menu...', ''],
	['Help', '/help'],
	['Query', '/query'],
	['Reports', '/report'],
	['Logout', '/logout'],
];

# A page is comprised of the following parts:
# * http_header (the Content-type: text/html, etc -- see the HTTP RFC)
# * page_header (the <HEAD> component)
# * page_body (the <BODY> component)
# *   page_content (the stuff inside the <BODY> component)
# *     page_content_debug  (the error/debugging manager)
# *     page_content_header (the stuff starting out the content -- usually common)
# *     page_content_body   (the real page-specific content)
# *     page_content_footer (the stuff finishing out the content -- usually common)

sub new
{
    my $class = shift;
    
    # Grab the page startup time for benchmarking purposes
    my $startBenchmark = new Benchmark;
    
    my $self = $class->SUPER::new(@_, flags => DEFAULT_OPTIONS);
    my %params = @_;
    
    $self->{startBenchmark} = $startBenchmark;
    $self->{benchmarks} = [];

	$self->{page_colors} =
		[
			'#FFFFFF',          # page
			'LIGHTYELLOW',      # channel (normal pane)
			'RED',              # channel ("add" portion of edit channel)
			'BEIGE',            # tools (tools pane)
			'YELLOW',           # banner (banner underneath frame of a pane)
			'LIGHTSTEELBLUE',   # locator
			'YELLOW',           # heading
			'NAVY',             # channel frame
			'DARKRED',          # channel frame when editing
			'BLACK',            # tools frame
		] unless exists $self->{page_colors};

	$self->{page_fontTags} =
		[
			'<FONT FACE="Arial,Helvetica" SIZE="2">', '</FONT>',             # plain page font
			'<FONT FACE="Arial,Helvetica" SIZE="2"><B>', '</B></FONT>',      # channel frame
			'<FONT FACE="Arial,Helvetica" SIZE="2">', '</FONT>',             # channel content
			'<FONT FACE="Arial,Helvetica" SIZE="1">', '</FONT>',             # channel content (small)
			'<FONT FACE="Arial,Helvetica" SIZE="2" COLOR="RED">', '</FONT>', # highlighted channel content
			'<FONT FACE="Arial,Helvetica" SIZE="2"><B>', '</B></FONT>',      # tool frame
			'<FONT FACE="Arial,Helvetica" SIZE="2">', '</FONT>',             # tool content
			'<FONT FACE="Arial,Helvetica" SIZE="2" COLOR="RED">', '</FONT>', # highlighted tool content
			'<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">', '</FONT>', # locator font
			'<B>', '</B>',                                                   # locator selected
			'<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt" COLOR=GREEN>', '</FONT>', # date/time
		] unless exists $self->{page_fontTags};

	$self->{page_content_header} = [];
	$self->{page_content_footer} = [];

	$self->{page_menu_app} = MENU_APP_DEFAULT;
	my @systemMenu = @{MENU_APP_SUPPORT()}; # Make a copy of the constant menu
	$self->{page_menu_support} = \@systemMenu;
	$self->{page_menu_sibling} = undef;
	$self->{page_menu_siblingSelectorParam} = '';

	$self->{panemgr_header} = [];
	$self->{panemgr_columns} = [];
	$self->{panemgr_footer} = [];
	$self->{panemgr_padding} = 5;
	# optional: panemgr_msgPane = undef

	# make sure this is the last statement (in lieu of a return statement)
    $self;
}

sub DESTROY
{
	my ($self) = @_;

	# remove circular reference
	delete $self->{panemgr_msgPane}->{_paneMgr} if exists $self->{panemgr_msgPane};
}

sub recordActivity
{
	my $self = shift;
	# actual parameters:
	#my ($self, $activityType, $actionType, $scope, $key, $level, $msg) = @_;

	$STMTMGR_PERSON->execute($self, STMTMGRFLAG_REPLACEVARS, 'insSessionActivity',
		$self->session('_session_id'), @_);
}

sub getInternalOrgId
{
	#my ($self,$orgId,$org_internal_id) = @_;
	#$org_internal_id = $self->session('org_internal_id') if defined $org_internal_id;
	#return $STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $org_internal_id, $orgId);
}

sub incrementViewCount
{
	my ($self, $caption, $arl) = @_;

	unless($caption)
	{
		return unless $self->flagIsSet(PAGEFLAG_RECORD_VIEWCOUNT);
	}

	my ($scope, $key) = ($1, $2) if $self->referer() =~ m!http://.*?/(.*?)/(.*?)/.*!;
	my $sessionId = $self->session('_session_id');
	return unless $sessionId;
	my $userId    = $self->session('user_id');

	my @arlItems = split(/\//, $self->param('arl'));
	my $rsrc = $arlItems[0];

	my $paramKey = $self->param($rsrc . '_id');

	unless ($scope eq $rsrc && $key eq $paramKey)
	{
		if ($STMTMGR_PAGE->recordExists($self, STMTMGRFLAG_NONE, 'sel_SessionInfo', $userId, $rsrc, $paramKey))
		{
			$STMTMGR_PAGE->execute($self, STMTMGRFLAG_NONE, 'upd_count', $userId, $rsrc, $paramKey);
		}
		else
		{
			$STMTMGR_PAGE->execute($self, STMTMGRFLAG_NONE, 'ins_newKey', $sessionId, $userId, $rsrc, $paramKey,
		$caption, $arl);
		}
	}
}

# --- url-management functions -----------------------------------------------

#
# get all parameters for a new ARL
#
sub arlParams
{
	my $self = shift;

    my ($param, @value, $var);
    my $pNum = 0;
    my $urlParams = '';
    my $joinWith = '';
    foreach $param ($self->param)
	{
		# don't put arl_ variables in the self reference
		next if $param =~ m/^arl/;  # don't put field or ARL variables in the URL
		next if $param eq 'keywords';

		$pNum++;
		@value = $self->param($param);
		foreach (@value)
		{
			$urlParams .= $joinWith . $param . '=' . $self->escape($_);
		}

		$joinWith = '&' unless $joinWith;
    }
	return $urlParams;
}

#
# get all parameters for a new ARL minus dialog state parameters
#
sub arlNoDlgParams
{
	my $self = shift;

    my ($param, @value, $var);
    my $pNum = 0;
    my $urlParams = '';
    my $joinWith = '';
    foreach $param ($self->param)
	{
		# don't put arl_ variables in the self reference
		next if $param =~ m/^arl/;  # don't put field or ARL variables in the URL
		next if $param =~ m/^_f_dlg/;  # don't put dialogs state variables in the URL
		next if $param eq 'keywords';

		$pNum++;
		@value = $self->param($param);
		foreach (@value)
		{
			$urlParams .= $joinWith . $param . '=' . $self->escape($_);
		}

		$joinWith = '&' unless $joinWith;
    }
	return $urlParams;
}

sub hrefSelf
{
	# return a url with reference to self + all CGI params - session params and arl_ params
	my $self = shift;
	my $params = $self->arlParams();
	'/' . $self->param('arl') . ($params ? ('?' . $params) : '');
}

sub hrefSelfNoDlg
{
	# return a url with reference to self + all CGI params - session params and arl_ and _f_dlg params
	my $self = shift;
	my $params = $self->arlNoDlgParams();
	'/' . $self->param('arl') . ($params ? ('?' . $params) : '');
}

sub hrefSelfPopup
{
	# return a url with reference to self + all CGI params - session params and arl_ params
	my $self = shift;
	my $params = $self->arlParams();
	'/' . $self->param('arl_asPopup') . ($params ? ('?' . $params) : '');
}

sub hrefSelfNoDlgPopup
{
	# return a url with reference to self + all CGI params - session params and arl_ and _f_dlg params
	my $self = shift;
	my $params = $self->arlNoDlgParams();
	'/' . $self->param('arl_asPopup') . ($params ? ('?' . $params) : '');
}

sub anchorSelf
{
	# return an anchor with reference to self + all CGI params - session params and arl_ params
	my $self = shift;
	my $params = $self->arlParams();
	'<A HREF="/' . $self->param('arl') . ($params ? ('?' . $params) : '') . '">' . $_[0] . '</A>';
}

sub anchorSelfPopup
{
	# return an targetted anchor with reference to self + all CGI params - session params and arl_ params
	my $self = shift;
	my $params = $self->arlParams();
	'<A HREF="javascript:doActionPopup(\'/' . $self->param('arl_asPopup') . ($params ? ('?' . $params) : '') . '\')">' . $_[0] . '</A>';
}

# --- menu-management functions -----------------------------------------------

use enum qw(BITMASK:MENUITEMFLAG_ FORCESELECTED);
use enum qw(BITMASK:MENUFLAG_ SELECTEDISHOT SELECTEDISLARGER TARGETTOP HIDEUNSELLEVELS);

use constant MENUFLAGS_DEFAULT => 0;

use constant MENUITEM_CAPTION       => 0; # menu caption
use constant MENUITEM_HREF          => 1; # url to go to when clicked (optional prefix xxx:: means TARGET=xxx)
use constant MENUITEM_SELECTORVALUE => 2; # sel value (what is the value of CGI parameter when item should be considered "selected")
use constant MENUITEM_FLAGS         => 3; # any menu-specificflags
use constant MENUITEM_SUBMENU       => 4; # submenus or undef if no submenus

sub getMenu_Simple
{
	my ($self, $flags, $selectorParamName, $items, $separator, $unselHtmlFmt, $selHtmlFmt) = @_;
	return '' unless @$items;

	#
	# the *Fmt strings can have %0, %1, %2, etc. based on MENUITEM_* captions
	# for example %0 means replace with the item's caption, %1 means replace with URL, etc.
	#
	my $target = $flags & MENUFLAG_TARGETTOP ? ' TARGET="_top"' : '';
	$selHtmlFmt   ||=
				($flags & MENUFLAG_SELECTEDISHOT) ?
				"<FONT COLOR=DARKRED @{[($flags & MENUFLAG_SELECTEDISLARGER) ? 'SIZE=+1' : '']}><B><A HREF='%1'>%0</A></B></FONT>" :
				"<FONT COLOR=DARKRED @{[($flags & MENUFLAG_SELECTEDISLARGER) ? 'SIZE=+1' : '']}><B>%0</B></FONT>";
	$unselHtmlFmt ||= "<A HREF='%1'$target>%0</A>";

	my @html = ();
	my $selectorValue = $selectorParamName ? $self->param($selectorParamName) : undef;
	foreach my $item (@$items)
	{
		next unless $item;
		my ($caption, $href, $itemFlags) = ($item->[MENUITEM_CAPTION], $item->[MENUITEM_HREF], $item->[MENUITEM_FLAGS]);
		my $htmlFmt = ($itemFlags & MENUITEMFLAG_FORCESELECTED) || (defined $selectorValue && $selectorValue eq $item->[MENUITEM_SELECTORVALUE]) ? $selHtmlFmt : $unselHtmlFmt;
		$htmlFmt =~ s/\%(\d+)/$item->[$1]/g;
		push(@html, $htmlFmt);
	}
	return join($separator, @html);
}

sub getMenu_Tabs
{
	my ($self, $flags, $selectorParamName, $items, $params) = @_;
	$params = {} unless $params;
	my $unselColor = $params->{unselColor} || '#126A97';
	my $unselTextColor = $params->{unselTextColor} || 'white';
	my $selColor = $params->{selColor} || '#dddddd';
	my $selTextColor = $params->{selTextColor} || 'navy';
	my $leftImage = $params->{leftImage} || 'images/design/tab-top-left-corner';
	my $rightImage = $params->{rightImage} || 'images/design/tab-top-right-corner';
	my $highColor = $params->{highColor} || 'yellow';
	return $self->getMenu_Simple($flags, $selectorParamName, $items, '',
		qq{
			<td bgcolor="$unselColor" width="3" valign="top">$IMAGETAGS{$leftImage}</td>
			<td bgcolor="$unselColor" height="16">
			<nobr>
			<font face="tahoma,helvetica" size="2" color="$unselTextColor" style="font-size: 8pt;">
			&nbsp;
			<a style="color: $unselTextColor; text-decoration: none" href='%1' onmouseover='anchorMouseOver(this, "$highColor")' onmouseout='anchorMouseOut(this, "$unselTextColor")'>%0</a>
			&nbsp;
			</font>
			</nobr>
			</td>
			<td bgcolor="$unselColor" width="3" valign="top">$IMAGETAGS{$rightImage}</td>
			<td width="2">@{[getImageTag('design/transparent-line', {width => "2", height => 2})]}</td>
		},
		qq{
			<td bgcolor="$selColor" width="3" valign="top">$IMAGETAGS{$leftImage}</td>
			<td bgcolor="$selColor" height="16">
			<nobr>
			<font face="tahoma,helvetica" size="2" color="$selTextColor" style="font-size: 8pt;">
			&nbsp;
			<b><a style="color: $selTextColor; text-decoration: none" href='%1'>%0</a></b>
			&nbsp;
			</font>
			</font>
			</nobr>
			</td>
			<td bgcolor="$selColor" width="3" valign="top">$IMAGETAGS{$rightImage}</td>
			<td width="2">@{[getImageTag('design/transparent-line', {width => "2", height => 2})]}</td>
		});
}

sub getMenu_TwoLevelTable
{
	my ($self, $flags, $selectorParamName, $items, $separator, $mainHtmlFmt, $unselHtmlFmt, $selHtmlFmt) = @_;
	$separator ||= ', ';
	return '' unless @$items;

	#
	# the *Fmt strings can have %0, %1, %2, etc. based on MENUITEM_* captions
	# for example %0 means replace with the item's caption, %1 means replace with URL, etc.
	#
	$mainHtmlFmt  ||= '<FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY><B>%0</B></FONT>';
	$selHtmlFmt   ||=
				($flags & MENUFLAG_SELECTEDISHOT) ?
				"<FONT COLOR=DARKRED @{[($flags & MENUFLAG_SELECTEDISLARGER) ? 'SIZE=+1' : '']}><B><A HREF='%1'>%0</A></B></FONT>" :
				"<FONT COLOR=DARKRED @{[($flags & MENUFLAG_SELECTEDISLARGER) ? 'SIZE=+1' : '']}><B>%0</B></FONT>";
	$unselHtmlFmt ||= '<A HREF="%1">%0</A>';

	my @rows = ();
	my $selectorValue = $self->param($selectorParamName);
	$flags &= ~MENUFLAG_HIDEUNSELLEVELS unless $selectorValue;

	foreach my $mainItem (@$items)
	{
		my @html = ();
		my $hasSelectedValue = 0;
		foreach my $item (@{$mainItem->[MENUITEM_SUBMENU]})
		{
			my ($caption, $href, $itemFlags) = ($item->[MENUITEM_CAPTION], $item->[MENUITEM_HREF], $item->[MENUITEM_FLAGS]);
			my $isSel = ($itemFlags & MENUITEMFLAG_FORCESELECTED) || (defined $selectorValue && $selectorValue eq $item->[MENUITEM_SELECTORVALUE]);
			my $htmlFmt = $isSel ? $selHtmlFmt : $unselHtmlFmt;
			$htmlFmt =~ s/\%(\d+)/$item->[$1]/g;
			push(@html, $htmlFmt);

			$hasSelectedValue++ if $isSel;
		}

		if($flags & MENUFLAG_HIDEUNSELLEVELS)
		{
			next unless $hasSelectedValue;
		}
		my $mainHtml = $mainHtmlFmt;
		$mainHtml =~ s/\%(\d+)/$mainItem->[$1]/ge;
		push(@rows, "<TR><TD ALIGN=RIGHT>$mainHtml</TD><TD><FONT FACE='Arial,Helvetica' SIZE=2>@{[join($separator, @html)]}</FONT></TD>");

	}
	return qq{<TABLE BORDER="0">@rows</TABLE>};
}

sub getMenu_ComboBox
{
	my ($self, $flags, $selectorParamName, $items, $objName) = @_;
	return '' unless @$items;

	#
	# the *Fmt strings can have %0, %1, %2, etc. based on MENUITEM_* captions
	# for example %0 means replace with the item's caption, %1 means replace with URL, etc.
	#
	my $unselHtmlFmt = '<option value="%1">%0</option>';
	my $selHtmlFmt = '<option value="%1" selected>%0</option>';
	$objName ||= "$selectorParamName\_menu";

	my @html = ();
	my $selectorValue = $self->param($selectorParamName);
	foreach my $item (@$items)
	{
		next unless $item;
		my ($caption, $href, $itemFlags) = ($item->[MENUITEM_CAPTION], $item->[MENUITEM_HREF], $item->[MENUITEM_FLAGS]);
		my $htmlFmt = ($itemFlags & MENUITEMFLAG_FORCESELECTED) || (defined $selectorValue && $selectorValue eq $item->[MENUITEM_SELECTORVALUE]) ? $selHtmlFmt : $unselHtmlFmt;
		$htmlFmt =~ s/\%(\d+)/$item->[$1]/g;
		push(@html, $htmlFmt);
	}
	return join('', qq{<SELECT class="header" name="$objName" onchange="document.location.href = this.options[this.selectedIndex].value">}, @html, '</SELECT>');
}

# --- theme-management functions ----------------------------------------------

sub getThemeColors
{
	return (defined $_[1] ? $_[0]->{page_colors}->[$_[1]] : $_[0]->{page_colors});
}

sub getThemeFontTags
{
	return (defined $_[1] ? $_[0]->{page_fontTags}->[$_[1]] : $_[0]->{page_fontTags});
}

sub getTextBoxHtml
{
	my $self = shift;
	my %params = @_;
	$params{hcolor} ||= 'NAVY';
	$params{color} ||= 'BEIGE';
	$params{altColor} ||= $params{color} eq 'BEIGE' ? 'LIGHTYELLOW' : $params{color};
	$params{width} ||= '100%';
	$params{halign} ||= 'CENTER';
	$params{shalign} ||= 'CENTER';
	$params{align} ||= 'LEFT';
	$params{valign} ||= 'TOP';
	$params{falign} ||= 'CENTER';

	my $headingRow = $params{heading} ?
		qq{<tr bgcolor="$params{hcolor}" valign=top><td ALIGN=$params{halign}>
			<font face=arial color=yellow size=2><b>$params{heading}</font></font>
		</td></tr>}
		: '';
	my $subHeadRow = $params{subhead} ?
		qq{<tr><td ALIGN=$params{shalign}>
			<font face=arial color=navy size=2><b>$params{subhead}</b></font>
		</td></tr>}
		: '';
	my $footRow = $params{footer} ?
		qq{<tr><td ALIGN=$params{falign}>
		<font face=arial color=darkred size=2><b>$params{footer}</b></font>
		</td></tr>}
		: '';

	my $message = $params{message};
	if(ref $params{messages} eq 'ARRAY')
	{
		$message = '';
		my $count = 0;
		foreach my $msg (@{$params{messages}})
		{
			my $color = $params{color};
			$params{color} = $params{altColor};
			$params{altColor} = $color;
			$count++;
			$message .= "<tr BGCOLOR=$color VALIGN=TOP><td><b>$count</b></td><td ALIGN=$params{align} VALIGN=$params{valign}>$msg</td></tr>";
		}
		$message = qq{<table cellpadding="10" cellspacing="0" border="0" width="100%">$message</table>};
	}

	return qq{
		<table cellspacing="2" cellpadding="0" border="0" bgcolor="$params{hcolor}" width="$params{width}">$headingRow<tr><td><table cellpadding="0" cellspacing="0" border="0" width="100%">$subHeadRow<tr><td ALIGN="$params{align}">
			<font face="arial" size="2" color="black">
			$message
			</font>
		</td></tr>$footRow</table></tr></td></table>
	};
}

sub getLogStructHtml
{
	my ($self, $flags, $log, $struct, $level) = @_;
	$level = 0 unless defined $level;

	my @rows = ();

	if(my $items = $struct->{_items})
	{
		push(@rows, '<TABLE BORDER="0">');
		foreach (@$items)
		{
			push(@rows,
				qq{<TR VALIGN=TOP><TD>
					<FONT SIZE=2 FACE=Arial COLOR=DARKRED>$_->[1]
				</TD><TD>
					<FONT SIZE=2 FACE=Arial COLOR=999999>$_->[2]
				</TD><TD>
					<FONT SIZE=2 FACE=Arial>$_->[4]
				</TD></TR>});
		}
		push(@rows, '</TABLE>');
	}

	push(@rows, '<UL>');
	foreach my $category (sort keys %{$struct})
	{
		next if $category eq '_items';
		my $size = $level < 3 ? 3 - $level : 2;
		my $subHtml = $self->getLogStructHtml($flags, $log, $struct->{$category}, $level+1);
		push(@rows, qq{<LI><FONT SIZE=$size COLOR=NAVY><B>$category</B>$subHtml</LI>});
	}
	push(@rows, '</UL>');
	return join("\n", @rows);
}

# --- page creation functions -------------------------------------------------

sub initialize
{
	my $self = shift;
	$ENV{TZ} = $self->session('timezone');

	$self->addLocatorLinks(
			["$IMAGETAGS{'images/icons/home-sm'} Home", '/home'],
		);
	
	# Determine where to store person/org specific temp files
	my $personId = $self->session('person_id');
	my $orgId = $self->session('org_id');
	my ($pTmpDir, $pTmpUrl)	= $self->getTemp($personId, 'person');
	my ($oTmpDir, $oTmpUrl) = $self->getTemp($orgId, 'org');
	$self->param('person_temp_dir', $pTmpDir);
	$self->param('person_temp_url', $pTmpUrl);
	$self->param('org_temp_dir', $oTmpDir);
	$self->param('org_temp_url', $oTmpUrl);
	$self->setFlag(PAGEFLAG_ISHANDHELD) if $self->param('arl_resource') eq 'mobile';

	$self->incrementViewCount();
}

sub getSecurityMessage
{
	my $self = shift;

	my $roles = $self->session('aclRoleNames');
	my $permissions = $self->session('aclPermissions');
	return qq{
		<p>
		If you believe you should have access to this page, please contact Physia Customer Service and
		give them the following information:

		<p>
		<ul>
			<li>User ID: <font face=Courier><b>#session.user_id#</b></font></li>
			<li>Org ID: <font face=Courier><b>#session.org_id# (#session.org_internal_id#)</b></font></li>
			<li>Roles: <font face=Courier><b>@{[ $roles ? join(', ', @$roles) : 'None' ]}</b></font></li>
			<li>Permissions: <font face=Courier><b>@{[ $permissions ? $permissions->run_list() : 'None' ]}</b></font></li>
			<li>Request: <font face=Courier><b>#param.arl#</b></font></li>
		</ul>
	};
}

sub disable
{
	my $self = shift;
	$self->setFlag(PAGEFLAG_ISDISABLED);
	$self->{_disabledMsg} = shift() . $self->getSecurityMessage();
}


sub getChildResources
{
	my $self = shift;
	my $resourceMap = shift;

	my $children = {};
	$resourceMap = $self->property('resourceMap') unless $resourceMap;

	return $children unless ref($resourceMap) eq 'HASH';
	foreach (keys %$resourceMap)
	{
		next if $_ =~ /^_/;
		next unless ref($resourceMap->{$_}) eq 'HASH';
		if (exists $resourceMap->{$_}->{_class})
		{
			$children->{$_} = $resourceMap->{$_};
		}
	}
	return $children;
}


sub send_page_header
{
	my $self = shift;
	my $html .= join(' ', @{$self->{page_head}});
	unless($self->flagIsSet(PAGEFLAG_ISHANDHELD))
	{
		if ( $self->{flags} & PAGEFLAG_INCLUDEDEFAULTSCRIPTS )
		{
			$html .= qq{
				<script language="JavaScript">var _version = 1.0;</script>
				<script language="JavaScript1.1">_version = 1.1;</script>
				<script language="JavaScript1.2">_version = 1.2;</script>
				<script language="JavaScript1.3">_version = 1.3;</script>
				<script language="JavaScript1.4">_version = 1.4;</script>
				<script src='/lib/page.js' language="JavaScript1.2"></script>
				<script>
				if(typeof pageLibraryLoaded == 'undefined')
				{
					alert('ERROR: /lib/page.js could not be loaded');
				}
				</script>
			};
		}
		$html .= qq{
			<STYLE>
				a.head { text-decoration: none; }
				a:hover { color : red; }
				.required {background-image:url(/resources/icons/triangle-northeast-red.gif); background-position:top right; background-repeat:no-repeat; }
				form { border: 0; margin: 0; }
				select { font-size: 10pt; font-family: Tahoma, Ariel, Helvetica; }
				select.header { font-size: 8pt; font-family: Tahoma, Ariel, Helvetica; }
				input { font-size: 10pt; font-family: Tahoma, Ariel, Helvetica; }
				input.header { font-size: 8pt; font-family: Tahoma, Ariel, Helvetica; }
				textarea { font-size: 10pt; font-family: Tahoma, Ariel, Helvetica; }
				button { font-size: 10pt; font-family: Tahoma, Ariel, Helvetica; }
				button.header { font-size: 8pt; font-family: Tahoma, Ariel, Helvetica; }
			</STYLE>
			<TITLE>[Physia] #property._title#</TITLE>
			@{[ $self->flagIsSet(PAGEFLAG_ISFRAMESET) ? $self->getFrameSet() : '' ]}
			};
	}

	$self->replaceVars(\$html);
	if (defined wantarray and wantarray eq 'TRUE') {
		return "<head>\n$html\n</head>\n";
	} else {
		print "<head>\n$html\n</head>\n";
		return 1;
	}
}


sub getFrameSet
{
	my $self = shift;

	my $arl = $self->param('arl');
	my ($headerURL, $bodyURL) = ($arl, $arl);
	$headerURL =~ s/^(\w+)/\/$1-fh/;
	$bodyURL =~ s/^(\w+)/\/$1-fb/;

	return qq{
		<FRAMESET ROWS="95,*" FRAMEBORDER=0 FRAMESPACING=0 SCROLLING="NO" BORDER=0>
			<FRAME SRC="$headerURL" NAME="dheader" SCROLLING="NO" NORESIZE MARGINHEIGHT=5 MARGINWIDTH=5>
			<FRAME SRC="$bodyURL" NAME="dcontent" SCROLLING="AUTO" NORESIZE MARGINHEIGHT=5 MARGINWIDTH=5>
		</FRAMESET>
	};
}

sub send_page_body
{
	my $self = shift;
	my $startTime = [gettimeofday] if $self->param('_debug_benchmarks');
	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());
	my $flags = $self->{flags};

	print $flags & PAGEFLAG_ISHANDHELD ? '' : qq{<BODY leftmargin="0" topmargin="0" marginheight="0" marginwidth="0" bgcolor="$colors->[THEMECOLOR_BKGND_PAGE]" onload="return processOnInit()">$fonts->[THEMEFONTTAG_PLAIN_OPEN]};
	my $html = '';
	my $preliminaries = '';

	$html = join('', @{$self->{page_content_header}}) unless $flags & PAGEFLAG_ISFRAMEBODY;
	unless($flags & PAGEFLAG_ISFRAMEHEAD)
	{
		$html .= qq{<div style="width: 100%; margin: 10">} . join('', @{$self->{page_content}}) . "</div><br>";
		$html .= join('', @{$self->{page_content_footer}});
	}

	my $startRVTime = [gettimeofday] if $self->param('_debug_benchmarks');
	$self->replaceVars(\$html);
	push @{$self->{benchmarks}}, "<b>replaceVars() in send_page_body():</b> " . tv_interval($startRVTime) . ' seconds' if $self->param('_debug_benchmarks');

	$html = $self->component('sde-page-params-and-fields') . $html if $self->param('_debug_params');
	$html = $self->component('sde-page-fields') . $html if $self->param('_debug_fields');
	$html = $self->component('sde-page-session') . $html if $self->param('_debug_session');
	$html = $self->component('sde-page-cookies') . $html if $self->param('_debug_cookies');
	$html = $self->component('sde-page-env') . $html if $self->param('_debug_env');
	$html = $self->component('sde-page-components') . $html if $self->param('_debug_comp');
	$html = $self->component('sde-page-acl') . $html if $self->param('_debug_acl');

	$preliminaries .= $self->getTextBoxHtml(heading => 'Errors', messages => $self->{page_errors}) if $self->haveErrors();
	$preliminaries .= $self->getTextBoxHtml(heading => 'Debugging Statements', messages => $self->{page_debug}) if @{$self->{page_debug}};

	if (defined wantarray) {
		my $finalHTML = qq{<BODY leftmargin="0" topmargin="0" marginheight="0" marginwidth="0" bgcolor="$colors->[THEMECOLOR_BKGND_PAGE]" onload="return processOnInit()">$fonts->[THEMEFONTTAG_PLAIN_OPEN]};
		$finalHTML .= $preliminaries;
		$finalHTML .= $html;
		$finalHTML .= "$fonts->[THEMEFONTTAG_PLAIN_CLOSE]</BODY>";

		return $finalHTML;
	} else {
		print $preliminaries;
		print $html;
		print "$fonts->[THEMEFONTTAG_PLAIN_CLOSE]</BODY>";
	}
	push @{$self->{benchmarks}}, "<b>send_page_body():</b> " . tv_interval($startTime) . ' seconds' if $self->param('_debug_benchmarks');
}

sub addLocatorLinks
{
	my $self = shift;
	push(@{$self->{page_locator_links}}, @_);
}

sub replaceLocatorLinks
{
	my $self = shift;
	delete $self->{page_locator_links};
	push(@{$self->{page_locator_links}}, @_);
}

sub prepare_page_body
{
	my $self = shift;
	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());

	my $sessStatus = $self->sessionStatus();
	if($sessStatus == CGI::Page::SESSIONTYPE_NOTSECURE || $sessStatus == CGI::Page::SESSIONTYPE_SESSIONERROR)
	{
		return 1 unless $self->prepare_login() == LOGINSTATUS_SUCCESS;
	}

	# if for security or other reasons we've disable the page, then show the message and leave
	if($self->flagIsSet(PAGEFLAG_ISDISABLED))
	{
		$self->addContent($self->{_disabledMsg});
	}
	elsif(my $action = $self->param('_stdAction'))
	{
		if(my $method = $self->can("prepare_stdAction_$action"))
		{
			return 0 unless &$method($self);
		}
		else
		{
			$self->addError("Unknown stdAction '$action'.");
		}
	}
	elsif($self->param('_panepkg'))
	{
		return 0 unless $self->prepare_pane();
	}
	elsif($self->param('_showchangelog'))
	{
		return 0 unless $self->prepare_changes();
	}
	else
	{
		my $handlersCount = 0;
		my $handlersOkCount = 0;
		foreach ($self->getContentHandlers())
		{
			s/\$(\w+)[=]?(.*)\$/$self->param($1, $2) if defined $2 && ! defined $self->param($1); $self->param($1)/ge;
			if($self->can($_))
			{
				$handlersCount++;
				$handlersOkCount++ if $self->$_();
			}
		}

		if($handlersCount)
		{
			return 0 unless $handlersCount == $handlersOkCount;
		}
		else
		{
			return 0 unless $self->prepare();
		}
	}

	unless($self->flagIsSet(PAGEFLAG_IGNORE_BODYHEAD))
	{
		return 0 unless $self->prepare_page_content_header();
	}
	return
		$self->prepare_page_content_footer();
}

sub prepare_page_content_header
{
	my $self = shift;
	return 1 if $self->flagIsSet(PAGEFLAG_ISPOPUP);
	return 1 if $self->flagIsSet(PAGEFLAG_ISHANDHELD);

	# Add items to allow org switching
	push @{$self->{page_menu_support}}, ["SDE Page", "/sde"] if $self->hasPermission('page/sde');
	my $currentOrgId = $self->session('org_id');
	foreach (split(',', $self->session('validOrgs')))
	{
		next if $_ eq $currentOrgId;
		push @{$self->{page_menu_support}}, ["Switch to $_", "/home?_switchTo=$_"];
	}


	my $resourceMap = $self->property('resourceMap');
	unless($self->{page_menu_sibling})
	{
		if (defined $resourceMap->{_views})
		{
			my $menu = ($self->{page_menu_sibling} = []);
			my $urlPrefix = "/" . $self->param('arl_resource');
			foreach my $view (@{$resourceMap->{_views}})
			{
				push @$menu, [ $view->{caption}, "$urlPrefix/$view->{name}", $view->{name} ];
			}
			$self->{page_menu_siblingSelectorParam} = '_pm_view';
		}
	}

	unshift(@{$self->{page_content_header}}, qq{
	<SCRIPT>
		function anchorMouseOver(element, color)
		{
			element.style.color = color;
			element.style.textDecoration = 'underline';
		}

		function anchorMouseOut(element, color)
		{
			element.style.color = color;
			element.style.textDecoration = 'none';
		}
	</SCRIPT>
	<table cellspacing="0" cellpadding="0" border="0" bgcolor="#389cce" width="100%"><tr><td width="100">
		$IMAGETAGS{'images/design/app-corporate-logo'}<br>
	</td><td>
		<font face="tahoma,arial" size="2" style="font-size:8pt" color="white">
		$IMAGETAGS{'images/icons/home-sm'} <a href="/home" style='text-decoration:none; color:yellow' onmouseover='anchorMouseOver(this, "white")' onmouseout='anchorMouseOut(this, "yellow")'><b>#session.user_id#</b></a>@<a href="/homeorg" style='text-decoration:none; color:yellow' onmouseover='anchorMouseOver(this, "white")' onmouseout='anchorMouseOut(this, "yellow")'>#session.org_id#</a>
		$IMAGETAGS{'images/icons/arrow-right-lblue'}
		@{[ $self->getMenu_Simple(MENUFLAGS_DEFAULT, undef, $self->{page_menu_app}, ' <font color=silver>|</font> ', "<A HREF='%1' style='text-decoration:none; color:white' onmouseover='anchorMouseOver(this, \"yellow\")' onmouseout='anchorMouseOut(this, \"white\")'>%0</A>" ) ]}
		</font>
	</td><td align="right" valign="middle" width="100">
		<form>
		<font face="tahoma,arial" size="2" style="font-size:8pt" color="yellow">
		@{[ $self->getMenu_ComboBox(MENUFLAGS_DEFAULT, undef, $self->{page_menu_support}, ' <font color=silver>|</font> ', "<A HREF='%1' style='text-decoration:none; color:yellow' onmouseover='anchorMouseOver(this, \"white\")' onmouseout='anchorMouseOut(this, \"yellow\")'>%0</A>" ) ]}
		</font>
		</form>
	</td><td>
		&nbsp;
	</td><td align="right" valign="middle" width="10">
		<table cellpadding="1" cellspacing="0" style="border: 2; border-style: outset; background-color: #EEEEEE;"></tr><td align="right" valign="bottom">
			<font face="tahoma,arial" size="2" style="font-size:8pt" color="yellow">
			<nobr>
			<a href="/logout">$IMAGETAGS{'icons/small-arrow'}</a>
			<b><a href="/logout" style="text-decoration: none; color: black" onmouseover="anchorMouseOver(this, 'red')" onmouseout=	"anchorMouseOut(this, 'black')">Logout</a></b>
			</nobr>
			</font>
		</td></tr></table>
	</td><td>
		&nbsp;
	</td></tr></table>
	<table cellspacing="0" cellpadding="0" border="0" bgcolor="#353365" width="100%"><tr height="1" bgcolor="#ff9935"><td colspan="3">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td></tr><tr height="4"><td colspan="3">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td></tr><tr><td width="4">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td><td valign=top>
		<font face="tahoma,arial" size="2" style="font-size:8pt" color="#ff9935">
		@{[ $self->getMenu_Simple(MENUFLAGS_DEFAULT, undef, $self->{page_locator_links}, " $IMAGETAGS{'images/design/parent-separator'} ", "<A HREF='%1' style='text-decoration:none; color:#ff9935' onmouseover='anchorMouseOver(this, \"white\")' onmouseout='anchorMouseOut(this, \"#ff9935\")'>%0</A>" ) ]}
		</font>
	</td><td align="right" valign="bottom" rowspan=2>
		@{[ $self->{page_menu_sibling} ? ('<table cellspacing="0" cellpadding="0" border="0"><tr>' . $self->getMenu_Tabs(MENUFLAGS_DEFAULT, $self->{page_menu_siblingSelectorParam}, $self->{page_menu_sibling}) . '</tr></table>') : '' ]}
	</td></tr><tr height="2" bgcolor="#353365"><td colspan="2">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td></tr><tr height="2" bgcolor="#dddddd"><td colspan="3">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td></tr></table>
	<table cellspacing="0" cellpadding="0" border="0" bgcolor="#353365" width="100%"><tr bgcolor="#dddddd"><td width="4">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td><td width=15>
		@{[ $IMAGETAGS{$resourceMap->{_iconMedium}} || $IMAGETAGS{'images/page-icons/default'} ]}
	</td><td valign=center>
		&nbsp;<b><font face="helvetica" size="4">@{[ $self->{page_heading} || $resourceMap->{_title} ]}</font></b>
	</td><td align="right">
		<font face="tahoma,arial,helvetica" style="font-size: 8pt" color="navy">
		Updated @{[ UnixDate('today', '%a %b %d %i:%M %p') ]} @{[ $self->session('TZ') ]}
		</font>
		&nbsp;
	</td></tr><tr height="2" bgcolor="#dddddd"><td colspan="4">@{[
		getImageTag('design/transparent-line', {width => "100%", height => 1})
	]}</td></tr><!-- <tr height="1" bgcolor="#ff9935"><td colspan="3">
		&nbsp;
	</td></tr> --></table>});
}

sub prepare_page_content_footer
{
	my $self = shift;
	if($self->{schemaFlags} & SCHEMAAPIFLAG_LOGSQL)
	{
		$self->addDebugStmt('SQL Logging is on');
		$self->addContent('<hr size="1" color="darkred"><font size="3"><code><ol>');
		foreach(@{$self->{sqlLog}})
		{
			$self->addContent(scalar(@{$_->[1]} > 0) ? qq{<li>@{[ $_->[0] ]}<br><font color="red">@{[ join('<br>', @{$_->[1]}) ]}</font></li>} : "<li>@{[ $_->[0] ]}</li>");
		}
		$self->addContent('</ol></code></font>');
	}
	return 1;
}

sub component
{
	my ($self, $compId) = @_;
	my $resources = \%App::ResourceDirectory::RESOURCES;
	my $compPrefix = &App::ResourceDirectory::COMPONENT_RESOURCE_PREFIX;
	my $resourceName = $compPrefix . $compId;
	if(my $component = $resources->{$resourceName}{_class})
	{
		my $compType = ref $component eq 'CODE' ? App::Universal::COMPONENTTYPE_STATEMENT : App::Universal::COMPONENTTYPE_CLASS;
		my $package = exists $resources->{$resourceName}{_stmtMgr} ? $resources->{$resourceName}{_stmtMgr} : $resources->{$resourceName}{_package};
		my $stmtId = exists $resources->{$resourceName}{_stmtId} ? $resources->{$resourceName}{_stmtId} : '';
		push(@{$self->{components}}, [
			$compType,
			$resourceName,
			$package,
			$stmtId,
			]);
		my $startTime = [gettimeofday] if $self->param('_debug_benchmarks');
		my $html = ref $component eq 'CODE' ? &$component($self, 0) : $component->getHtml($self, 0);
		push @{$self->{benchmarks}}, "<b>$resourceName:</b> " . tv_interval($startTime) . ' seconds' if $self->param('_debug_benchmarks');
		return $html;
	}
	return "Component '$compId' not found";
}

sub getContentHandlers
{
	# return a list of methods that will automatically be called based on
	# the values of one or more CGI parameters
	#
	# you can have $xxx$ in the method name to replace value of xxx CGI parameter
	# or you can have $xxx=yyy$ to replace value of CGI parameter XXX or default to profile
	#
	# for example, and entry that looks like 'prepare_view_$_pm_view=profile$' will call
	# a method "prepare_view_abc" if the value of CGI parameter _pm_view is "abc"
	#
	return ();
}

sub prepare
{
	# this function is called to populate the page's body_content
	# when no "view" is specified -- this means that this function will
	# draw the entire page (if called)
	#
	my $self = shift;
	$self->addError('App::Page::prepare method not overriden.');

	return 1;
}

sub prepare_session_error
{
	my $self = shift;

	$self->addContent($self->getTextBoxHtml(heading => 'Critical Session Error', message => $self->{sessError}));
	return 1;
}

sub prepare_login
{
	my $self = shift;

	use App::Dialog::Login;
	my $dialog = new App::Dialog::Login();
	$dialog->handle_page($self, 'login');

	return $self->property('login_status');
}

sub prepare_stdAction_dialog
{
	my $self = shift;
	my ($dlgId, $dlgCmd, $startArlIndex) = scalar(@_) > 0 ? @_ :
		($self->param('_dlgId'), $self->param('_dlgCmd'), $self->param('_dlgParamStartIndex'));
	my $dlgPrefix = &App::ResourceDirectory::DIALOG_RESOURCE_PREFIX;
	$self->addContent('<BR>');

	my $permissionName = "dlg/$dlgId/$dlgCmd";
	if (!$self->hasPermission($permissionName))		# Check permission to the dialog
	{
		$self->addContent("You do not have permissions to the dialog <B>$permissionName</B>.<P>Click <a href=\"javascript:history.back()\">here</a> to go back.", $self->getSecurityMessage());
	}
	elsif(my $dlgInfo = $App::ResourceDirectory::RESOURCES{$dlgPrefix . $dlgId})
	{
		my ($dlgClass, %dlgConstructParams, $dlgParams);
		if(ref $dlgInfo eq 'HASH')
		{
			$dlgClass = $dlgInfo->{_class};
			%dlgConstructParams = %{$dlgInfo};
			$dlgParams = $dlgInfo->{"_arl_$dlgCmd"} || ($dlgCmd eq 'update' || $dlgCmd eq 'remove' ? $dlgInfo->{_arl_modify} : undef) || $dlgInfo->{_arl};
		}
		else
		{
			$dlgClass = $dlgInfo;
		}
		$dlgConstructParams{id} = $dlgId unless exists $dlgConstructParams{id};
		my $dialog = $dlgClass->new(schema => $self->{schema}, %dlgConstructParams);
		if($dlgParams)
		{
			my $arlIndex = $startArlIndex;
			my @pathItems = $self->param('arl_pathItems');
			foreach (@$dlgParams)
			{
				$self->param($_, $pathItems[$arlIndex]);
				$arlIndex++;
			}
		}
		$dialog->handle_page($self, $dlgCmd);
	}
	else
	{
		$self->addContent("Dialog '$dlgId' not found. The ID must be one of the following: <P>", join '<BR>', grep {$_ =~ s/^$dlgPrefix//} sort keys %App::ResourceDirectory::RESOURCES );
	}

	return 1;
}

sub prepare_stdAction_publish
{
	my $self = shift;

	my $arlIndex = $self->param('_publParamStartIndex');
	my @pathItems = $self->param('arl_pathItems');
	if($pathItems[$arlIndex] =~ /^dlg\-(.*?)\-(.*)$/)
	{
		$self->prepare_stdAction_dialog($2, $1, $arlIndex+1);
		$self->addContent('<BR><CENTER>', $self->publish($self->param('_publParams')), '</CENTER>');
	}
	else
	{
		$self->addContent($self->publish($self->param('_publParams')));
	}
	return 1;
}

sub prepare_stdAction_component
{
	my $self = shift;
	my $compId = $self->param('_compId');
	my $compPrefix = &App::ResourceDirectory::COMPONENT_RESOURCE_PREFIX;
	my $resourceName = $compPrefix . $compId;


	my $permissionName = "comp/$compId";
	if (!$self->hasPermission($permissionName))		# Check permission to the dialog
	{
		$self->addContent("You do not have permissions to the component <B>$permissionName</B>.<P>Click <a href=\"javascript:history.back()\">here</a> to go back.", $self->getSecurityMessage());
	}
	elsif(my $component = $App::ResourceDirectory::RESOURCES{$resourceName}{_class})
	{
		my $m = ref $component eq 'CODE' ? $component : $component->can('getHtml');

		my $arlIndex = $self->param('_compParamStartIndex');
		my @pathItems = $self->param('arl_pathItems');
		if($pathItems[$arlIndex] =~ /^dlg\-(.*?)\-(.*)$/)
		{

			$self->prepare_stdAction_dialog($2, $1, $arlIndex+1);
			$self->addContent('<BR><CENTER>',
				ref $component eq 'CODE' ? &$component($self, 0) : $component->getHtml($self, 0),
				'</CENTER>');
		}
		else
		{
			$self->addContent(ref $component eq 'CODE' ? &$component($self, 0) : $component->getHtml($self, 0));
		}
	}
	else
	{
		$self->addContent("Component '$compId' not found. The ID must be one of the following: <P>", join '<BR>', grep {$_ =~ s/^$compPrefix//} sort keys %App::ResourceDirectory::RESOURCES );
	}
	return 1;
}

sub arlHasStdAction
{
	my ($self, $rsrc, $pathItems, $startArlIndex) = @_;
	$startArlIndex = 0 unless defined $startArlIndex;

	if(my $action = $pathItems->[$startArlIndex])
	{
		if($action =~ /^dlg\-(.*?)\-(.*)$/)
		{
			# format in ARL is /blah/blah/dlg-<cmd>-<id>/param/param
			# where <cmd> is the dialog command like 'add', 'update' or 'remove'
			$self->param('_stdAction', 'dialog');
			$self->param('_dlgId', $2);
			$self->param('_dlgCmd', $1);
			$self->param('_dlgParamStartIndex', $startArlIndex+1);
			return 1;
		}
		elsif($action =~ /^publish\-(.*)$/)
		{
			$self->param('_stdAction', 'publish');
			$self->param('_publParams', $1);
			$self->param('_publParamStartIndex', $startArlIndex+1);
			return 1;
		}
		elsif(my $component = $App::ResourceDirectory::RESOURCES{&App::ResourceDirectory::COMPONENT_RESOURCE_PREFIX . $action})
		{
			$self->param('_stdAction', 'component');
			$self->param('_compId', $action);
			$self->param('_compParamStartIndex', $startArlIndex+1);
			return 1;
		}
	}


	# if we get to here, it wasn't a standard action
	return 0;
}

sub prepare_changes
{
	my $self = shift;

	my $moduleName = $self;
	$moduleName =~ s/=.*//;

	my $log = undef;
	if(eval("\$log = \\\@$moduleName\::CHANGELOG"))
	{
		my $struct = $self->createLogStruct(0, $log);
		$self->addContent($self->getLogStructHtml(0, $log, $struct));
		undef $struct;
		undef $log;
	}
}

sub printContents
{
	my ($self, $psOptions) = @_;
	my $html;

	$self->establishSession();
	$self->initialize();
	$self->prepare_page_body();

	if ($psOptions) {
		$self->setFlag (PAGEFLAG_IGNORE_BODYHEAD);
		$self->setFlag (PAGEFLAG_IGNORE_BODYFOOT);

		$html .= "<html>\n";
		$html .= $self->send_page_header ();
		$html .= $self->send_page_body ();
		$html .= "\n</html>\n";

		my $uniqueFilename = time ();
		$uniqueFilename .= "_$$.html";

		my $tempDir = $CONFDATA_SERVER->path_temp();
		$uniqueFilename = $tempDir."/".$uniqueFilename;

#		my $htmlPrinter = "| html2ps -L -i 0.70 > $uniqueFilename";
		my $htmlPrinter = ">$uniqueFilename";

		my $tempFileHandle = IO::File->new($htmlPrinter);
		print $tempFileHandle $html;
		$tempFileHandle->close;

		$self->clearFlag (PAGEFLAG_IGNORE_BODYHEAD);
		$self->clearFlag (PAGEFLAG_IGNORE_BODYFOOT);

	}

	if ($self->send_http_header()) {
		print "<html>\n";
		if ($self->send_page_header()) {
			$self->send_page_body()
		}
		if ($self->param('_debug_benchmarks'))
		{
			push @{$self->{benchmarks}}, '<b>Entire Page:</b> ' . tv_interval($self->{startBenchmark}) . ' seconds';
			print $self->getTextBoxHtml(heading => 'Benchmarks', messages => $self->{benchmarks});
		}
		print "\n</html>\n";
	}
}


sub homeArl
{
	my ($self) = @_;
	my $homeArl = $self->param('home') || $self->param('arl');
	$homeArl = '/' . $homeArl unless $homeArl =~ /^\//;
	return $homeArl;
}


sub constant
{
	my ($self, $name) = @_;

	no strict 'refs';
	return defined &{"App::Universal::$name"} ? &{"App::Universal::$name"} : "Constant '$name' not found!";

}


sub getTemp
{
	my $self = shift;
	my ($id, $type) = @_;
	
	my $url = File::Spec->catfile(
		'file',
		$type,
		substr($id,0,1),
		substr($id,0,2),
		substr($id,0,3),
		$id);
	my $path = File::Spec->catfile(
		$CONFDATA_SERVER->path_WebSite(),
		$url);
	$url = "/$url/";
	return ($path, $url);
}


sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	#
	# $arl is the complete ARL
	# $params is anything after the ? in the ARL
	# $rsrc is the first word of the ARL (blah/blah2/blah3 -- here it would be blah)
	# $pathItems is ref to an array of all path items after first word (resource)

	$self->param('_logout', 1) if $rsrc eq 'logout';

	if($pathItems->[0] eq 'changes')
	{
		$self->param('_showchangelog', 1);
		$self->printContents();
		return 0;
	}

	# normally handleARL will return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	# in our case (since we're the root method for all our children) we force -1 to say we did
	#   not handle the ARL.
	return -1;
}


1;
