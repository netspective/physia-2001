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
'person.messageRegardingPatient' => {
	sqlStmt => qq{
		SELECT * FROM (
			select d.doc_name, to_char(d.doc_orig_stamp - :2, '$SQLSTMT_DEFAULTSTAMPFORMAT')
				as doc_orig_stamp, d.doc_source_id, d.doc_dest_ids, d.doc_spec_subtype,
				d.doc_id
			from document d, document_attribute da
			where da.item_name = 'Regarding Patient'
				and da.value_text = :1
				and d.doc_id = da.parent_id
			order by d.doc_orig_stamp DESC
		)
		WHERE ROWNUM < 11
	},
	publishDefn =>
	{
		columnDefn =>
		[
			{
				dataFmt => '<a href="/person/#session.user_id#/dlg-read-message_#4#/#5#/#4#?home=#homeArl#" >#1#</a> &nbsp; From: #2# - To: #3# <br>&nbsp; #0#'
			},
		],
	},
	publishDefn_panel =>
	{
		style => 'panel.static',
		inherit => 'panel',
		frame =>
		{
			heading => 'Messages Regarding Patient',
			-editUrl => '',
		},
	},
	publishDefn_panelTransp =>
	{
		style => 'panel.transparent',
		inherit => 'panel',
		frame =>
		{
			-editUrl => '',
		},

	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageRegardingPatient', [$personId, $page->session('GMT_DAYOFFSET')]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageRegardingPatient', [$personId, $page->session('GMT_DAYOFFSET')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageRegardingPatient', [$personId, $page->session('GMT_DAYOFFSET')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageRegardingPatient', [$personId, $page->session('GMT_DAYOFFSET')], 'panelTransp'); },
},

'person.account-notes' => {
	sqlStmt => qq{
		SELECT * FROM (
			select to_char(trans_begin_stamp -:2, '$SQLSTMT_DEFAULTDATEFORMAT'),
				detail, trans_id, trans_type, provider_id
			from transaction
			where trans_owner_id = :1
				and trans_status = 2
				and trans_type = $ACCOUNT_NOTES
			order by trans_id desc
		)
		WHERE ROWNUM < 11
	},
	sqlStmtBindParamDescr => ['Person ID for transaction table'],
	publishDefn => {
			columnDefn => [
				{ head => 'Account Notes', dataFmt => '#&{?}# - by #4#<br/> <b>#1#</b>' },
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
					{	#url => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-alert-person?home=#param.home#',
						caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-account-notes/#param.person_id#?home=#param.home#'>Account Notes</A> },
					},
				],
			},
			stdIcons =>	{
				updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#3#/#param.person_id#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#3#/#2#/#0#?home=#param.home#'
			},
},

	publishComp_st => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId, $page->session('GMT_DAYOFFSET')] ); },
	publishComp_stp => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id');  $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId, $page->session('GMT_DAYOFFSET')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id');$sessionId||=$page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId, $page->session('GMT_DAYOFFSET')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId,$sessionId) = @_; $personId ||= $page->param('person_id'); $sessionId||=$page->session('user_id');$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.account-notes', [$personId, $page->session('GMT_DAYOFFSET')], 'panelTransp'); },
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
			SELECT
				value_type,
				item_id,
				parent_id,
				item_name,
				value_text,
				%simpleDate:value_date%,
				value_textB
				from  Person_Attribute
			where  	parent_id = ?
			and item_name = 'Misc Notes'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => 'Misc Notes by <A HREF="/person/#6#/profile">#6#</A> (#5#): #4#' },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-misc-notes/#1#?home=#homeArl#',
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

	publishComp_st =>
	sub
	{
		my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId]);
	},
	publishComp_stp =>
	sub
	{
		my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panel');
	},
	publishComp_stpe =>
	sub
	{
		my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panelEdit');
	},
	publishComp_stpt =>
	sub
	{
		my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.miscNotes', [$personId], 'panelTransp');
	},
},


