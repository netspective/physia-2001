##############################################################################
package App::Component::WorkList::ReferralPhysician;
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
	'worklist-referral-physician' => {
		_class => new App::Component::WorkList::ReferralPhysician(),
		},
	);

sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist/patientflow';

	my $facility_id = $page->session('org_internal_id');
	my $user_id = $page->session('user_id');

	$layoutDefn->{frame}->{heading} = " ";
	$layoutDefn->{style} = 'panel.transparent';

	$layoutDefn->{banner}->{actionRows} =
	[
		{
			caption => qq{
				<a href='/person/$user_id/dlg-add-referral'>Add Referral</a>
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
	my $userID = $page->session('user_id');
	$referrals = $STMTMGR_COMPONENT_REFERRAL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_referrals_physician', $userID, $userID, $userID, $userID);
	#$referrals = $STMTMGR_COMPONENT_REFERRAL->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'sel_referrals_physician', $userID, $userID);

	my @data = ();
	my $html = qq{
		<style>
			a.today {text-decoration:none; font-family:Verdana; font-size:8pt}
			strong {font-family:Tahoma; font-size:8pt; font-weight:normal}
		</style>
	};
#$_->{referral_id}
	foreach (@$referrals)
	{
		#$_->{checkin_time}

		my $referralID;
		if ($_->{trans_id_mod} eq $_->{referral_id})
		{
			$referralID = '/person/' . $_->{patient_id} . '/dlg-add-trans-6010/' . $_->{trans_id_mod};
		}
		else
		{
			$referralID = '/person/' . $_->{patient_id} . '/dlg-update-trans-6010/' . $_->{trans_id_mod};
		}

		my $addCommentARL = '/person/' . $_->{patient_id} . '/dlg-add-trans-6020/' . $_->{trans_id_mod};

		my @rowData = (
			qq{

				<IMG VSPACE=2 HSPACE=0 ALIGN=left VALIGN=top SRC='/resources/icons/info.gif' BORDER=0 ALT='Request information'>
			},
			qq{
				$_->{trans_id_mod}
			},
			qq{
				$_->{trans_status_reason}
			},
			qq{
				$_->{patient}
			},
			qq{
				$_->{service_provider}
			},
			qq{
				$_->{service_provider_type}
			},
			qq{
				$_->{requested_service}
			},
			qq{
				$_->{trans_end_stamp}
			},
			qq{
				$referralID
			},
			qq{
				$addCommentARL
			},
		);

		push(@data, \@rowData);
	}

	$html .= createHtmlFromData($page, 0, \@data, $App::Statements::Component::Referral::STMTRPTDEFN_WORKLIST);

	$html .= "<i style='color=red'>No referrals data found.</i> <P>"
		if (scalar @{$referrals} < 1);

	#$html .= $userID;

	return $html;
}

1;
