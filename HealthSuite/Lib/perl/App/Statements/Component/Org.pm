##############################################################################
package App::Statements::Component::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_ORG
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_ORG);

$STMTMGR_COMPONENT_ORG = new App::Statements::Component::Org(

#----------------------------------------------------------------------------------------------------------------------

'org.contactMethods' => {
	sqlStmt => $SQLSTMT_CONTACTMETHODS,
	sqlvar_entityName => 'Org',
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Contact Methods' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Contact Methods' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgphone?home=#param.home#'>Telephone</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgfax?home=#param.home#'>Fax</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgemail?home=#param.home#'>E-mail</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orginternet?home=#param.home#'>Internet</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#1#/#4#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#1#/#4#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.contactMethodsAndAddresses' => {
	sqlStmt => $SQLSTMT_CONTACTMETHODS_AND_ADDRESSES,
		sqlvar_entityName => 'Org',
		sqlStmtBindParamDescr => ['Org ID for Attribute Table', 'Org ID for Address Table'],
		publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			separateDataColIdx => 2, # when the item_name is '-' add a row separator
			frame => { heading => 'Contact Methods/Addresses' },
		},
		publishDefn_panelTransp =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.transparent',
			inherit => 'panel',
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			separateDataColIdx => 2, # when the item_name is '-' add a row separator
			frame => { heading => 'Edit Contact Methods/Addresses' },
			banner => {
				actionRows =>
				[
					{ caption => qq{ Add
						<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgphone?home=#param.home#'>Telephone</A>,
						<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgfax?home=#param.home#'>Fax</A>,
						<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgemail?home=#param.home#'>E-mail</A>,
						<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orginternet?home=#param.home#'>Internet</A>,
						<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-orgbilling?home=#param.home#'>Billing Contact</A> }
					  },
					{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-address-org?home=#param.home#'>Physical Address</A> }, url => 'x', },

				],
			},
			stdIcons =>	{
				updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-#5#/#3#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-#5#/#3#?home=#param.home#',
			},
		},
		publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses', [$orgId,$orgId]); },
		publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses', [$orgId,$orgId], 'panel'); },
		publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses', [$orgId,$orgId], 'panelTransp'); },
		publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses', [$orgId,$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.alerts' => {
	sqlStmt => qq{
		select 	trans_id, trans_type, caption, detail
		from 	transaction
		where	trans_owner_type = 1
		and 	trans_owner_id = ?
		and	trans_type between 8000 and 8999
		and	trans_status = 2
		order by trans_begin_stamp desc
		},
	sqlStmtBindParamDescr => ['Org ID for Transaction Table'],
	publishDefn => {
			columnDefn => [
				#{ colIdx => 0, dataFmt => '&{fmt_stripLeadingPath:0}:', dAlign => 'RIGHT' },
				#{ colIdx => 1,  dataFmt => '#1#', dAlign => 'LEFT' },
				{ head => 'Alerts', dataFmt => '#2#<br/><I>#3#</I>' },
			],
			bullets => 'stpe-#my.stmtId#/dlg-update-trans-#1#/#0#?home=/#param.arl#',
			frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-alert-org?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Alerts' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Alerts' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-alert-org?home=#param.home#'>Alert</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-trans-#1#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#1#/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.generalInformation' => {
	sqlStmt => qq{
		select 	name_primary, name_trade, category, tax_id, org_id
		from 	org
		where 	org_id = ?
		},
	sqlStmtBindParamDescr => ['Org ID for Org Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Primary Name', dataFmt => '<b>#0#</b> <br> Legal Name: #0# <br> Tax ID: #3# <br> Category: #2#' },
			#{ colIdx => 1, head => 'Trade Name', dataFmt => '#1#' },
			#{ colIdx => 2, head => 'Category', dataFmt => '#2#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-org/#4#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-attr-0?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'General Information' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit General Information' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-attr-0?home=#param.home#'>General Information</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-org/#4#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-org/#4#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.credentials' => {
	sqlStmt => qq{
		select  value_type, item_id, item_name, value_text
		from 	org_attribute
		where	parent_id = ?
		and 	value_type = @{[ App::Universal::ATTRTYPE_CREDENTIALS ]}
		},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Name', dataFmt => '&{fmt_stripLeadingPath:2}' },
			{ dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-credential?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Credentials' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Credentials' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-credential?home=#param.home#'>Credentials</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$orgId], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.departments' => {
	sqlStmt => qq{
		select 	ocat.parent_id, org.name_primary, org.parent_org_id, org.org_id
		from 	org org, org_category ocat
		where 	org.parent_org_id = ?
		and 	ocat.member_name = 'Department'
		and 	ocat.parent_id = org.org_id
		},
	sqlStmtBindParamDescr => ['Org ID for Org Table'],
	publishDefn => {
		columnDefn => [
			#{ colIdx => 0, head => 'Org Category', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Primary Name', dataFmt => '#1#:' },
			{ colIdx => 2, head => 'Org ID', dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-org-dept/#3#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-org-dept?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Departments' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Departments' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-org-dept?home=#param.home#'>Department</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-org-dept/#3#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-org-dept/#3#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.associatedOrgs' => {
	sqlStmt => qq{
			select 	item_id, value_type, item_name, value_text
			from 	org_attribute
			where	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
		},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 2, head => 'Org', dataFmt => '&{fmt_stripLeadingPath:2}:' },
			{ colIdx => 3, head => 'Org ID', dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-resource-org?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Associated Orgs' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Associated Orgs' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-resource-org?home=#param.home#'>Associated Organization</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#1#/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.personnel' => {
	sqlStmt => qq{
			select 	p.complete_name, pa.category, pa.person_id, pa.org_id
			from 	person_org_category pa, person p
			where	pa.org_id = ?
				and pa.category <> 'Patient'
				and pa.category <> 'Guarantor'
				and	p.person_id = pa.person_id
			order by pa.category, p.complete_name, pa.person_id
		},
	sqlStmtBindParamDescr => ['Org ID for org_id in Person_Org_Category Table'],
	publishDefn => {
		columnDefn => [
			#{ head => 'Category', dataFmt => '#1#: <A HREF = "/person/#2#/profile">#0# (#2#)</A>'},
			{head => 'Name', colIdx => 0, dataFmt => '<A HREF = "/person/#2#/profile">#2# #0#</A>'},
			{head => 'Type', colIdx => 1, dataFmt => '#1#'},
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-password/#2#/#3#?home=/org/#3#/personnel',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		frame => { heading => 'Personnel', editUrl => 'personnel' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		frame => { editUrl => 'personnel' },
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Personnel' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-personnel?home=#param.home#'>Personnel</A> }	},
				#{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-physician?home=#param.home#'>Physician</A> }	},
				#{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-nurse?home=#param.home#'>Nurse</A> }	},
				#{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-staff?home=#param.home#'>Staff Member</A> }	},
			],
		},
		stdIcons =>	{
			#updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-#1#/#2#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-#1#/#2#?home=#param.home#',
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-password/#2#/#3#?home=/org/#3#/personnel', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-#1#/#2#?home=/org/#3#/personnel',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$orgId] ); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$orgId], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.associatedResourcesStats' => {
	sqlStmt => qq{
			select 	category, count(category), org_id
			from 	person_org_category
			where	org_id = ?
			group by category, org_id
		},
	sqlStmtBindParamDescr => ['Org ID for org_id in Person_Org_Category Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Category', dataFmt => '#1# #0#(s)' },
		],
		#bullets => 'stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Personnel', editUrl => 'personnel' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		frame => { editUrl => 'personnel?home=/#param.arl#' },
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Personnel' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-physician?home=#param.home#'>Physician</A> }	},
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-nurse?home=#param.home#'>Nurse</A> }	},
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-staff?home=#param.home#'>Staff Member</A> }	},
			],
		},
		#stdIcons =>	{
		#	updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#1#/#0#?home=#param.home#',
		#},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$orgId] ); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$orgId], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.feeSchedule' => {
	sqlStmt => qq{
			select 	oc.catalog_id, oc.caption, count(oce.entry_id)
			from	offering_catalog oc, offering_catalog_entry oce
			where	oc.catalog_id = oce.catalog_id (+)
			and	oc.org_id = ?
			group by oc.catalog_id, oc.caption, oc.description, oc.parent_catalog_id
			order by oc.caption
		},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'ID', url => '/search/catalog/detail/#0#', dataFmt => '&{level_indent:0}#0#', tDataFmt => '&{count:0} Schedules', options => PUBLCOLFLAG_DONTWRAP },
			{ colIdx => 1, head => 'Name' },
			{ colIdx => 2, head => 'Entries', dAlign => 'CENTER', tAlign=>'CENTER', summarize => 'sum' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-catalog/#0#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-catalog?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Fee Schedule' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Fee Schedule' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-catalog?home=#param.home#'>Fee Schedule</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-catalog/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-catalog/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.catalogItems' => {
	sqlStmt => qq{
			select 	oce.entry_id, oce.catalog_id, oce.code, oce.unit_cost
			from 	offering_catalog_entry oce, offering_catalog oc
			where	oc.catalog_id = oce.catalog_id
			and	oc.org_id = ?
			order by oce.entry_type, oce.status, oce.name, oce.code
		},
	sqlStmtBindParamDescr => ['Org ID for offering catalog Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Catalog ID', options => PUBLCOLFLAG_DONTWRAP },
			{ colIdx => 2, head => 'Code' },
			{ colIdx => 3, head => 'Cost' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-catalog-item/#0#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-catalog-item?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Catalog Items' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Catalog Items' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-catalog-item?home=#param.home#'>Catalog Item</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-catalog-item/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-catalog-item/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$orgId], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.insurancePlans' => {
	sqlStmt => qq{
			select o.ins_internal_id, o.parent_ins_id, o.product_name,  decode(o.record_type, 1, 'product', 2, 'plan', 3, 'coverage') as record_type,
					o.plan_name, o.owner_org_id, o.owner_org_id, cm.caption, o.ins_type,
					o.indiv_deductible_amt, o.family_deductible_amt, o.percentage_pay, o.copay_amt
			from insurance o, claim_type cm
			where o.record_type in (1, 2)
			and ins_type = cm.id
			and o.ins_org_id = ?
		},
	#sqlStmt => qq{
	#		select 	o.plan_name, o.group_number,
	#			o.group_name, o.ins_internal_id,
	#			decode(o.record_type, 0, 'ins-', 1, 'ins-', 2, 'ins-', 3, 'ins-', 4, 'ins-', 5, 'ins-')||o.record_type as test
	#		from 	insurance o, claim_type ct
	#		where	ct.id = o.ins_type
	#		and	o.ins_org_id = ?
	#		and	o.record_type in (0,1,2,3,4,5)
	#		and	o.ins_type != 6
	#		UNION ALL
	#		select 	o.plan_name, o.product_name, o.ins_org_id, o.ins_internal_id, decode(o.record_type, 5, 'ins-')||o.record_type as test
	#		from 	insurance o, claim_type ct
	#		where	ct.id = o.ins_type
	#		and	o.ins_org_id = ?
	#		and	o.record_type = 5
	#		and	o.ins_type = 6
	#		UNION ALL
	#		select 	'Workers Comp' as item_name, value_text, value_textb, item_id,'attr-'||361 as test
	#		from 	org_attribute
	#		where	parent_id = ?
	#		and 	value_type = @{[ App::Universal::ATTRTYPE_INSGRPWORKCOMP ]}
	#		UNION ALL
	#		select 	'Ins Plan' as item_name, value_text, value_textb, item_id,'attr-'||360  as test
	#		from 	org_attribute
	#		where	parent_id = ?
	#		and 	value_type = @{[ App::Universal::ATTRTYPE_INSGRPINSPLAN ]}
	#	},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table','Org ID for Attribute Table','Org ID for Attribute Table','Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Policy Name', dataFmt => '#2#(#3#): #4#, #6#, (#7#)' },
			#{ head => 'Plan', dataFmt => '#2# (#1#)' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		#separateDataColIdx => 2, # when the item_name is '-' add a row separator
		frame => { heading => 'Insurance Plans' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		separateDataColIdx => 2, # when the item_name is '-' add a row separator
		frame => { heading => 'Edit Insurance Plans' },
		banner => {
			actionRows =>
			[
				{
					caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-ins-product?_f_ins_org_id=#param.org_id#&home=#param.home#'>Insurance Product</A> },
					hints => "Insurance Plan offered to org's customers"
				},
				{
					caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-ins-plan?_f_ins_org_id=#param.org_id#&home=#param.home#'>Insurance Plan</A> },
					hints => "Insurance Plan offered to org's customers"
				},
				#{
				#	caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-ins-newplan?home=#param.home#'>Insurance Plan</A> },
				#	hints => "Insurance Plan offered to org's customers"
				#},
				#{
				#	caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-ins-workerscomp?home=#param.home#'>Workers Compensation Plan</A> },
				#	hints => "Worker's Compensation Plan offered to org's customers"
				#},
				#{
				#	caption => qq{ Choose <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-org-attachinsurance?home=#param.home#'>Insurance Plan</A> },
				#	hints => "Insurance Plan offered to org's employees"
				#},
				#{
				#	caption => qq{ Choose <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-org-attachworkerscomp?home=#param.home#'>Workers Compensation Plan</A> },
				#	hints => "Worker's Compensation Plan offered to org's employees"
				#},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-ins-#3#/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHierHtml($page, $flags, ['org.insurancePlans', 0, 1], [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.healthMaintenanceRule' => {
	sqlStmt => qq{
			select  rule_id, start_age, end_age, diagnoses, measure, directions, src_begin_date, src_end_date
			from 	Hlth_Maint_Rule
			where 	org_id = ?
		},
	sqlStmtBindParamDescr => ['Org ID for HealthMaintenanceRule'],
	publishDefn => {
		columnDefn => [
			{ head => 'Rule', dataFmt => '#0#: #3#, #4#, #5# (#6#, #7#)' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-health-rule/#0#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-health-rule?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Health Maintenance Rules' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Health Maintenance Rules' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-health-rule?home=#param.home#'>Health Maintenance Rule</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-health-rule/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-health-rule/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule', [$orgId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule', [$orgId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule', [$orgId], 'panelTransp'); },
},



);

1;
