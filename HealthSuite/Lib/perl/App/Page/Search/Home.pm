##############################################################################
package App::Page::Search::Home;
##############################################################################

use strict;
use App::Page::Search;
use CGI::ImageManager;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/_default' => {
		_title => 'Main Menu',
		_iconSmall => 'images/page-icons/search',
		_iconMedium => 'images/page-icons/search',
		_iconLarge => 'images/page-icons/search',
		},
	);

sub getForm
{
	return ('Main Menu');
}

sub prepare_page_content_header
{
	my $self = shift;
	my $urlPrefix = "/search";
	my $functions = $self->getMenu_ComboBox(App::Page::MENUFLAG_SELECTEDISLARGER,
		'lookup_record',
		[
			['Lookup...'],
			['All Persons', "$urlPrefix/person", 'person'],
			['Patients', "$urlPrefix/patient", 'patient'],
			['Claims', "$urlPrefix/claim", 'claim'],
			['Appointments', "$urlPrefix/appointment", 'appointment'],
			['Appointment Types', "$urlPrefix/appttype", 'appttype'],
			['Available Slots', "$urlPrefix/apptslot", 'apptslot'],
			['Organizations', "$urlPrefix/org", 'org'],
			['Insurance Products', "$urlPrefix/insproduct", 'insproduct'],
			['Insurance Plans', "$urlPrefix/insplan", 'plan'],
			['Fee Schedules', "$urlPrefix/catalog", 'catalog'],
			['ICD', "$urlPrefix/icd", 'icd'],
			['CPT', "$urlPrefix/cpt", 'cpt'],
			['HCPCS', "$urlPrefix/cpt", 'hcpcs'],
			['EPSDT', "$urlPrefix/epsdt", 'epsdt'],
			['Misc Procedure Code', "$urlPrefix/miscprocedure", 'miscprocedure'],
			['Schedule Template', "$urlPrefix/template", 'template'],
			['User Sessions', "$urlPrefix/session", 'session'],
		]);

	my $addFunctions = $self->getMenu_ComboBox(App::Page::MENUFLAG_SELECTEDISLARGER,
		'add_record',
		[
			['Add...'],
			['Patient', "/org/#session.org_id#/dlg-add-patient", 'patient'],
			['Claim', "/org/#session.org_id#/dlg-add-claim", 'claim'],
			['Appointment', "/schedule/dlg-add-appointment?_dialogreturnurl=/menu", 'appointment'],
			['Appointment Type', "/org/#session.org_id#/dlg-add-appttype", 'appttype'],
			['Insurance Org', "/org/#session.org_id#/dlg-add-org-insurance", 'insurance'],
			['Insurance Product', "/org/#session.org_id#/dlg-add-ins-product", 'insproduct'],
			['Insurance Plan', "/org/#session.org_id#/dlg-add-ins-plan", 'insplan'],
			['Fee Schedule', "/org/#session.org_id#/dlg-add-catalog", 'catalog'],
			['Batch Payment', "/org/#session.org_id#/dlg-add-batch", 'batch'],
			['Monthly Cap Payment', "/org/#session.org_id#/dlg-add-postcappayment", 'postcappayment'],
			['Schedule Template', "/schedule/dlg-add-template?_dialogreturnurl=/menu", 'template'],
		]);


	push (@{$self->{page_content_header}}, qq{
		<table width=100% bgcolor="#EEEEEE" cellspacing="0" cellpadding="0" border="0"><tr><form><td align="right">
			$functions
			$addFunctions
		</td></form></tr><tr><td>
			@{[ getImageTag('design/bar', { width => "100%", height => "1", }) ]}<br>
		</td></tr></table>
	});

	$self->SUPER::prepare_page_content_header(@_);

}

