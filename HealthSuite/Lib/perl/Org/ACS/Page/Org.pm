##############################################################################
package Org::ACS::Page::Org;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Number::Format;
use Date::Manip;
use App::ImageManager;

use DBI::StatementManager;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Component::Org;
use App::Statements::Person;
use App::Statements::Invoice;
use App::Statements::Search::Catalog;

use App::Dialog::Organization;

use App::Page::Search;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page);
%RESOURCE_MAP = (
	'org' => {
		_views => [
			{caption => 'Summary', name => 'profile',},
#			{caption => 'Departments', name => 'departments',},
#			{caption => 'Personnel', name => 'personnel',},
#			{caption => 'Catalog', name => 'catalog',},
#			{caption => 'Account', name => 'account',},
			],
		},
	);

#use constant FORMATTER => new Number::Format('INT_CURR_SYMBOL' => '$');
my $intOrgId;
sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	my $orgId = $self->param('org_id');
	$intOrgId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selOrgId',
		$self->session('org_internal_id'), $orgId);

	unless($intOrgId)
	{
		$self->disable(
			qq{
				<br>
				Org '$orgId' does NOT exist in your Organization.
				Click <a href='javascript:history.back()'>here</a> to go back.
			}
		);
	}
	$self->param('org_internal_id',$intOrgId);

	$STMTMGR_ORG->createPropertiesFromSingleRow($self, STMTMGRFLAG_CACHE, ['selOrgCategoryRegistry', 'org_'], $intOrgId);
	my $orgAttr = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selAttribute', $intOrgId, 'Business Hours');
	my $orgClearHouseAttr = $STMTMGR_ORG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selAttribute', $intOrgId, 'Clearing House ID');
	$self->property('org_type', split(/,/, $self->property('org_category')));
	$self->property('org_hrs_oper', $orgAttr->{'value_text'});
	$self->property('org_clear_house', $orgClearHouseAttr->{'value_text'});
	#my $x = $test->{'value_text'};
	#$self->addDebugStmt("TEST : $x ");

	$self->addLocatorLinks(
			['Organization', '/search/org'],
			[$orgId, 'profile'],
		);

	# Check user's permission to page
	my $activeView = $self->param('_pm_view');
	if ($activeView)
	{
		unless($self->hasPermission("page/org/$activeView"))
		{
			$self->disable(
				qq{
					<br>
					You do not have permission to view this information.
					Permission page/org/$activeView is required.

					Click <a href='javascript:history.back()'>here</a> to go back.
				}
			);
		}
	}
}

sub getContentHandlers
{
	return ('prepare_view_$_pm_view=profile$');
}

