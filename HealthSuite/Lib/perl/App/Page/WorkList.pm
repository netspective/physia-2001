##############################################################################
package App::Page::WorkList;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use CGI::ImageManager;
use Devel::ChangeLog;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Page;
use App::Statements::Search::Appointment;
use App::Schedule::Utilities;

use vars qw(@ISA @CHANGELOG %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'worklist' => {
		_title => 'Work List Menu',
		_iconSmall => 'images/page-icons/worklists',
		_iconMedium => 'images/page-icons/worklists',
		_iconLarge => 'images/page-icons/worklists',
		},
	);


sub prepare_view_default
{
	my $self = shift;
	my $children = $self->getChildResources();
	my $html = qq{<br>\n<br>\n<p>\n<table align="center" cellpadding="10" cellspacing="5" border="0">};
	foreach (keys %$children)
	{
		my $icon = $IMAGETAGS{$children->{$_}->{_iconMedium}};
		my $title = $children->{$_}->{_title};
		my $description = defined $children->{$_}->{_description} ? $children->{$_}->{_description} : '';
		next unless $icon && $title;
		$title = qq{<font face="Arial,Helvetica" size="4" color="darkred"><b>$title</b></font>};
		$description = qq{<br><font face="Arial,Helvetica" size="2" color="black">$description</font>} if $description;
		$title = qq{<a href="/worklist/$_">$title</a>};
		$html .= "<tr><td>\n$icon<br>\n</td><td>\n$title$description<br>\n</td></tr>";
	}
	$html .= '</table><p>';
	$self->addContent($html);
	return 1;
}


sub getChildResources
{
	my $self = shift;
	my $children = {};
	my $resourceMap = $self->property('resourceMap');
	return $children unless ref($resourceMap) eq 'HASH';
	foreach (keys %$resourceMap)
	{
		next unless ref($resourceMap->{$_}) eq 'HASH';
		if (exists $resourceMap->{$_}->{_class})
		{
			$children->{$_} = $resourceMap->{$_};
		}
	}
	return $children;
}


sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	$self->addLocatorLinks(
		[ 'Work List Menu', '/worklist' ],
	);
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=default$');
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	return 1 if ref($self) ne __PACKAGE__;

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
	}

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
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

sub getControlBarHtml
{
	my ($self) = @_;

	my $selectedDate = $self->param('_seldate') || $self->session('selectedDate') || 'today';
	#$selectedDate = 'today' unless ParseDate($selectedDate);

	$selectedDate = 'today' unless validateDate($selectedDate);
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	$self->param('_seldate', $selectedDate);
	$self->session('selectedDate', $selectedDate);
	$self->session('decodedDate', decodeDate($selectedDate));

	my $optionIndex;

	my $javascripts = $self->getJavascripts();
	#my $chooseDateOptsHtml = $self->getChooseDateOptsHtml($fmtDate);
	my $chooseDateOptsHtml = App::Page::Schedule::getChooseDateOptsHtml($self, $fmtDate);

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
				$time1 = '12:00 AM';
				$self->session('time1', $time1);
			} else {
				$time1 = $self->session('time1');
			}

			if (! $self->session('time2') || $self->session('time2') !~ /:/) {
				$time2 = '11:59 PM';
				$self->session('time2', $time2);
			} else {
				$time2 = $self->session('time2');
			}
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
		}

		my $javascriptValidate;
		$javascriptValidate = qq{ONBLUR="validateChange_Time(event)"}
			if $self->param('showTimeSelect');
		
		$timeFieldsHtml = qq{
			<SCRIPT>
				function prefillDefaults(Form)
				{
					if (Form.showTimeSelect.value == 1)
					{
						Form.time1.value = '12:00 AM';
						Form.time2.value = '11:59 PM';
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
			<SELECT class='controlBar' name=showTimeSelect onChange="prefillDefaults(document.dialog);">
				<option value=0>Minutes before/after</option>
				<option value=1>Range from/to</option>
			</SELECT>

			<script>
				setSelectedValue(document.dialog.showTimeSelect, '@{[$self->session('showTimeSelect')]}');
			</script>

			&nbsp;<input class='controlBar' name=time1 size=8 maxlength=8 value='$time1' title="$title1" 
				$javascriptValidate>
			&nbsp;<input class='controlBar' name=time2 size=8 maxlength=8 value='$time2' title="$title2" 
				$javascriptValidate>

			<INPUT TYPE=HIDDEN NAME="_f_action_change_controls" VALUE="1">
			<input class='controlBar' type=submit value="Go">
		};
	}
	else
	{
		my ($time1, $time2, $title1, $title2);

		if (! $self->session('time1') || $self->session('time1') !~ /:/) {
			$time1 = '12:00 AM';
			$self->session('time1', $time1);
		} else {
			$time1 = $self->session('time1');
		}

		if (! $self->session('time2') || $self->session('time2') !~ /:/) {
			$time2 = '11:59 PM';
			$self->session('time2', $time2);
		} else {
			$time2 = $self->session('time2');
		}

		$timeFieldsHtml = qq{
			&nbsp; &nbsp;
			Time:
			<INPUT class='controlBar' name=showTimeSelect value="Range from/to" READONLY>

			&nbsp;<input class='controlBar' name=time1 size=8 maxlength=8 value='$time1' title="$title1"
				ONBLUR="validateChange_Time(event)">
			&nbsp;<input class='controlBar' name=time2 size=8 maxlength=8 value='$time2' title="$title2"
				ONBLUR="validateChange_Time(event)">

			<INPUT TYPE=HIDDEN NAME="_f_action_change_controls" VALUE="1">
			<input class='controlBar' type=submit value="Go">
		};
	}

	return qq{
	<TABLE bgcolor='#EEEEEE' cellpadding=3 cellspacing=0 border=0 width=100%>
		$javascripts
		<STYLE>
			select.controlBar { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input.controlBar  { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>

		<tr>
			<FORM name='dialog' method=POST>
				<td ALIGN=LEFT>
					<SELECT class='controlBar' onChange="document.dialog.selDate.value = this.value;
						updatePage(document.dialog.selDate.value); return false;">
						$chooseDateOptsHtml
					</SELECT>

					<A HREF="javascript: showCalendar(document.dialog.selDate, 1);">
						<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></A> &nbsp

					<input name=left  type=button value='<' onClick="updatePage('$prevDay')" title="Goto $pDay">
					<INPUT class='controlBar' size=13 maxlength=10 name="selDate" type="text" value="$fmtDate" onChange="updatePage(this.value);">
					<input name=right type=button value='>' onClick="updatePage('$nextDay')" title="Goto $nDay">

					$timeFieldsHtml
				</td>
			</FORM>
		</tr>

	</TABLE>
	<br>
	};
}

1;
