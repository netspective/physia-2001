##############################################################################
package App::Page::Worklist::Collection;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use App::ImageManager;
use Devel::ChangeLog;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Page;
use App::Statements::Search::Appointment;

use App::Dialog::CollectionSetup;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'worklist/collection' => {},
	);

sub prepare_view_date
{
	my ($self) = @_;

	$self->addContent(qq{
		<TABLE BORDER=0 CELLSPACING=1 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD colspan=5>
					#component.worklist#
				</TD>
			</TR>
			<TR>
				<TD colspan=5>&nbsp;</TD>
			</TR>
			<TR VALIGN=TOP>
				<TD>
					#component.lookup-records#<BR>
				</TD>
				<TD>&nbsp;</TD>
				<TD>
					#component.create-records# <BR>
				</TD>
				<TD>&nbsp;</TD>
				<TD>
					#component.navigate-reports-root#
				</TD>
			</TR>
		</TABLE>
	});

	return 1;
}

sub prepare_view_recentActivity
{
	my ($self) = @_;

	$self->addContent(qq{<br>
		<TABLE BORDER=0 CELLSPACING=1 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					#component.stp-person.mySessionViewCount#<BR>
					#component.stp-person.recentlyVisitedPatients#<BR>
				</TD>
				<TD>
					&nbsp;
				</TD>
				<TD colspan=3>
					#component.stp-person.mySessionActivity# <br>
				</TD>
			</TR>
			<TR>
				<TD colspan=5>&nbsp;</TD>
			</TR>
			<TR VALIGN=TOP>
				<TD>
					#component.lookup-records#<BR>
				</TD>
				<TD>&nbsp;</TD>
				<TD>
					#component.create-records# <BR>
				</TD>
				<TD>&nbsp;</TD>
				<TD>
					#component.navigate-reports-root#
				</TD>
			</TR>
		</TABLE>
	});

	return 1;
}

sub prepare_view_setup
{
	my ($self) = @_;

	my $dialog = new App::Dialog::CollectionSetup(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'apptslot'));
	$self->SUPER::prepare_page_content_footer(@_);

	return 1;
}

sub decodeDate
{
	my ($date) = @_;

	$date = 'today' unless ParseDate($date);
	my @date_ = Decode_Date_US(UnixDate($date, '%m/%d/%Y'));
	my @today = Today();

	if (Delta_Days(@date_, @today) == 0)
	{
		return "Today";
	}
	elsif ($date_[0] == $today[0])
	{
		return UnixDate($date, '%a %b %e');
	}
	else
	{
		return UnixDate($date, '%a %m/%d/%Y');
	}
}

sub prepare_page_content_header
{
	my $self = shift;

	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);
	unshift(@{$self->{page_content_header}}, '<A name=TOP>');

	$self->SUPER::prepare_page_content_header(@_);

	my $heading = "Work List";
	my $dateTitle = decodeDate($self->param('_seldate'));

	my $urlPrefix = "/worklist";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			[$dateTitle, "/worklist/date", 'date'],
			['Recent Activity', "/worklist/recentActivity", 'recentActivity'],
			['Setup', "/worklist/collection/setup", 'setup', ],
			#['Setup', "#SETUP", 'setup'],

		], ' | ');

	push(@{$self->{page_content_header}},
	qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					$IMAGETAGS{'icon-m/schedule'} <B>$heading</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
		</TABLE>
		</TD></TR>
		</TABLE>
	}, @{[ $self->param('dialog') ? '<p>' : '' ]});

	push(@{$self->{page_content_header}}, $self->getControlBarHtml())
		unless ($self->param('noControlBar'));

	return 1;
}