#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.phoneMessage' => {
	sqlStmt => qq{
		select trans_id, trans_owner_id, trans_type, decode(trans_status,4,'Read',5,'Not Read'),
			caption, provider_id, data_text_c, data_text_a, data_text_b, cr_user_id, consult_id
		from Transaction
		where trans_owner_id = ?
			and caption = 'Phone Message'
			and data_num_a is null
		UNION
		select trans_id, trans_owner_id, trans_type, decode(trans_status,4,'Read',5,'Not Read'),
			caption, provider_id, data_text_c, data_text_a, data_text_b, cr_user_id, consult_id
		from Transaction
		where trans_owner_id = ?
		and caption = 'Phone Message'
		and data_num_a is not null
		and trans_status = 5
		and trans_owner_id <> consult_id
	},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => "<A HREF='/person/#10#/profile'>#10#</A> (#6#): #7# (<A HREF='/person/#5#/profile'>#5#</A>)" },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#0#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-send-phone_message?home=#homeArl#',
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-send-phone_message?home=#param.home#'>Phone Message</A> } },
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
		SELECT count(*)
		FROM document, document_attribute
		WHERE document_attribute.value_text = :1
			AND document.doc_spec_type = @{[ App::Universal::DOCSPEC_INTERNAL ]}
			AND document.doc_id = document_attribute.parent_id
			AND document_attribute.item_name IN ('To', 'CC')
			AND document_attribute.value_int = 0
			AND doc_spec_subtype = 2
	},

	publishDefn => {
		columnDefn => [
			{
				dataFmt => qq{<a href='/person/#param.person_id#/mailbox/prescriptionRequests'>Prescription Approval Request</a> #0#},
			},
		],
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

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.refillRequest', [$personId], 'panelTransp'); },
},


#-------------------------------------------------------------------------------------------------------------------------------------------------------------
###### PROBABLY NOT USED ANY MORE #########
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
			and pa.value_type between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_UNEMPLOYED]}
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
		SELECT
			t.caption,
			detail,
			trans_type,
			trans_id,
			trans_subtype,
			%simpleDate:trans_end_stamp% as value_dateend,
			(
				SELECT
				trans_type
				FROM person_attribute p
				WHERE p.item_id = t.data_text_b
				AND t.trans_type = 8040
			) AS type
		FROM alert_priority a, transaction t
		WHERE trans_type between 8000 and 8999
			AND trans_owner_type = 0
			AND trans_owner_id = :1
			AND trans_status = 2
			AND a.caption = t.trans_subtype
			AND NOT EXISTS (
				SELECT tt.trans_end_stamp
				FROM transaction tt, person_attribute pa
				WHERE tt.trans_id = t.trans_id
					AND tt.trans_end_stamp > sysdate + 90
					AND tt.data_text_b = pa.item_id
					AND tt.trans_type = 8040
			)
		ORDER BY a.id desc, trans_begin_stamp desc
	},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
		{
			colIdx => 6 ,
			dataFmt => {
				'8040' => '<b>#4#</b>: #0#<br/><I>#1# (Due Date: #5#)</I>',
				'' => "<b>#4#</b>: #0#<br/><I>#1#</I>",
			},
		},

			#{ head => 'Alerts', dataFmt => '<b>#4#</b>: #0#<br/><I>#1# (Due Date:#5#)</I>' },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#3#?home=#homeArl#',
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
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#3#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#2#/#3#?home=#param.home#',
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
			DECODE(bill_sequence,1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive', 'Active'),
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

			),
			i.coverage_begin_date,
			i.coverage_end_date
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
					'0' => '<A HREF = "/person/#14#/profile">#12#</A> (Third Party, #5#): Begin Date: #18#, End Date: #19#',
					'1' => '<A HREF = "/org/#17#/profile">#12#</A> (Third Party, #5#): Begin Date: #18#, End Date: #19#',
					''  => '<A HREF = "/org/#16#/profile">#16#</A>(#5# #13#): #4#, #2#, Begin Date: #18#, End Date: #19#',
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
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#13#/#0#?home=#param.home#',
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
				) AS org_id,
			guarantor_id,
			guarantor_name,
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

			),
			i.coverage_begin_date
			FROM 	insurance i
			WHERE 	owner_person_id = ?
			ORDER BY bill_sequence
			},
	sqlStmtBindParamDescr => ['Person ID for Insurance Table'],
	publishDefn => {
		columnDefn => [
				{
					colIdx => 14,
					dataFmt => {
						'0' => '<b>Client Billing (</b><A HREF = "/person/#12#/profile">#13#</A>, Third Party)',
						'1' => '<A HREF = "/org/#15#/profile">#13#</A> (Third Party)',
						''  => '<b>#0#</b> (#1#, <b>#11#</b>, #10#)<BR><b> Policy Name: </b>#5# (#6#) <BR><b>  Member Num: </b>#2#, <b>Co-Pay:</b> $#7#, Begin Date: #17#, End Date: #8#',
					},
				},
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
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-coverage?home=#param.home#'>Personal Insurance Coverage</A> },
				},
				{
					caption => qq{ Choose <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-ins-thirdparty?home=#param.home#'>Third Party Payer</A> },
				},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-ins-#4#/#3#?home=#param.home#',
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
			select
				p.value_type,
				p.item_id,
				p.item_name,
				p.value_text,
				p.value_textb,
				p.parent_id,
				decode(p.value_int,1,', Primary Physician', ''),
				pc.category
			from 	person_org_category pc, person_attribute p
			where p.parent_id = upper(:1)
			and p.value_type = @{[ App::Universal::ATTRTYPE_PROVIDER ]}
			and pc.person_id = p.value_text
			and pc.org_internal_id = :2
			and pc.category in ('Physician', 'Referring-Doctor')
		},
	sqlStmtBindParamDescr => ['Person ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'CareProvider',
				colIdx => 7,
				dataFmt => {
					'Physician' => qq{<A HREF = '/person/#3#/profile' title='View #3# Profile'>#3#</A> (#2##6#)
						<A HREF ='/person/#5#/dlg-add-appointment/#5#/#3#?_dialogreturnurl=#homeArl#' title='Schedule Appointment with #3#'>Sched Appointment</A>
					},
					'Referring-Doctor'  => "<A HREF = '/person/#3#/profile'>#3#</A> (#2#, #6#)",
				},
			},
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
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
	publishComp_st => sub { my ($page, $flags, $personId, ) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.careProviders', [$personId,$orgInternalId], 'panelInDlg'); },
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
	sqlStmt => qq{
		SELECT
			permed_id,
			med_name,
			dose,
			dose_units,
			TO_CHAR(start_date, 'IYYYMMDD') as start_date,
			frequency,
			num_refills,
			approved_by
		FROM
			Person_Medication
		WHERE
			parent_id = ? AND
			(end_date IS NULL OR end_date >= TRUNC(sysdate))
		ORDER BY
			start_date DESC,
			med_name
	},
	publishDefn => {
		columnDefn => [
			{ head => 'Medication', colIdx => 1, },
			{ head => 'Date', colIdx => 4, dformat => 'date', },
			{ head => 'Dosage', dataFmt => '#2##3#',},
			{ head => 'Freq', colIdx => 5,},
			{ head => 'Refills', dataFmt => '#6# Refills', },
			{ head => 'Approved By', colIdx => 7,},
			{ head => 'Print', colIdx => 8, dataFmt => '<a href=javascript:doActionPopup(\'/popup/prescription_pdf?permed_id=#0#\');>Print Prescription</a>'},
		],
		bullets => [
			'/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#homeArl#',
			{
				imgSrc => '/resources/widgets/mail/prescription.gif',
				title => 'Refill Request',
				urlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-refill-medication/#0#?home=#homeArl#',
			}
		],
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
				{ caption => qq{ Prescribe <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-prescribe-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allMedications', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.activeMedications', [$personId], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------
'person.inactiveMedications' => {
	sqlStmt => qq{
		SELECT
			permed_id,
			med_name,
			dose,
			dose_units,
			route,
			frequency,
			TO_CHAR(start_date, 'IYYYMMDD') as start_date,
			TO_CHAR(end_date, 'IYYYMMDD') as end_date,
			notes
		FROM
			Person_Medication
		WHERE
			parent_id = ? AND
			end_date < TRUNC(sysdate)
		ORDER BY
			start_date DESC,
			med_name
	},
	publishDefn => {
		columnDefn => [
			{ head => 'Medication', colIdx => 1, },
			{ head => 'Date', colIdx => 6, dformat => 'date', },
			{ head => 'End Date', colIdx => 7, dformat => 'date', },
			{ head => 'Dosage', dataFmt => '#2##3#',},
			{ head => 'Freq', colIdx => 5,},
			{ head => 'Route', colIdx => 4, },
			{ head => 'Notes', colIdx => 8,},
		],
		bullets => [
			#'/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#homeArl#',
			{
				imgSrc => '/resources/widgets/mail/prescription.gif',
				title => 'Refill Request',
				urlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-refill-medication/#0#?home=#homeArl#',
			}
		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
			heading => 'Inactive Medications',
			#editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
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
		frame => { heading => 'Edit Inactive Medications' },
		#banner => {
		#	actionRows =>
		#	[
		#		{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
		#		{ caption => qq{ Prescribe <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-prescribe-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
		#	],
		#},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inactiveMedications', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inactiveMedications', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inactiveMedications', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inactiveMedications', [$personId], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------
'person.allMedications' => {
	sqlStmt => qq{
		SELECT
			permed_id,
			med_name,
			dose,
			dose_units,
			TO_CHAR(start_date, 'IYYYMMDD') as start_date,
			frequency,
			num_refills,
			approved_by,
			TO_CHAR(end_date, 'IYYYMMDD') as end_date
		FROM
			Person_Medication
		WHERE
			parent_id = ?
		ORDER BY
			start_date DESC,
			med_name
	},
	publishDefn => {
		columnDefn => [
			{ head => 'Medication', colIdx => 1, },
			{ head => 'Start Date', colIdx => 4, dformat => 'date', },
			{ head => 'End Date', colIdx => 8, dformat => 'date', },
			{ head => 'Dosage', dataFmt => '#2##3#',},
			{ head => 'Freq', colIdx => 5,},
			{ head => 'Refills', dataFmt => '#6# Refills', },
			{ head => 'Approved By', colIdx => 7,},
		],
		bullets => [
			'/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#homeArl#',
			{
				imgSrc => '/resources/widgets/mail/prescription.gif',
				title => 'Refill Request',
				urlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-refill-medication/#0#?home=#homeArl#',
			}
		],
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
		flags => 0,
		frame => { heading => 'Edit Medications' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
				{ caption => qq{ Prescribe <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-prescribe-medication/#param.person_id#?home=#param.home#'>Medication</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-medication/#0#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allMedications', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allMedications', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allMedications', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.allMedications', [$personId], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------

'person.activeMedicationsOld' => {
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
			select tm.trans_owner_id, to_char(tm.trans_begin_stamp - ?, 'mm/dd/yyyy HH:MI PM'),tm.data_text_b,tm.data_text_a,tc.no_of_tests
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
	publishComp_st => sub {
								my ($page, $flags, $personId) = @_;
								$personId ||= $page->param('person_id');
								$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$page->session('GMT_DAYOFFSET'), $personId]);
							},
	publishComp_stp => sub {
								my ($page, $flags, $personId) = @_;
								$personId ||= $page->param('person_id');
								$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$page->session('GMT_DAYOFFSET'), $personId], 'panel');
							},
	publishComp_stpe => sub {
								my ($page, $flags, $personId) = @_;
								$personId ||= $page->param('person_id');
								$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$page->session('GMT_DAYOFFSET'), $personId], 'panelEdit');
							},
	publishComp_stpt => sub {
								my ($page, $flags, $personId) = @_;
								$personId ||= $page->param('person_id');
								$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.testsAndMeasurements', [$page->session('GMT_DAYOFFSET'), $personId], 'panelTransp');
							},
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
	    data_text_a,
	    	%simpleDate:t.curr_onset_date% AS curr_onset_date,
	    	ref.name,
	    	provider_id,
	    	trans_type,
	    	trans_id,
	    	'(CPT ' || t.code || ')' AS code
		FROM
			transaction t,
			ref_cpt ref
		WHERE
			trans_type = 4050
			AND trans_owner_id = :1
			AND t.code = ref.cpt (+)
			AND trans_status = 2

		ORDER BY
			curr_onset_date DESC
		},
	sqlStmtBindParamDescr => ['Person ID for Diagnoses Transactions'],
	publishDefn => {
		columnDefn => [
			{ head => 'Surgical Procedures', dataFmt => '#0#: #2# <A HREF = "/search/icd">#6#</A><BR>performed by <A HREF = "/person/#3#/profile">#3#</A> (#1#)' },
		],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#homeArl#',
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#4#/#5#?home=#homeArl#',
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
			 updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#4#/#5#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#4#/#5#?home=#param.home#',
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
			select  %simpleDate:trans_begin_stamp%, org.name_primary, org.org_id, provider_id, caption, data_num_a, detail, data_text_c,
				trans_type, trans_id, %simpleDate:trans_end_stamp%, auth_ref, data_text_a, data_text_b
			from 	org, transaction
			where 	trans_type between 11000 and 11999
			and 	trans_owner_id = ?
			and 	trans_status = 2
			and service_facility_id = org.org_internal_id
		},
	sqlStmtBindParamDescr => ['Person ID for Transaction Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 3, head => 'Provider',
				dataFmt => '#1# (<A HREF ="/org/#2#/profile">#2#</A>)<BR>Admitted by <A HREF ="/person/#3#/profile">#3#</A> (#0#), Discharged (#10#)<BR>Room: #4#, Prior Auth: #11#<BR>ICD(s): #6#, CPT(s): #7#' },
			#{ head => 'Hospitalization', dataFmt => '<b>#1#, #2#</b><BR>Room:#4#, Duration Of Stay:#5# <BR>Orders:#6#, Procedures:#7#' },
			#{ colIdx => 1, head => 'Hospital', dataFmt => '#1#' },
			#{ colIdx => 2, head => 'Hospital Id', dataFmt => '#2#' },
			#{ colIdx => 3, head => 'Provider', dataFmt => '#3#' },
			#{ colIdx => 4, head => 'Room', dataFmt => '#4#', dAlign => 'RIGHT' },
			#{ colIdx => 5, head => 'Duration', dataFmt => '#5#' },
			#{ colIdx => 4, head => 'Diagnoses', dataFmt => '#6#' },
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
		frame => { heading => 'Attendance (Not Yet Implemented)' },
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
					from person_attribute a where  a.value_type in (@{[ App::Universal::ATTRTYPE_SPECIALTY ]}) and a.item_id = b.item_id)value_int,
					name_sort,
					decode(sign(value_dateend - sysdate), -1, 'Inactive', 'Active')
			from 	person_attribute b
			where 	parent_id = ?
			and 	value_type in (@{[ App::Universal::ATTRTYPE_LICENSE ]}, @{[ App::Universal::ATTRTYPE_STATE ]}, @{[ App::Universal::ATTRTYPE_ACCREDITATION ]}, @{[ App::Universal::ATTRTYPE_SPECIALTY ]}, @{[ App::Universal::ATTRTYPE_PROVIDER_NUMBER ]}, @{[App::Universal::ATTRTYPE_BOARD_CERTIFICATION]})
			and     item_name not in('Nurse/Title', 'RN', 'Driver/License', 'Employee')
			order by value_int
		},
	sqlStmtBindParamDescr => ['Person ID for Certification'],
	publishDefn => {
		columnDefn => [
					{
						colIdx => 0,
						dataFmt => {
							"@{[ App::Universal::ATTRTYPE_LICENSE ]}" => '<b>#7#</b> #2# (#4# #5#): #3#, #6#',
							"@{[ App::Universal::ATTRTYPE_PROVIDER_NUMBER ]}" => '<b>#7#</b> #2# (#4# #5#): #3#, #6#',
							"@{[ App::Universal::ATTRTYPE_STATE ]}"  => '<b>#7#</b> #2# (#4# #5#): #3#',
							"@{[ App::Universal::ATTRTYPE_ACCREDITATION ]}"  => '<b>#7#</b> #2# (#4# #5#)',
							"@{[ App::Universal::ATTRTYPE_BOARD_CERTIFICATION ]}"  => '<b>#7#</b> #2# (#4# #5#)',
							"@{[ App::Universal::ATTRTYPE_SPECIALTY ]}" => '<b>#7#</b> #2# (#4# #5#)'
						},
					},
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-board?home=#param.home#'>Board Certification</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-specialty?home=#param.home#'>Specialty</A> } },
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-certificate-provider-number?home=#param.home#'>Provider Number</A> } },
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

'person.billinginfo' => {
	sqlStmt => qq{
		select value_type, item_id, value_text, %simpleDate:value_date%,
			decode(value_int, 0,'Per-Se', 2,'THINet', 'Other'),
			decode(value_intb, '1','Active', 'Inactive')
		from	person_attribute
		where	parent_id = ?
			and	value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
		order by value_int
	},
	sqlStmtBindParamDescr => ['Person ID for Electronic Billing Information'],
	publishDefn => {
		columnDefn => [
			{
				colIdx => 0,
				dataFmt => "<b>#5#</b> #4# ID: <b>#2#</b> (Effective: #3#)",
			},
		],

		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#/0?home=#homeArl#',
		frame => {
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		style => 'panel',
		frame => { heading => 'Clearing House Billing Information' },
	},
	publishDefn_panelTransp =>
	{
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		style => 'panel.edit',
		frame => { heading => 'Edit Clearing House Billing Information' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-billinginfo/#param.person_id#/0?home=#param.home#'>Billing ID</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#/0?home=#param.home#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#/0?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.billinginfo', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.billinginfo', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.billinginfo', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.billinginfo', [$personId], 'panelTransp'); },
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
		where parent_id = :1
			and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
			and item_name = 'WorkList'
			and parent_org_id = :2
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
	publishComp_st => sub { my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		my $orgInternalId = $page->session('org_internal_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId]);
	},
	publishComp_stp => sub { my ($page, $flags, $personId) = @_;
		$personId ||= $page->param('person_id');
		my $orgInternalId = $page->session('org_internal_id');
		$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panel');
	},
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.associatedSessionPhysicians', [$personId, $orgInternalId], 'panelTransp'); },
},


#----------------------------------------------------------------------------------------------------------------------

'person.myAssociatedResourceAppointments' => {
	sqlStmt => qq{
		select to_char(e.start_time - :1, 'hh:miam') as start_time,
			ea.value_textB as resource_id,
			patient.simple_name as patient_complete_name,
			e.subject,
			at.caption as appt_type,
			aat.caption as patient_type,
			e.remarks,
			ea.value_text as patient_id,
			e.event_id, patient.person_id
		from 	Appt_Status, Appt_Attendee_type aat, Person patient, Person provider,
			Event_Attribute ea, Appt_Type at, Event e
		where e.start_time between to_date(:2, '$SQLSTMT_DEFAULTSTAMPFORMAT') + :1
			and to_date(:3, '$SQLSTMT_DEFAULTSTAMPFORMAT') + :1
			and e.discard_type is null
			and e.event_status in (0,1,2)
			and at.appt_type_id (+) = e.appt_type
			and ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = patient.person_id
			and ea.value_textB = provider.person_id
			and
			(	ea.value_textB = :4 or
				ea.value_textB in
				(select value_text
					from person_attribute
					where parent_id = :4
						and item_name = 'WorkList'
						and value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
						and parent_org_id = :5
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
	publishComp_st =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 12:00 AM';
			my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 11:59 PM';
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments',
				[$page->session('GMT_DAYOFFSET'), $dateStringAM, $dateStringPM, $personId, $orgId]);
		},
	publishComp_stp =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 12:00 AM';
			my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 11:59 PM';
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments',
				[$page->session('GMT_DAYOFFSET'), $dateStringAM, $dateStringPM, $personId, $orgId], 'panel');
		},
	publishComp_stpe =>
		sub {
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 12:00 AM';
			my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 11:59 PM';
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments',
				[$page->session('GMT_DAYOFFSET'), $dateStringAM, $dateStringPM, $personId, $orgId], 'panelEdit');
		},
	publishComp_stpt =>
		sub {
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $dateStringAM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 12:00 AM';
			my $dateStringPM = UnixDate('today', $page->defaultUnixDateFormat()) . ' 11:59 PM';
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceAppointments',
				[$page->session('GMT_DAYOFFSET'), $dateStringAM, $dateStringPM, $personId, $orgId], 'panelTransp');
		},
},


#----------------------------------------------------------------------------------------------------------------------

'person.myAssociatedResourceInPatients' => {
	sqlStmt => qq{
		SELECT
			%simpleDate:trans_begin_stamp - :1%,
			initcap(simple_name) as simple_name,
			provider_id,
			caption as room_number,
			data_num_a as duration_days,
			detail as diags,
			data_text_c as procedures,
			data_text_a,
			consult_id,
			trans_id,
			trans_type,
			trans_owner_id,
			org.name_primary
		FROM
			org,
			transaction,
			person
		WHERE
			trans_type BETWEEN 11000 AND 11999 AND
			person_id = trans_owner_id AND
			(
				provider_id = :2 OR provider_id IN
				(
					SELECT value_text
					FROM person_attribute
					WHERE parent_id = :2
						AND value_type = @{[ App::Universal::ATTRTYPE_RESOURCEPERSON ]}
						AND item_name = 'WorkList'
						AND parent_org_id = :3
				)
			) AND
			trans_status = 2
			AND (SYSDATE - trans_begin_stamp) <= data_num_a
			AND org.org_internal_id = transaction.service_facility_id
		ORDER BY trans_begin_stamp DESC
		},
	sqlStmtBindParamDescr => ['Person ID for the person table, Person ID for the Person_Attribute table, Org ID for the Person_Attribute table '],
	publishDefn => {
		columnDefn => [
			{ head => 'My Associated Resources In Patients', dataFmt => '#0#' },
			{ dataFmt => qq{<A HREF="/person/#11#/chart">#1#</A> <BR>
					<b>#12#</b> <BR>
					(#2#) <br>
					Room: #3#  <BR>
					Duration of Stay: #4# day(s)<BR>
					Diagnoses: #5# <BR>
					Procedures: #6#
				}
			},
		],
		bullets => '/person/#11#/stpe-#my.stmtId#/dlg-update-trans-#10#/#9#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-hospitalization?home=#homeArl#',
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
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-hospitalization?home=#homeArl#'>Add Hospitalization</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#12#/#11#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#12#/#11#?home=#param.home#',
		},
	},
	publishComp_st =>
		sub {
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients',
				[$page->session('GMT_DAYOFFSET'), $personId, $orgId]);
		},
	publishComp_stp =>
		sub{
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients',
				[$page->session('GMT_DAYOFFSET'), $personId, $orgId], 'panel');
		},
	publishComp_stpe =>
		sub {
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients',
				[$page->session('GMT_DAYOFFSET'), $personId, $orgId], 'panelEdit');
		},
	publishComp_stpt =>
		sub {
			my ($page, $flags, $personId) = @_; $personId ||= $page->session('user_id');
			my $orgId ||= $page->session('org_internal_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.myAssociatedResourceInPatients',
				[$page->session('GMT_DAYOFFSET'), $personId, $orgId], 'panelTransp');
		},
},

#----------------------------------------------------------------------------------------------------------------------

'person.mySessionActivity' => {
	sqlStmt => qq{
		select to_char(pa.activity_stamp - :1 - :3, '$SQLSTMT_DEFAULTSTAMPFORMAT') as activity_stamp,
			sat.caption as caption,
			pa.activity_data as data,
			pa.action_scope as scope,
			pa.action_key as action_key
		from Session_Action_Type sat, perSess_Activity pa
		where pa.person_id = :2
			and	pa.activity_stamp >= trunc(sysdate) + :1 + :3
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
	publishComp_st =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $standarTimeOffset = $page->session('TZ') ne $page->session('DAYLIGHT_TZ') ? 1/24 : 0;
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity',
				[$page->session('GMT_DAYOFFSET'), $personId, $standarTimeOffset]);
		},
	publishComp_stp =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $standarTimeOffset = $page->session('TZ') ne $page->session('DAYLIGHT_TZ') ? 1/24 : 0;
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity',
				[$page->session('GMT_DAYOFFSET'), $personId, $standarTimeOffset], 'panel');
		},
	publishComp_stpe =>
		sub { my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $standarTimeOffset = $page->session('TZ') ne $page->session('DAYLIGHT_TZ') ? 1/24 : 0;
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity',
				[$page->session('GMT_DAYOFFSET'), $personId, $standarTimeOffset], 'panelEdit');
		},
	publishComp_stpt =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			my $standarTimeOffset = $page->session('TZ') ne $page->session('DAYLIGHT_TZ') ? 1/24 : 0;
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.mySessionActivity',
				[$page->session('GMT_DAYOFFSET'), $personId, $standarTimeOffset], 'panelTransp');
		},
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

		bullets => '/invoice/#0#/summary?home=#homeArl#',
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
		select 	%simpleDate:e.start_time - :1%,
			to_char(e.start_time - :1, 'HH12:MI AM'),
			ea.value_textB,
			e.subject,
			to_char(e.start_time - :1, 'MM-DD-YYYY'),
			1 as group_sort,
			e.start_time as apptdate
		from Event_Attribute ea, Event e
		where ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = :2
			and e.event_status != 3
			and e.start_time > sysdate
		UNION
		select 	%simpleDate:sysdate - :1%,
			to_char(sysdate - :1, 'HH12:MI AM'),
			'-',
			'-',
			to_char(sysdate - :1, 'MM-DD-YYYY'),
			2 as group_sort,
			trunc(sysdate) as apptdate
		from DUAL
		UNION
		select 	%simpleDate:e.start_time - :1%,
			to_char(e.start_time - :1, 'HH12:MI AM'),
			ea.value_textB,
			e.subject,
			to_char(e.start_time - :1, 'MM-DD-YYYY'),
			3 as group_sort,
			e.start_time as apptdate
		from Event_Attribute ea, Event e
		where ea.parent_id = e.event_id
			and ea.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
			and ea.value_text = :2
			and e.event_status != 3
			and e.start_time < sysdate
			and 10 > (select count(*) from Event_Attribute ea2, Event e2
				where ea2.parent_id = e2.event_id
					and ea2.value_text = ea.value_text
					and ea2.value_type = @{[ App::Universal::EVENTATTRTYPE_APPOINTMENT ]}
					and e.start_time < e2.start_time
					and e2.event_status != 3
					and e2.start_time < sysdate
			)
		ORDER by group_sort, apptdate DESC
	},

	sqlStmtBindParamDescr => ['Person ID for Event Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Appointments',
				dataFmt => '<a href="javascript:location=\'/schedule/apptsheet/#4#\';">#0#</A>:' },
			{ dataFmt => 'Scheduled with <A HREF="/person/#2#/profile">#2#</A> at #1# <BR>
					Reason for Visit: #3#'},

		],
		separateDataColIdx => 2, # when the date is '-' add a row separator
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
	publishComp_st =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->param('person_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments',
				[$page->session('GMT_DAYOFFSET'), $personId]);
		},
	publishComp_stp =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->param('person_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments',
				[$page->session('GMT_DAYOFFSET'), $personId], 'panel');
		},
	publishComp_stpe =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->param('person_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments',
				[$page->session('GMT_DAYOFFSET'), $personId], 'panelEdit');
		},
	publishComp_stpt =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->param('person_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientAppointments',
				[$page->session('GMT_DAYOFFSET'), $personId], 'panelTransp');
		},
},


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

