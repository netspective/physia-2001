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
	@ISA @EXPORT $STMTMGR_COMPONENT_PERSON $PUBLDEFN_CONTACTMETHOD_DEFAULT
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_PERSON);

my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;

$PUBLDEFN_CONTACTMETHOD_DEFAULT = {
	bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-#5#/#3#?home=#homeArl#',
	columnDefn => [
		{
			head => 'P',
			hHint => 'Preferred Method',
			comments => 'Boolean value indicating whether the contact method is a preferred method or not',
			dataFmt => ['', '<IMG SRC="/resources/icons/checkmark.gif">'],
			hint => 'Preferred'
		},
		{ head => 'Type', dataFmt => '#4#:', dAlign => 'RIGHT' },
		{ head => 'Value' },
	],
};

$STMTMGR_COMPONENT_PERSON = new App::Statements::Component::Person(
#----------------------------------------------------------------------------------------------------------------------
'person.account-notes' => {


				sqlStmt => qq{
					select  trans_owner_id, detail,trans_id,trans_type
					from transaction
					where trans_owner_id = :1 and
					provider_id = :2 and
					trans_status = 2 and
					trans_type = $ACCOUNT_NOTES
				},
				sqlStmtBindParamDescr => ['Person ID for transaction table'],
				publishDefn => {
						columnDefn => [
							{ head => 'Account Notes', dataFmt => '#&{?}#<br/><I>#1#</I>' },
						],
						bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#3#/#2#?home=#homeArl#',
						frame => {
							addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-account-notes?home=#homeArl#',
							editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
							},
					},
					publishDefn_panel =>
					{
						# automatically inherites columnDefn and other items from publishDefn
						style => 'panel',
						frame => { heading => 'Account Notes' },
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
						frame => { heading => 'Edit Account Notes' },
						banner => {
							actionRows =>
							[
								{	url => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#',
									caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-account-notes/#param.person_id#?home=#param.home#'>Account Notes</A> },
								},
							],
						},
						stdIcons =>	{
							updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#3#/#param.person_id#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#3#/#2#/#0#?home=#param.home#'
						},
		},

				publishComp_st => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId,$sessionId] ); },
				publishComp_stp => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id');  $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId,$sessionId], 'panel'); },
				publishComp_stpe => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId,$sessionId], 'panelEdit'); },
				publishComp_stpt => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id');$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId,$sessionId], 'panelTransp'); },
		},


'person.group-account-notes' => {

			sqlStmt => qq{
				select complete_name, count (*) as count, min(trans_begin_stamp),max(trans_begin_stamp),
				trans_owner_id
				from transaction, person
				where provider_id = ? and
				trans_owner_id = person_id and
				trans_status = 2 and
				trans_type = $ACCOUNT_NOTES
				group by complete_name,trans_owner_id
			},
			sqlStmtBindParamDescr => ['Person ID for transaction table'],

			publishDefn => {
				columnDefn => [
					{ head=> 'Patient Name', url => "/person/#4#/profile" },
					#{ head=> 'Notes#', dAlign => 'right' ,url => '/person/#param.person_id#/stpe-person.alerts/#4#?home=#homeArl#' },
					{ head=> 'Notes#', dAlign => 'right' ,url => '/person/#param.person_id#/stpe-person.account-notes?home=#homeArl#&person_id=#4#' },
					#{ head=> 'Notes#', dAlign => 'right' ,url => '/person/#param.person_id#/stpe-person.alerts/dlg-add-alert-person/#4#/?home=#homeArl#' },
					{ head=> 'First  Note Date' },
					{ head=> 'Last Note Date' },
				],
				frame => {
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
				},
			},
			publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.static',
				flags => 0,
				frame => { heading => 'Account Notes' },
			},
			publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
			},


			publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.group-account-notes', [$personId] ); },
			publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.group-account-notes', [$personId], 'panel'); },
			publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.group-account-notes', [$personId], 'panelEdit'); },
			publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.group-account-notes', [$personId], 'panelTransp'); },
	},



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
		frame => {
			heading => 'Contact Methods',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personphone?home=#param.home#'>Telephone</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personemail?home=#param.home#'>E-mail</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personpager?home=#param.home#'>Pager</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personfax?home=#param.home#'>Fax</A>, or
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personinternet?home=#param.home#'>Web Page (URL)</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#4#?home=#param.home#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#1#/#4#?home=#param.home#',
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
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
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
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personphone?home=#homeArl#'>Telephone</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personemail?home=#homeArl#'>E-mail</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personphone?_f_attr_name=Cellular&home=#homeArl#'>Mobile</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personpager?home=#homeArl#'>Pager</A>,
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personfax?home=#homeArl#'>Fax</A>, or
					<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-contact-personinternet?home=#homeArl#'>Web Page (URL)</A> }
				},
				{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-address-person?home=#homeArl#'>Physical Address</A> }, url => 'x', },

			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-#5#/#3#?home=#homeArl#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-#5#/#3#?home=#homeArl#',
		},
		#stdIcons =>	{
		#	updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-address-person/#2#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-address-person/#2#?home=#param.home#',
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

