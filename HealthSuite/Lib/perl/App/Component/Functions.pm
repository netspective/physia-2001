##############################################################################
package App::Component::Construct;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use vars qw(@ISA %RESOURCE_MAP);
@ISA   = qw(CGI::Component);

use constant ON_CHANGE => q{ onchange='document.location.href = this.options[this.selectedIndex].value' };
use constant CONTENT_HTML => qq{
	<TABLE>
		<FORM ACTION="" METHOD=POST>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#People:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION>Select type</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-patient">Patient</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-physician">Physician</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-nurse">Nurse</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-staff">Staff Member</OPTION>
				</SELECT>
			</TD>
		</TR>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Organizations:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION>Select type</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-org-dept">Department</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-org-provider">Associated Provider</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-org-employer">Employer</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-org-insurance">Insurance</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-org-ipa">IPA</OPTION>
				</SELECT>
			</TD>
		</TR>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Billing:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION>Select type</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-claim">Claim</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-catalog">Fee Schedule</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-catalog-item">Fee Schedule Item</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-ins-product">Insurance Product</OPTION>
					<OPTION VALUE="/org/#session.org_id#/dlg-add-ins-plan">Insurance Plan</OPTION>
				</SELECT>
			</TD>
		</TR>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Appointments:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION>Select type</OPTION>
					<OPTION VALUE="/schedule/dlg-add-appointment?_dialogreturnurl=/#param.arl#">Appointment</OPTION>
					<OPTION VALUE="/schedule/dlg-add-template?_dialogreturnurl=/#param.arl#">Schedule Template</OPTION>
					<OPTION VALUE="/schedule/dlg-add-appttype">Appointment Type</OPTION>
				</SELECT>
			</TD>
		</TR>
		</FORM>
	</TABLE>
};

%RESOURCE_MAP = (
	'create-records' => {
		_class => new App::Component::Construct(),
		},
	);

sub init
{
	my $self = shift;
	$self->{layoutDefn}->{frame}->{heading} = 'Add a new record';
}

sub getHtml
{
	my ($self, $page) = @_;
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, CONTENT_HTML);
}


##############################################################################
package App::Component::OnSelect;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use vars qw(@ISA %RESOURCE_MAP);
@ISA   = qw(CGI::Component);

use constant ON_CHANGE => q{ onchange='document.location.href = this.options[this.selectedIndex].value' };
use constant CONTENT_HTML => qq{
	<TABLE>
		<FORM ACTION="" METHOD=POST>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Patient:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION VALUE="#">View Profile</OPTION>
					<OPTION VALUE="#">View Account</OPTION>
					<OPTION VALUE="#">Add Prescription</OPTION>
				</SELECT>
			</TD>
		</TR>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Physician:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION VALUE="#">View Profile</OPTION>
					<OPTION VALUE="#">View Schedule</OPTION>
					<OPTION VALUE="#">View Templates</OPTION>
				</SELECT>
			</TD>
		</TR>

		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Organization:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION VALUE="#">View Profile</OPTION>
					<OPTION VALUE="#">Add Fee Schedule</OPTION>
				</SELECT>
			</TD>
		</TR>
		<TR>
			<TD ALIGN=RIGHT>#fmtdefn.defaultFontOpen#Appointment:#fmtdefn.defaultFontClose#</TD>
			<TD>
				<SELECT @{[ ON_CHANGE ]}>
					<OPTION VALUE="#">Reschedule</OPTION>
					<OPTION VALUE="#">Cancel</OPTION>
					<OPTION VALUE="#">No-Show</OPTION>
					<OPTION VALUE="#">Update</OPTION>
				</SELECT>
			</TD>
		</TR>
		</FORM>
	</TABLE>
};

%RESOURCE_MAP = (
	'on-select' => {
		_class => new App::Component::OnSelect(),
		},
	);

sub init
{
	my $self = shift;
	$self->{layoutDefn}->{frame}->{heading} = 'On Select';
}

sub getHtml
{
	my ($self, $page) = @_;
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, CONTENT_HTML);
}


##############################################################################
package App::Component::Lookup;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use vars qw(@ISA %RESOURCE_MAP);
@ISA   = qw(CGI::Component);

use constant CONTENT_HTML => qq{
	<nobr><input type="radio" name="search_scope" value="person" checked ondblclick="location.href='/search/'+this.value">Person/Patient</nobr><br>
	<nobr><input type="radio" name="search_scope" value="appointment"  ondblclick="location.href='/search/'+this.value">Appointment
	<nobr><input type="radio" name="search_scope" value="apptslot" ondblclick="location.href='/search/'+this.value">Avail. Slot&nbsp;</nobr><br>
	<nobr><input type="radio" name="search_scope" value="claim" ondblclick="location.href='/search/'+this.value">Claim/Invoice</nobr><br>
	<nobr><input type="radio" name="search_scope" value="insplan" ondblclick="location.href='/search/'+this.value">Ins./Workers Comp Plan&nbsp;</nobr><br>
	<nobr><input type="radio" name="search_scope" value="org" ondblclick="location.href='/search/'+this.value">Organization/Facility</nobr><br>
	<nobr>
		<input type="radio" name="search_scope" value="icd" ondblclick="location.href='/search/'+this.value">ICD-9
		<input type="radio" name="search_scope" value="cpt" ondblclick="location.href='/search/'+this.value">CPT
		<input type="radio" name="search_scope" value="hcpcs" ondblclick="location.href='/search/'+this.value">HCPCS
	</nobr><br>
	<nobr>
		<input type="radio" name="search_scope" value="drug/name" ondblclick="location.href='/search/'+this.value">Drug Name
		<input type="radio" name="search_scope" value="drug/keyword" ondblclick="location.href='/search/'+this.value">Drug Keywords
	</nobr><br>
	<input name="search_expression"><input type="submit" value="Search">
};

%RESOURCE_MAP = (
	'lookup-records' => {
		_class => new App::Component::Lookup(),
		},
	);

sub init
{
	my $self = shift;
	my $layoutDefn = $self->{layoutDefn};
	$layoutDefn->{formAction} = '/search/auto';
	$layoutDefn->{frame}->{heading} = 'Lookup a record';
}

sub getHtml
{
	my ($self, $page) = @_;
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, CONTENT_HTML);
}

1;