'person.recentlyVisitedPatients' => {
	sqlStmt => qq{

			select p.simple_name, pvc.view_key  from PerSess_View_Count pvc,
						person p , Person_Org_Category  pog
						where p.person_id = pvc.view_key AND pvc.person_id = :2 and
						pog.person_id = p.person_id AND pog.category = 'Patient'
						and	pvc.view_latest >= trunc(sysdate) + :1
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
	publishComp_st =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients',
				[$page->session('GMT_DAYOFFSET'), $personId]);
		},
	publishComp_stp =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients',
				[$page->session('GMT_DAYOFFSET'), $personId], 'panel');
		},
	publishComp_stpt =>
		sub {
			my ($page, $flags, $personId) = @_;
			$personId ||= $page->session('user_id');
			$STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.recentlyVisitedPatients',
				[$page->session('GMT_DAYOFFSET'), $personId], 'panelTransp');
		},
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

#------------------------------------------------------------------------------------------------------------------------------------------------------------
'person.patientInfo'=> {
	sqlStmt => qq{
			SELECT
				UNIQUE person_id,
				ssn,
				date_of_birth,
				simple_name,
				g.caption
			FROM	person p, transaction t, gender g
			WHERE   trans_type in (6000, 6010)
			AND    consult_id = ?
			AND 	  p.person_id = t.consult_id
			AND 	  g.id = p.gender
		},
		publishDefn => 	{
			columnDefn =>
			[
				{  dataFmt => "<a href='/person/#0#/profile'>#3#</a>: SSN (#1#), DOB(#2#), Gender(#4#)"},
			],
			bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-patient?home=#homeArl#',
		},

	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Patient Information' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientInfo', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientInfo', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientInfo', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.patientInfo', [$personId], 'panelTransp'); },

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


'person.childReferral' => {
	sqlStmt => qq{
			SELECT 	tr.trans_id,
				to_char(tr.data_date_a,'MM/DD/YY'),
				(SELECT rsd.name
					FROM ref_service_category rsd , transaction tp
				 WHERE rsd.serv_category = tsr.trans_expire_reason
				 AND	tp.trans_id = tsr.parent_trans_id),
				(SELECT caption FROM referral_followup_status where id = tr.trans_status_reason),
				to_char(tr.data_date_b,'MM/DD/YY'),
				tr.trans_type,
				(SELECT parent_trans_id FROM transaction where trans_id = tr.parent_trans_id)
			FROM  transaction tsr, transaction tr
			WHERE tsr.parent_trans_id = :1
			AND	tr.parent_trans_id = tsr.trans_id
			ORDER BY 1 desc
		},
		sqlStmtBindParamDescr => ['Trans ID'],

	publishDefn =>
	{
		columnDefn => [
		{colIdx => 0, head => 'RID', hHint=>'Referral ID', dAlign => 'center',tDataFmt => '&{count:0} Referrals',
			url=>'/org/#session.org_id#/dlg-update-trans-6010/#0#'},
		{colIdx => 1, head => 'Date', hHint=>'Referral Date'},
		{colIdx => 2, head => 'Type', hHint=>'Referral Type', dAlign => 'center'},
		{colIdx => 3, head => 'FUD', hHint=>'Follow Up Date', dAlign => 'center'},
		{colIdx => 4, head => 'Followup', hHint=>'Follow Up Caption', dAlign => 'center'},

		],
		#bullets => '/org/#session.org_id#/dlg-update-trans-6010/#0#?home=#homeArl#',
		frame => {
		#addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-referral?_f_person_id=#param.person_id#&home=#homeArl#',
		#editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		frame => { heading => 'Referrals' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		#style => 'panel.transparent.static',
		inherit => 'panel',
		flags => 0,
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Referrals' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-referral?_f_person_id=#param.person_id#&home=#param.home#'>Service Request</A> } },
			],
		},
		stdIcons =>	{
			#updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#0#?home=#param.home#',
			#delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#8#/#0#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $transId) = @_; $transId ||= $page->param('trans_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.childReferral', [$transId]); },
	publishComp_stp => sub { my ($page, $flags, $transId) = @_; $transId ||= $page->param('trans_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.childReferral', [$transId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $transId) = @_; $transId ||= $page->param('trans_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.childReferral', [$transId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $transId) = @_; $transId ||= $page->param('trans_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.childReferral', [$transId], 'panelTransp'); },
	publishComp_stpd => sub { my ($page, $flags, $transId) = @_; $transId ||= $page->param('trans_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.childReferral', [$transId], 'panelInDlg'); },
},


#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.referralAndIntake' => {
	sqlStmt => qq{
			SELECT 	trans_id,
				to_char(data_date_a,'MM/DD/YY'),
				(SELECT to_char(data_date_a,'MM/DD/YY') FROM transaction where trans_id = t.parent_trans_id),
				(

					SELECT rsd.name
					FROM ref_service_category rsd, transaction t1 where t1.trans_id = t.parent_trans_id
					AND t1.trans_expire_reason = rsd.SERV_CATEGORY
				),

				to_char(data_date_b,'MM/DD/YY'),
				(SELECT caption FROM referral_followup_status where id = trans_status_reason),
				trans_type,
				(SELECT parent_trans_id FROM transaction where trans_id = t.parent_trans_id),
				(SELECT to_char(t2.trans_end_stamp,'MM/DD/YY') FROM transaction t1, transaction t2 WHERE t1.trans_id = t.parent_trans_id
				AND	t2.trans_id = t1.parent_trans_id),
				(SELECT to_char(data_date_b,'MM/DD/YY') FROM transaction where trans_id = t.parent_trans_id)
			FROM  transaction t
			WHERE  	consult_id = ?
			AND trans_type in (6010)
			ORDER BY 3 desc
		},
		sqlStmtBindParamDescr => ['Trans ID'],

	publishDefn =>
	{
		columnDefn => [
		{colIdx => 0, head => 'RID', hHint=>'Referral ID',hint=>'Referral ID', dAlign => 'center',tDataFmt => '&{count:0} Referrals',},
		#{colIdx => 1, head => 'Date', hHint=>'Referral Date'},
		{colIdx => 3, head => 'Type', hHint=>'Referral Type', hint=>'Referral Type' ,dAlign => 'center'},
		{colIdx => 4, head => 'FUD', hHint=>'Follow Up Date',hint=>'Follow Up Date', dAlign => 'center'},
		{colIdx => 5, head => 'Followup', hHint=>'Follow Up Caption', hint=>'Follow Up Caption',dAlign => 'center'},
		{colIdx => 7, head => 'SID', hHint=>'Service Request ID', hint=>'Service Request ID', dAlign => 'center',url=>'/org/#session.org_id#/dlg-update-trans-6000/#7#'},
		{colIdx => 8, head => 'SD', hHint=>'Service Request Date',hint=>'Service Request Date', dAlign => 'center',},
		{colIdx => 2, head => 'SBD', hHint=>'Service Begin Date', hint=>'Service Begin Date',dAlign => 'center',},
		{colIdx => 9, head =>'SED', hHint=>'Service End Date',hint=>'Service End Date', dAlign => 'center',},

		],
		bullets => '/person/#param.person_id#/dlg-update-trans-#6#/#0#?home=#homeArl#',
		frame => {
		#addUrl => '/person/#param.person_id#/dlg-add-referral?_f_person_id=#param.person_id#&home=#homeArl#',
		#editUrl => '/person/#param.person_id#/?home=#homeArl#',
		editUrl => '/person/#param.person_id#/dlg-add-referral?_f_person_id=#param.person_id#&home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
		frame => { heading => 'Service Requests And Referrals' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		#style => 'panel.transparent.static',
		inherit => 'panel',
		flags => 0,
	},
	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Service Requests And Referrals' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-referral?_f_person_id=#param.person_id#&home=#param.home#'>Service Request</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#8#/#0#?home=#param.home#',
			#delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-trans-#8#/#0#?home=#param.home#',
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


#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------Doc Short Term Stuff


'person.linkNonMedicalSite'=>{
	sqlStmt => qq{
			SELECT  'CNN','News And Information','http://www.cnn.com',to_number(NULL) as item_id  FROM dual
			UNION
			SELECT 	value_text,value_textb,name_sort,item_id FROM person_attribute
			WHERE 	parent_id = ?
			AND	item_name = 'User/Link/NonMedical'
			},
	publishDefn => {

			columnDefn => [
				{ dataFmt => '<A HREF="#2#" TARGET="NEWS">#0#</A>',},
				{ dataFmt => '#1#',},
				],
				bullets => '/person/#param.person_id#/dlg-update-link-non-url/#3#',
			frame => {
					editUrl => '/person/#param.person_id#/dlg-add-link-non-url',
				},

			},
	publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel',
				frame => { heading=>'Non Medical Sites', },
			},
	publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
				frame => { heading=>'Non Meidical Sites', },
			},



	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkNonMedicalSite', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkNonMedicalSite', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkNonMedicalSite', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkNonMedicalSite', [$personId], 'panelTransp'); },
},