#OLD WAY
#	{SELECT
#		oc.catalog_id,
#		count(oce.entry_id) entries_count,
#		oc.caption,
#		oc.description,
#		oc.parent_catalog_id,
#		oc.internal_catalog_id,
#		'Add',
#		DECODE(oc_a.value_int, 1, '(Capitated)', null) AS capitated
#	FROM    person_attribute pa,
#		ofcatalog_Attribute oc_a,
#		offering_catalog oc,
#		offering_catalog_entry oce
#	WHERE   pa.parent_id = :1
#	AND	pa.item_name = 'Fee Schedules'
#	AND	pa.item_type = 0
#	AND	pa.value_type = @{[ App::Universal::ATTRTYPE_TEXT ]}
#	AND	pa.value_int = oc.internal_catalog_id
#	AND	oce.catalog_id (+) = oc.internal_catalog_id
#	AND 	oc_a.parent_id (+) = oc.internal_catalog_id
#	GROUP BY
#		oc.catalog_id,
#		oc.internal_catalog_id,
#		oc.caption,
#		oc.description,
#		oc.parent_catalog_id ,
#		oc_a.value_int
#	ORDER BY
#		oc.catalog_id
#
#	},

'person.feeschedules'=>
{
	sqlStmt =>qq
	{SELECT	oc.catalog_id,
		oc.caption,
		oc.description,
		oc.internal_catalog_id,
		pa.item_id
	FROM    person_attribute pa,
		offering_catalog oc
	WHERE   pa.parent_id = :1
	AND	pa.item_name = 'Fee Schedule'
	AND	pa.item_type = 0
	AND	pa.value_type = @{[ App::Universal::ATTRTYPE_INTEGER ]}
	AND	pa.value_int = oc.internal_catalog_id
	ORDER BY oc.catalog_id
	},
	sqlvar_entityName => 'Person',
	sqlStmtBindParamDescr => ['Person ID for Fee Schedules'],
	publishDefn =>
	{
		frame =>
		{
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-feeschedule-person?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
		columnDefn =>
			[
			{ head => 'Associated Fee Schedules', dataFmt => '<A HREF=/org/#session.org_id#/catalog/#3#/#0#>#0#</A>'  },
			{colIdx => 1,  dAlign => 'left'},
			],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-feeschedule-person/#4#?home=#homeArl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
			heading => 'Associated Fee Schedules',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
		frame => { heading => 'Edit Associated Fee Schedule' },
		banner =>
		{
			actionRows =>
			[
			{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-feeschedule-person?home=#param.home#'>Associated Fee Schedules</A> }, url => 'x', },
			],
		},
		stdIcons =>
		{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-feeschedule-person/#4#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-feeschedule-person/#4#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.feeschedules', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.feeschedules', [$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.feeschedules', [$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.feeschedules', [$personId], 'panelEdit'); },
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
		frame => {
			heading => 'Addresses',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-address-person?home=#param.home#'>Physical Address</A> }, url => 'x', },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-address-person/#2#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-address-person/#2#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-misc-notes?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Misc Notes' },
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-misc-notes?home=#param.home#'>Misc Notes</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
			select 	trans_id, trans_owner_id, trans_type, decode(trans_status,4,'Read',5,'Not Read'), caption, provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b, cr_user_id, consult_id
				from  Transaction
			where  	trans_owner_id = ?
			and caption = 'Phone Message'
                        and data_num_a is null
                        union
                        select  trans_id, trans_owner_id, trans_type, decode(trans_status,4,'Read',5,'Not Read'), caption, provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b, cr_user_id, consult_id
                                from  Transaction
                        where   trans_owner_id = ?
                        and caption = 'Phone Message'
                        and data_num_a is not null
                        and trans_status = 5
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => "<A HREF='/person/#10#/profile'>#10#</A> (#6#): #7# (<A HREF='/person/#5#/profile'>#5#</A>)" },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#0#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-phone-message?_f_person_called=#param.person_id#&home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-phone-message?_f_person_called=#param.person_id#&home=#param.home#'>Phone Message</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-refill-#2#/#0#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#2#/#0#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.phoneMessage', [$personId,$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.refillRequest' => {
	sqlStmt => qq{
			select 	trans_id, trans_owner_id, trans_type, decode(trans_status,7,'Filled',6,'Pending'), caption,
					provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b, cr_user_id, processor_id, receiver_id
				from  Transaction
			where  	trans_owner_id = ?
			and caption = 'Refill Request'
                        and data_num_a is null
                        union
                        select  	trans_id, trans_owner_id, trans_type, decode(trans_status,7,'Filled',6,'Pending'), caption,
                        		provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b, cr_user_id, processor_id, receiver_id
                                from  Transaction
                        where   trans_owner_id = ?
                        and caption = 'Refill Request'
                        and data_num_a is not null
                        and trans_status = 6
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table', 'Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => "<A HREF='/person/#9#/profile'>#9#</A> (#6#): <A HREF='/person/#11#/profile'>#11#</A> #7# (#3#)" },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-refill-#2#/#0#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-refill-request?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-refill-request?home=#param.home#'>Refill Request</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#0#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-refill-#2#/#0#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId,$personId], 'panelTransp'); },
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-employment?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-employment?home=#param.home#'>Employment</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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

			select 	value_type, item_id, item_name,
				(select p.person_id
					from person p
						where p.person_id = b.value_text)person_id, value_textb,
				(select a.value_text
					from person_attribute a
						where a.value_int = 0
						and a.item_id = b.item_id)value_text
			from 	person_attribute b
			where	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_EMERGENCY ]}
			and 	item_name not in( 'Guarantor', 'Responsible Party')

		},
				#UNION ALL
			#					select 0 as value_type, 1 as item_id, 'a' as item_name, value_text as value_text, 'b' as value_textb, person_id
			#						from 	person pp, person_attribute aa
			#			where pp.person_id = aa.value_text and 	item_name like 'Association/Emergency/%'
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Emergency Contact', dataFmt => '<A HREF ="/person/#3#/profile">#3#</A>#5# (&{fmt_stripLeadingPath:2}, <NOBR>#4#</NOBR>)' },
			#{ colIdx => 2, head => 'Relation', dataFmt => '&{fmt_stripLeadingPath:2}:', dAlign => 'RIGHT' },
			#{ colIdx => 3, head => 'Name', dataFmt => '#3#', dAlign => 'LEFT' },
			#{ colIdx => 4, head => 'Phone', dataFmt => '(#4#)', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-contact-emergency?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Emergency Contacts' },
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
		frame => { heading => 'Edit Emergency Contacts' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-contact-emergency?home=#param.home#'>Emergency Contact</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
			select 	value_type, item_id, item_name,
				(select p.person_id
					from person p
						where p.person_id = b.value_text)person_id, value_textb,
				(select a.value_text
					from person_attribute a
						where a.value_int = 0
						and a.item_id = b.item_id)value_text
			from 	person_attribute b
			where	parent_id = ?
			and	value_type = @{[ App::Universal::ATTRTYPE_FAMILY ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Family Contact', dataFmt => '<A HREF ="/person/#3#/profile">#3#</A>#5# (&{fmt_stripLeadingPath:2}, <NOBR>#4#</NOBR>)' },
			#{ colIdx => 2, head => 'Relation', dataFmt => '&{fmt_stripLeadingPath:2}:', dAlign => 'RIGHT' },
			#{ colIdx => 3, head => 'Name', dataFmt => '#3#', dAlign => 'LEFT'},
			#{ colIdx => 4, head => 'Phone', dataFmt => '(#4#)', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-contact-family?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},

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
				{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-contact-family?home=#param.home#'>Family Contact</A> } },
			],
			icons => { data => [ { imgSrc => '/resources/icons/square-lgray-sm.gif' } ] },
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
					#editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
				},
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
			heading => 'Authorization',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
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
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.indialog',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Edit Authorizations' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-auth-patientsign?home=#param.home#'>Patient Signature Authorization</A>} },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-auth-providerassign?home=#param.home#'>Provider Assignment Indicator (for medicare)</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-auth-inforelease?home=#param.home#'>Information release</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#/?home=#param.home#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#/?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#2#/#3#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-additional?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-additional?home=#param.home#'>User Defined Data</A>} },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#2#/#3#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#2#/#3#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#4#/#3#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{	url => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#',
					caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#'>Alert</A> },
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#4#/#3#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#3#?home=#param.home#',
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
		SELECT
			ins_internal_id,
			parent_ins_id,
			product_name,
			DECODE(record_type, 3, 'coverage') AS record_type,
			plan_name,
			DECODE(bill_sequence,1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive'),
			owner_person_id,
			ins_org_id,
			indiv_deductible_amt,
			family_deductible_amt,
			percentage_pay,
			copay_amt,
			guarantor_name,
			decode(ins_type, 7, 'thirdparty', 'coverage') AS ins_type,
			guarantor_id,
			guarantor_type,
			(
				SELECT 	b.org_id
				FROM org b
				WHERE b.org_internal_id = i.ins_org_id
			) AS org_id,
			(
				SELECT 	g.org_id
				FROM org g
				WHERE guarantor_type = @{[App::Universal::GUARANTOR_ORG]}
				AND  g.org_internal_id = i.guarantor_id

			)
		FROM insurance i
		WHERE record_type = 3
		AND owner_person_id = ?
		ORDER BY bill_sequence
	},

	sqlStmtBindParamDescr => ['Person ID for Insurance Table'],
	publishDefn => {

		columnDefn => [
			{
				colIdx => 15,
				dataFmt => {
					'0' => '<A HREF = "/person/#14#/profile">#12#</A> (Third Party)',
					'1' => '<A HREF = "/org/#17#/profile">#12#</A> (Third Party)',
					''  => '<A HREF = "/org/#16#/profile">#16#</A>(#5# #13#): #4#, #2#',
				},
			},
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#13#/#0#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-coverage?home=#param.home#'>Personal Insurance Coverage</A> },
				},
				{
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-thirdparty?home=#param.home#'>Third Party Payer</A> },
				},
				#{
				#	caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-exists?home=#param.home#'>Insurance Plan</A> },
				#	hints => ''
				#},
				#{
				#	caption => qq{ Add Unique <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-unique?home=#param.home#'>Insurance Plan</A> },
				#	hints => ''
				#},
				#{
				#	caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-attachworkerscomp?home=#param.home#'>Workers Compensation Plan</A> },
				#	hints => ''
				#},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#13#/#0#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-ins-#13#/#0#?home=#param.home#',
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
			SELECT 	decode(bill_sequence, 1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive'),
				decode(ins_type,0,'Self-Pay',1,'Insurance',2,'HMO',3,'PPO',4,'Medicare',5,'Medicaid',6,'W.Comp',7,'Client Billing',8,'Champus',9,'ChampVA',10,
					'FECA Blk Lung',11,'BCBS'),
				member_number,
				ins_internal_id,
				record_type,
				plan_name,
				policy_number,
				copay_amt,
				coverage_end_date,
				ins_org_id,
				product_name,
				(
					SELECT 	b.org_id
					FROM org b
					WHERE b.org_internal_id = i.ins_org_id
				) AS org_id
			FROM 	insurance i
			WHERE 	owner_person_id = ?
			ORDER BY bill_sequence
			},
	sqlStmtBindParamDescr => ['Person ID for Insurance Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx =>0, head => 'BillSeq', dataFmt => '<b>#0#</b> (#1#, <b>#11#</b>, #10#, End Date: #8#)<BR><b> Policy Name: </b>#5# (#6#) <BR><b>  Member Num: </b>#2#, <b>Co-Pay:</b> $#7#'},

		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#4#/#3#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-coverage?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
		#frame => {	editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#' },
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
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-exists?home=#param.home#'>Insurance Plan</A> },
					hints => ''
				},
				{
					caption => qq{ Add Unique <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-unique?home=#param.home#'>Insurance Plan</A> },
					hints => ''
				},
				{
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-attachworkerscomp?home=#param.home#'>Workers Compensation Plan</A> },
					hints => ''
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#4#/#3#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-ins-#4#/#3#?home=#param.home#',
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
			select	value_type, item_id, item_name, value_text, value_textb, parent_id, decode(value_int,1,'Primary Physician','')
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = @{[ App::Universal::ATTRTYPE_PROVIDER ]}
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'CareProvider', dataFmt => '<A HREF = "/person/#3#/profile">#3#</A> (#2#, #6#) <A HREF ="/person/#5#/dlg-add-appointment?_f_resource_id=#3#&_f_attendee_id=#5#"> Sched Appointment</A>' },
			#{ colIdx => 1, head => 'Provider', dataFmt => '&{fmt_stripLeadingPath:1}:' },
			#{ colIdx => 2, head => 'Name', dataFmt => '#2#' },
			#{ colIdx => 3, head => 'Phone', dataFmt => '#3#', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-provider?home=#homeArl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-assoc-provider?home=#param.home#'>Care Provider</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-allergy-medication?home=#param.home#'>Drug/Medication Allergies</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-allergy-environmental?home=#param.home#'>Environmental Allergies</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-allergy-intolerance?home=#param.home#'>Drug/Medication Intolerance</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-preventivecare?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-preventivecare?home=#param.home#'>Preventive Care</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		SELECT
			tr.trans_type,
			tr.trans_id,
			tr.caption,
			%simpleDate:tr.trans_begin_stamp%,
			tt.caption,
			tr.provider_id,
			tr.data_text_a
		FROM
			transaction tr,
			transaction_type tt
		WHERE
			tr.trans_type BETWEEN 7000 AND 7999
			AND tr.trans_type = tt.id
			AND tr.trans_owner_type = 0
			AND tr.trans_owner_id = ?
			AND tr.trans_status = 2
		ORDER BY tr.trans_begin_stamp DESC
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#0#/#1#?home=#homeArl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
			heading => 'Active Medications',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-medication-current?home=#param.home#'>Current Medication</A> } },
				{ caption => qq{ Prescribe <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-medication-prescribe?home=#param.home#'>Medication</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#0#/#1#?home=#param.home#',
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
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-tests?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
					caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-tests?home=#param.home#'>New Tests/Measurements</A> },
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-activeproblems-notes?home=#param.home#'>Notes</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-activeproblems-perm?home=#param.home#'>Permanent Diagnosis</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-activeproblems-trans?home=#param.home#'>Diagnosis</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeProblems', [$personId, $personId, $personId, $personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.surgicalProcedures' => {
	sqlStmt => qq{
	    SELECT
	    	2 AS group_sort,
	    	%simpleDate:t.curr_onset_date% AS curr_onset_date,
	    	ref.descr,
	    	provider_id,
	    	trans_type,
	    	trans_id,
	    	'(ICD ' || t.code || ')' AS code
		FROM
			transaction t,
			ref_icd ref
		WHERE
			trans_type = 4050
			AND trans_owner_type = 0
			AND trans_owner_id = :1
			AND t.code = ref.icd (+)
			AND trans_status = 2
		UNION ALL (
			SELECT
				2 as group_sort,
				%simpleDate:curr_onset_date% AS curr_onset_date,
				data_text_a,
				provider_id,
				trans_type,
				trans_id,
				'' AS code
			FROM transaction
			WHERE
				trans_type = 4050
				AND trans_owner_id = :1
				AND trans_status = 2
		)
		ORDER BY
			group_sort,
			curr_onset_date DESC
		},
	sqlStmtBindParamDescr => ['Person ID for Diagnoses Transactions'],
	publishDefn => {
		columnDefn => [
			{ head => 'Surgical Procedures', dataFmt => '#2# <A HREF = "/search/icd">#6#</A><BR>performed on <A HREF = "/person/#3#/profile">#3#</A> (#1#)' },
		],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#homeArl#',
		bullets => {},
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-activeproblems-surgical?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
		separateDataColIdx => 2, # when the date is '-' add a row separator
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Surgical Procedures' },
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
		frame => { heading => 'Edit Surgical Procedures' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-activeproblems-surgical?home=#param.home#'>Surgical Procedure</A> } },
			],
		},
		stdIcons =>	{
			 delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgicalProcedures', [ $personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgicalProcedures', [ $personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgicalProcedures', [ $personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.surgicalProcedures', [ $personId], 'panelTransp'); },
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-directive-patient?home=#param.home#'>Patient Directive</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-directive-physician?home=#param.home#'>Physician Directive</A> } },
			],
		},
		stdIcons =>	{
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#9#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-hospitalization?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
					caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-hospitalization?home=#param.home#'>New Hospitalization</A> },
					hints => 'Info when a patient is admitted or discharged from a hospital'
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#9#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#8#/#9#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-affiliation?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-affiliation?home=#param.home#'>Affiliation</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-attendance?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-attendance?home=#param.home#'>Attendance</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-benefit-insurance?home=#param.home#'>Insurance Benefit</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-benefit-retirement?home=#param.home#'>Retirement Benefit</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-benefit-other?home=#param.home#'>Other Benefit</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-employment-empinfo?home=#param.home#'>Employment Information</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-employment-salinfo?home=#param.home#'>Salary Information</A> } },
		],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#0#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#0#?home=#param.home#',
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
			select 	value_type, item_id, item_name, value_text, %simpleDate:value_dateend%,
				(select (decode(a.value_int,5,'Unknown',1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary'))
					from person_attribute a where  a.value_type in (@{[ App::Universal::ATTRTYPE_SPECIALTY ]}) and a.item_id = b.item_id)value_int
			from 	person_attribute b
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::ATTRTYPE_LICENSE ]}, @{[ App::Universal::ATTRTYPE_STATE ]}, @{[ App::Universal::ATTRTYPE_ACCREDITATION ]}, @{[ App::Universal::ATTRTYPE_SPECIALTY ]})
			and     item_name not in('Nurse/Title', 'RN', 'Driver/License', 'Employee')
			order by value_int
		},
	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
			{ dataFmt => '#2# (#4# #5#): #3#' },
			#{ dataFmt => '#3#' },
			#{ colIdx => 3, head => 'Value' },
			#{ colIdx => 4, head => 'Date', options => PUBLCOLFLAG_DONTWRAP },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-license?home=#param.home#'>License</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-state?home=#param.home#'>State</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-accreditation?home=#param.home#'>Accreditation</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-specialty?home=#param.home#'>Specialty</A> } },
		],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-assoc-nurse-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-nurse?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>Associated Physician</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-assoc-nurse-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-assoc-nurse-#0#/#1#?home=#param.home#',
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
		select value_text as resource_id
		from Person_Attribute
		where parent_id = ?
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = 'WorkList'
			and parent_org_id = ?
			order by 1
	},

	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
			{ head => 'Record', dataFmt => '#0#' },

		],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			#addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-session-physicians?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-resource-session-physicians?home=#homeArl#',
		},
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
				#{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-session-physicians?home=#param.home#'>Session Set Of Physicians</A> } },
			],
		},
		stdIcons =>	{
			#updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#',
			#delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.myAssociatedResourceAppointments' => {
	sqlStmt => qq{
		select to_char(e.start_time, 'hh:miam') as start_time,
			ea.value_textB as resource_id,
			patient.complete_name as patient_complete_name,
			e.subject,
			at.caption as appt_type,
			aat.caption as patient_type,
			e.remarks,
			ea.value_text as patient_id,
			e.event_id, patient.person_id
		from 	Appt_Status, Appt_Attendee_type aat, Person patient, Person provider,
			Event_Attribute ea, Appt_Type at, Event e
		where e.start_time between to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and to_date(?, '$SQLSTMT_DEFAULTSTAMPFORMAT')
			and e.discard_type is null
			and e.event_status in (0,1,2)
			and at.appt_type_id (+) = e.appt_type
			and ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = patient.person_id
			and ea.value_textB = provider.person_id
			and
			(	ea.value_textB = ? or
				ea.value_textB in
				(select value_text
					from person_attribute
					where parent_id = ?
						and item_name = 'WorkList'
						and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
				)
			)
			and aat.id = ea.value_int
			and Appt_Status.id = e.event_status
		order by e.start_time
	},
	sqlStmtBindParamDescr => ['sysdate starting at 12 AM, sysdate at midnight, Org ID for event table, Person ID for Event_Attribute table, Person ID for Person_Attribute table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Associated Resources Appointments', dataFmt => '<a href="javascript:location=\'/schedule/apptsheet/encounterCheckin/#8#\';">#0#</A>:' },
			{ dataFmt => '<A HREF="/person/#7#/profile">#2#</A> <BR> (<i>#5#</i>) <BR> Scheduled with #1# <BR> Appt Type: #4#  <BR> Subject: #3#'},
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-appointment/#8#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-appointment?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-appointment?home=#param.home#'>Appointment</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-appointment/#8#?home=#homeArl#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-cancel-appointment/#8#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . '12:00 AM'; my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . '11:59 PM'; my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments', [$dateStringAM,$dateStringPM,$personId,$personId], 'panelTransp'); },
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
					and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
					and item_name = 'WorkList'
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
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>My Associated Resources Appointments</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); my $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients', [$personId,$personId], 'panelTransp'); },
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
			and 10 > (
				select count(*) from perSess_Activity pa2
				where pa.activity_stamp < pa2.activity_stamp
				and pa.person_id = pa2.person_id
			)
		order by pa.activity_stamp desc
	},

	sqlStmtBindParamDescr => ['Session ID for the perSess_Activity table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Session Activity', dataFmt => '#0# ' },
			{ dataFmt => '#1# #2#'},
		],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
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
				#{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-resource-nurse?home=#param.home#'>My Associated Resources Appointments</A> } },
			],
		},
		stdIcons =>	{
			#updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#param.home#',
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
			SELECT
				i.invoice_id,
				i.client_id,
				i.owner_id,
				i.submitter_id,
				i.invoice_date,
				i.total_cost,
				i.balance,
				ib.bill_to_id,
				(
					SELECT 	b.org_id
					FROM org b
					WHERE b.org_internal_id = ib.bill_to_id
					AND ib.bill_party_type not in(@{[ App::Universal::INVOICEBILLTYPE_CLIENT]},@{[ App::Universal::INVOICEBILLTYPE_THIRDPARTYPERSON]})
				) AS org_id,
				ib.bill_party_type
			FROM invoice i, invoice_billing ib
			WHERE i.client_id = ?
			AND ib.invoice_id = i.invoice_id
			AND ib.bill_sequence = 1
			AND ib.invoice_item_id is NULL
			AND i.balance > 0
			ORDER BY i.invoice_date
			},
	sqlStmtBindParamDescr => ['Person ID for Invoice Table'],
	publishDefn => {
		columnDefn => [
				{
					colIdx => 9, head => 'Invoice',
					dataFmt => {
						'0'  => '<b>Invoice: </b>#0#, Bill To: #7#<BR><b>Total Amount:</b> $#5#, <b>Balance Remaining:</b> $#6#',
						'1'  => '<b>Invoice: </b>#0#, Bill To: #7#<BR><b>Total Amount:</b> $#5#, <b>Balance Remaining:</b> $#6#',
						'2' => '<b>Invoice: </b>#0#, Bill To: #8#<BR><b>Total Amount:</b> $#5#, <b>Balance Remaining:</b> $#6#',
						'3' => '<b>Invoice: </b>#0#, Bill To: #8#<BR><b>Total Amount:</b> $#5#, <b>Balance Remaining:</b> $#6#',

					},
				},
		],

		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-invoice/#0#?home=#homeArl#',
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
					heading => 'Outstanding Balances',
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
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
			ea.value_textB,
			e.subject,
			to_char(e.start_time, 'MM-DD-YYYY'),
			1 as group_sort,
			trunc(e.start_time) as apptdate
		from Event_Attribute ea, Event e
		where ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = ?
			and e.start_time > sysdate
		UNION
		select 	%simpleDate:sysdate%,
			to_char(sysdate, 'HH12:MI AM'),
			to_char(sysdate, 'HH12:MI AM'),
			'-',
			'-',
			to_char(sysdate, 'MM-DD-YYYY'),
			2 as group_sort,
			trunc(sysdate) as apptdate
		from DUAL
		UNION
		select 	%simpleDate:e.start_time%,
			to_char(e.start_time, 'HH12:MI AM'),
			to_char(e.start_time+(e.duration/1440), 'HH12:MI AM'),
			ea.value_textB,
			e.subject,
			to_char(e.start_time, 'MM-DD-YYYY'),
			3 as group_sort,
			trunc(e.start_time) as apptdate
		from Event_Attribute ea, Event e
		where ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = ?
			and e.start_time < sysdate
		ORDER by group_sort, apptdate DESC
	},

	sqlStmtBindParamDescr => ['Person ID for Event Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Appointments', dataFmt => '<a href="javascript:location=\'/schedule/apptsheet/#5#\';">#0#</A>:' },
			{ dataFmt => 'Scheduled with <A HREF="/person/#3#/profile">#3#</A> at #1# <BR>
					Reason for Visit: #4#'},

		],
		separateDataColIdx => 3, # when the date is '-' add a row separator
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-appointment?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-appointment?home=#homeArl#'>Appointment</A> } },
			],
		},
		stdIcons =>	{
			# delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#homeArl#',
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
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.diagnosisSummary' => {
	sqlStmt => qq{
			select member_name as code, name as description, to_char(min(trans_begin_stamp), 'mm/dd/yyyy') as earliest_date,
			       to_char(max(trans_begin_stamp), 'mm/dd/yyyy') as latest_date, count(member_name) as num_times
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
			{ head => 'Diagnosis Summary', dataFmt => '<A HREF = "/search/icd/detail/#0#">(ICD #0#)</A> #1#<br> #2#--#3#: #4#<br><br>'},
		],
	},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.static',
		inherit => 'panel',
		frame =>
		{
				heading => 'Diagnosis Summary',
				-editUrl => '',
		},
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
		frame =>
		{
				-editUrl => '',
		},

	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.diagnosisSummary', [$personId], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