sub prepare_page_content_header
{
	my $self = shift;

	return if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	my $orgId = $self->param('org_id');
	my $urlPrefix = "/org/$orgId";
	my $orgName = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selOrgSimpleNameById', $intOrgId) || "No org_id parameter provided.";

	$self->{page_heading} = $orgName;
	$self->{page_menu_sibling} = [
			['Summary', "$urlPrefix/profile", 'profile'],
			#['Insurance', "$urlPrefix/insurance", 'insurance'],
			#['Departments', "$urlPrefix/departments", 'departments'],
			#['Personnel', "$urlPrefix/personnel?home=$urlPrefix/profile", 'personnel'],
			#['Catalog', "$urlPrefix/catalog", 'catalog'],
			#['Account', "$urlPrefix/account", 'account'],
		];
	$self->{page_menu_siblingSelectorParam} = '_pm_view';

	$self->SUPER::prepare_page_content_header(@_);
	#my $category = $self->property('org_group_name');
	my $category = defined $self->property('org_type') ? lc($self->property('org_type')) : undef;
	for ($category)
	{
		/employer/ and do {$category = 'employer'; last};
		/insurance/ and do {$category = 'insurance'; last};
		/ipa/ and do {$category = 'ipa'; last};
		/department/ and do {$category = 'dept'; last};
		/location_dir_entry/ and do {$category = 'provider'; last};
		/main_dir_entry/ and do {$category = 'provider'; last};
		$category = defined $self->property('org_parent_org_id') ? 'provider' : 'main';

	}

	my $profileLine = '<b>Profile: </b>';
	$profileLine .=  '&nbsp;Primary Name: #property.org_name_primary# ' if $self->property('org_name_primary');
	$profileLine .=  '&nbsp;Category: #property.org_category# ' if $self->property('org_category');
	$profileLine .=  '&nbsp;Trade Name: #property.org_name_trade# ' if $self->property('org_name_trade');
	$profileLine .=  '&nbsp;Tax ID: #property.org_tax_id# ' if $self->property('org_tax_id');
	$profileLine .=  '&nbsp;Hours of Operation: #property.org_hrs_oper# #property.org_time_zone#' if $self->property('org_hrs_oper');
	$profileLine .=  '&nbsp;Clearing House ID: #property.org_clear_house# ' if $self->property('org_clear_house');

	my $chooseAction = '';
	$chooseAction = qq{
				<TD ALIGN=RIGHT>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<SELECT style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
						<OPTION>Choose Action</OPTION>
						<OPTION value="/org/#session.org_id#/dlg-add-appointment">Schedule Appointment</OPTION>
						<OPTION value="/org/#session.org_id#/dlg-add-claim">Add Claim</OPTION>
						<OPTION value="/org/#param.org_id#/dlg-update-org-dir-entry">Edit Profile</OPTION>
						<OPTION value="/org/#session.org_id#/account">Apply Payment</OPTION>
						<OPTION value="/org/#session.org_id#/profile">Go To Parent Org</OPTION>
					</SELECT>
					</FONT>
				<TD>
	} if $self->param('_pm_view');

	push(@{$self->{page_content_header}},
		qq{
		<TABLE WIDTH=100% BGCOLOR=#EEEEEE CELLSPACING=0 CELLPADDING=0 BORDER=0>
			<TR>
			<FORM>
				<TD><FONT FACE="Arial,Helvetica" SIZE=4 STYLE="font-family: tahoma; font-size: 14pt">&nbsp;</TD>
				<TD ALIGN=LEFT>
					<FONT FACE="Arial,Helvetica" SIZE=2 STYLE="font-family: tahoma; font-size: 8pt">
						$profileLine
					</FONT>
				</TD>
$chooseAction
			</FORM>
			</TR>
			<TR><TD COLSPAN=3><IMG SRC="/resources/design/bar.gif" WIDTH=100% HEIGHT=1></TD></TR>
		</TABLE>
		},'<P>'
	);

	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;

	#return if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'org')) if $self->param('_pm_view');
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
}

sub prepare_view_update
{
	my ($self) = @_;

	my $orgId = $self->param('org_id');
	unless($orgId)
	{
		$self->errorBox('No org Id provided', 'org_id is a required parameter');
		return;
	};

	my $dialog = new App::Dialog::Organization(schema => $self->getSchema(), cancelUrl => "/org/$orgId/profile");
	$dialog->handle_page($self, 'update');
}

sub prepare_view_remove
{
	my ($self) = @_;

	my $orgId = $self->param('org_id');
	unless($orgId)
	{
		$self->errorBox('No org Id provided', 'org_id is a required parameter');
		return;
	};

	my $dialog = new App::Dialog::Organization(schema => $self->getSchema(), cancelUrl => "/org/$orgId/profile");
	$dialog->handle_page($self, 'remove');
}