'person.linkMedicalSite'=>{
	sqlStmt => qq{
			select 'PDR NET','Meidical Reference Information','http://physician.pdr.net/physician/index.htm',to_number(NULL) as item_id  FROM dual
			UNION
			SELECT 	value_text,value_textb,name_sort,item_id FROM person_attribute
			WHERE 	parent_id = ?
			AND	item_name = 'User/Link/Medical'

			},
	publishDefn => {

			columnDefn => [
				{ dataFmt => '<A HREF="#2#" TARGET="NEWS">#0#</A>',},
				{ dataFmt => '#1#',},
				],
				bullets => '/person/#param.person_id#/dlg-update-link-med-url/#3#',
			frame => {
					editUrl => '/person/#param.person_id#/dlg-add-link-med-url',
				},
			},
	publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel',
				frame => { heading=>'Medical Sites', },
			},
	publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
				frame => { heading=>'Meidical Sites', },
			},



	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkMedicalSite', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkMedicalSite', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkMedicalSite', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.linkMedicalSite', [$personId], 'panelTransp'); },
},

'person.docSign' => {
	sqlStmt => qq{select 'NOT IMPLEMENTED' from dual

		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => "<B>#0#</B>" },
		],

	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Signature Request' },
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
		frame => { heading => 'Signature Request' },
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

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docSign', []); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docSign', [], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docSign', [], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docSign', [], 'panelTransp'); },
},