'sel_referral'=> {
	sqlStmt => qq{
			SELECT
				trans_id,
				trans_owner_id,
				a.ssn,
				a.date_of_birth,
				t.data_text_a as referral_type,
				aa.value_int as claim_number,
				trans_substatus_reason,
				trans_status_reason,
				t.data_text_b,
				t.data_text_c,
				t.caption,
				 %simpleDate:trans_begin_stamp%,
				 %simpleDate:trans_end_stamp%,
				 t.data_text_a,
				 t.data_num_a,
				 detail,
				 related_data,
				 initiator_id
				 from transaction t, person a, trans_attribute aa
				 where trans_type = 6000
				 and trans_id = ?
				 and a.person_id = t.consult_id
				 and aa.parent_id = t.trans_id
				 and aa.item_name = 'Referral Insurance'
		},
		publishDefn => 	{
			columnDefn =>
			[
				{colIdx => 0, head => 'Trans ID', dataFmt => "<a href=\"javascript:doActionPopup('/org/#17#/dlg-update-trans-6000/#0#');\">#0#</a>"},
				{colIdx => 1, head => 'Claim Number', dataFmt => '#5#'},
				{colIdx => 2, head => 'ICD Codes', dataFmt =>"<a href=\"javascript:doActionPopup('/lookup/icd');\">#8#</a>"},
				{colIdx => 3, head => 'CPT Codes', dataFmt =>"<a href=\"javascript:doActionPopup('/lookup/cpt');\">#9#</a>"},
				{colIdx => 4, head => 'Date Of Injury', options => PUBLCOLFLAG_DONTWRAP, dataFmt =>'#11#'},
				{colIdx => 5, head => 'Date Of Request', options => PUBLCOLFLAG_DONTWRAP, dataFmt =>'#12#'},
				{colIdx => 6, head => 'Referral Type', dataFmt =>'#13#'},
				{colIdx => 7, head => 'SSN', dataFmt => '#2#'},
				{colIdx => 8, head => 'Date of Birth', dataFmt => '#3#'},
				{colIdx => 9, head => 'Comments', dataFmt =>'#16#'},
			],
		},
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.officeLocation' => {
	sqlStmt => qq{
			SELECT 	value_type, item_id, parent_id, item_name, value_text, value_textB, value_int, name_primary
				from  Person_Attribute, Org
			where  	parent_id = ?
			AND     value_text = org_id
			AND item_name = 'Office Location'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
				{
					colIdx => 6,
					dataFmt => {
						'1' => '<img src="/resources/icons/checkmark.gif" width="16" height="16" border="0">',
						'' => "",
					},
				},

				{colIdx => 2, dataFmt => "<A HREF = '/org/#4#/profile'>#7#</A> (#4#, #5#) "},

		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-office-location/#1#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-office-location?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Office Location' },
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
		frame => { heading => 'Office Location' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-office-location?home=#param.home#'>Office Location</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-office-location/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-office-location/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.officeLocation', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.officeLocation', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.officeLocation', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.officeLocation', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.referralAndIntake' => {
	sqlStmt => qq{
			SELECT 	trans_id,
			        DECODE(parent_trans_id,'','Service Request','Referral') as parent_trans_id,
			        parent_trans_id,
			        %simpleDate:trans_end_stamp%,
			        %simpleDate:data_date_b%,
			        (
					SELECT caption
					FROM intake_service i
					WHERE i.id = t.caption
				) AS caption,
			        (
					SELECT r.caption
					FROM referral_followup_status r
					WHERE r.id = t.trans_status_reason
				) AS follow_up,
				(
					SELECT org_id
					FROM org
					WHERE org_internal_id = t.service_facility_id
				) AS org_id,
				trans_type
			FROM  transaction t
			WHERE  	consult_id = ?
			AND trans_type in (6000, 6010)
		},
		sqlStmtBindParamDescr => ['Trans ID'],

	publishDefn =>
	{
		columnDefn => [
				{
					colIdx => 1,
					dataFmt => {
						'Service Request' => 'Referral : #0#, Date Of Request : #3#',
						'Referral' => "Intake (#2#): #0#, Follow Up : #6# (#4#), Service: #5#, Provider: <A HREF = '/org/#7#/profile'>#7#</A>",
					},
				},



		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#0#?home=#homeArl#',
		frame => {
		addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-referral?_f_person_id=#param.person_id#&home=#homeArl#',
		editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Service Requests And Referrals' },
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
		frame => { heading => 'Service Requests And Referrals' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-referral?_f_person_id=#param.person_id#&home=#param.home#'>Referral</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#0#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#8#/#0#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntake', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntake', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntake', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntake', [$personId], 'panelTransp'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntake', [$personId], 'panelInDlg'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.referralAndIntakeCount' => {
	sqlStmt => qq{
			SELECT
				(COUNT(trans_id)-COUNT(parent_trans_id)) AS service_request,
				COUNT(parent_trans_id) AS referral
			FROM  transaction
			WHERE  	consult_id = ?
			AND trans_type in (6000, 6010)
		},
		sqlStmtBindParamDescr => ['Trans ID'],

	publishDefn =>
	{
		columnDefn => [

			{ head => 'Record Count', dataFmt => 'Service Request Count : #0# <BR> Referral Count : #1#'},

		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Service Request And Referral Count' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntakeCount', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntakeCount', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntakeCount', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntakeCount', [$personId], 'panelTransp'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.referralAndIntakeCount', [$personId], 'panelInDlg'); },
},

);

1;