sub prepare_view_profile
{
	my ($self) = @_;

	#$self->addLocatorLinks(['Profile', 'profile']);


	$self->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD WIDTH=30%>
					<font size=1 face=arial>
					#component.stpt-org.contactMethodsAndAddresses#<BR>
					#component.stpt-org.miscNotes#<BR>
					#component.stpt-org.listAssociatedOrgs#<BR>
					</font>
				</TD>
				<TD WIDTH=60%>
					<font size=1 face=arial>
					#component.stp-org.serviceCatalog#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_worklist
{
	my ($self) = @_;

	#$self->addLocatorLinks(['WorkList', 'worklist']);

	$self->addContent(qq{
			<TR VALIGN=TOP>
				<TD>
					#component.worklist# <BR>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_clinic
{
	my ($self) = @_;

	#$self->addLocatorLinks(['Clinic', 'clinic']);
#	$self->>addContent(" ", $self->param('errorcode'), "	-- NOT YET IMPLEMENTED.");
#	my $orgId = $self->param('org_id');

	return 1;
}

sub prepare_view_facility
{
	my ($self) = @_;

	#$self->addLocatorLinks(['Facility', 'facility']);
	$self->addContent(" ", $self->param('errorcode'), " -- NOT YET IMPLEMENTED.");
	my $orgId = $self->param('org_id');

	return 1;
}

sub prepare_view_insurance
{
	my ($self) = @_;
	$self->addContent('#component.stp-org.insurancePlans#');
	return 1;
}

sub prepare_view_catalog
{
	my ($self) = @_;

	#$self->addLocatorLinks(['Catalog', 'catalog']);

	my @pathItems = split('/', $self->param('arl'));

	if ($self->param('catalog_id', $pathItems[4]))
	{
		$self->param('internal_catalog_id', $pathItems[3]);
		#Determine if service type of catalog
		my $catalog = $STMTMGR_CATALOG->getRowAsHash($self, STMTMGRFLAG_CACHE, 'selCatalogById', $self->param('internal_catalog_id'));
		if($catalog->{catalog_type} eq '1')
		{
			$self->addContent('#component.stp-org.serviceCatalogEntry#');
		}
		elsif($catalog->{catalog_type} eq '0')
		{
			$self->addContent('#component.stp-org.fsCatalogEntry#');
		}
	}
	else
	{
		$self->addContent('#component.stp-org.serviceCatalog#');
	}

	return 1;
}

sub prepare_view_account
{
	my ($self) = @_;

	#$self->addLocatorLinks(['Account', 'account']);

	my $orgId = $self->param('org_id');
	my $ownerOrg = $self->session('org_internal_id');
	my $orgIntId = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_NONE, 'selOrgId', $ownerOrg, $orgId);
	my $todaysDate = $self->getDate();
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	$self->addContent(
		'<CENTER>',
		$STMTMGR_INVOICE->createHtml($self, STMTMGRFLAG_NONE, 'selInvoiceTypeForOrg',
			[$orgIntId],
			#[
				#['<SPAN TITLE="Claim Identifier">ID</SPAN>', '<A HREF=\'/invoice/%0\'>%0</A>', undef, 'RIGHT'],
				#['<SPAN TITLE="Number of Items in Claim">IC</SPAN>', undef, undef, 'CENTER'],
				#['Client'],
				#['Date'],
				#['Status'],
				#['Reference'],
				#['Total', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
				#['Adjust', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
				#['Balance', undef, undef, 'RIGHT', CREATEOUPUT_COLFLAG_CURRENCY | CREATEOUPUT_COLFLAG_SUM],
			#]
			),
		'</CENTER>'
		);
}

sub prepare_view_departments
{
	my ($self) = @_;
	#$self->addLocatorLinks(['Personnel', 'personnel']);
	$self->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
					#component.stpt-org.associatedOrgs#<BR>
					#component.stpt-org.listAssociatedOrgs#<BR>
					</font>
				</TD>
				<td>
					<font size=1 face=arial>
					#component.stpt-org.departments#
					</font>
				</td>
			</TR>
		</TABLE>
	});
	return 1;
}

sub prepare_view_personnel
{
	my ($self) = @_;
	#$self->addLocatorLinks(['Personnel', 'personnel']);
	$self->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD>
					<font size=1 face=arial>
						#component.stp-org.personnel#<BR>
					</font>
				</TD>
				<td>
					<font size=1 face=arial>
						#component.stp-org.associatedResourcesStats#<BR>
					</font>
				</td>
			</TR>
		</TABLE>
	});
	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	# person_id must be the first item in the path
	return 'UIE-002010' unless $pathItems->[0];

	$pathItems->[0] = uc($pathItems->[0]);
	$self->param('org_id', $pathItems->[0]);

	if ( ($pathItems->[1] eq 'catalog') && $pathItems->[2] )
	{
		$self->param('_pm_view', $pathItems->[1]);
		$self->param('arl', $arl);
		$self->printContents();
		return 0;
	}

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 1))
	{
		$self->param('_pm_view', $pathItems->[1]) if $pathItems->[1];
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

	$self->printContents();

	# return 0 if successfully printed the page (handled the ARL) -- or non-zero error code
	return 0;
}

1;