'person.inPatient' => {
	sqlStmt => qq{
			select t.trans_owner_id , t.caption as room_number, initcap(p.short_sortable_name)
				as simple_name, t.consult_id, o.name_primary, %simpleDate:t.trans_begin_stamp - :3%
				as admit_date, data_num_a
			FROM org o, person p, transaction t
			WHERE
				t.trans_type BETWEEN 11000 AND 11999
				AND	t.provider_id = :1
				AND p.person_id = t.trans_owner_id
				AND t.trans_status = 2
				AND t.trans_begin_stamp >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT') - data_num_a
				AND o.org_internal_id = t.service_facility_id
			ORDER by p.name_last
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

			publishDefn => {
				columnDefn => [
					{ head=> 'Patient ', colIdx=>2, url => "/person/#0#/profile",hint=>"#3#",
						options => PUBLCOLFLAG_DONTWRAP,
					},
					{ head=> 'Hospital/Room',
						dataFmt => qq{#5# <br> <b>#4#</b> - Room #1# <br> Duration: #6# day(s)},
						dAlign=>'left',hAlign=>'left'},
				],
			},
			publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.static',
				#flags => 0,
				frame => { heading => 'Inpatient'
			},
			},
			publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
			},


	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inPatient', [$personId, $page->param('_date'), $page->session('GMT_DAYOFFSET')]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inPatient', [$personId, $page->param('_date'), $page->session('GMT_DAYOFFSET')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inPatient', [$personId, $page->param('_date'), $page->session('GMT_DAYOFFSET')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.inPatient', [$personId, $page->param('_date'), $page->session('GMT_DAYOFFSET')], 'panelTransp'); },
},

