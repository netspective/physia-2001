##############################################################################
package App::Page::Person;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Number::Format;
use Date::Manip;
use App::ImageManager;

use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Invoice;
use App::Statements::Page;

use App::Dialog::Person;
use App::Dialog::Person::Patient;
use App::Dialog::Person::Physician;
use App::Dialog::Person::Nurse;
use App::Dialog::Adjustment;
use App::Dialog::PostGeneralPayment;
use App::Dialog::PostRefund;
use App::Dialog::PostTransfer;

use App::Page::Search;

use vars qw(@ISA);
@ISA = qw(App::Page);

#use constant FORMATTER => new Number::Format('INT_CURR_SYMBOL' => '$');

sub initialize
{
	my $self = shift;

	my $personId = $self->param('person_id');
	my $userId = $self->session('user_id');

	$self->SUPER::initialize(@_);

	$STMTMGR_PERSON->createPropertiesFromSingleRow($self, STMTMGRFLAG_CACHE, ['selRegistry', 'person_'], $personId);
	$self->property('person_complete_name', "Unknown ID: $personId") unless $self->property('person_complete_name');
	$self->property('person_categories', $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_id')));

	unless ($personId eq $userId)
	{
		$self->incrementViewCount($self->property('person_complete_name'), "/person/$personId/profile");
	}

	my $guarantor = 'Guarantor';
	my $guarantorName =  $STMTMGR_PERSON->getRowAsHash($self, STMTMGRFLAG_NONE, 'selAttribute', $personId, $guarantor);
	my $respPerson = $guarantorName->{'value_text'} eq $personId ? 'Self' :  $guarantorName->{'value_text'};
	$self->property('person_responsible', $respPerson);

	unless($self->property('person_categories'))
	{
		$self->disable(
				qq{
					<br>
					You do not have permission to view this information. <br>
					Either you or your organization do not have the security rights.<br><br>

					Click <a href='javascript:history.back()'>here</a> to go back.
				});
	}

	unless($personId eq $userId)
	{
		$self->addLocatorLinks(
				['Person Look-up', '/search/person'],
				[$personId, "/person/$personId/profile"],
			);
	}
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=profile$');
}

sub prepare_page_content_header
{
	my $self = shift;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	$self->SUPER::prepare_page_content_header(@_);
	return 1 if $self->flagIsSet(PAGEFLAG_ISDISABLED);

	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());
	my $personId = $self->param('person_id');

	my $category = lc($self->property('person_categories')->[0]) || undef;

	my $urlPrefix = "/person/$personId";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Summary', "$urlPrefix/profile", 'profile'],
			['Chart', "$urlPrefix/chart", 'chart'],
			['Account', "$urlPrefix/account", 'account'],
			['Activity', "$urlPrefix/activity", 'activity'],
			['Add Appointment', "$urlPrefix/appointment", 'appointment'],
			['Refills', "$urlPrefix/refill_request", 'refill_request'],
			['Voice Msgs', "$urlPrefix/phone_message", 'phone_message'],			
		], ' | ');


	push(@{$self->{page_content_header}},
		qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					$IMAGETAGS{'icon-m/person'}<B>#property.person_complete_name#</B>
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
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE CELLSPACING=0 CELLPADDING=0 BORDER=0>
			<TR>
			<FORM>
				<TD><FONT FACE="Arial,Helvetica" SIZE=4 STYLE="font-family: tahoma; font-size: 14pt">&nbsp;</TD>
				<TD ALIGN=LEFT>
					<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">
					<!--
					<A HREF="/person/$personId/dlg-add-appointment">Schedule Appointment</A> -
					<A HREF="/person/$personId/dlg-add-claim/$personId">Create Claim</A> -
					<A HREF="/person/$personId/dlg-add-medication-prescribe">Prescribe Meds</A>
					-->
					Responsible Person : #property.person_responsible#, SSN #property.person_ssn#, #property.person_gender_caption#, Age #property.person_age# (#property.person_date_of_birth#), #property.person_ethnicity#, #property.person_marstat_caption#
					</FONT>
				</TD>
				<TD ALIGN=RIGHT>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<SELECT style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
						<OPTION>Choose Action</OPTION>
						<OPTION value="/person/$personId/dlg-add-appointment">Schedule Appointment</OPTION>
						<OPTION value="/person/$personId/dlg-add-claim">Create Claim</OPTION>
						<OPTION value="/person/$personId/dlg-add-invoice">Create Invoice</OPTION>
						<OPTION value="/person/$personId/dlg-update-$category">Edit Profile</OPTION>
						<OPTION value="/person/$personId/dlg-add-medication-prescribe">Prescribe Medication</OPTION>
						<OPTION value="/person/$personId/dlg-add-refill-request">Refills</OPTION>
						<OPTION value="/person/$personId/dlg-add-phone-message">Voice Msgs</OPTION>
						<!-- <OPTION value="/person/$personId/dlg-add-">Create Note</OPTION> -->
						<OPTION value="/person/$personId/dialog/postpayment/personal">Apply Payment</OPTION>
						<OPTION value="/person/$personId/dialog/postrefund/refund">Post Refund</OPTION>
						<OPTION value="/person/$personId/dialog/posttransfer/transfer">Post Transfer</OPTION>
						<OPTION value="/person/$personId/dlg-remove-$category">Delete Record</OPTION>
					</SELECT>
					</FONT>
				<TD>
			</FORM>
			</TR>
			<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		},'<P>'
	);

	return 1;
}

