##############################################################################
package App::Statements::Component::Person;
##############################################################################

use strict;
use Exporter;
use Date::Manip;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use App::Statements::Component;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_PERSON
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_PERSON);

$STMTMGR_COMPONENT_PERSON = new App::Statements::Component::Person(

#----------------------------------------------------------------------------------------------------------------------

'person.contactMethods' => {
	sqlStmt => $SQLSTMT_CONTACTMETHODS,
	sqlvar_entityName => 'Person',
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Contact Methods' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Contact Methods' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personphone?home=#param.home#'>Telephone</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personemail?home=#param.home#'>E-mail</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personpager?home=#param.home#'>Pager</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personfax?home=#param.home#'>Fax</A>, or
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personinternet?home=#param.home#'>Internet Address</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#1#/#4#?home=#param.home#',
			delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#1#/#4#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethods', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethods', [$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethods', [$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethods', [$personId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.contactMethodsAndAddresses' => {
	sqlStmt => $SQLSTMT_CONTACTMETHODS_AND_ADDRESSES,
	sqlvar_entityName => 'Person',
	sqlStmtBindParamDescr => ['Person ID for Attribute Table', 'Person ID for Address Table'],
	publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		separateDataColIdx => 2, # when the item_name is '-' add a row separator
		frame => {
					heading => 'Contact Methods/Addresses',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#',
				},
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		separateDataColIdx => 2, # when the item_name is '-' add a row separator
		frame => { heading => 'Edit Contact Methods/Addresses' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personphone?home=#param.home#'>Telephone</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personemail?home=#param.home#'>E-mail</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personphone?home=#param.home#'>Mobile</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personpager?home=#param.home#'>Pager</A>,
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personfax?home=#param.home#'>Fax</A>, or
					<A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-contact-personinternet?home=#param.home#'>Internet Address</A> }
				},
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-address-person?home=#param.home#'>Physical Address</A> }, url => 'x', },

			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-#6#/#4#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-#6#/#4#?home=#param.home#',
		},
		#stdIcons =>	{
		#	updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-address-person/#2#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-address-person/#2#?home=#param.home#',
		#},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId], 'panelEdit'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.contactMethodsAndAddresses', [$personId,$personId], 'panelInDlg'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.addresses' => {
	sqlStmt => $SQLSTMT_ADDRESSES,
	sqlvar_entityName => 'Person',
	sqlStmtBindParamDescr => ['Person ID for Addresses'],
	publishDefn => {
		columnDefn => [
			{ dataFmt => '<IMG SRC="/resources/icons/address.gif">', },
			{ head => 'Address', dataFmt => '<b>#0#</b><BR>#1#' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Addresses' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Addresses' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-address-person?home=#param.home#'>Physical Address</A> }, url => 'x', },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-address-person/#2#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-address-person/#2#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.addresses', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.addresses', [$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.addresses', [$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.addresses', [$personId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.miscNotes' => {
	sqlStmt => qq{
			select 	value_type, item_id, parent_id, item_name, value_text, %simpleDate:value_date%
				from  Person_Attribute
			where  	parent_id = ?
			and item_name = 'Misc Notes'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => 'Misc Notes (#5#): #4#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-misc-notes?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Misc Notes !' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Misc Notes' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-misc-notes?home=#param.home#'>Misc Notes</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.phoneMessage' => {
	sqlStmt => qq{
			select 	value_type, item_id, parent_id, item_name, value_text, %simpleDate:value_date%, value_textB, value_block, cr_user_id
				from  Person_Attribute
			where  	parent_id = ?
			and item_name = 'Phone Message'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => '#8# (#5#): #4#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-phmsg-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-phone-message?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Phone Message' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Phone Message' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-phone-message?home=#param.home#'>Phone Message</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-phmsg-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-phmsg-#0#/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.refillRequest' => {
	sqlStmt => qq{
			select 	value_type, item_id, parent_id, item_name, value_text, %simpleDate:value_date%, value_textB
				from  Person_Attribute
			where  	parent_id = ?
			and item_name = 'Refill Request'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => '#6# (#5#): #4#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-refillreq-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-refill-request?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Refill Request' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Refill Request' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-refill-request?home=#param.home#'>Refill Request</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-refillreq-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-refillreq-#0#/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panelTransp'); },
},


#-------------------------------------------------------------------------------------------------------------------------------------------------------------

'person.sessionActivity' => {
	sqlStmt => qq{
			select 	%simpleDate:to_char(a.activity_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT')% as activity_date,
				b.caption as caption, a.activity_data as data,
				a.action_scope as scope, a.action_key as action_key
				from  perSess_Activity a,  Session_Action_Type b
			where  	activity_stamp > (select max(activity_stamp) - 1 from perSess_Activity)
			and	a.session_id = ?
			and	a.action_type = b.id
			and 	rownum <= 20
			order by activity_date desc
		},
	publishDefn =>
		{
			columnDefn => [
				{ head => 'Time'},
				{ head => 'Event' },
				{ head => 'Details'},
				{ head => 'Scope', colIdx => 3,
					dataFmt =>
					{
						'person' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
						'org' => 'Organization <A HREF=\'/org/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
						'insurance' => 'Organization <A HREF=\'/org/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
						'insurance' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
						'person_attribute' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
						'offering_catalog' => 'FeeSchedule <A HREF=\'/search/catalog/detail/#4#/\' STYLE="text-decoration:none">#4#</A>',
						'offering_catalog_entry' => 'FeeSchedule <A HREF=\'/search/catalog/detail/#4#/ \' STYLE="text-decoration:none">#4#</A>',
						'invoice' => 'Claim <A HREF=\'/invoice/#4#/summary\' STYLE="text-decoration:none">#4#</A>',
						'invoice_item' => 'Claim <A HREF=\'/invoice/#4#\' STYLE="text-decoration:none">#4#</A>',
						'transaction' => 'Person <A HREF=\'/person/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
						'person_address' => 'Person <A HREF=\'/person/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
						'org_attribute' => 'Organization <A HREF=\'/org/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
						'_DEFAULT' => '#4#',
					},
				},
			],
		},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.sessionActivity', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.sessionActivity', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.sessionActivity', [$personId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.employmentAssociations' => {
	sqlStmt => qq{
			select	pa.value_type, pa.item_id, pa.item_name, pa.value_text, avt.caption
			from 	person_attribute pa, attribute_value_type avt
			where	pa.parent_id = ?
			and	pa.value_type = avt.id
			and pa.value_type between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			#{ colIdx => 2, head => 'EmpType', dataFmt => '&{fmt_stripLeadingPath:2}:', dAlign => 'RIGHT' },
			#{ colIdx => 4, head => 'Location', dataFmt => '#4# -', dAlign => 'LEFT' },
			#{ colIdx => 3, head => 'Status', dataFmt => '#3#' },
			{ head => 'Employer', dataFmt => '<A HREF = "/org/#3#/profile">#3#</A><BR>#4#, &{fmt_stripLeadingPath:2}' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-assoc-employment?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Employment' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Employment' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-assoc-employment?home=#param.home#'>Employment</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentAssociations', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentAssociations', [$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentAssociations', [$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentAssociations', [$personId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.emergencyAssociations' => {
	sqlStmt => qq{

			select 	value_type, item_id, item_name, value_text, value_textb
			from 	person_attribute
			where	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_EMERGENCY ]}
			and 	item_name != 'Guarantor'
			and 	item_name != 'Responsible Party'
		},
				#UNION ALL
			#					select 0 as value_type, 1 as item_id, 'a' as item_name, value_text as value_text, 'b' as value_textb, person_id
			#						from 	person pp, person_attribute aa
			#			where pp.person_id = aa.value_text and 	item_name like 'Association/Emergency/%'
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Emergency Contact', dataFmt => '<A HREF ="/person/#3#/profile">#3#</A> (&{fmt_stripLeadingPath:2}, <NOBR>#4#</NOBR>)' },
			#{ colIdx => 2, head => 'Relation', dataFmt => '&{fmt_stripLeadingPath:2}:', dAlign => 'RIGHT' },
			#{ colIdx => 3, head => 'Name', dataFmt => '#3#', dAlign => 'LEFT' },
			#{ colIdx => 4, head => 'Phone', dataFmt => '(#4#)', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-assoc-emergency?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Emergency' },
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
		frame => { heading => 'Edit Emergency' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-assoc-emergency?home=#param.home#'>Emergency Contact</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.emergencyAssociations', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.emergencyAssociations', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.emergencyAssociations', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.emergencyAssociations', [$personId], 'panelTransp'); },

},

#----------------------------------------------------------------------------------------------------------------------

'person.familyAssociations' => {
	sqlStmt => qq{
			select	value_type, item_id, item_name, value_text, value_textb
			from 	person_attribute
			where	parent_id = ?
			and	value_type = @{[ App::Universal::ATTRTYPE_FAMILY ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Family Contact', dataFmt => '<A HREF ="/person/#3#/profile">#3#</A> (&{fmt_stripLeadingPath:2}, <NOBR>#4#</NOBR>)' },
			#{ colIdx => 2, head => 'Relation', dataFmt => '&{fmt_stripLeadingPath:2}:', dAlign => 'RIGHT' },
			#{ colIdx => 3, head => 'Name', dataFmt => '#3#', dAlign => 'LEFT'},
			#{ colIdx => 4, head => 'Phone', dataFmt => '(#4#)', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-assoc-family?home=/#param.arl#' },

	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Family Contacts' },
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
		frame => { heading => 'Edit Family Contacts' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='#param.home#/../stpe-#my.stmtId#/dlg-add-assoc-family?home=#param.home#'>Family Contact</A> } },
			],
			icons => { data => [ { imgSrc => '/resources/icons/square-lgray-sm.gif' } ] },
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.familyAssociations', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.familyAssociations', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.familyAssociations', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.familyAssociations', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.authorization' => {
	sqlStmt => qq{
			select  value_type, item_id, item_name, value_text, %simpleDate:value_date%
			from 	person_attribute
			where	parent_id = ?
			and 	value_type in (
									@{[ App::Universal::ATTRTYPE_AUTHPATIENTSIGN ]},
									@{[ App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN ]},
									@{[ App::Universal::ATTRTYPE_AUTHINFORELEASE ]}
								)
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 2, head => 'Type', dataFmt => '&{fmt_stripLeadingPath:2} (#4#):' },
			{ colIdx => 3, head => 'Text', dataFmt => '#3#' },
			#{ colIdx => 4, head => 'Date', dataFmt => '#4#', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => {
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#',
				},
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Authorization' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Authorization' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-auth-patientsign?home=#param.home#'>Patient Signature Authorization</A>} },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-auth-providerassign?home=#param.home#'>Provider Assignment Indicator (for medicare)</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-auth-inforelease?home=#param.home#'>Information release</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#/?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#/?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.authorization', [$personId], 'panelInDlg'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.additionalData' => {
	sqlStmt => qq{
			select  item_name, value_text, value_type, item_id
			from 	person_attribute
			where	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_PERSONALGENERAL ]}

		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{  head => 'Additional Data', dataFmt => '&{fmt_stripLeadingPath:0}: ' },
			{ dataFmt => '#1#' },
			#{ colIdx => 1, head => 'Text', dataFmt => '#1#', dAlign => 'LEFT' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#2#/#3#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-person-additional?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Additional Data' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Additional Data' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-person-additional?home=#param.home#'>User Defined Data</A>} },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#2#/#3#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#2#/#3#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.additionalData', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.additionalData', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.additionalData', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.additionalData', [$personId], 'panelTransp'); },
},



#----------------------------------------------------------------------------------------------------------------------

'person.alerts' => {
	sqlStmt => qq{
			select 	 caption, detail, trans_type, trans_id, trans_type
			from 	transaction
			where	trans_type between 8000 and 8999
			and	trans_owner_type = 0
			and 	trans_owner_id = ?
			and	trans_status = 2
			order by trans_begin_stamp desc
		},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
			#{ colIdx => 0, dataFmt => '&{fmt_stripLeadingPath:0}:', dAlign => 'RIGHT' },
			#{ colIdx => 1,  dataFmt => '#1#', dAlign => 'LEFT' },
			{ head => 'Alerts', dataFmt => '#&{?}#<br/><I>#1#</I>' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-trans-#4#/#3#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-alert-person?home=/#param.arl#' },
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
				{	url => '#param.home#/../stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#',
					caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#'>Alert</A> },
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-trans-#4#/#3#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#4#/#3#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.alerts', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.alerts', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.alerts', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.alerts', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.insurance' => {
	sqlStmt => qq{
			select ins_internal_id, parent_ins_id, product_name,  decode(record_type, 3, 'coverage') as record_type,
					plan_name, decode(bill_sequence,1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive'),
					owner_person_id, ins_org_id, indiv_deductible_amt, family_deductible_amt, percentage_pay,
					copay_amt
			from insurance
			where record_type = 3
			and owner_person_id = ?
			order by bill_sequence

			},
			#select 	decode(bill_sequence,0,'Inactive',1,'Primary',2,'Secondary',3,'Tertiary','','W. Comp'),
			#	plan_name, ins_org_id, ins_internal_id, record_type, product_name
			#from 	insurance
			#where 	owner_person_id = ?
			#order by coverage_end_date desc, bill_sequence
			#},
	sqlStmtBindParamDescr => ['Person ID for Insurance Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 2, head => 'ID', dataFmt => '<A HREF = "/org/#7#/profile">#7#</A>(#5#): #4#, #2#' },
			#{ dataFmt => '&{fmt_stripLeadingPath:0} #5#'}
			#{ colIdx => 0, head => 'Type', dataFmt => '&{fmt_stripLeadingPath:0}:' },
			#{ colIdx => 1, head => 'Employer', dataFmt => '#1#' },
			#{ colIdx => 2, head => 'ID', dataFmt => '<A HREF = "/org/#2#/profile">#2#</A>' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-ins-coverage?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Health Coverage' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Health Coverage' },
		banner => {
			actionRows =>
			[
				{
					caption => qq{ Choose <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-ins-coverage?home=#param.home#'>Personal Insurance Coverage</A> },
					hints => ''
				},
				#{
				#	caption => qq{ Choose <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-ins-exists?home=#param.home#'>Insurance Plan</A> },
				#	hints => ''
				#},
				#{
				#	caption => qq{ Create Unique <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-ins-unique?home=#param.home#'>Insurance Plan</A> },
				#	hints => ''
				#},
				#{
				#	caption => qq{ Choose <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-person-attachworkerscomp?home=#param.home#'>Workers Compensation Plan</A> },
				#	hints => ''
				#},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-ins-#3#/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.insurance', [$personId], 'panelInDlg'); },
},

#----------------------------------------------------------------------------------------------------------------------
'person.extendedHealthCoverage' => {
	sqlStmt => qq{
			select 	decode(bill_sequence, 1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive'),
				decode(ins_type,0,'Self-Pay',1,'Insurance',2,'HMO',3,'PPO',4,'Medicare',5,'Medicaid',6,'W.Comp',7,'Client Billing',8,'Champus',9,'ChampVA',10,
					'FECA Blk Lung',11,'BCBS'), member_number, ins_internal_id, record_type, plan_name, policy_number, copay_amt, coverage_end_date, ins_org_id, product_name
			from 	insurance
			where 	owner_person_id = ?
			order by bill_sequence
			},
	sqlStmtBindParamDescr => ['Person ID for Insurance Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx =>0, head => 'BillSeq', dataFmt => '<b>#0#</b> (#1#, <b>#9#</b>, #10#, End Date: #8#)<BR><b> Policy Name: </b>#5# (#6#) <BR><b>  Member Num: </b>#2#, <b>Co-Pay:</b> $#7#'},

		],
		bullets => 'stpe-#my.stmtId#/dlg-update-ins-#4#/#3#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-ins-coverage?home=/#param.arl#' },
		#frame => {	editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Health Coverage' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Health Coverage' },
		banner => {
			actionRows =>
			[
				{
					caption => qq{ Choose <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-ins-exists?home=#param.home#'>Insurance Plan</A> },
					hints => ''
				},
				{
					caption => qq{ Create Unique <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-ins-unique?home=#param.home#'>Insurance Plan</A> },
					hints => ''
				},
				{
					caption => qq{ Choose <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-person-attachworkerscomp?home=#param.home#'>Workers Compensation Plan</A> },
					hints => ''
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-ins-#4#/#3#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-ins-#4#/#3#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.extendedHealthCoverage', [$personId], 'panelInDlg'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.careProviders' => {

	sqlStmt => qq{
			select	value_type, item_id, item_name, value_text, value_textb, parent_id
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_PROVIDER ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'CareProvider', dataFmt => '<A HREF = "/person/#3#/profile">#3#</A> (#2#) <A HREF ="/person/#5#/dlg-add-appointment?_f_resource_id=#3#&_f_attendee_id=#5#"> Sched Appointment</A>' },
			#{ colIdx => 1, head => 'Provider', dataFmt => '&{fmt_stripLeadingPath:1}:' },
			#{ colIdx => 2, head => 'Name', dataFmt => '#2#' },
			#{ colIdx => 3, head => 'Phone', dataFmt => '#3#', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => {
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-provider?home=/#param.arl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#',
				},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Care Providers' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Care Providers' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-assoc-provider?home=#param.home#'>Care Provider</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId], 'panelInDlg'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.allergies' => {
	sqlStmt => qq{
			select 	value_type, item_id,item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::MEDICATION_ALLERGY ]}, @{[ App::Universal::ENVIRONMENTAL_ALLERGY ]}, @{[ App::Universal::MEDICATION_INTOLERANCE ]})
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Allergies', dataFmt => '&{fmt_stripLeadingPath:2}: <I>#3#</I>' },
			#{ colIdx => 2, head => 'Prescription', dataFmt => '&{fmt_stripLeadingPath:2}:' },
			#{ colIdx => 3, head => 'Reactions', dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Allergies' },
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
		frame => { heading => 'Edit Allergies' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-allergy-medication?home=#param.home#'>Drug/Medication Allergies</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-allergy-environmental?home=#param.home#'>Environmental Allergies</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-allergy-intolerance?home=#param.home#'>Drug/Medication Intolerance</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allergies', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allergies', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allergies', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allergies', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------


'person.preventiveCare' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, %simpleDate:value_date%, %simpleDate:value_dateend%, value_text, value_textb
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::PREVENTIVE_CARE ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Preventive Care', dataFmt => '&{fmt_stripLeadingPath:2} : #6# (CPT #5#, #4#)' },
			#{ colIdx => 1, head => 'Type', dataFmt => '&{fmt_stripLeadingPath:1}:' },
			#{ colIdx => 2, head => 'Dates', dataFmt => '#2# - #3#', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-preventivecare?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Preventive Care' },
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
		frame => { heading => 'Edit Preventive Care' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-preventivecare?home=#param.home#'>Preventive Care</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.preventiveCare', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.preventiveCare', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.preventiveCare', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.preventiveCare', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.activeMedications' => {
	#App::Universal::TRANSSTATUS_ACTIVE is 2 which is tr.trans_status here
	#App::Universal::TRANSSTATUS_INACTIVE is 3
	sqlStmt => qq{
            		select 	tr.trans_type, tr.trans_id, tr.caption, %simpleDate:tr.trans_begin_stamp%, tt.caption,
            			tr.provider_id, tr.data_text_a
			from 	transaction tr, transaction_type tt
			where 	tr.trans_type between 7000 and 7999
			and 	tr.trans_type = tt.id
			and 	tr.trans_owner_type = 0
			and 	tr.trans_owner_id = ?
			and 	tr.trans_status = 2
			order by tr.trans_begin_stamp DESC
		},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 3, head => 'Date', dataFmt => '#2# (#4#)<BR>by <A HREF ="/person/#5#/profile">#5#</A> (#3#)' },
			#{ head => 'Active Medication', dataFmt => '#2# (#4#)', options => PUBLCOLFLAG_DONTWRAP },
			#{ colIdx => 2, head => 'Medicine', dataFmt => '#2#:' },
			#{ colIdx => 4, head => 'Type', dataFmt => '#4#' },
			#{ colIdx => 5, head => 'Doctor,Dosage', dataFmt => '(#4#, #5#)' },

		],
		bullets => 'stpe-#my.stmtId#/dlg-update-trans-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Active Medications' },
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
		frame => { heading => 'Edit Active Medications' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-medication-current?home=#param.home#'>Current Medication</A> } },
				{ caption => qq{ Prescribe <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-medication-prescribe?home=#param.home#'>Medication</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-trans-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------
			#select %simpleDate:trans_begin_stamp% , data_text_b, data_text_a, 0 as junk
			#from transaction t
			#where trans_begin_stamp =
			#			(select max(trans_begin_stamp)
			#			from transaction tt
			#			where t.data_text_b = tt.data_text_b
			#			and tt.trans_type between 12000 and 12999
			#			and tt.trans_owner_id = ?
			#			group by tt.data_text_b)
			#UNION ALL
			#select  %simpleDate:to_date('01/01/1529', 'MM/DD/YYYY')% AS trans_begin_stamp ,
			#	data_text_b,'a' as data_text_a,
			#	count(*) as junk
			#from transaction
			#where trans_type between 12000 and 12999
			#and trans_owner_id = ?
			#group by to_date('01/01/1529', 'MM/DD/YYYY') , data_text_b,'a'
			#order by data_text_b

###TO BE COMPLETED, the activeproblemnotes, ActiveProblemsDiagnosis and PersonIncompleteInvoices are missing

'person.testsAndMeasurements' => {
	sqlStmt => qq{
			select tm.trans_owner_id, %simpleDate:tm.trans_begin_stamp%,tm.data_text_b,tm.data_text_a,tc.no_of_tests
			from testsandmeasurements tm, testsandmeasurementscount tc
			where tm.trans_owner_id = tc.trans_owner_id
			and tm.data_text_b = tc.data_text_b
			and tm.trans_owner_id = ?
		},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table', 'Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Date', dataFmt => '#1# #2#', options => PUBLCOLFLAG_DONTWRAP },
			{ colIdx => 3, head => 'Tests', dataFmt => '#3#', options => PUBLCOLFLAG_DONTWRAP, dAlign => 'LEFT'},
			{ colIdx => 4, head => 'Value', dataFmt => '#4#' },
			#{ colIdx => 2, head => 'Type', dataFmt => '#2#' },
		],
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-tests?home=/#param.arl#' },
		#icons => { data => [ { imgSrc => '/resources/icons/square-lgray-sm.gif' } ] },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Tests/Measurements' },
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
		frame => { heading => 'Edit Tests/Measurements' },
		banner => {
			actionRows =>
			[
				{
					caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-tests?home=#param.home#'>New Tests/Measurements</A> },
					hints => 'This pane displays the latest tests carried out on the patient and their values'
				},
			],
		},
		#stdIcons =>	{
		#	updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
		#},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.activeProblems' => {
	sqlStmt => qq{
		select  0 as GROUP_SORT, %simpleDate:sysdate% as curr_onset_date, 'Claims in progress: ' || count(invoice_id), '' as provider_id, 11 as trans_type, 111 as trans_id, '' as code
		from    invoice where invoice_type = 0 and invoice_status < 3 and client_id = ?
		UNION ALL
		select  1 as GROUP_SORT, %simpleDate:sysdate% as curr_onset_date, '-', '-', -1 as trans_type, -1 as trans_id, '' as code
		from dual
		UNION ALL
		select 	2 as GROUP_SORT, %simpleDate:trans_begin_stamp% as curr_onset_date, data_text_a, provider_id, trans_type, trans_id, '' as code
		from 	transaction
		where 	trans_type = 3100 and trans_owner_id = ?
		and 	trans_status = 2
		UNION ALL
	    	select	2 as GROUP_SORT, %simpleDate:t.curr_onset_date% as curr_onset_date, ref.descr, provider_id, trans_type, trans_id, '(ICD ' || t.code || ')' as code
			from 	transaction t, ref_icd ref
			where 	trans_type = 3020
			and 	trans_owner_type = 0 and trans_owner_id = ?
			and 	t.code = ref.icd (+)
			and 	trans_status = 2
		UNION ALL
		select	2 as GROUP_SORT, %simpleDate:curr_onset_date%, data_text_a, provider_id, trans_type, trans_id, '' as code
		from 	transaction
		where 	trans_type between 3000 and 3010
		and 	trans_owner_id = ?
		and 	trans_status = 2
		order by GROUP_SORT, curr_onset_date DESC
		},
	sqlStmtBindParamDescr => ['Person ID for Open Invoices', 'Person ID for Notes Transactions', 'Person ID for Diagnoses Transactions', 'Person ID for ICD-9 Transactions'],
	publishDefn => {
		columnDefn => [
			{ head => 'Active Problems', dataFmt => '#2# <A HREF = "/search/icd">#6#</A><BR>by <A HREF = "/person/#3#/profile">#3#</A> (#1#)' },
			#{ colIdx => 2,head => 'Active Problems', dataFmt => '#2#' },
			#{ colIdx => 1, head => 'Date', options => PUBLCOLFLAG_DONTWRAP },
			#{ colIdx => 2, head => 'Description' },
			#{ colIdx => 3, head => 'Provider' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=/#param.arl#',
		separateDataColIdx => 2, # when the date is '-' add a row separator
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Active Problems' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Active Problems' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-activeproblems-notes?home=#param.home#'>Notes</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-activeproblems-perm?home=#param.home#'>Permanent Diagnosis</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-activeproblems-trans?home=#param.home#'>Diagnosis</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.surgeryProcedures' => {
	sqlStmt => qq{
	    	select	2 as GROUP_SORT, %simpleDate:t.curr_onset_date% as curr_onset_date, ref.descr, provider_id, trans_type, trans_id, '(ICD ' || t.code || ')' as code
			from 	transaction t, ref_icd ref
			where 	trans_type = 4050
			and 	trans_owner_type = 0 and trans_owner_id = ?
			and 	t.code = ref.icd (+)
			and 	trans_status = 2
		UNION ALL
		select	2 as GROUP_SORT, %simpleDate:curr_onset_date%, data_text_a, provider_id, trans_type, trans_id, '' as code
		from 	transaction
		where 	trans_type = 4050
		and 	trans_owner_id = ?
		and 	trans_status = 2
		order by GROUP_SORT, curr_onset_date DESC
		},
	sqlStmtBindParamDescr => ['Person ID for Diagnoses Transactions', 'Person ID for ICD-9 Transactions'],
	publishDefn => {
		columnDefn => [
			{ head => 'Surgery Procedures', dataFmt => '#2# <A HREF = "/search/icd">#6#</A><BR>performed on <A HREF = "/person/#3#/profile">#3#</A> (#1#)' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=/#param.arl#',
		separateDataColIdx => 2, # when the date is '-' add a row separator
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Surgery Procedures' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Surgery Procedures' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-activeproblems-surgical?home=#param.home#'>Surgery Procedures</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgeryProcedures', [ $personId, $personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgeryProcedures', [ $personId, $personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgeryProcedures', [ $personId, $personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgeryProcedures', [ $personId, $personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------


'person.advancedDirectives' => {
	sqlStmt => qq{
			select 	value_type, item_id, %simpleDate:value_date%, item_name
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::DIRECTIVE_PATIENT ]}, @{[ App::Universal::DIRECTIVE_PHYSICIAN ]})
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Advance Directives', dataFmt => '&{fmt_stripLeadingPath:3} (#2#)' },
			#{ colIdx => 2, head => 'Date', dataFmt => '#2#:', options => PUBLCOLFLAG_DONTWRAP },
			#{ colIdx => 3, head => 'Description', dataFmt => '&{fmt_stripLeadingPath:3}' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Advance Directives' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Advance Directives' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-directive-patient?home=#param.home#'>Patient Directive</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-directive-physician?home=#param.home#'>Physician Directive</A> } },
			],
		},
		stdIcons =>	{
			delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.advancedDirectives', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.advancedDirectives', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.advancedDirectives', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.advancedDirectives', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------


'person.hospitalizationSurgeriesTherapies' => {
	sqlStmt => qq{
			select  %simpleDate:trans_begin_stamp%, related_data, trans_status_reason,
				provider_id, caption, data_text_b, detail, data_text_c, trans_type, trans_id
			from 	transaction
			where 	trans_type between 11000 and 11999
			and 	trans_owner_id = ?
			and 	trans_status = 2
		},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 3, head => 'Provider', dataFmt => '#1# (#2#)<BR>Admitted by <A HREF ="/person/#3#/profile">#3#</A> (#0#)<BR>Room: #4#, Duration Of Stay: #5#, Orders: #6#, Procedures: #7#' },
			#{ head => 'Hospitalaziation', dataFmt => '<b>#1#, #2#</b><BR>Room:#4#, Duration Of Stay:#5# <BR>Orders:#6#, Procedures:#7#' },
			#{ colIdx => 1, head => 'Hospital', dataFmt => '#1#' },
			#{ colIdx => 2, head => 'Reason', dataFmt => '#2#' },
			#{ colIdx => 3, head => 'Provider', dataFmt => '#3#' },
			#{ colIdx => 4, head => 'Room', dataFmt => '#4#', dAlign => 'RIGHT' },
			#{ colIdx => 5, head => 'Duration', dataFmt => '#5#' },
			#{ colIdx => 4, head => 'Orders', dataFmt => '#6#' },
			#{ colIdx => 5, head => 'Procedures', dataFmt => '#7#', dAlign => 'RIGHT' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-trans-#8#/#9#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-hospitalization?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Active Hospitalization/Surgeries/Therapies' },
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
		frame => { heading => 'Edit Active Hospitalization/Surgeries/Therapies' },
		banner => {
			actionRows =>
			[
				{
					caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-hospitalization?home=#param.home#'>New Hospitalization</A> },
					hints => 'Info when a patient is admitted or discharged from a hospital'
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-trans-#8#/#9#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#8#/#9#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.hospitalizationSurgeriesTherapies', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.hospitalizationSurgeriesTherapies', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.hospitalizationSurgeriesTherapies', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.hospitalizationSurgeriesTherapies', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.affiliations' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text, %simpleDate:value_dateend%
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_AFFILIATION ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Affiliations'],
	publishDefn => {
		columnDefn => [
			{ head => 'Affiliation', dataFmt => '&{fmt_stripLeadingPath:2}, #3# (#4#) <br>', options => PUBLCOLFLAG_DONTWRAP },
			#{ colIdx => 2, head => 'Others' },
			#{ colIdx => 3, head => 'Date', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-affiliation?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Affiliations' },
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
		frame => { heading => 'Edit Affiliations' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-affiliation?home=#param.home#'>Affiliation</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.affiliations', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.affiliations', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.affiliations', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.affiliations', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.attendance' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attendance'],
	publishDefn => {
		columnDefn => [
			{ head => 'Reason', dataFmt => '&{fmt_stripLeadingPath:2}: #3#', options => PUBLCOLFLAG_DONTWRAP },
			#{ dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-attendance?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Attendance' },
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
		frame => { heading => 'Edit Attendance' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-attendance?home=#param.home#'>Attendance</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.attendance', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.attendance', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.attendance', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.attendance', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.benefits' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::BENEFIT_INSURANCE ]}, @{[ App::Universal::BENEFIT_RETIREMENT ]}, @{[ App::Universal::BENEFIT_OTHER ]})
		},
	sqlStmtBindParamDescr => ['Person ID for benefits'],
	publishDefn => {
		columnDefn => [
			{ head => 'Benefits', dataFmt => '&{fmt_stripLeadingPath:2}:', options => PUBLCOLFLAG_DONTWRAP },
			{ dataFmt => '#3#', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Benefits' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Benefits' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-benefit-insurance?home=#param.home#'>Insurance Benefit</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-benefit-retirement?home=#param.home#'>Retirement Benefit</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-benefit-other?home=#param.home#'>Other Benefit</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.benefits', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.benefits', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.benefits', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.benefits', [$personId], 'panelTransp'); },
},



#----------------------------------------------------------------------------------------------------------------------

'person.employmentRecord' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_EMPLOYMENTRECORD ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Employment Record'],
	publishDefn => {
		columnDefn => [
			{ head => 'Record', dataFmt => '&{fmt_stripLeadingPath:2}: ', options => PUBLCOLFLAG_DONTWRAP },
			{ dataFmt => '#3#' },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Employment Record' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Employment Record' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-employment-empinfo?home=#param.home#'>Employment Information</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-employment-salinfo?home=#param.home#'>Salary Information</A> } },
		],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#0#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentRecord', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentRecord', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentRecord', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.employmentRecord', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.certification' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text, %simpleDate:value_dateend%
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::ATTRTYPE_LICENSE ]}, @{[ App::Universal::ATTRTYPE_STATE ]}, @{[ App::Universal::ATTRTYPE_ACCREDITATION ]}, @{[ App::Universal::ATTRTYPE_SPECIALTY ]})
			and     item_name != 'Nurse/Title'
			and 	item_name != 'RN'
		},
	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
			{ dataFmt => '#2# (#4#): #3#' },
			#{ dataFmt => '#3#' },
			#{ colIdx => 3, head => 'Value' },
			#{ colIdx => 4, head => 'Date', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Certification' },
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
		frame => { heading => 'Edit Certification' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-certificate-license?home=#param.home#'>License</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-certificate-state?home=#param.home#'>State</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-certificate-accreditation?home=#param.home#'>Accreditation</A> } },
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-certificate-specialty?home=#param.home#'>Specialty</A> } },
		],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.certification', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.certification', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.certification', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.certification', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.associatedResources' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = 'Physician'
		},
	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
			{ head => 'Record', dataFmt => '&{fmt_stripLeadingPath:2}:' },
			{ dataFmt => '#3#'},
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-assoc-nurse-#0#/#1#?home=/#param.arl#',
		frame => { addUrl => 'stpe-#my.stmtId#/dlg-add-resource-nurse?home=/#param.arl#' },
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Associated Resources' },
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
		frame => { heading => 'Edit Associated Resources' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>Associated Physician</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-assoc-nurse-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-assoc-nurse-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedResources', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedResources', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedResources', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedResources', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------
'person.associatedSessionPhysicians' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text, value_int
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and 	item_name = 'SessionPhysicians'
			and value_int = 1
		},
	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
			{ head => 'Record', dataFmt => 'Session Set Of Physicans: #3#' },

		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Session Set Of Physicians' },
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
		frame => { heading => 'Edit Session Set Of Physicians' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-resource-session-physicians?home=#param.home#'>Session Set Of Physicians</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.myAssociatedResourceAppointments' => {
	sqlStmt => qq{
			select to_char(e.start_time, 'hh:miam') as start_time,
				ep2.value_text as resource_id,
				patient.complete_name as patient_complete_name,
				e.subject,
				et.caption as event_type,
				aat.caption as patient_type,
				e.remarks,
				ep1.value_text as patient_id,
				e.event_id, patient.person_id
			from 	Appt_Status, Appt_Attendee_type aat, Person patient, Person provider,
				Event_Attribute ep2, Event_Attribute ep1,
				Event_Type et, Event e
			where 	e.start_time between to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				and e.discard_type is null
				and e.event_status in (0,1,2)
				and et.id = e.event_type
				and ep1.parent_id = e.event_id
				and ep1.item_name='Appointment/Attendee/Patient'
					and ep1.value_text = patient.person_id
				and ep2.parent_id = ep1.parent_id
				and ep2.item_name='Appointment/Attendee/Physician'
					and ep2.value_text = provider.person_id
				and
				(	ep2.value_text = ? or
					ep2.value_text in
					(select value_text
						from person_attribute
						where parent_id = ?
							and item_name = 'Physician'
							and value_type = 250
					)
				)
				and aat.id = ep1.value_int
				and Appt_Status.id = e.event_status
			order by e.start_time
		},
	sqlStmtBindParamDescr => ['sysdate starting at 12 AM, sysdate at midnight, Org ID for event table, Person ID for Event_Attribute table, Person ID for Person_Attribute table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Associated Resources Appointments', dataFmt => '<a href="javascript:location=\'/schedule/apptsheet/encounterCheckin/#8#\';">#0#</A>:' },
			{ dataFmt => '<A HREF="/person/#7#/profile">#2#</A> <BR> (<i>#5#</i>) <BR> Scheduled with #1# <BR> Appt Type: #4#  <BR> Subject: #3#'},
		],
		bullets => '/modify/appointment/#9#/#8#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'My Associated Resources Appointments', editUrl => '/search/appointment/', },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit My Associated Resources Appointments' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>My Associated Resources Appointments</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.myAssociatedResourceInPatients' => {
	sqlStmt => qq{
		select 	%simpleDate:trans_begin_stamp%, complete_name,
			related_data,
			trans_status_reason,
			provider_id, caption,
			data_text_b,
			detail,
			data_text_c,
			data_text_a,
			consult_id,
			trans_id,trans_type,
			trans_owner_id
		from 	transaction, person
		where 	trans_type between 11000 and 11999
		and 	person_id = trans_owner_id
		and	(provider_id = ? or
			provider_id in
			(select value_text from person_attribute
				where parent_id = ?
					and value_type = 250
					and item_name = 'Physician'
			)
		)
		and 	trans_status = 2
		},
	sqlStmtBindParamDescr => ['Person ID for the person table, Person ID for the Person_Attribute table, Org ID for the Person_Attribute table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Associated Resources In Patients', dataFmt => '#0#' },
			{ dataFmt => '<A HREF="/person/#13#/chart">#1#</A> <BR> #2#, #3# <BR> (#4#) <BR> Room: #5#  <BR> Duration of Stay: #6# <BR> Orders: #7# <BR> Procedures: #8#'},
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'My Associated Resources In Patients' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit My Associated Resources In Patients' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>My Associated Resources Appointments</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.mySessionActivity' => {
	sqlStmt => qq{
		select  to_char(pa.activity_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as activity_date,
			sat.caption as caption,
			pa.activity_data as data,
			pa.action_scope as scope,
			pa.action_key as action_key
		from Session_Action_Type sat, perSess_Activity pa
		where pa.person_id = ?
			and	pa.activity_stamp >= trunc(sysdate)
			and	sat.id = pa.action_type
		order by pa.activity_stamp desc
	},

	sqlStmtBindParamDescr => ['Session ID for the perSess_Activity table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Session Activity', dataFmt => '#0# ' },
			{ dataFmt => '#1# #2#'},
		],
		#bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		frame => { heading => 'My Recent Activity (Today)' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit My Session Activity' },
		banner => {
			actionRows =>
			[
				#{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>My Associated Resources Appointments</A> } },
			],
		},
		stdIcons =>	{
			#updUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------
'person.accountPanel' => {
	sqlStmt => qq{
			select 	i.invoice_id, i.client_id, i.owner_id, i.submitter_id, i.invoice_date, i.total_cost, i.balance, ib.bill_to_id
			from invoice i, invoice_billing ib
			where i.client_id = ?
			and ib.invoice_id = i.invoice_id
			and ib.invoice_item_id is NULL
			and i.balance > 0
			order by i.invoice_date
			},
	sqlStmtBindParamDescr => ['Person ID for Invoice Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx =>0, head => 'Invoice', dataFmt => '<b>Invoice: </b>#0#, Bill To: #7#<BR><b>Total Amount:</b> $#5#, <b>Balance Remaining:</b> $#6#'},

		],
		bullets => 'stpe-#my.stmtId#/dlg-update-invoice/#0#?home=/#param.arl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
					heading => 'Outstanding Balances',
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=/#param.arl#',
				},
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.accountPanel', [$personId], 'panelInDlg'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.patientAppointments' => {
	sqlStmt => qq{
	    	select 	%simpleDate:e.start_time%,
	    		to_char(e.start_time, 'HH12:MI AM'),
	    		to_char(e.start_time+(e.duration/1440), 'HH12:MI AM'),
	    		eadoc.value_text,
	    		e.subject,
	    		to_char(e.start_time, 'MM-DD-YYYY'),
	    		1 as group_sort,
	    		trunc(e.start_time) as apptdate
		from 	event_attribute eaper, event_attribute eadoc, event e
		where 	eaper.parent_id = e.event_id
		and	eadoc.parent_id = e.event_id
		and	eaper.parent_id = eadoc.parent_id
		and	eaper.item_name like '%Patient'
		and	eadoc.item_name like '%Physician'
		and	eaper.value_text = ?
		and	e.start_time > sysdate
		UNION
		select 	%simpleDate:sysdate%,
			to_char(sysdate, 'HH12:MI AM'),
			to_char(sysdate, 'HH12:MI AM'),
			'-',
			'-',
			to_char(sysdate, 'MM-DD-YYYY'),
			2 as group_sort,
			trunc(sysdate) as apptdate
			from dual
		UNION
	    	select 	%simpleDate:e.start_time%,
	    		to_char(e.start_time, 'HH12:MI AM'),
	    		to_char(e.start_time+(e.duration/1440), 'HH12:MI AM'),
	    		eadoc.value_text,
	    		e.subject,
	    		to_char(e.start_time, 'MM-DD-YYYY'),
	    		3 as group_sort,
	    		trunc(e.start_time) as apptdate
		from 	event_attribute eaper, event_attribute eadoc, event e
		where 	eaper.parent_id = e.event_id
		and	eadoc.parent_id = e.event_id
		and	eaper.parent_id = eadoc.parent_id
		and	eaper.item_name like '%Patient'
		and	eadoc.item_name like '%Physician'
		and	eaper.value_text = ?
		and	e.start_time < sysdate
		order by group_sort, apptdate
		},
	sqlStmtBindParamDescr => ['Person ID for Event Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Appointments', dataFmt => '<a href="javascript:location=\'/schedule/apptsheet/#5#\';">#0#</A>:' },
			{ dataFmt => 'Scheduled with <A HREF="/person/#3#/profile">#3#</A> at #1# <BR> Subject: #4#'},

		],
		#bullets => 'stpe-#my.stmtId#/dlg-remove-patientappointments?home=/#param.arl#',
		separateDataColIdx => 3, # when the date is '-' add a row separator
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Appointments' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Appointments' },
		banner => {
			actionRows =>
			[
				#{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-patientappointments?home=#param.home#'>Appointments</A> } },
			],
		},
		stdIcons =>	{
			# delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments', [  $personId, $personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments', [  $personId, $personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments', [  $personId, $personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments', [  $personId, $personId], 'panelTransp'); },
},


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

'person.recentlyVisitedPatients' => {
	sqlStmt => qq{

			select p.complete_name, pvc.view_key  from PerSess_View_Count pvc,
						person p , Person_Org_Category  pog
						where p.person_id = pvc.view_key AND pvc.person_id = ? and
						pog.person_id = p.person_id AND pog.category = 'Patient'
						and	pvc.view_latest >= to_date(sysdate)
			order by pvc.view_latest desc

		},
	sqlStmtBindParamDescr => ['Person Id for PerSess_View_count table'],
	publishDefn => {
		columnDefn => [
				{ head => 'Recently Visited Patients', dataFmt => '<A HREF="/person/#1#/profile" >#1#</A> <A> (#0#)</A>' },
			],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Recently Visited Patients' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Recently Visited Patients' },
		banner => {
			actionRows =>
			[
				#{ caption => qq{ Add <A HREF= '#param.home#/../stpe-#my.stmtId#/dlg-add-patientappointments?home=#param.home#'>Appointments</A> } },
			],
		},
		stdIcons =>	{
			# delUrlFmt => '#param.home#/../stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.diagnosisSummary' => {
	sqlStmt => qq{
			select member_name as code, name as description, to_char(min(trans_begin_stamp), 'mm/dd/yy') as earliest_date,
			       to_char(min(trans_begin_stamp), 'mm/dd/yy') as latest_date, count(member_name) as num_times
			from   ref_icd, invoice_claim_diags,transaction, invoice
			where  client_id = ?
			and    trans_id = main_transaction
			and    invoice_claim_diags.parent_id = invoice.invoice_id
			and    ref_icd.icd (+) = member_name
			group  by member_name, name
	},
	sqlStmtBindParamDescr => ['Person ID for Diagnosis Summary'],
	publishDefn =>
	{
		columnDefn =>
		[
			{ colIdx =>0, head => 'Code', dataFmt => '#0#'},
			{ colIdx =>0, head => 'Diagnosis', dataFmt => '#1#'},
			{ colIdx =>1, head => 'Earliest Date', dataFmt => '#2#'},
			{ colIdx =>2, head => 'Latest Date', dataFmt => '#3#'},
			{ colIdx =>3, head => 'Diagnosed Times', dataFmt => '#4#', dAlign => 'CENTER'},
		],
		frame =>
		{
				heading => 'Diagnosis Summary'
		},
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
		frame =>
		{
				heading => ''
		},
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

);

1;