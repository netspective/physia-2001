##############################################################################
package App::Page::Org;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Number::Format;
use Date::Manip;
use App::ImageManager;

use DBI::StatementManager;
use App::Statements::Org;
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
			{caption => 'Insurance', name => 'insurance',},
			{caption => 'Personnel', name => 'personnel',},
			{caption => 'Catalog', name => 'catalog',},
			{caption => 'Account', name => 'account',},
			],
		},
	);

#use constant FORMATTER => new Number::Format('INT_CURR_SYMBOL' => '$');

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	my $orgId = $self->param('org_id');
	$STMTMGR_ORG->createPropertiesFromSingleRow($self, STMTMGRFLAG_CACHE, ['selOrgCategoryRegistry', 'org_'], $orgId);
	$self->property('org_type', split(/,/, $self->property('org_category')));
	#$self->property('org_categories', $STMTMGR_ORG->getSingleValueList($self, STMTMGRFLAG_CACHE, 'selOrgCategory', $orgId));

	#unless($orgId eq $self->session('org_id'))
	#{
		$self->addLocatorLinks(
				['Organization Look-up', '/search/org'],
				[$orgId, 'profile', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
			);
	#}
	#$self->addDebugStmt(@{[$self->property('org_group_name')]});
	
	my $activeView = $self->param('_pm_view');
	#unless($self->hasPermission("page/org/$activeView"))
	unless($self->hasPermission("page/org"))
	{
		$self->disable(
				qq{
					<br>
					You do not have permission to view this information. 
					Permission page/org is required.

					Click <a href='javascript:history.back()'>here</a> to go back.
				});
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

	$self->SUPER::prepare_page_content_header(@_);
	my $category = $self->property('org_group_name');
#	my $category = defined $self->property('org_type') ? lc($self->property('org_type')) : undef;
#	for ($category)
#	{
#		/employer/ and do {$category = 'employer'; last};
#		/insurance/ and do {$category = 'insurance'; last};
#		/ipa/ and do {$category = 'ipa'; last};
#		/department/ and do {$category = 'dept'; last};
#		$category = defined $self->property('org_parent_org_id') ? 'provider' : 'main';
#
#	}
	#Retired Pane/Org/Heading.pm
	#push(@{$self->{page_content_header}}, new App::Pane::Org::Heading()->as_html($self), '<P>');

	my $orgName = undef;
	if(my $orgId = $self->param('org_id'))
	{
		$orgName = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selOrgSimpleNameById', $orgId);
	}
	else
	{
		return 'No org_id parameter provided';
	}

	my $orgId = $self->param('org_id');
	my $urlPrefix = "/org/$orgId";

	#my $orgCategories = $STMTMGR_ORG->getSingleValue($self, STMTMGRFLAG_CACHE, 'selCategory', $orgId);
	#my @extras = ();
	#foreach my $category (split(/,/, $orgCategories))
	#{
	#	push(@extras, ["\u$category", "$urlPrefix/\l$category", "\l$category"]);
	#}

	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Summary', "$urlPrefix/profile", 'profile'],
			['Insurance', "$urlPrefix/insurance", 'insurance'],
			#@extras,
			['Personnel', "$urlPrefix/personnel?home=$urlPrefix/profile", 'personnel'],
			['Catalog', "$urlPrefix/catalog", 'catalog'],
			['Account', "$urlPrefix/account", 'account'],
			#['WorkList', "$urlPrefix/worklist", 'worklist'],
			#['Activity', "$urlPrefix/activity", 'activity'],
		], ' | ');

	my $profileLine = '<b>Profile: </b>';
	$profileLine .=  '&nbsp;Primary Name: #property.org_name_primary# ' if $self->property('org_name_primary');
	$profileLine .=  '&nbsp;Category: #property.org_category# ' if $self->property('org_category');
	$profileLine .=  '&nbsp;Trade Name: #property.org_name_trade# ' if $self->property('org_name_trade');
	$profileLine .=  '&nbsp;Tax ID: #property.org_tax_id# ' if $self->property('org_tax_id');

	push(@{$self->{page_content_header}},
		qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					$IMAGETAGS{'icon-m/org'}<B>$orgName</B>
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
						$profileLine
					</FONT>
				</TD>
				<TD ALIGN=RIGHT>
					<FONT FACE="Arial,Helvetica" SIZE=2>
					<SELECT style="font-family: tahoma,arial,helvetica; font-size: 8pt" onchange="if(this.selectedIndex > 0) window.location.href = this.options[this.selectedIndex].value">
						<OPTION>Choose Action</OPTION>
						<OPTION value="/org/#session.org_id#/dlg-add-appointment">Schedule Appointment</OPTION>
						<OPTION value="/org/#session.org_id#/dlg-add-claim">Add Claim</OPTION>
						<OPTION value="/org/#session.org_id#/dlg-add-batch">Post Batch Payments</OPTION>
						<OPTION value="/org/#param.org_id#/dlg-update-org-$category">Edit Profile</OPTION>
						<OPTION value="/org/#session.org_id#/account">Apply Payment</OPTION>
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

sub prepare_page_content_footer
{
	my $self = shift;

	#return if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'org'));
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

	$self->addLocatorLinks(['Profile', 'profile']);

	$self->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD WIDTH=30%>
					<font size=1 face=arial>
					#component.stpt-org.contactMethodsAndAddresses#<BR>
					#component.stpt-org.associatedOrgs#<BR>
					#component.stpt-org.credentials#<BR>
					#component.stpt-org.departments#
					</font>
				</TD>
				<TD WIDTH=60%>
					<font size=1 face=arial>
					<!--
					<TABLE CELLSPACING=0 BORDER=0 CELLPADDING=0 WIDTH=100%>
						<TR VALIGN=TOP>
							<TD>#component.stp-org.alerts#</TD>
							<TD WIDTH=10><FONT SIZE=1>&nbsp;</FONT></TD>
							<TD>#component.stp-org.feeSchedule#</TD>
						</TR>
					</TABLE><BR>
					-->
					#component.stp-org.alerts#<BR>
					#component.stp-org.insurancePlans#<BR>
					#component.stpt-org.healthMaintenanceRule#<BR>
					#component.stpt-org.associatedResourcesStats#<BR>
					</font>
				</TD>
			</TR>
		</TABLE>
	});
}