'person.messageCounts' => {
	sqlStmt => qq{SELECT doc_spec_subtype, count(*)
		FROM document, document_attribute
		WHERE document_attribute.value_text = :1
			AND document.doc_spec_type = @{[ App::Universal::DOCSPEC_INTERNAL ]}
			AND document.doc_id = document_attribute.parent_id
			AND document_attribute.item_name IN ('To', 'CC')
			AND document_attribute.value_int = 0
			AND document.cr_org_internal_id = :2
			GROUP BY document.doc_spec_subtype
		union
		SELECT '-1' as doc_spec_subtype,count (*)
		FROM	observation
		WHERE	observation.observer_org_id = :2
		AND	observation.observer_id = :1
		group by 1

	},

	publishDefn => {
		columnDefn => [
			{
				colIdx => 0,
				dataFmt => {
					'0' => qq{<a href='/person/#param.person_id#/mailbox/internalMessages'>Internal Message</a>},
					'1' => qq{<a href='/person/#param.person_id#/mailbox/phoneMessages'>Phone Message</a>},
					'2' => qq{<a href='/person/#param.person_id#/mailbox/prescriptionRequests'>Prescription Approval Request</a>},
					'-1' =>qq{<a href='/worklist/documents/labs'>Results</a>},
				},
			},
			{
				colIdx => 1,
			},
		],
	},
	publishDefn_panel =>
	{
		style => 'panel',
		frame => {
			heading => 'Work Lists',
		},
	},
	publishDefn_panelTransp =>
	{
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelStatic =>
	{
		style => 'panel.static',
		inherit => 'panel',
	},
	publishDefn_panelInDlg =>
	{
		style => 'panel.indialog',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.messageCounts', [$personId,$page->session('org_internal_id')], 'panelInDlg'); },
},


'person.docResults' => {
	sqlStmt => qq{
			select 	'Ms Cindy Crawford',to_char(sysdate,'Mon-DD'), 'Lab','CBC' ,'CCRAWFORD','Abnormal' FROM DUAL
			UNION
			select 	'GEORGE SCHMIDT' ,to_char(sysdate,'Mon-DD'),'X-Ray','Chest-Xray', 'GSCHMIDT','Normal'  FROM DUAL
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => qq{<A HREF='javascript:alert("NOT IMPLEMENTED")' >#0#</A>: (#1#) #3#  <B>#5#</B>}, },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Results' },
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
		frame => { heading => 'Results' },

	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docResults', []); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docResults', [], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docResults', [], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docResults', [], 'panelTransp'); },
},





'person.docPhone' => {
	sqlStmt => qq{

                        select  trans_id, trans_owner_id, trans_type, decode(trans_status,4,'Read',5,'Not Read'), caption, provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b,  consult_id,complete_name
                                from  Transaction,person
                        where   trans_owner_id = ?
                        and caption = 'Phone Message'
                        and data_num_a is not null
                        and trans_status = 5
                        and person.person_id = consult_id
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table, Person ID for Transaction Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => qq{<A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#0#?home=#homeArl#' >#10#</A>: (#6#): #7# }, },
		],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-#2#/#0#?home=#homeArl#',
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

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docPhone', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docPhone', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docPhone', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docPhone', [$personId], 'panelTransp'); },
},




'person.docRefill' => {
	sqlStmt => qq{
			select 	trans_id, trans_owner_id, trans_type, decode(trans_status,7,'Filled',6,'Pending'), caption,
					provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b,  processor_id, receiver_id,
					person.complete_name
				from  Transaction,person
			where  	trans_owner_id = ?
			and caption = 'Refill Request'
                        and data_num_a is null
                        and processor_id = person_id
                        union
                        select  	trans_id, trans_owner_id, trans_type, decode(trans_status,7,'Filled',6,'Pending'), caption,
                        		provider_id, %simpleDate:trans_begin_stamp%, data_text_a, data_text_b,  processor_id, receiver_id,
                        		person.complete_name
                                from  Transaction, person
                        where   trans_owner_id = ?
                        and caption = 'Refill Request'
                        and data_num_a is not null
                        and processor_id = person_id
                        and trans_status = 6
		},
		sqlStmtBindParamDescr => ['Person ID for Transaction Table', 'Person ID for Transaction Table'],

	publishDefn =>
	{

		columnDefn => [
				{ dataFmt =>qq{<A HREF = '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-refill-#2#/#0#?home=#homeArl#'> #11#</A> : (#6#) #7# (#3#)}, },
				],
		#bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-trans-refill-#2#/#0#?home=#homeArl#',
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
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docRefill', [$personId,$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docRefill', [$personId,$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docRefill', [$personId,$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.docRefill', [$personId,$personId], 'panelTransp'); },
},


'person.scheduleAppts' =>{

			sqlStmt => qq{
			SELECT p.person_id, to_char(e.start_time - :1, 'hh:miam') as start_time,
				a.caption, e.subject as visit, org_id, initcap(p.short_sortable_name) as simple_name
			FROM appt_status a, org, person p, event_attribute ePhy, event e
			WHERE e.start_time >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :1
				AND e.start_time <  to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT') + :1 + 1
				AND e.event_status < 3
				AND ePhy.parent_id = e.event_id
				AND ePhy.item_name = 'Appointment'
				AND ePhy.value_textB = :2
				AND p.person_id = ePhy.VALUE_TEXT
				AND org.org_internal_id = e.facility_id
				AND a.id = e.event_status
			ORDER by e.start_time
			},
			sqlStmtBindParamDescr => ['Person ID for transaction table'],

			publishDefn => {
				columnDefn => [
					{ head=> 'Patient', colIdx=>5, hAlign=>'left', url => "/person/#0#/profile",
						options => PUBLCOLFLAG_DONTWRAP,
					},
					{ head=> 'Appointment Time', hAlign => 'left' , },
					{ head=>'Status' ,hAlign => 'left'},
					{ head=> 'Reason For Visit',hAlign => 'left' },
					{ head=> 'Facility' },

				],
			},
			publishDefn_panel =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.static',
				flags => 0,
				frame => { heading => qq{ Date
						<INPUT size=10	NAME="_date" value='#param._date#' onChange="validateChange_Date(event); updatePage(this.value)">
						<A HREF="javascript:showCalendar(_date, 1);"> <img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></A>
						&nbsp Appointments
						<INPUT name=person_id type=hidden value='#param.person_id#'>
					}
				},
			},
			publishDefn_panelTransp =>
			{
				# automatically inherits columnDefn and other items from publishDefn
				style => 'panel.transparent.static',
				inherit => 'panel',
			},


			publishComp_st => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.scheduleAppts', [$page->session('GMT_DAYOFFSET'),$personId,$page->param('_date')] ); },
			publishComp_stp => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.scheduleAppts', [$page->session('GMT_DAYOFFSET'),$personId,$page->param('_date')], 'panel'); },
			publishComp_stpe => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.scheduleAppts', [$page->session('GMT_DAYOFFSET'),$personId,$page->param('_date')], 'panelEdit'); },
			publishComp_stpt => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->session('user_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.scheduleAppts', [$page->session('GMT_DAYOFFSET'),$personId,$page->param('_date')], 'panelTransp'); },

	},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.bookmarks' =>
{
	sqlStmt => qq
	{
		select value_text, value_textb, parent_id, item_id
		from person_attribute
		where parent_id = :1
		and item_name = 'Bookmarks'
	},

	sqlStmtBindParamDescr => ['Person ID for transaction table'],

	publishDefn =>
	{
		columnDefn => [
			{ head => 'Bookmarks', dataFmt => '#1#: <A HREF="#0#">#0#</A>' },
		],
		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-book-marks/#3#?home=#homeArl#',
		frame => {
			addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-book-marks?home=#homeArl#',
			editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},

	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.static',
#		flags => 0,
		frame => { heading => 'Bookmarks / HyperLinks' },
	},

	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		inherit => 'panel',
	},

	publishDefn_panelEdit =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.edit',
		frame => { heading => 'Bookmarks / HyperLinks' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-book-marks?home=#homeArl#'>Bookmarks</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-book-marks/#3#?home=#param.home#',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-book-marks/#3#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bookmarks', [$personId] ); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bookmarks', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bookmarks', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_;  $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bookmarks', [$personId], 'panelTransp'); },

},

#----------------------------------------------------------------------------------------------------------------------------------------------------------

'person.appointmentCount' => {
	sqlStmt => qq{
			SELECT
				count(e.discard_type),
				DECODE(d.caption, 'Patient Reschedule','Reschedule', d.caption)
			FROM event e, event_attribute ea, Appt_Discard_Type d, person p
			WHERE Ea.value_text = p.person_id
			AND p.person_id = ?
			AND ea.parent_id = e.event_id
			AND d.id = e.discard_type
			GROUP BY d.caption


		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => '#1#s : #0#' },
		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Appointment Discard Type Count' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.appointmentCount', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.appointmentCount', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.appointmentCount', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.appointmentCount', [$personId], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
'person.bloodType' => {
	sqlStmt => qq{
			SELECT
					value_type,
					item_id,
					parent_id,
					item_name,
					DECODE(value_text, '', 'Unknown', (
																	SELECT b.caption
																	FROM  blood_type b
																	WHERE b.id = p.value_text
																)
					) AS caption
				FROM  Person_Attribute p
			WHERE  	parent_id = ?
			AND item_name = 'BloodType'

		},
		sqlStmtBindParamDescr => ['Person ID for Attribute Table'],

	publishDefn =>
	{

		columnDefn => [
					{ dataFmt => 'Blood Type: #4#' },
		],

		bullets => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-blood-type/#1#?home=#homeArl#',
		frame => {
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-blood-type?home=#homeArl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},

	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Blood Type' },
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
		frame => { heading => 'Blood Type' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-blood-type?home=#param.home#'>Blood Type</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-blood-type/#1#?home=#param.home#', delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-blood-type/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bloodType', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bloodType', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bloodType', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.bloodType', [$personId], 'panelTransp'); },
},

#-----------------------------------------------------------------------------------------------------------------------------------------
'person.personCategory' => {
	sqlStmt => qq{
			select 	p.simple_name, pa.category, pa.person_id, pa.org_internal_id
			from 	person_org_category pa, person p
			where	 p.person_id = ?
				and pa.org_internal_id = ?
				and pa.category in ('Patient', 'Guarantor','Insured-Person')
				and	p.person_id = pa.person_id
			order by pa.category
		},
	sqlStmtBindParamDescr => ['Org ID for org_id in Person_Org_Category Table'],
	publishDefn => {
		columnDefn => [
			{head => 'Type', dataFmt => '#1#'},
		],
		bullets => 'stpe-#my.stmtId#/dlg-update-person-category/?_f_person_id=#2#&_f_category=#1#&home=#homeArl#',
		frame => {
					addUrl => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-category?home=#homeArl#',
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Person Categories' },
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
		frame => { heading => 'Edit Person Categories' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='/person/#param.person_id#/stpe-#my.stmtId#/dlg-add-person-category?home=#homeArl#'>Person Category</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-person-category/?_f_person_id=#2#&_f_category=#1#&home=/person/#param.person_id#/profile',
			delUrlFmt => '/person/#param.person_id#/stpe-#my.stmtId#/dlg-remove-person-category/?_f_person_id=#2#&_f_category=#1#&home=/person/#param.person_id#/profile',
		},
	},
	publishComp_st => sub { my ($page, $flags, $personId, ) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId], 'panelTransp'); },
	publishComp_stps => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId], 'panelStatic'); },
	publishComp_stpd => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); my $orgInternalId = $page->session('org_internal_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.personCategory', [$personId,$orgInternalId], 'panelInDlg'); },
},