sub getControlBarHtml
{
	my ($self) = @_;

	my $selectedDate = $self->param('_seldate') || 'today';
	$selectedDate = 'today' unless ParseDate($selectedDate);
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	my $optionIndex;

	my $javascripts = $self->getJavascripts();
	my $chooseDateOptsHtml = $self->getChooseDateOptsHtml($fmtDate);

	my $nextDay = UnixDate(DateCalc($selectedDate, "+1 day"), '%m-%d-%Y');
	my $prevDay = UnixDate(DateCalc($selectedDate, "-1 day"), '%m-%d-%Y');
	my $nDay = $nextDay; $nDay =~ s/\-/\//g;
	my $pDay = $prevDay; $pDay =~ s/\-/\//g;

	if($self->param('_f_action_change_controls'))
	{
		$self->session('showTimeSelect', $self->param('showTimeSelect'));
		$self->session('time1', $self->param('time1'));
		$self->session('time2', $self->param('time2'));
	}

	my @dateSelected = Decode_Date_US($fmtDate);
	my $timeFieldsHtml;

	if (Delta_Days(@dateSelected, Today()) == 0)
	{
		$self->param('Today', 1);

		my ($time1, $time2, $title1, $title2);

		if ($self->session('showTimeSelect') == 1)
		{
			if (! $self->session('time1') || $self->session('time1') !~ /:/) {
				$time1 = '12:00am';
				$self->session('time1', $time1);
			} else {
				$time1 = $self->session('time1');
			}

			if (! $self->session('time2') || $self->session('time2') !~ /:/) {
				$time2 = '11:59pm';
				$self->session('time2', $time2);
			} else {
				$time2 = $self->session('time2');
			}

			#$time1 = $self->session('time1') || '12:00am';
			#$time2 = $self->session('time2') || '11:59pm';
		}
		else
		{
			if (! $self->session('time1') || $self->session('time1') =~ /:/) {
				$time1 = 30;
				$self->session('time1', $time1);
			} else {
				$time1 = $self->session('time1');
			}

			if (! $self->session('time2') || $self->session('time2') =~ /:/) {
				$time2 = 120;
				$self->session('time2', $time2);
			} else {
				$time2 = $self->session('time2');
			}

			#$time1 = $self->session('time1') || 30;
			#$time2 = $self->session('time2') || 120;
		}

		$timeFieldsHtml = qq{
			<SCRIPT>
				function prefillDefaults(Form)
				{
					if (Form.showTimeSelect.options[Form.showTimeSelect.selectedIndex].value == 1)
					{
						Form.time1.value = '12:00am';
						Form.time2.value = '11:59pm';
					}
					else
					{
						Form.time1.value = 30;
						Form.time2.value = 120;
					}
				}
			</SCRIPT>
			&nbsp; &nbsp;
			Time:
			<SELECT name=showTimeSelect onChange="prefillDefaults(document.dateForm);">
				<option value=0>Minutes before/after</option>
				<option value=1>Range from/to</option>
			</SELECT>

			<script>
				setSelectedValue(document.dateForm.showTimeSelect, '@{[$self->session('showTimeSelect')]}');
			</script>

			&nbsp;<input name=time1 size=6 value=$time1 title="$title1">
			&nbsp;<input name=time2 size=6 value=$time2 title="$title2">

			<INPUT TYPE=HIDDEN NAME="_f_action_change_controls" VALUE="1">
			<input type=submit value="Go">
		};
	}
	else
	{
		my ($time1, $time2, $title1, $title2);

		if (! $self->session('time1') || $self->session('time1') !~ /:/) {
			$time1 = '12:00am';
			$self->session('time1', $time1);
		} else {
			$time1 = $self->session('time1');
		}

		if (! $self->session('time2') || $self->session('time2') !~ /:/) {
			$time2 = '11:59pm';
			$self->session('time2', $time2);
		} else {
			$time2 = $self->session('time2');
		}


		$timeFieldsHtml = qq{
			&nbsp; &nbsp;
			Time:
			<INPUT name=showTimeSelect value="Range from/to" READONLY>

			&nbsp;<input name=time1 size=6 value=$time1 title="$title1">
			&nbsp;<input name=time2 size=6 value=$time2 title="$title2">

			<INPUT TYPE=HIDDEN NAME="_f_action_change_controls" VALUE="1">
			<input type=submit value="Go">
		};

	}

	#<FORM name='dateForm' method=POST onsubmit="updatePage(document.dateForm.selDate.value); return false;">

	return qq{
	<TABLE bgcolor='#EEEEEE' cellpadding=3 cellspacing=0 border=0 width=100%>
		$javascripts
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input  { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>

		<tr>
			<FORM name='dateForm' method=POST>
				<td ALIGN=LEFT>
					<SELECT onChange="document.dateForm.selDate.value = this.options[this.selectedIndex].value;
						updatePage(document.dateForm.selDate.value); return false;">
						$chooseDateOptsHtml
					</SELECT>

					<A HREF="javascript: showCalendar(document.dateForm.selDate);">
						<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></A> &nbsp

					<input name=left  type=button value='<' onClick="updatePage('$prevDay')" title="Goto $pDay">
					<INPUT size=13 name="selDate" type="text" value="$fmtDate" onChange="updatePage(this.value);">
					<input name=right type=button value='>' onClick="updatePage('$nextDay')" title="Goto $nDay">

					$timeFieldsHtml
				</td>
			</FORM>
		</tr>

	</TABLE>
	<br>
	};
}

sub getChooseDateOptsHtml
{
	my ($self, $date) = @_;

	# Choose Date drop down list
	my @quickChooseItems =
		(
			{ caption => 'Choose Day', value => '' },
			{ caption => 'Today', value => 'today' },
			{ caption => 'Yesterday', value => DateCalc('today', '-1 day') },
			{ caption => 'Tomorrow', value => DateCalc('today', '+1 day') },
			{ caption => 'Day after Tomorrow', value => DateCalc('today', '+2 days') },
		);

	my $quickChooseDateOptsHtml = '';
	foreach (@quickChooseItems)
	{
		my $formatDate = UnixDate($_->{value}, '%m/%d/%Y');
		$quickChooseDateOptsHtml .=  qq{
			<option value="$formatDate">$_->{caption}</option>
		};
	}
	return $quickChooseDateOptsHtml;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		['WorkList', '/worklist'],
	);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('_pm_view', $pathItems->[1] || 'date');
	$self->param('noControlBar', 1);

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->printContents();
	return 0;
}

sub handleARL_date
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$pathItems->[2] =~ s/\-/\//g if defined $pathItems->[1];
	$self->param('_seldate', $pathItems->[2]);
	$self->param('noControlBar', 0);
}

#sub handleARL_setup
#{
#	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
#	if ($pathItems->[1] =~ /^resource$/i)
#	{
#		$self->param('resources', $pathItems->[2]);
#	}
#}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=date$');
}

sub getJavascripts
{
	my ($self) = @_;

	return qq{

		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>

		<SCRIPT>
			function updatePage(selectedDate)
			{
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = '/worklist/date/' + dashDate;
			}

			function chooseEntry2(itemValue, actionObj, destObj)
			{
				if(isLookupWindow())
				{
					populateControl(itemValue, true);
					return;
				}

				if(actionObj == null)
					actionObj = search_form.item_action_arl_select;

				if(actionObj != null) {
					var arlFmt = actionObj.options[actionObj.selectedIndex].value;
					var newArl = replaceString(arlFmt, '%itemValue%', itemValue);

					if (destObj == null)
					{
						window.location.href = newArl;
					}
					else
					{
						if(destObj.selectedIndex == 0)
							window.location.href = newArl;
						else
							doActionPopup(newArl);
					}
				}
			}
		</SCRIPT>
	};
}

1;
