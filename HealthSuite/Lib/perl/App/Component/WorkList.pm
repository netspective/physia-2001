##############################################################################
package App::Component::WorkList;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use Date::Calc qw(:all);
use Date::Manip;
use DBI::StatementManager;
use App::Statements::Component::Scheduling;
use App::Statements::Person;
use App::Schedule::Utilities;
use Data::Publish;

use vars qw(@ISA);
@ISA   = qw(CGI::Component);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist';

	$layoutDefn->{frame}->{heading} = " ";
	$layoutDefn->{style} = 'panel.transparent';


	$layoutDefn->{banner}->{actionRows} =
	[
		{
			caption => qq{
				<a href='$arlPrefix/dlg-add-appointment'>Add Walk-In</a> |
				<a href='$arlPrefix/dlg-add-appointment'>Add Appointment</a> |
				<a href='$arlPrefix/dlg-add-patient/'>Add Patient</a> |
				
				&nbsp
				<SELECT onChange='location.href=this.options[selectedIndex].value'>
					<option value='#'>Select Action</option>
					<option value='$arlPrefix/dlg-add-ins-product/'>Create Insurance Product</option>
					<option value='$arlPrefix/dlg-add-ins-plan/'>Create Insurance Plan</option>
					<option value='$arlPrefix/dlg-add-assign/'>Reassign Physician</option>
					<option value='#'>Print Encounter Form</option>
					<option value='#'>Print Face Sheet</option>
				</SELECT>
			}
		},
	];
}

sub getHtml
{
	my ($self, $page) = @_;

	$self->initialize($page);
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, $self->getComponentHtml($page));
}

sub saveResourcePref
{
	my ($self, $page, @physicians) = @_;
	my $userId =  $page->session('user_id');
	
	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_resources', $userId);

	for (@physicians)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
			item_name => 'WorkList',
			value_text => $_,
			value_int =>  1,
			_debug => 0
		);
	}
}

sub saveFacilityPref
{
	my ($self, $page, @facilities) = @_;
	my $userId = $page->session('user_id');

	$STMTMGR_COMPONENT_SCHEDULING->execute($page, STMTMGRFLAG_NONE,
		'del_worklist_facilities', $userId);

	for (@facilities)
	{
		$page->schemaAction(
			'Person_Attribute',	'add',
			item_id => undef,
			parent_id => $userId,
			parent_org_id => $page->session('org_id') || undef,
			value_type => App::Universal::ATTRTYPE_RESOURCEORG || undef,
			item_name => 'WorkList',
			value_text => $_,
			value_int =>  1,
			_debug => 0
		);
	}
}