sub prepare_page_content_header_home
{
	my ($self, $colors, $fonts, $personId, $personData) = @_;
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	my $urlPrefix = "/person/$personId";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Summary', "$urlPrefix/profile", 'profile'],
			['Chart', "$urlPrefix/chart", 'chart'],
			['Account', "$urlPrefix/account", 'account'],
			['Session', "$urlPrefix/session", 'session'],
		], ' | ');

	#die $personId;
	return qq{
		<TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR VALIGN=BOTTOM>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=5 COLOR=NAVY>
					$IMAGETAGS{'icon-l/home'}&nbsp;<B>$personData->{complete_name}</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT VALIGN=CENTER>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
			</TR>
		</TABLE>
		};
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;

	return if $self->property('person_denied');
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'person'));
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
}

#-----------------------------------------------------------------------------
# DIALOG MANANGEMENT METHODS
#-----------------------------------------------------------------------------

sub prepare_dialog_postpayment
{
	my $self = shift;
	my $personId = $self->param('person_id');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	my ($action, $invoiceId) = split(/,/, $dialogCmd);
	$self->param('invoice_id', $invoiceId);
	$self->param('posting_action', $action);
	#$self->addDebugStmt($payType);

	my $cancelUrl = "/person/$personId/account";
	my $dialog = new App::Dialog::PostGeneralPayment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);

	$self->addContent('<p>');
	return $self->prepare_view_account();
}

sub prepare_dialog_postrefund
{
	my $self = shift;
	my $personId = $self->param('person_id');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	#my ($action, $invoiceId) = split(/,/, $dialogCmd);
	#$self->param('invoice_id', $invoiceId);
	#$self->param('posting_action', $action);
	#$self->addDebugStmt($payType);

	my $cancelUrl = "/person/$personId/account";
	my $dialog = new App::Dialog::PostRefund(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);

	$self->addContent('<p>');
	return $self->prepare_view_account();
}

sub prepare_dialog_posttransfer
{
	my $self = shift;
	my $personId = $self->param('person_id');

	my $dialogCmd = $self->param('_pm_dialog_cmd') || 'add';
	#my ($action, $invoiceId) = split(/,/, $dialogCmd);
	#$self->param('invoice_id', $invoiceId);
	#$self->param('posting_action', $action);
	#$self->addDebugStmt($payType);

	my $cancelUrl = "/person/$personId/account";
	my $dialog = new App::Dialog::PostTransfer(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);

	$self->addContent('<p>');
	return $self->prepare_view_account();
}

#-----------------------------------------------------------------------------
# VIEW-MANAGEMENT METHODS
#-----------------------------------------------------------------------------

sub prepare_view_appointment
{
	my $self = shift;
	my $personId = $self->param('person_id');
	
	my $dialogCmd = 'add';
	my $cancelUrl = "/person/$personId/profile";
	my $dialog = new App::Dialog::Appointment(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);
}

sub prepare_view_refill_request
{
	my $self = shift;
	my $personId = $self->param('person_id');
	
	my $dialogCmd = 'add';
	my $cancelUrl = "/person/$personId/profile";
	my $dialog = new App::Dialog::Attribute::RefillRequest(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);
}

sub prepare_view_phone_message
{
	my $self = shift;
	my $personId = $self->param('person_id');
	
	my $dialogCmd = 'add';
	my $cancelUrl = "/person/$personId/profile";
	my $dialog = new App::Dialog::Attribute::PhoneMessage(schema => $self->getSchema(), cancelUrl => $cancelUrl);
	$dialog->handle_page($self, $dialogCmd);
}

sub prepare_view_update
{
	my ($self) = @_;

	my $personId = $self->param('person_id');
	unless($personId)
	{
		$self->errorBox('No person Id provided', 'person_id is a required parameter');
		return;
	};

	my $dialog = new App::Dialog::Person::Patient(schema => $self->getSchema(), cancelUrl => "/person/$personId/profile");
	$dialog->handle_page($self, 'update');

	return 1;
}

