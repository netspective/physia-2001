##############################################################################
package App::Page::Person;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Number::Format;
use Date::Manip;
use App::ImageManager;
use CGI::ImageManager;

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
use App::Dialog::Budget;
#use App::Dialog::BillingCycle;
use App::Statements::Worklist::WorklistCollection;
use App::Page::Search;
use App::Configuration;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'person' => {
		_views => [
			{caption => 'Summary', name => 'profile',},
			{caption => 'Chart', name => 'chart',},
			{caption => 'Account', name => 'account',},
			{caption => 'Activity', name => 'activity',},
			{caption => 'Home', name => 'home',},
			{caption => 'Face Sheet', name => 'facesheet',},
			{caption => 'Associate', name => 'associate',},
			{caption => 'Home', name=>'home',},
			],
		_iconMedium => 'icon-m/person',
		},
	);

#use constant FORMATTER => new Number::Format('INT_CURR_SYMBOL' => '$');

sub initialize
{
	my $self = shift;

	my $personId = $self->param('person_id');
	my $userId = $self->session('user_id');
	$self->SUPER::initialize(@_);

	$STMTMGR_PERSON->createPropertiesFromSingleRow($self, STMTMGRFLAG_CACHE, ['selRegistry', 'person_'], $personId);
	$self->property('person_simple_name', "Unknown ID: $personId") unless $self->property('person_simple_name');
	my $categories = $self->property('person_categories', $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_internal_id')));
	my $personCategory = defined $categories ? join(', ', @$categories) : '';
	$self->property('person_org_category', $personCategory);

	unless ($personId eq $userId)
	{
		$self->incrementViewCount($self->property('person_simple_name'), "/person/$personId/profile");
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


	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		if ($self->hasPermission("page/person/$activeView"))
		{
			if (($activeView eq 'home') && ($personId ne $userId))
			{
				$self->disable(
						qq{
							<br>
							You do not have permission to view this information.
							Only the user $personId can view this page.

							Click <a href='javascript:history.back()'>here</a> to go back.
						});
			}
		}
		else
		{
			$self->disable(
					qq{
						<br>
						You do not have permission to view this information.
						Permission page/person/$activeView is required.

						Click <a href='javascript:history.back()'>here</a> to go back.
					});
		}
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

	my $personId = $self->param('person_id');
	my $urlPrefix = "/person/$personId";


	my $sessionUserID = $self->session('user_id');
	#
	my $showSummary=0;
	my $summaryList = 'ALL_CATEGORIES';

	my $showChart=0;
	my $chartList = 'PATIENT';

	my $showAccount=0;
	my $accountList = 'PATIENT|GUARANTOR';

	my $showActivity=0;
	my $activityList = '';

	my $showAssociate=0;
	my $assoicateList = 'STAFF|NURSE|PHYSICIAN|ADMINISTRATOR|REFERRING-DOCTOR';

	my $showHome=0;

	#Get Categories
	my $categories = $self->property('person_categories');

	#Add all options
	push (@$categories,'ALL_CATEGORIES');
	$showSummary=1 if grep {uc($_)=~m/$summaryList/} @$categories;
	$showChart=1 if grep {uc($_)=~m/$chartList/} @$categories;
	$showAccount=1 if grep {uc($_)=~m/$accountList/} @$categories;
	$showAssociate=1 if grep {uc($_)=~m/$assoicateList/} @$categories;
	$showActivity=1 if grep {uc($_)=~m/$activityList/} @$categories;

	#Only show home option is person is looking at their page
	$showHome=1 if ($personId eq $sessionUserID);



	$self->{page_heading} = $self->property('person_simple_name');
	$self->{page_menu_sibling} = [
			$showHome ? ['Home', "$urlPrefix/home",'home'] : undef,
			$showSummary ? ['Summary', "$urlPrefix/profile", 'profile']: undef,
			$showChart ? ['Chart', "$urlPrefix/chart", 'chart']: undef,
			$showAccount ? ['Account', "$urlPrefix/account", 'account'] : undef,,
			$showActivity ? ['Activity', "$urlPrefix/activity", 'activity'] : undef,
			$showAssociate ? ['Associate', "$urlPrefix/associate",'associate'] : undef,
			#['Face Sheet', "javascript:doActionPopup(\"/person-p/$personId/facesheet\")", 'facesheet'],
			#['Add Appointment', "$urlPrefix/appointment", 'appointment'],
		];
	$self->{page_menu_siblingSelectorParam} = '_pm_view';

	$self->SUPER::prepare_page_content_header(@_);

	return 1 if $self->flagIsSet(PAGEFLAG_ISDISABLED);

	my $category = lc($self->property('person_categories')->[0]) || undef;
	# If the category isnt one of the predefined four, assume its staff.
	my $updateCategory = $category;
	unless (($category eq 'nurse') or ($category eq 'physician') or ($category eq 'staff') or ($category eq 'patient') or ($category eq 'referring-doctor') or ($category eq 'guarantor')) {
		$updateCategory = 'staff';
	}

	my $profileLine = '<b>Profile: </b>';
	$profileLine .= '<font color=red>(Account in Collection)</font>' if $STMTMGR_WORKLIST_COLLECTION->recordExists($self, STMTMGRFLAG_NONE, 'selInColl', $personId);
	$profileLine .=  '&nbsp;Category: #property.person_org_category# ' if $self->property('person_org_category');
	$profileLine .= '&nbsp;SSN #property.person_ssn# ' if $self->property('person_ssn');
	$profileLine .= '&nbsp;#property.person_gender_caption# ' if $self->property('person_gender_caption');
	$profileLine .= '&nbsp;Age #property.person_age# ' if $self->property('person_age');
	$profileLine .= '(#property.person_date_of_birth#) ' if $self->property('person_date_of_birth');
	$profileLine .= '&nbsp;#property.person_ethnicity# ' if $self->property('person_ethnicity');
	$profileLine .= '&nbsp;#property.person_marstat_caption# ' if $self->property('person_marstat_caption');
	if ($self->property('person_responsible'))
	{
		$profileLine .=  $self->property('person_responsible') eq 'Self' ? '&nbsp;Responsible Person: #property.person_responsible# ' : '&nbsp;Responsible Person: <A HREF="/person/#property.person_responsible#/profile">#property.person_responsible#</A> ';
	}

	my $homeArl = '/' . $self->param('arl');
	$homeArl =~ s/\?.*//;
	my $chooseAction = '';
	$chooseAction =
		qq{<SELECT onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
			<OPTION>Choose Action</OPTION>
			<OPTION value="/person/$personId/dlg-add-referral?home=$homeArl">Add Service Request</OPTION>
			<OPTION value="/person/$personId/dlg-add-appointment?_dialogreturnurl=/person/$personId">Schedule Appointment</OPTION>
			<OPTION value="/person/$personId/dlg-add-claim?home=$homeArl">Add Claim</OPTION>
			<OPTION value="/person/$personId/dlg-add-invoice?home=$homeArl">Add Invoice</OPTION>
			<OPTION value="/person/$personId/dlg-update-$updateCategory?home=$homeArl">Edit Profile</OPTION>
			<OPTION value="/person/$personId/account?home=$homeArl&viewall=1">View All Claims</OPTION>
			<OPTION value="/person/$personId/dlg-add-medication-prescribe?home=$homeArl">Prescribe Medication</OPTION>
			<OPTION value="/person/$personId/dlg-add-refill-request?home=$homeArl">Refills</OPTION>
			<OPTION value="/person/$personId/dlg-add-phone-message?home=$homeArl">Voice Msgs</OPTION>
			<!-- <OPTION value="/person/$personId/dlg-add-">Add Note</OPTION> -->
			<OPTION value="/person/$personId/dlg-add-postpersonalpayment?home=$homeArl">Apply Personal Payment</OPTION>
			<OPTION value="/person/$personId/dlg-add-postrefund?home=$homeArl">Post Refund</OPTION>
			<OPTION value="/person/$personId/dlg-add-posttransfer?home=$homeArl">Post Transfer</OPTION>
			<!-- <OPTION value="/person/$personId/dlg-add-billingcycle">Billing Cycle</OPTION> -->
		</SELECT>} if $self->param('_pm_view');

	push(@{$self->{page_content_header}},
		qq{<table width="100%" bgcolor="#EEEEEE" cellspacing="0" cellpadding="0" border="0"><tr><td>
			<font face="Arial,Helvetica" size="2" style="font-family: tahoma; font-size: 8pt">
			&nbsp; $profileLine
			</font>
		</td><td align="right">
			<font face="Arial,Helvetica" size="2" style="font-family: tahoma; font-size: 8pt">
			<form>$chooseAction
			</font>
		</td><tr><tr><td colspan="2">@{[
			getImageTag('design/bar', {width => '100%', height => 1})
		]}</td></tr><tr bgcolor="#FFFFFF"><td></form></td></tr></table>
		},'<p>'
	);

	#getImageTag('design/bar', {width => '100%', height => 1})

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

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'person')) if $self->param('_pm_view');
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
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


        my ($self) = @_;
        $self->addContent(qq{
                <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
                        <TR VALIGN=TOP>
                                <TD>
                                        #component.stp-person.refillRequest#<BR>
                                </TD>
                        </TR>
                </TABLE>
        });

}