#-----------------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------

'person.clinical' => {
	sqlStmt => qq{
			select 	value_type, item_id, item_name, value_text
			from 	person_attribute
			where 	parent_id = ?
			and 	value_type = 111111
		},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Clinical Records (Not Yet Implemented)' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.clinical', [$personId]); },
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.clinical', [$personId], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.clinical', [$personId], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.clinical', [$personId], 'panelTransp'); },
},

#----------------------------------------------------Doc Short Term Stuff
#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------
'person.labOrderSummary' => {
	sqlStmt => qq{
			Select	org_id,name_primary,org_internal_id,
			(SELECT count (*)
			FROM 	person_lab_order lo
			WHERE 	lo.person_id = :2
			AND	lo.lab_internal_id = org.org_internal_id
			) as entry
			FROM	org ,ORG_CATEGORY oc
			WHERE  	owner_org_id= :1
			AND	oc.parent_id = org.org_internal_id
			AND	oc.member_name='Ancillary Service'
			order by org_id
			},
	sqlvar_entityName => 'OrgInternal ID for LAB',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn => {

			frame => {
					editUrl => '/person/#param.person_id#/stpe-#my.stmtId#?home=#homeArl#',
				},
				columnDefn =>
				[
				{colIdx => 1,hint=>"Add Order Entry to #1#" , url=>'/person/#param.person_id#/dlg-add-lab-order/#0#?home=#homeArl#&org_id=#0#',hAlign=>'left', head => 'Lab Name',},
				{colIdx => 3, hAlign=>'left', head => 'Patient Lab Requests'},
				],

			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => { heading => 'Ancillary Tests' },
		bullets => '/person/#param.person_id#/stpe-person.labOrderDetail?id=#2#&home=#homeArl#',

	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		style => 'panel.edit',
		frame => { heading => 'Ancillary Test Entry' },
				columnDefn =>
				[
				{colIdx => 1,hint=>"Add Order Entry to #1#" , hAlign=>'left', head => 'Lab Company',},
				{colIdx => 3, dAlign=>'right', head => 'Entries'},
				{dAlign=>'right', dataFmt=>'Add', url=>'/person/#param.person_id#/dlg-add-lab-order/#0#?home=#homeArl#&org_id=#0#', hint=>'Add Ancillary Test Entry'},
				],
	},
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderSummary', [$page->session('org_internal_id'),$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderSummary', [$page->session('org_internal_id'),$personId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderSummary', [$page->session('org_internal_id'),$personId], 'panelEdit'); },
},
#------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------------------
'person.labOrderDetail' => {
	sqlStmt => qq{
			Select	lo.lab_order_id,lo.date_order,lo.provider_id, los.caption
			FROM	org ,person_lab_order lo, lab_order_status los
			WHERE  	owner_org_id= :1
			AND	lo.lab_internal_id = org.org_internal_id
			AND 	lo.lab_internal_id = :2
			AND	lo.person_id = :3
			AND	los.id = lo.lab_order_status
			order by date_order desc
			},
	sqlvar_entityName => 'OrgInternal ID for LAB',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn => {
			#bullets => ['/person/#param.person_id#/stpe-#my.stmtId#/dlg-update-lab-order/#0#?home=#homeArl#',
			bullets => ['/person/#param.person_id#/dlg-update-lab-order/#0#?home=#homeArl#',

		],
				columnDefn =>
				[
				{colIdx => 0, hAlign=>'left', head => 'Lab Order ID',},
				{colIdx => 1, hAlign=>'left', head => 'Order Date',dformat=>'date'},
				{colIdx => 2, hAlign=>'left', head => 'Provider ID'},
				{colIdx => 3, hAlign=>'left', head => 'Lab Order Status'},
				],
			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => { heading => 'Ancillary Tests' },

	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		#style => 'panel.edit',
		frame => { heading => 'Edit Ancillary Test' ,
				closeUrl => '#param.home#',
			},

	}	,
	publishComp_stp => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderDetail', [$page->session('org_internal_id'),27960,$personId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderDetail', [$page->session('org_internal_id'),$page->param('id')||undef,$personId ], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $personId) = @_; $personId ||= $page->param('person_id'); $STMTMGR_COMPONENT_PERSON->createHtml($page, $flags, 'person.labOrderDetail', [$page->session('org_internal_id'),$page->param('id')||undef,$personId ], 'panelEdit'); },
},
#------------------------------------------------------------------------------------------------------------------------

);

1;