sub prepare
{
	my $self = shift;
	$self->addContent(qq{
		<center>
		<table border="0" cellspacing="0" cellpadding="5" align="center"><tr valign="top"><td>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				$IMAGETAGS{'images/page-icons/person'}
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>People</b></font>
			</td></tr><tr><td colspan="2">
				@{[ getImageTag('design/bar', { height => "1", width => "100%", }) ]}<br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/person">All Persons</a>,
					<a href="/search/patient">Patients</a>,
					<a href="/search/physician">Physician / Providers</a>,
					<a href="/search/referring-Doctor">Referring Doctors</a>,
					<a href="/search/nurse">Nurses</a>,
					<a href="/search/staff">Staff Members</a>, or
					<a href="/search/associate">Personnel</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new <a href="/org/#session.org_id#/dlg-add-patient">Patient</a>,
					<a href="/org/#session.org_id#/dlg-add-physician">Physician / Provider</a>,
					<a href="/org/#session.org_id#/dlg-add-referring-doctor">Referring Doctor</a>,
					<a href="/org/#session.org_id#/dlg-add-nurse">Nurse</a>, or
					<a href="/org/#session.org_id#/dlg-add-staff">Staff Member</a>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				$IMAGETAGS{'images/page-icons/org'}
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Organizations</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/org">Departments</a>,
					<a href="/search/org">Associated Providers</a>,
					<a href="/search/org">Employers</a>,
					<a href="/search/org">Insurers</a>, or
					<a href="/search/org">IPAs</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/org/#session.org_id#/dlg-add-org-dept">Department</a>,
					<a href="/org/#session.org_id#/dlg-add-org-provider">Associated Provider</a>,
					<a href="/org/#session.org_id#/dlg-add-org-employer">Employer</a>,
					<a href="/org/#session.org_id#/dlg-add-org-insurance">Insurance</a>, or
					<a href="/org/#session.org_id#/dlg-add-org-ipa">IPA</a>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor="white" border="0" cellspacing="1" cellpadding="2"><tr valign="top" bgcolor="white"><td valign="middle">
				$IMAGETAGS{'images/page-icons/reference'}
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>References / Codes</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/icd">ICD-9</a>,
					<a href="/search/cpt">CPT</a>,
					<a href="/search/hcpcs">HCPCS</a>,
					<a href="/search/epsdt">EPSDT</a>,
					<a href="/search/miscprocedure">Misc Procedure Code</a>,
					<a href="/search/modifier">Modifier</a>,
					<a href="/search/serviceplace">Service Place</a>,
					<a href="/search/servicetype">Service Type</a>,
					<a href="/search/gpci">GPCI</a>, or
					<a href="/search/epayer">E-Remit Payer</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/org/#session.org_id#/dlg-add-misc-procedure">Misc Procedure Code</a>
				</font>
		</td></tr></table></td><td>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				$IMAGETAGS{'images/page-icons/accounting'}
			</td><td valign="middle">
				<font face="arial,helvetica" size=5 color=navy><b>Accounting / Billing</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%></td></tr>
			<tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/claim">Claims</a>,
					<a href="/search/catalog">Fee Schedules</a>,
					<a href="/search/insproduct">Insurance Product</a>, or
					<a href="/search/insplan">Insurance Plan</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/org/#session.org_id#/dlg-add-claim">Claim</a>,
					<a href="/org/#session.org_id#/dlg-add-batch">Batch Payment</a>,
					<a href="/org/#session.org_id#/dlg-add-postcappayment">Monthly Cap Payment</a>,
					<a href="/org/#session.org_id#/dlg-add-close-date">Close Date</a>,
					<a href="/org/#session.org_id#/dlg-add-catalog">Fee Schedule</a>,
					<a href="/org/#session.org_id#/dlg-add-catalog-item">Fee Schedule Item</a>,
					<a href="/org/#session.org_id#/dlg-add-ins-product">Insurance Product</a>,
					<a href="/org/#session.org_id#/dlg-add-ins-plan">Insurance Plan</a>, or
					<a href="/org/#session.org_id#/dlg-add-ins-coverage">Personal Insurance Coverage</a>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				$IMAGETAGS{'images/page-icons/schedule'}
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Appointments / Scheduling</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Lookup</b>
					<a href="/search/appointment">Existing Appointment</a>,
					<a href="/search/apptslot">Next Available Appointment Slot</a>
					<a href="/search/template">Scheduling Template</a>, or
					<a href="/search/appttype">Appointment Type</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}
			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Add</b> a new
					<a href="/schedule/dlg-add-appointment?_dialogreturnurl=/menu">Appointment</a>
					<a href="/schedule/dlg-add-template?_dialogreturnurl=/menu">Schedule Template</a>, or
					<a href="/schedule/dlg-add-appttype?">Appointment Type</a>
				</font>
			</td></tr></table>
			<p>
			<table bgcolor=white border=0 cellspacing=1 cellpadding=2><tr valign=top bgcolor=white><td valign="middle">
				$IMAGETAGS{'images/page-icons/tools'}
			</td><td valign="middle">
				<font face="arial,helvetica" size="5" color="navy"><b>Utilities / Functions</b></font>
			</td></tr><tr><td colspan=2>
				<img src="/resources/design/bar.gif" height=1 width=100%><br>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}

			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Print Destination</b>
					<a href="/utilities/printerSpec" title="Select paper-claim printer">Paper Claims Printer</a>
				</font>
			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}

			</td><td>
				<font face="arial,helvetica" size=2>
					<b>Paper Claims</b>
					<a href="/utilities" title="Create a new batch of paper claims for printing">Create new Batch</a>,&nbsp;
					<a href="/paperclaims" title="Print a batch of paper claims">Print</a>
				</font>

			</td></tr><tr valign=top bgcolor=white><td align="right">
				$IMAGETAGS{'icons/arrow_right_red'}

			</td><td>
				<font face="arial,helvetica" size=2>
					<b>EDI Reports</b>
					<a href="/edi" title="View reports from Clearing House">View</a>
				</font>

			</td></tr></table>
		</td></tr></table>

		</td></tr></table>
		</center>
	});

	return 1;
}

1;