sub prepare_view_phone_message
{

        my ($self) = @_;
        $self->addContent(qq{
                <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
                        <TR VALIGN=TOP>
                                <TD>
                                        #component.stp-person.phoneMessage#<BR>
                                </TD>
                        </TR>
                </TABLE>
        });

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
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_internal_id'));

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
	#######################################################
	#DEMO CODE
	my $categories = $self->session('categories');
	my $selectedDate = 'today' ;
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');
	$self->param('timeDate',$fmtDate);
	#DEMO CODE
	#######################################################
	my $pageHome;
	#If user is a Physicina and the user id is TSAMO then show Physicianm home page
	#Currently this is only for DEMO
	if ($CONFDATA_SERVER->name_Group() eq App::Configuration::CONFIGGROUP_DEMO && grep {$_ eq 'Physician'} @$categories  )
	{
                $pageHome =qq
                {
        		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>
        		<SCRIPT>
			function updatePage(selectedDate)
			{
				alert('TEST');
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = './' + dashDate;
			}
			</SCRIPT>
               	 	<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
               	 	<TR VALIGN=TOP>
               	 	 <TD>
               	 	        #component.stp-person.scheduleAppts#</BR>
               	 	        #component.stp-person.inPatient#<BR>
               	 	        #component.lookup-records#<BR>

                 	</TD>
                 	<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
                 	<TD>
                 	       #component.stpt-person.docSign#<BR>
                 	       #component.stpt-person.docPhone#<BR>
                 	       #component.stpt-person.docRefill#<BR>
                 	       #component.stpt-person.docResults#<BR>
                	</TD>
                 	<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
                 	<TD>
                 	       #component.stp-person.linkMedicalSite#<BR>
                 	       #component.stp-person.linkNonMedicalSite#<BR>
                 	       #component.news-top#<BR>
                 	       #component.news-health#<BR>
                	</TD>
                	</TR>
                	</TABLE>
                }
        }
        else
        {
		$pageHome = qq
		{
			<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
					<TR VALIGN=TOP>
					<TD>
						#component.lookup-records#<BR>
						#component.navigate-reports-root#<BR>
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
		}
	};
	$self->addContent($pageHome);
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

sub prepare_view_facesheet
{
	my ($self) = @_;

	my $personId = $self->param('person_id');
	my $accountInfo = $STMTMGR_WORKLIST_COLLECTION->recordExists($self, STMTMGRFLAG_NONE, 'selInColl', $personId) ? '<font color=red>(Account in Collection)</font>' : '';
	my $content = qq{
		<center><h2>Patient Profile Summary</h2></center>

		<p align=right>
			@{[ UnixDate('today', '%g') ]}<br>
			#session.user_id#
		</p>
		<table width=100%>
			<tr valign=top>
				<td>
					<b>#property.person_simple_name#</b> $accountInfo<br>
					Responsible Party: @{[ $self->property('person_responsible') || 'Self' ]}
				</td>
				<td>
					ID: <b>$personId</b><br>
					SSN: #property.person_ssn#
				</td>
				<td align=right>
					DOB: #property.person_date_of_birth#<br>
					Gender: #property.person_gender_caption#
				</td>
			</tr>
		</table>
		<p>
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.officeLocation#
					<p>
					#component.stpt-person.contactMethodsAndAddresses#
					<p>
					#component.stpt-person.insurance#
					<p>
					#component.stpt-person.careProviders#
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stpt-person.employmentAssociations#
					<p>
					#component.stpt-person.emergencyAssociations#
					<p>
					#component.stpt-person.familyAssociations#
					<p>
					#component.stpt-person.accountPanel#
				</TD>
			</TR>
		</TABLE>
	};

	$self->replaceVars(\$content);

	# strip all of the images because we don't want them linked
	#
	$content =~ s!<A.*?><IMG.*action-(add|edit).*?></A>!!g;
	$self->addContent($content);
}


sub prepare_view_associate
{
	my ($self, $flags, $colors, $fonts, $viewParamValue) = @_;
	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
				<font size=1 face=arial>
				#component.stp-person.attendance#<BR>
				#component.stp-person.certification#<BR>
				#component.stp-person.affiliations#<BR>
				#component.stp-person.benefits#<BR>
				</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
				<font size=1 face=arial>
				#component.stpt-person.feeschedules#<BR>
				#component.stpt-person.associatedSessionPhysicians#<BR>
				</font>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_profile
{
	my ($self) = @_;

	$self->addLocatorLinks(['Summary', 'profile']);
	my $personId = $self->param('person_id');
	my $personCategories = $STMTMGR_PERSON->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selCategory', $personId, $self->session('org_internal_id'));
	my $category = $personCategories->[0];

	my $careProvider='';
	my $authorization='';
	my $categories = $self->property('person_categories');
	if (grep {uc($_) eq 'PATIENT'} @$categories)
	{
		$careProvider = '#component.stpt-person.careProviders#<BR>' ;
		$authorization = '#component.stp-person.authorization#<BR>';
	}
	$self->addContent(qq{
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.contactMethodsAndAddresses#<BR>
					#component.stpt-person.officeLocation#
					#component.stpt-person.insurance#<BR>
					$careProvider
					#component.stpt-person.employmentAssociations#<BR>
					#component.stpt-person.emergencyAssociations#<BR>
					#component.stpt-person.familyAssociations#<BR>
					#component.stpt-person.additionalData#<BR>
					</font>
				</TD>
				<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD>
					#component.stp-person.miscNotes#<BR>
					#component.stp-person.alerts#<BR>
					#component.stp-person.refillRequest#<BR>
					#component.stp-person.phoneMessage#<BR>
					$authorization
					</font>
				</TD>

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
					#component.stp-person.surgicalProcedures#<BR>
					#component.stp-person.testsAndMeasurements#<BR>
					#component.stp-person.bloodGroup#<BR>
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
					#component.stpt-person.diagnosisSummary#
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
	my $queryStmt = $self->param('viewall') ? 'selAllInvoiceTypeForClient' : 'selNonVoidInvoiceTypeForClient';


	$self->addContent(
		"<CENTER>
		<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-person.account-notes#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>",
		$STMTMGR_INVOICE->createHtml($self, STMTMGRFLAG_NONE, $queryStmt,
			[$personId, $self->session('org_internal_id')],
		),
		"</CENTER>"
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
	if($pathItems->[0] eq 'SZSMTIH' && $pathItems->[1] eq 'chart' && $CONFDATA_SERVER->name_Group() eq App::Configuration::CONFIGGROUP_DEMO )
	{
	                $self->redirect('/temp/EMRsummary/index.html');
        }
        else
        {
		unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
		{
			$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
		}
	}
	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