sub prepare_view_remove
{
	my ($self) = @_;

	my $personId = $self->param('person_id');
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_id'));

	unless($personId)
	{
		$self->errorBox('No person Id provided', 'person_id is a required parameter');
		return;
	};

	my $category = $personCategories->[0];

	if($category eq 'Patient')
	{
		my $dialog = new App::Dialog::Person::Patient(schema => $self->getSchema(), cancelUrl => "/person/$personId/profile");
		$dialog->handle_page($self, 'remove');
	}
	elsif($category eq 'Physician')
	{
		my $dialog = new App::Dialog::Person::Physician(schema => $self->getSchema(), cancelUrl => "/person/$personId/profile");
		$dialog->handle_page($self, 'remove');
	}
	elsif($category eq 'Nurse')
	{
		my $dialog = new App::Dialog::Person::Nurse(schema => $self->getSchema(), cancelUrl => "/person/$personId/profile");
		$dialog->handle_page($self, 'remove');
	}
	elsif($category eq 'Staff')
	{
		my $dialog = new App::Dialog::Person::Staff(schema => $self->getSchema(), cancelUrl => "/person/$personId/profile");
		$dialog->handle_page($self, 'remove');
	}

	return 1;
}

sub prepare_view_worklist
{
	my ($self) = @_;
	$self->addContent(qq{
		<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD colspan=5>
					#component.worklist# <BR>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_home
{
	my ($self) = @_;
	$self->addContent(qq{
		<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					#component.lookup-records#<BR>
					#component.navigate-reports-root#<BR>
					TO-DO List will go here
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.associatedSessionPhysicians#<BR>
					#component.stp-person.myAssociatedResourceAppointments#<BR>
					#component.stp-person.myAssociatedResourceInPatients#<BR>
					#component.stp-person.mySessionActivity#
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.create-records#<BR>
					#component.news-top#<BR>
					#component.news-health#
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_session
{
	my $self = shift;

	$self->addLocatorLinks(['Session', 'session']);

	$self->addContent(
		$STMTMGR_PERSON->createHtml($self, STMTMGRFLAG_NONE, "selSessionActivity",
			[$self->session('_session_id')],
			#[
			#	['Time'],
			#	['Event'],
			#	['Details'],
			#	['Scope',
			#		{
			#			'person' => 'Person (<a href="/person/%4/profile">%4</a>)',
			#			'org' => 'Organization (<a href="/org/%4/profile">%4</a>)',
			#			'insurance' => 'Organization (<a href="/org/%4/profile">%4</a>)',
			#			'person_attribute' => 'Person (<a href="/person/%4/profile">%4</a>)',
			#			'offering_catalog' => 'FeeSchedule (<a href="/search/catalog/detail/%4">%4</a>)',
			#			'offering_catalog_entry' => 'FeeSchedule (<a href="/search/catalog/detail/%4">%4</a>)',
			#			'invoice' => 'Claim (<a href="/invoice/%4/summary">%4</a>)',
			#			'invoice_item' => 'Claim (<a href="/invoice/%4">%4</a>)',
			#			'transaction' => 'Person (<a href="/person/%4/profile">%4</a>)',
			#			'person_address' => 'Person (<a href="/person/%4/profile">%4</a>)',
			#			'org_address' => 'Organization (<a href="/org/%4/profile">%4</a>)',
			#			'org_attribute' => 'Organization (<a href="/org/%4/profile">%4</a>)',
					#}]

			#]
			),
		);

	return 1;
}

sub prepare_view_profile
{
	my ($self) = @_;

	$self->addLocatorLinks(['Summary', 'profile']);
	my $personId = $self->param('person_id');
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_id'));
	my $category = $personCategories->[0];
	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.phoneMessage#<BR>
					#component.stpt-person.insurance#<BR>
					#component.stpt-person.careProviders#<BR>
					#component.stpt-person.employmentAssociations#<BR>
					#component.stpt-person.emergencyAssociations#<BR>
					#component.stpt-person.familyAssociations#<BR>
					#component.stpt-person.additionalData#
					#component.stpt-person.diagnosisSummary#<BR>
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.miscNotes#<BR>
					<font size=1 face=arial>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
						<TR VALIGN=TOP>
							<TD>#component.stp-person.alerts#</TD>
							<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
							<TD>#component.stp-person.activeMedications#</TD>
						</TR>
					</TABLE><BR>
					#component.stp-person.refillRequest#<BR>					
					#component.stp-person.hospitalizationSurgeriesTherapies#<BR>
					#component.stp-person.activeProblems#<BR>
					#component.stp-person.authorization#<BR>
						<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
							<TR VALIGN=TOP>
								<TD>#component.stp-person.attendance#</TD>
								<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
								<TD>#component.stp-person.certification#</TD>
							</TR>
						</TABLE><BR>
					#component.stp-person.affiliations#<BR>
					#component.stp-person.associatedSessionPhysicians#<BR>
					#component.stp-person.benefits#</BR>				
					</font>
				</TD>
				<!--
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<font size=1 face=arial>					
					#component.st-person.diagnosisSummary#<BR>
					</font>
				</TD>
				-->
				<!--
				<TD WIDTH=25%>
					<font size=1 face=arial>
					#component.stpt-person.allergies#<BR>
					#component.stpt-person.preventiveCare#<BR>
					#component.stpt-person.advancedDirectives#<BR>
					</font>
				</TD>
				-->
			</TR>
		</TABLE>
	});
}


##### #component.stp-person.diagnosisSummaryTitle# 


sub prepare_view_chart
{
	my ($self) = @_;

	$self->addLocatorLinks(['Chart', 'chart']);

	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
						<TR VALIGN=TOP>
							<TD>#component.stp-person.alerts#</TD>
							<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
							<TD>#component.stp-person.activeMedications#</TD>
						</TR>
					</TABLE><BR>
					#component.stp-person.patientAppointments#</BR>
					#component.stp-person.hospitalizationSurgeriesTherapies#<BR>
					#component.stp-person.activeProblems#<BR>
					#component.stp-person.surgeryProcedures#<BR>
					#component.stp-person.testsAndMeasurements#
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.careProviders#<BR>
					#component.stpt-person.allergies#<BR>
					#component.stpt-person.preventiveCare#<BR>
					#component.stpt-person.advancedDirectives#<BR>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.insurance#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_account
{
	my ($self) = @_;

	$self->addLocatorLinks(['Account', 'account']);

	my $personId = $self->param('person_id');
	my $todaysDate = $self->getDate();
	my $invoiceType = App::Universal::INVOICETYPE_HCFACLAIM;
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	$self->addContent(
		'<CENTER>',
		$STMTMGR_INVOICE->createHtml($self, STMTMGRFLAG_NONE, 'selInvoiceTypeForClient',
			[$personId, $self->session('org_id')],
			#[
			#	['<SPAN TITLE="Claim Identifier">ID</SPAN>', '<A HREF=\'/invoice/%0\'>%0</A>', undef, 'RIGHT'],
			#	['<SPAN TITLE="Number of Items in Claim">IC</SPAN>', undef, undef, 'CENTER'],
			#	['Date'],
			#	['Status'],
			#	['Payer'],
			#	['Reference'],
			#	['Total', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
			#	['Adjust', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
			#	['Balance', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
			#]
			),
		'</CENTER>'
		);
}

sub prepare_view_activity
{
	my ($self, $flags, $colors, $fonts, $viewParamValue) = @_;

	$self->addLocatorLinks(['Activity', 'activity']);
	$self->addContent(" ", $self->param('errorcode'), " -- NOT YET IMPLEMENTED.");

	my $personId = $self->param('person_id');

	#$self->addHeaderPane(new App::Pane::Person::Encounters(style => App::Pane::PANESTYLE_PAGE, mode => App::Pane::PANEMODE_VIEW, dataStyle => $App::Pane::DATASTYLE_SUMMARY, personId => $personId));

	return 1;
}

sub prepare_view_dialog
{
	my $self = shift;
	my $dialog = $self->param('_pm_dialog');

	if(my $method = $self->can("prepare_dialog_$dialog"))
	{
		return &{$method}($self);
	}
	else
	{
		$self->addError("Can't find prepare_dialog_$dialog method");
	}
	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# person_id must be the first item in the path
	return 'UIE-001010' unless $pathItems->[0];

	$pathItems->[0] = uc($pathItems->[0]);
	$self->param('person_id', $pathItems->[0]);

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];

		if(defined $pathItems->[2] && $self->param('_pm_view') eq 'dialog')
		{
			$self->param('_pm_dialog', $pathItems->[2]);
			$self->param('_pm_dialog_cmd', $pathItems->[3]) if defined $pathItems->[3];
		}
		else
		{
			unless($pathItems->[1])
			{
				$self->redirect("/$arl/profile");
				$self->send_http_header();
				return 0;
			}

			if(scalar(@$pathItems) > 3)
			{
				$self->param('_panefile', $pathItems->[2]);
				$self->param('_panepkg', $pathItems->[3]);
			}
			else
			{
				$self->param('_panefile', $pathItems->[2]);
				$self->param('_panepkg', $pathItems->[2]);
			};
			$self->param('_panemode', 2);
		}
	}

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