sub getComponentHtml
{
	my ($self, $page) = @_;
	
	if($page->param('_f_action_change_resources'))
	{
		my @resources = $page->param('_f_physList');
		$self->saveResourcePref($page, @resources);
	}

	if($page->param('_f_action_change_facilities'))
	{
		my @facilities = $page->param('_f_facility_list');
		$self->saveFacilityPref($page, @facilities);
	}
	
	my $selectedDate = $page->param('_seldate') || 'today';
	$selectedDate = 'today' unless ParseDate($selectedDate);
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	my $facility_id = $page->session('org_id');
	my $user_id = $page->session('user_id');
	
	my ($time1, $time2);
	
	if ($page->session('showTimeSelect'))
	{
		$time1 = $page->session('time1') || '12:00am';
		$time2 = $page->session('time2') || '11:59pm';
	}
	else
	{
		$time1 = $page->session('time1') || 30;
		$time2 = $page->session('time2') || 120;
	}

	my @start_Date = Decode_Date_US($fmtDate);
	my @end_Date   = Add_Delta_Days (@start_Date, 1);
	my $startDate = sprintf("%02d/%02d/%04d", $start_Date[1],$start_Date[2],$start_Date[0]);
	my $endDate   = sprintf("%02d/%02d/%04d", $end_Date[1],$end_Date[2],$end_Date[0]);
	
	my $startTime = $startDate . " $time1";
	my $endTime   = $startDate . " $time2";

	my $appts;
	if ($page->param('Today'))
	{
		if ($page->session('showTimeSelect') == 0)
		{
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE, 
				'sel_events_worklist_today', $time1, $time2, $user_id, $user_id);
		} else 
		{
			$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
				'sel_events_worklist_today_byTime', $startTime, $endTime, $user_id, $user_id);
		}
	}
	else
	{
		$appts = $STMTMGR_COMPONENT_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
			'sel_events_worklist_not_today', $startDate, $endDate, $user_id, $user_id);
	}

	my @data = ();
	my $html = qq{
		<style>
			a.today {text-decoration:none; font-family:Verdana; font-size:8pt}
			strong {font-family:Tahoma; font-size:8pt; font-weight:normal}
		</style>
	};

	for (@$appts)
	{
		my ($apptMinutes, $checkinMinutes, $checkoutMinutes, $waitMinutes, $visitMinutes);
		$apptMinutes = hhmmAM2minutes($_->{appointment_time});

		if ($_->{checkin_time})
		{
			$checkinMinutes  = hhmmAM2minutes($_->{checkin_time});
			$waitMinutes = $checkinMinutes - $apptMinutes;
			$waitMinutes = 'early' if $waitMinutes < 0;
		}

		if ($_->{checkout_time})
		{
			$checkoutMinutes = hhmmAM2minutes($_->{checkout_time});
			$visitMinutes = $checkoutMinutes - $checkinMinutes;
			$visitMinutes = 'early' if $visitMinutes < 0;
		}
		
		my $deadBeatBalance = $STMTMGR_COMPONENT_SCHEDULING->getSingleValue($page, 
			STMTMGRFLAG_NONE, 'sel_deadBeatBalance', $_->{patient_id});
		
		my $copay;
		$copay = $STMTMGR_COMPONENT_SCHEDULING->getRowAsHash($page,
			STMTMGRFLAG_NONE, 'sel_copayInfo', $_->{invoice_id}) if $_->{invoice_id};

		my @rowData = (
			qq{
				<A HREF='/worklist/dlg-reschedule-appointment/$_->{event_id}' TITLE='Reschedule Appointment'><IMG SRC='/resources/icons/square-lgray-hat-sm.gif' BORDER=0></A>
				<br><nobr>
				<A HREF='/worklist/dlg-cancel-appointment/$_->{event_id}' TITLE='Cancel Appointment'><IMG SRC='/resources/icons/action-edit-remove-x.gif' BORDER=0></A>
				<A HREF='/worklist/dlg-noshow-appointment/$_->{event_id}' TITLE='No-Show Appointment'><IMG SRC='/resources/icons/schedule-noshow.gif' BORDER=0></A>
				</nobr>
			},

			qq{
				<nobr>
				<A HREF='/person/$_->{patient_id}' TITLE='$_->{patient_id} profile' class=today>
				<b>$_->{patient}</b> ($_->{patient_type})</A>
				</nobr>
				<br>

				<A HREF='/person/$_->{physician}' TITLE='$_->{physician} profile' class=today>
				$_->{physician}</A>
				(<A HREF='/org/$_->{facility}' TITLE='$_->{facility} profile' class=today>$_->{facility}</A>)
			},

			qq{
				<A HREF='/worklist/dlg-update-appointment/$_->{event_id}'
				TITLE='Update Appointment' class=today>
				<b>$_->{appointment_time}</b></A> <br>
				<strong style="color:#999999">($_->{appt_type})</strong>
			},

			qq{<nobr>
				<A HREF='javascript:alert("Confirm Appointment with $_->{patient_id}")'
				TITLE='Confirm Appointment'>
				<IMG SRC='/resources/icons/verify-appointment-incomplete.gif' BORDER=0></A>

				<A HREF='javascript:alert("Verify Insurance for $_->{patient_id}")'
				TITLE='Verify Insurance'>
				<IMG SRC='/resources/icons/verify-insurance-complete.gif' BORDER=0></A>

				<A HREF='javascript:alert("Verify Medical Records for $_->{patient_id}")'
				TITLE='Verify Medical Records'>
				<IMG SRC='/resources/icons/verify-medical-complete.gif' BORDER=0></A>

				<A HREF='javascript:alert("Verify Prerequisites for $_->{patient_id}")'
				TITLE='Verify Prerequisites'>
				<IMG SRC='/resources/icons/verify-personal-incomplete.gif' BORDER=0></A>
				</nobr>
			},

			$_->{checkin_time} ? qq{<strong>$_->{checkin_time}</strong><br>
				<strong title="Wait time in minutes" style="color:#999999">($waitMinutes)</strong>}:
				qq{<a href='/worklist/dlg-add-checkin/$_->{event_id}' class=today>CheckIn</a>},

			$_->{checkin_time} ?
				($_->{checkout_time} ? qq{<strong>$_->{checkout_time}</strong><br>
				<strong title="Visit time in minutes" style="color:#999999">($visitMinutes)</strong>} :
					qq{<a href='/worklist/dlg-add-checkout/$_->{event_id}' class=today>CheckOut</a>}
				)
				: undef ,

			$_->{invoice_id} ? qq{
				<a href='/invoice/$_->{invoice_id}' class=today><b>$_->{invoice_id}</b></a> <br>
				<strong style="color:#999999">($_->{invoice_status})</strong>
			}
				#: qq{<a href='/create/invoice_id/$_->{patient_id}' class=today>Create</a>},
				: undef,
			
			$_->{invoice_id} ? $copay->{balance} : undef,
			
			$deadBeatBalance,
			$_->{invoice_id},
			$_->{patient_id},
			$copay->{item_id},
		);

		push(@data, \@rowData);
	}

	$html .= createHtmlFromData($page, 0, \@data, 
		$App::Statements::Component::Scheduling::STMTRPTDEFN_WORKLIST);
		
	return $html;
}

# auto-register instance
new App::Component::WorkList(id => 'worklist');

1;
