##############################################################################
package App::Component::WorkList::Referral;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use Date::Calc qw(:all);
use Date::Manip;
use DBI::StatementManager;

use App::Statements::Component::Referral;

use App::Statements::Person;
use App::Statements::Scheduling;
use App::Schedule::Utilities;
use Data::Publish;
use Exporter;

use vars qw(@ISA %RESOURCE_MAP @EXPORT
	@ITEM_TYPES
	%PATIENT_URLS
	%PHYSICIAN_URLS
	%ORG_URLS
	%APPT_URLS
	$patientDefault
	$physicianDefault
	$orgDefault
	$apptDefault
);
@ISA   = qw(CGI::Component Exporter);

@ITEM_TYPES = ('patient', 'physician', 'org', 'appt');

%PATIENT_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Chart' => {arl => '/person/itemValue/chart', title => 'View Chart'},
	'View Account' => {arl => '/person/itemValue/account', title => 'View Account'},
	'Make Appointment' => {arl => '/worklist/patientflow/dlg-add-appointment/itemValue', title => 'Make Appointment'},
);

%PHYSICIAN_URLS = (
	'View Profile' => {arl => '/person/itemValue/profile', title => 'View Profile'},
	'View Schedule' => {arl => '/schedule/apptcol/itemValue', title => 'View Schedule'},
	'Add Template' => {arl => '/worklist/patientflow/dlg-add-template/itemValue', title => 'Add Schedule Template'},
);

%ORG_URLS = (
	'View Profile' => {arl => '/org/itemValue/profile', title => 'View Profile'},
	'View Fee Schedules' => {arl => '/org/itemValue/catalog', title => 'View Fee Schedules'},
);

%APPT_URLS = (
	'Reschedule' => {arl => '/worklist/patientflow/dlg-reschedule-appointment/itemValue', title => 'Reschedule Appointment'},
	'Cancel' => {arl => '/worklist/patientflow/dlg-cancel-appointment/itemValue', title => 'Cancel Appointment'},
	'No-Show' => {arl => '/worklist/patientflow/dlg-noshow-appointment/itemValue', title => 'No-Show Appointment'},
	'Update' => {arl => '/worklist/patientflow/dlg-update-appointment/itemValue', title => 'Update Appointment'},
);

$patientDefault = 'View Profile';
$physicianDefault = 'View Profile';
$orgDefault = 'View Profile';
$apptDefault = 'Update';

@EXPORT = qw(%PATIENT_URLS %PHYSICIAN_URLS %ORG_URLS %APPT_URLS @ITEM_TYPES);

%RESOURCE_MAP = (
	'worklist-referral' => {
		_class => new App::Component::WorkList::Referral(),
		},
	);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist/patientflow';

	my $facility_id = $page->session('org_internal_id');
	my $user_id = $page->session('org_id');

	$layoutDefn->{frame}->{heading} = " ";
	$layoutDefn->{style} = 'panel.transparent';
	$layoutDefn->{banner}->{actionRows} =
	[
		{
			caption => qq{
				<a href='/org/$user_id/dlg-add-referral-person'>Add Service Request</a>
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

sub getComponentHtml
{
	my ($self, $page) = @_;

	my $referrals;
	$referrals = $STMTMGR_COMPONENT_REFERRAL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_referrals_open', $page->session('org_internal_id'));

	my @data = ();
	my $html = qq{
					<script language="JavaScript1.2">
							function clickMenuRef(url)
							{
								var urlNext = url;
								window.location.href= '/' + urlNext;
							}
					</script>
					<TABLE>

						<TR VALIGN=TOP>
							<TD COLSPAN=2>
								<input type="button" value="Menu" onClick="javascript:clickMenuRef('menu');">
								<input type='button' value='Referral Followup Worklist' onClick="javascript:clickMenuRef('worklist/referral?user=physician');">
								<input type='button' value='Lookup Patient' onClick="javascript:clickMenuRef('search/patient');">
								<input type='button' value='Add Patient' onClick="javascript:clickMenuRef('org/#session.org_id#/dlg-add-patient');">
								<input type='button' value='Edit Patient' onClick="javascript:clickMenuRef('search/patient');">
								<input type='button' value='Edit Service Request' onClick="javascript:clickMenuRef('worklist/referral');">
								<input type='button' value='Add Service Request' onClick="javascript:clickMenuRef('org/#session.org_id#/dlg-add-referral-person');">
								<input type='button' value='Add Referral' onClick="javascript:clickMenuRef('worklist/referral');">
								<input type='button' value='Edit Referral' onClick="javascript:clickMenuRef('worklist/referral?user=physician');">
							</TD>
						</TR>
					</TABLE>
				};
#$_->{referral_id}

	foreach (@$referrals)
	{

		#$_->{checkin_time}

		my $referralID;
		my $orgId = $_->{org_id} ne '' ? $_->{org_id} : $page->session('org_id');

			$referralID = '/org/' . $orgId . '/dlg-add-trans-6010/' . $_->{referral_id};

		my $addCommentARL = '/org/' . $orgId . '/dlg-update-trans-6000/' . $_->{referral_id};
		my $updateReferral = '/org/' . $orgId . '/dlg-update-trans-6000/' . $_->{referral_id};

		my @rowData = (
			qq{

				<IMG VSPACE=2 HSPACE=0 ALIGN=left VALIGN=top SRC='/resources/icons/info.gif' BORDER=0 ALT='Request information'>
			},
			qq{
				$_->{referral_id}
			},
			qq{
				$_->{ref_status}
			},
			qq{
				$_->{patient}
			},
			qq{
					$_->{requested_service}
			},
			qq{
				$_->{trans_end_stamp}
			},
			qq{
				$_->{intake_coordinator}
			},
			qq{
				$_->{ssn}
			},
			qq{
				$referralID
			},
			qq{
				$addCommentARL
			},
			qq{
				$updateReferral
			},

		);

		push(@data, \@rowData);
	}

	$html .= createHtmlFromData($page, 0, \@data, $App::Statements::Component::Referral::STMTRPTDEFN_WORKLIST);

	$html .= "<i style='color=red'>No referrals data found.</i> <P>"
		if (scalar @{$referrals} < 1);

	return $html;
}

1;
