##############################################################################
package App::Page::Search::Home;
##############################################################################

use strict;
use App::Page::Search;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/_default' => {},
	);

sub getForm
{
	return ('Lookup or add a record');
}

sub prepare
{
	my $self = shift;
	$self->addContent(qq{
		<CENTER>
		<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=5>
		<TR VALIGN=TOP>
			<TD>
			<TABLE BGCOLOR=WHITE BORDER=0 CELLSPACING=1 CELLPADDING=2>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=3 COLOR=NAVY><B>People</B></FONT></TD>
				</TR>
				<TR><TD COLSPAN=2><IMG SRC="/resources/design/bar.gif" HEIGHT=1 WIDTH=100%></TD></TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Lookup</b>
						<a href="/search/person">All Persons</a>,
						<a href="/search/patient">Patients</a>,
						<a href="/search/physician">Physician/Providers</a>,
						<a href="/search/nurse">Nurses</a>, or
						<a href="/search/staff">Staff Members</a>.
						<a href="/search/associate">Personnel</a>.
					</TD>
				</TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Add</b> a new <a href="/org/#session.org_id#/dlg-add-patient">Patient</a>,
						<a href="/org/#session.org_id#/dlg-add-physician">Physician/Provider</a>,
						<a href="/org/#session.org_id#/dlg-add-nurse">Nurse</a>, or
						<a href="/org/#session.org_id#/dlg-add-staff">Staff Member</a> record.
					</TD>
				</TR>
			</TABLE>
			<P>
			<TABLE BGCOLOR=WHITE BORDER=0 CELLSPACING=1 CELLPADDING=2>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=3 COLOR=NAVY><B>Organizations</B></FONT></TD>
				</TR>
				<TR><TD COLSPAN=2><IMG SRC="/resources/design/bar.gif" HEIGHT=1 WIDTH=100%></TD></TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Lookup</b>
						<a href="/search/org">Departments</a>,
						<a href="/search/org">Associated Providers</a>,
						<a href="/search/org">Employers</a>,
						<a href="/search/org">Insururs</a>, or
						<a href="/search/org">IPAs</a>.
					</TD>
				</TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Add</b> a new
						<a href="/org/#session.org_id#/dlg-add-org-main">Main Organization</a>,
						<a href="/org/#session.org_id#/dlg-add-org-dept">Department</a>,
						<a href="/org/#session.org_id#/dlg-add-org-provider">Associated Provider</a>,
						<a href="/org/#session.org_id#/dlg-add-org-employer">Employer</a>,
						<a href="/org/#session.org_id#/dlg-add-org-insurance">Insurance</a>,
						<a href="/org/#session.org_id#/dlg-add-org-ipa">IPA</a>
						record.
					</TD>
				</TR>
			</TABLE>
			<P>
			<TABLE BGCOLOR=WHITE BORDER=0 CELLSPACING=1 CELLPADDING=2>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=3 COLOR=NAVY><B>References/Codes</B></FONT></TD>
				</TR>
				<TR><TD COLSPAN=2><IMG SRC="/resources/design/bar.gif" HEIGHT=1 WIDTH=100%></TD></TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Lookup</b>
						<a href="/search/icd">ICD-9</a>,
						<a href="/search/cpt">CPT</a>,
						<a href="/search/hcpcs">*HCPCS</a>,
						<a href="/search/serviceplace">Service Place</a>,
						<a href="/search/servicetype">Service Type</a>, or
						<a href="/search/envoypayer">Envoy Payer</a>.
					</TD>
				</TR>
			</TABLE>
			</TD>
			<TD>
			<TABLE BGCOLOR=WHITE BORDER=0 CELLSPACING=1 CELLPADDING=2>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=3 COLOR=NAVY><B>Billing</B></FONT></TD>
				</TR>
				<TR><TD COLSPAN=2><IMG SRC="/resources/design/bar.gif" HEIGHT=1 WIDTH=100%></TD></TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Lookup</b>
						<a href="/search/claim">Claims</a>,
						<a href="/search/catalog">Fee Schedules</a>,
						<a href="/search/insproduct">Insurance Product</a>,
						<a href="/search/insplan">Insurance Plan</a>.
					</TD>
				</TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Add</b> a new
						<a href="/org/#session.org_id#/dlg-add-claim">Claim</a>,
						<a href="/org/#session.org_id#/dlg-add-catalog">Fee Schedule</a>,
						<a href="/org/#session.org_id#/dlg-add-catalog-item">Fee Schedule Item</a>,
						<a href="/org/#session.org_id#/dlg-add-ins-product">Insurance Product</a>,
						<a href="/org/#session.org_id#/dlg-add-ins-plan">Insurance Plan</a>.
						<a href="/org/#session.org_id#/dlg-add-ins-coverage">Personal Insurance Coverage</a>.
					</TD>
				</TR>
			</TABLE>
			<P>
			<TABLE BGCOLOR=WHITE BORDER=0 CELLSPACING=1 CELLPADDING=2>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD COLSPAN=2><FONT FACE="Arial,Helvetica" SIZE=3 COLOR=NAVY><B>Appointments/Scheduling</B></FONT></TD>
				</TR>
				<TR><TD COLSPAN=2><IMG SRC="/resources/design/bar.gif" HEIGHT=1 WIDTH=100%></TD></TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD><FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Lookup</b>
						<a href="/search/appointment">Existing Appointment</a>,
						<a href="/search/apptslot">Next Available Appointment Slot</a>
						<a href="/search/template">Scheduling Template</a>, or
						<a href="/search/appttype">Appointment Type</a>
					</TD>
				</TR>
				<TR VALIGN=TOP BGCOLOR=WHITE>
					<TD><IMG SRC='/resources/icons/arrow_right_red.gif'></TD>
					<TD>
						<FONT FACE="Arial,Helvetica" SIZE=2>
						<b>Add</b> a new
						<a href="/org/#session.org_id#/dlg-add-appointment">Appointment</a>
						<a href="/org/#session.org_id#/dlg-add-template">Schedule Template</a>, or
						<a href="/org/#session.org_id#/dlg-add-appttype">Appointment Type</a>
					</TD>
				</TR>
			</TABLE>
			</TD>
		</TR>
		</TABLE>
		</CENTER>
	});

	return 1;
}

1;