sub prepare_view_worklist
{
	my ($self) = @_;

	$self->addLocatorLinks(['WorkList', 'worklist']);

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

	$self->addLocatorLinks(['Clinic', 'clinic']);
	$self->addContent(" ", $self->param('errorcode'), "	-- NOT YET IMPLEMENTED.");
	my $orgId = $self->param('org_id');

	return 1;
}

sub prepare_view_facility
{
	my ($self) = @_;

	$self->addLocatorLinks(['Facility', 'facility']);
	$self->addContent(" ", $self->param('errorcode'), " -- NOT YET IMPLEMENTED.");
	my $orgId = $self->param('org_id');

	return 1;
}

sub prepare_view_insurance
{
	my ($self) = @_;

	$self->addLocatorLinks(['Insurance', 'insurance']);

	my $orgId = $self->param('org_id');

	if ($orgId)
	{
		#$self->param('catalog_id', $pathItems[3]);
		$self->addContent(
			$STMTMGR_COMPONENT_ORG->createHierHtml($self, STMTMGRFLAG_NONE, ['org.insurancePlans', 0, 1],
				[$orgId]),
		);
	}
	#else
	#{
	#	$self->addContent(
	#		$STMTMGR_CATALOG_SEARCH->createHierHtml($self, STMTMGRFLAG_NONE, ['sel_catalogs_all_org', 0, 4],
	#			[$self->session('org_id')]) );
	#}

	return 1;
}

sub prepare_view_catalog
{
	my ($self) = @_;

	$self->addLocatorLinks(['Catalog', 'catalog']);

	my @pathItems = split('/', $self->param('arl'));

	if ($self->param('catalog_id', $pathItems[4]))
	{
		$self->param('internal_catalog_id', $pathItems[3]);
		$self->addContent(
			$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_catalog_detail_org',
				[$pathItems[3]] ),
		);
	}
	else
	{
		$self->addContent(
			$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_catalogs_all_org',
				[$self->param('org_id')]) );
	}

	return 1;
}

sub prepare_view_account
{
	my ($self) = @_;

	$self->addLocatorLinks(['Account', 'account']);

	my $orgId = $self->param('org_id');
	my $todaysDate = $self->getDate();
	my $formatter = new Number::Format('INT_CURR_SYMBOL' => '$');

	$self->addContent(
		'<CENTER>',
		$STMTMGR_INVOICE->createHtml($self, STMTMGRFLAG_NONE, 'selInvoiceTypeForOrg',
			[$orgId],
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

sub prepare_view_insurance
{
	my ($self) = @_;
	my $orgId = $self->param('org_id');

	return 1;
}

sub prepare_view_personnel
{
	my ($self) = @_;
	$self->addLocatorLinks(['Personnel', 'personnel']);
	$self->addContent(qq{
		<TABLE>
			<TR VALIGN=TOP>
				<TD WIDTH=30%>
					<font size=1 face=arial>
						#component.stpe-org.personnel#<BR>
					</font>
				</TD>
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
