##############################################################################
package App::Page::Person;
##############################################################################

use strict;
use App::Page;
use base qw(App::Page);

use CGI::ImageManager;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Worklist::WorklistCollection;
use App::Configuration;
use App::Page::Search;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'person' => {
		_iconMedium => 'icon-m/person',
		_arlParams => ['person_id'],
		},
	);


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
	my $respPersonSimpleName = $STMTMGR_PERSON->getSingleValue($self, STMTMGRFLAG_NONE, 'selPersonSimpleNameById', $guarantorName->{'value_text'});
	my $respPerson = $guarantorName->{'value_text'} eq $personId ? 'Self' : $guarantorName->{'value_text'};
	$self->property('person_responsible', $respPerson);
	$self->property('person_responsible_simple_name', $respPersonSimpleName);

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
	my $aclId = 'page/' . $self->param('arl_resource');
	if ($self->hasPermission($aclId))
	{
		if (($aclId eq 'page/person/home') && ($personId ne $userId))
		{
			$self->disable(qq{
				<br>
				You do not have permission to view this information.
				Only the user $personId can view this page.
				Click <a href='javascript:history.back()'>here</a> to go back.
			});
		}
	}
	else
	{
		$self->disable(qq{
			<br>
			You do not have permission to view this information.
			Permission $aclId is required.
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
	return ('prepare_view');
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

	my $showBilling=0;
	my $billingList = 'PATIENT';

	my $showActivity=0;
	my $activityList = '';

	my $showAssociate=0;
	my $assoicateList = 'STAFF|NURSE|PHYSICIAN|ADMINISTRATOR|REFERRING-DOCTOR';

	my $showHome=0;

	my $showMailBox = $personId eq $sessionUserID ? 1 : 0;

	#Get Categories
	my $categories = $self->property('person_categories');

	#Add all options
	push (@$categories,'ALL_CATEGORIES');
	$showSummary=1 if grep {uc($_)=~m/$summaryList/} @$categories;
	$showChart=1 if grep {uc($_)=~m/$chartList/} @$categories;
	$showAccount=1 if grep {uc($_)=~m/$accountList/} @$categories;
	$showBilling=1 if grep {uc($_)=~m/$billingList/} @$categories;
	$showAssociate=1 if grep {uc($_)=~m/$assoicateList/} @$categories;
	$showActivity=1 if grep {uc($_)=~m/$activityList/} @$categories;

	#Only show home option is person is looking at their page
	$showHome=1 if ($personId eq $sessionUserID);



	$self->{page_heading} = $self->property('person_simple_name');
	$self->{page_menu_sibling} = [
			$showHome ? ['Home', "$urlPrefix/home",'home'] : undef,
			$showSummary ? ['Summary', "$urlPrefix/profile", 'summary']: undef,
			$showChart ? ['Chart', "$urlPrefix/chart", 'chart']: undef,
			$showChart ? ['Clinical Note', "$urlPrefix/cnote", 'cnote']: undef,
			$showAccount ? ['Account', "$urlPrefix/account", 'account'] : undef,
			$showBilling ? ['Billing', "$urlPrefix/billing", 'billing'] : undef,
			$showActivity ? ['Activity', "$urlPrefix/activity", 'activity'] : undef,
			$showAssociate ? ['Associate', "$urlPrefix/associate",'associate'] : undef,
			#['Face Sheet', "javascript:doActionPopup(\"/person-p/$personId/facesheet\")", 'facesheet'],
			$showMailBox ? ['Mail Box', "$urlPrefix/mailbox", 'mailbox'] : undef,
			['Documents', "$urlPrefix/documents", 'documents'],
			#['Add Appointment', "$urlPrefix/appointment", 'appointment'],
		];
	$self->{page_menu_siblingSelectorParam} = '_pm_view';

	$self->SUPER::prepare_page_content_header(@_);

	return 1 if $self->flagIsSet(PAGEFLAG_ISDISABLED);

	my $category = lc($self->property('person_categories')->[0]) || undef;
	# If the category isnt one of the predefined four, assume its staff.
	$category = $category eq 'insured-person' ? 'insured-Person' : $category;
	my $updateCategory = $category;
	unless (($category eq 'nurse') or ($category eq 'physician') or ($category eq 'staff') or ($category eq 'patient') or ($category eq 'referring-doctor') or ($category eq 'guarantor') or ($category eq 'insured-Person')) {
		$updateCategory = 'staff';
	}
	my $profileLine = '<b>Profile: </b>';
	$profileLine .= '<font color=red>(Account in Collection)</font>' if $STMTMGR_WORKLIST_COLLECTION->recordExists($self, STMTMGRFLAG_NONE, 'selInColl', $personId,$self->session('org_internal_id'));
	$profileLine .=  '&nbsp;Category: #property.person_org_category# ' if $self->property('person_org_category');
	$profileLine .= '&nbsp;SSN #property.person_ssn# ' if $self->property('person_ssn');
	$profileLine .= '&nbsp;#property.person_gender_caption# ' if $self->property('person_gender_caption');
	$profileLine .= '&nbsp;Age #property.person_age# ' if $self->property('person_age');
	$profileLine .= '(#property.person_date_of_birth#) ' if $self->property('person_date_of_birth');
	$profileLine .= '&nbsp;#property.person_ethnicity# ' if $self->property('person_ethnicity');
	$profileLine .= '&nbsp;#property.person_marstat_caption# ' if $self->property('person_marstat_caption');
	if ($self->property('person_responsible'))
	{
		$profileLine .=  $self->property('person_responsible') eq 'Self' ? '&nbsp;Responsible Person: #property.person_responsible# ' : '&nbsp;Responsible Person: #property.person_responsible_simple_name# (<A HREF="/person/#property.person_responsible#/profile">#property.person_responsible#</A>) ';
	}

	my $homeArl = '/' . $self->param('arl');
	$homeArl =~ s/\?.*//;
	my $chooseAction = '';
	$chooseAction =
		qq{<SELECT onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
			<OPTION selected>Choose Action</OPTION>
			<OPTION value="/person/$personId/stpe-person.labOrderSummary?home=$homeArl">Add Ancillary Test</OPTION>
			<OPTION value="/person/$personId/dlg-add-referral?home=$homeArl">Add Service Request</OPTION>
			<OPTION value="/person/$personId/dlg-add-appointment?_dialogreturnurl=/person/$personId/profile">Schedule Appointment</OPTION>
			<OPTION value="/person/$personId/dlg-add-claim?home=$homeArl">Add Claim</OPTION>
			<OPTION value="/person/$personId/dlg-add-claim?home=$homeArl&isHosp=1">Add Hospital Claim</OPTION>
			<OPTION value="/person/$personId/dlg-add-invoice?home=$homeArl">Add Invoice</OPTION>
			<OPTION value="/person/$personId/dlg-update-$updateCategory?home=$homeArl">Edit Profile</OPTION>
			<OPTION value="/person/$personId/account?home=$homeArl&viewall=1">View All Claims</OPTION>
			<<OPTION value="/person/$personId/dlg-setup-payment_plan?home=$homeArl">Setup Payment Plan</OPTION>
			<OPTION value="/person/$personId/dlg-prescribe-medication?home=$homeArl">Prescribe Medication</OPTION>
			<OPTION value="/person/$personId/stpe-person.activeMedications?home=$homeArl">Refills</OPTION>
			<OPTION value="/person/$personId/dlg-send-phone_message?home=$homeArl">Voice Msgs</OPTION>
			<!-- <OPTION value="/person/$personId/dlg-add-">Add Note</OPTION> -->
			<OPTION value="/person/$personId/dlg-add-postpersonalpayment?home=$homeArl">Apply Personal Payment</OPTION>
			<OPTION value="/person/$personId/dlg-add-postrefund?home=$homeArl">Post Refund</OPTION>
			<OPTION value="/person/$personId/dlg-add-posttransfer?home=$homeArl">Post Transfer</OPTION>
			<OPTION value="/person/$personId/dlg-remove-category?home=$homeArl">Remove Login</OPTION>
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


sub prepare_page_content_footer
{
	my $self = shift;

	return if $self->property('person_denied');
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'person')) if $self->param('_pm_view');
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
}


sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# person_id must be the first item in the path
	#return 'UIE-001010' unless $pathItems->[0];

	#$pathItems->[0] = uc($pathItems->[0]);
	#$self->param('person_id', $pathItems->[0]);

	# see if the ARL points to showing a dialog, panel, or some other standard action
	#if($pathItems->[0] eq 'SZSMTIH' && $pathItems->[1] eq 'chart' && $CONFDATA_SERVER->name_Group() eq App::Configuration::CONFIGGROUP_DEMO )
	#{
	#                $self->redirect('/temp/EMRsummary/index.html');
	#}
	#else
	#{
	unless ($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
	}
	#}
	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;
