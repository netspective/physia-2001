##############################################################################
package App::Statements::Component::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use Data::Publish;
use App::Statements::Component;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Contract;
my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT_ORG $PUBLDEFN_CONTACTMETHOD_DEFAULT
	);
@ISA    = qw(Exporter App::Statements::Component);
@EXPORT = qw($STMTMGR_COMPONENT_ORG);

$PUBLDEFN_CONTACTMETHOD_DEFAULT = {
	bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-#5#/#3#?home=#homeArl#',
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
		frame => {
			heading => 'Contact Methods',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
		frame => { heading => 'Edit Contact Methods' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add
					<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgphone?home=#homeArl#'>Telephone</A>,
					<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgfax?home=#homeArl#'>Fax</A>,
					<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgemail?home=#homeArl#'>E-mail</A>,
					<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orginternet?home=#homeArl#'>Web Page (URL)</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#4#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-attr-#1#/#4#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethods', [$orgId], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------
'org.serviceCatalog' => {
	sqlStmt => qq{
			SELECT	oc.catalog_id,oct.caption, count (oce.catalog_id) ,oc.internal_catalog_id
			FROM 	offering_catalog oc, offering_catalog_entry oce,org_attribute oa,
				offering_catalog_type oct
			WHERE 	oce.catalog_id (+)= oc.internal_catalog_id
			AND  	oa.parent_id = :1
			AND  	oa.item_name = 'Fee Schedule'
			AND   	oa.value_int = oc.internal_catalog_id
			AND oct.id = oc.catalog_type
			GROUP BY oc.catalog_id,oct.caption,oc.internal_catalog_id
	},
	sqlvar_entityName => 'Org',
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
				bullets => '/org/#param.org_id#/catalog/#3#/#0#?home=#homeArl#',

				columnDefn => [
						{dataFmt =>'#1# : #0# (#2#)  '},
					],
			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		frame => {
			heading => 'Service Catalog/Fee Schedule',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
		frame => { heading => 'Edit Service Catalog/Fee Schedule' },
		banner => {
			actionRows =>
			[
			{caption =>qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-catalog-item/#param.fs_internal_catalog_id#?home=#homeArl#'>Fee Schedule Entry</A>} },
			{caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-service-catalog/#param.sc_internal_catalog_id#?home=#homeArl#'>Service Catalog Entry</A> },},
			],
			},

	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalog', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalog', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalog', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id');
	#Set param for fee schedule and service catalog
	my $fs_internal_catalog_id=$STMTMGR_CATALOG->getSingleValue($page,STMTMGRFLAG_NONE,'sel1CatalogByOrgIDType',$orgId,0);
	my $sc_internal_catalog_id=$STMTMGR_CATALOG->getSingleValue($page,STMTMGRFLAG_NONE,'sel1CatalogByOrgIDType',$orgId,1);
	$page->param('fs_internal_catalog_id',$fs_internal_catalog_id);
	$page->param('sc_internal_catalog_id',$sc_internal_catalog_id);
	$STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalog', [$orgId], 'panelEdit'); },
},
#------------------------------------------------------------------------------------------------------------------------
'org.ContractCatalogSummary' => {
	sqlStmt => qq{
			SELECT	con.contract_id,
				con.caption,
				(SELECT catalog_id from offering_catalog oc WHERE oc.internal_catalog_id = con.parent_catalog_id) as catalog_id,
				(SELECT product_name FROM Insurance WHERE ins_internal_id = con.product_ins_id) as product_name,
				(SELECT count (*) FROM offering_catalog_entry where catalog_id = con.parent_catalog_id) as code_entry,
				(SELECT 0 from dual) as price_entry,
				internal_contract_id
			FROM 	Contract_Catalog con
			WHERE 	org_internal_id = :1
	},
	sqlvar_entityName => 'Contract_Catalog',
	sqlStmtBindParamDescr => ['Contract ID and Org Internal ID'],
	publishDefn => {
				bullets => '/org/#param.org_id#/dlg-update-contract/#6#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0, tDataFmt => '&{count:0} Contracts', head => 'Contract ID',url=>qq{/org/#param.org_id#/catalog?catalog=contract_detail&contract_detail=#6#}},
				{colIdx => 1, head => 'Contract Name', },
				{colIdx => 2, head => 'Fee Schedule ID',},
				{colIdx => 3, head => 'Insurance Product'},
				{colIdx => 4, head => 'Entries',summarize => 'sum' },
				],
			banner =>
			{
				actionRows =>
				[
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-contract?home=#homeArl#'>Contract Catalog</A> } },
				],
				contentColor=>'#EEEEEE',
			},


			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		contentColor=>'#EEEEEE',
		frame => {
			heading => 'Contract Catalogs',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.ContractCatalogSummary', [$orgId], 'panel'); },
},
#------------------------------------------------------------------------------------------------------------------------
'org.FSCatalogSummary' => {
	sqlStmt => qq{
	SELECT *
	FROM (
		SELECT	oc.catalog_id,
			oc.caption,
			--oc.description,
			DECODE(oc_a.value_int, 1, '(Capitated)', '(FFS)') AS capitated	,
			count(oce.entry_id) entries_count,
			oc.parent_catalog_id,
			oc.internal_catalog_id,
			'Add'
		FROM
			ofcatalog_Attribute oc_a,
			offering_catalog oc,
			offering_catalog_entry oce
		WHERE
			oce.catalog_id (+) = oc.internal_catalog_id
			AND oc_a.parent_id (+) = oc.internal_catalog_id
			AND oc.catalog_type = 0
			AND (oc.org_internal_id IS NULL OR oc.org_internal_id = :1)
		GROUP BY
			oc.catalog_id,
			oc.internal_catalog_id,
			oc.caption,
			oc.description,
			oc.parent_catalog_id ,
			oc_a.value_int
		ORDER BY
			oc.catalog_id
	)
	WHERE rownum <= 250

	},
	sqlvar_entityName => 'Offering_Catalog',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn =>
		{
				bullets => '/org/#param.org_id#/dlg-update-catalog/#5#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0,hAlign=>'left', head => 'Catalog ID',url=>qq{/org/#param.org_id#/catalog?catalog=fee_schedule_detail&fee_schedule_detail=#5#},
				tDataFmt => '&{count:0} Schedules',},
				{colIdx => 1, head => 'Catalog Name', hAlign=>'left'},
				{colIdx => 2, head => 'Contract Type',},
				{colIdx => 3, head => 'Entries',summarize => 'sum',},
				{colIdx =>6,url=>'/org/#session.org_id#/dlg-add-catalog/#5#' ,hint=>'Add Child Item'},
				],
			banner =>
			{contentColor=>'#EEEEEE',

			actionRows =>
			[
				{
					caption => qq{
						<a href='/org/#session.org_id#/dlg-add-catalog'>Add Fee Schedule</a> |
						<a href='/org/#session.org_id#/dlg-add-feescheduledataentry'>Add Fee Schedule Entries</a> |
						<a href='/org/#session.org_id#/dlg-add-catalog-copy'>Copy Fee Schedule and its Entries</a>
					},
				},
			],			},
			stdIcons =>
			{
#				delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog/#5#',
			},
		},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => {
			heading => 'Fee Schedules Catalogs',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->session('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.FSCatalogSummary', [$orgId], 'panel'); },
},

#------------------------------------------------------------------------------------------------------------------------
'org.FSCatalogInsuranceSummary' => {
	sqlStmt => qq{
	SELECT *
	FROM (
		SELECT	oc.catalog_id,
			oc.caption,
			--oc.description,
			DECODE(oc_a.value_int, 1, '(Capitated)', '(FFS)') AS capitated	,
			count(oce.entry_id) entries_count,
			oc.parent_catalog_id,
			oc.internal_catalog_id,
			'Add'
		FROM
			ofcatalog_Attribute oc_a,
			offering_catalog oc,
			offering_catalog_entry oce
		WHERE
			oce.catalog_id (+) = oc.internal_catalog_id
			AND oc_a.parent_id (+) = oc.internal_catalog_id
			AND oc.catalog_type = 0
			AND (oc.org_internal_id IS NULL OR oc.org_internal_id = :1)
			AND EXISTS
				(
					SELECT unique ia.value_text
					FROM 	insurance i, org o,	insurance_attribute ia
					WHERE ia.value_text = oc.internal_catalog_id
					AND ia.parent_id = i.ins_internal_id
					AND ia.item_name = 'Fee Schedule'
					AND i.owner_org_id = :1
					AND i.ins_org_id = o.org_internal_id
					AND o.org_id = :2
				)
		GROUP BY
			oc.catalog_id,
			oc.internal_catalog_id,
			oc.caption,
			oc.description,
			oc.parent_catalog_id ,
			oc_a.value_int
		ORDER BY
			oc.catalog_id
	)
	WHERE rownum <= 250

	},
	sqlvar_entityName => 'Offering_Catalog',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn =>
		{
				bullets => '/org/#param.org_id#/dlg-update-catalog/#5#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0,hAlign=>'left', head => 'Catalog ID',url=>qq{/org/#param.org_id#/catalog?catalog=fee_schedule_detail&fee_schedule_detail=#5#},
				tDataFmt => '&{count:0} Schedules',},
				{colIdx => 1, head => 'Catalog Name', hAlign=>'left'},
				{colIdx => 2, head => 'Contract Type',},
				{colIdx => 3, head => 'Entries',summarize => 'sum',},
				{colIdx =>6,url=>'/org/#session.org_id#/dlg-add-catalog/#5#' ,hint=>'Add Child Item'},
				],
			banner =>
			{contentColor=>'#EEEEEE',

			actionRows =>
			[
				{
					caption => qq{
						<a href='/org/#session.org_id#/dlg-add-catalog'>Add Fee Schedule</a> |
						<a href='/org/#session.org_id#/dlg-add-feescheduledataentry'>Add Fee Schedule Entries</a> |
						<a href='/org/#session.org_id#/dlg-add-catalog-copy'>Copy Fee Schedule and its Entries</a>
					},
				},
			],			},
			stdIcons =>
			{
#				delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog/#5#',
			},
		},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => {
			heading => 'Fee Schedules Catalogs',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId, $insOrgId) = @_; $orgId ||= $page->session('org_internal_id');$insOrgId = $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.FSCatalogInsuranceSummary', [$orgId, $insOrgId], 'panel'); },
},


#------------------------------------------------------------------------------------------------------------------------
'org.ContractCatalogDetail' => {
	sqlStmt => qq{
			SELECT	code,
				modifier,
				(SELECT caption FROM Catalog_Entry_Type  WHERE id = oce.entry_type) as type,
				name,
				(expected_cost) as  exp_cost,
				(allowed_cost) as all_cost,
				oce.entry_id,
				con.internal_contract_id,
				ocp.price_id,
				decode(ocp.price_id,NULL,'Add','Mod')
			FROM 	Contract_Catalog con, Offering_catalog_Entry oce,
				Offering_CatEntry_Price ocp
			WHERE 	con.internal_contract_id = :1
			AND	oce.catalog_id = con.parent_catalog_id
			AND	con.org_internal_id = :2
			AND	ocp.internal_contract_id (+)= :1
			AND	ocp.entry_id (+) = oce.entry_id
			order by modifier, code
			},
	sqlvar_entityName => 'Contract_Catalog',
	sqlStmtBindParamDescr => ['Contract ID and Org Internal ID'],
	publishDefn => {
				columnDefn =>
				[
				{colIdx => 0, head => 'Code',tDataFmt =>'&{count:0} Entries'},
				{colIdx => 1, head => 'Modifier', },
				{colIdx => 2, head => 'Type',dAlign=>'left',hAlign=>'left'},
				{colIdx => 3, head => 'Name',hAlign=>'left'},
				{colIdx => 4, head => 'Expected Price', dformat => 'currency',summarize => 'sum'},
				{colIdx => 5, head => 'Allowed Price', dformat => 'currency',summarize => 'sum'},
				{colIdx => 9,head=>'Actions',
						dataFmt => {
								'Mod' => qq{<A HREF="/org/#param.org_id#/dlg-update-contract-item/#8#"
					TITLE='Modify Contract Price'>
					<img src="/resources/icons/black_m.gif" BORDER=0></A>
					<A HREF="/org/#param.org_id#/dlg-remove-contract-item/#8#"
										TITLE='Delete Contract Price'>
					<img src="/resources/icons/black_d.gif" BORDER=0></A>
									  },
								'Add' => qq{<A HREF="/org/#param.org_id#/dlg-add-contract-item/#7#/#6#"
					TITLE='Add Contract Price'>
					<IMG SRC="/resources/icons/black_a.gif" BORDER=0></A>}
							   },
				},
				#{head =>'Actions',dataFmt=>qq{<A HREF="/org/#param.org_id#/dlg-add-contract-item/#7#/#6#"
				#	TITLE='Add Contract Price'>
				#	<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0></A>}}
				],
#			banner =>
#			{
#				actionRows =>
#				[
#				{ caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-contract?home=#homeArl#'>Contract Catalog</A> } },
#				],
#			},
			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => {
			heading => '#param.contract_id# : Contract Entries ',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $contract_id,$org_id) = @_;$org_id = $page->session('org_internal_id');
	$contract_id = $page->param('contract_detail');
	#Get Contract ID
	my $catalog = $STMTMGR_CONTRACT->getRowAsHash($page,STMTMGRFLAG_NONE,'selContractByID',$contract_id);
	$page->param('contract_id',$catalog->{contract_id});
	$STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.ContractCatalogDetail', [$contract_id,$org_id], 'panel'); },
},

#------------------------------------------------------------------------------------------------------------------------
'org.FSCatalogDetail' => {
	sqlStmt => qq{
			SELECT
				code AS code,
				modifier AS modifier,
				catalog_entry_type.caption AS Type,
				name,
				--description AS description,
				DECODE(flags, 0, NULL, '(FFS)'),
				unit_cost AS price,
				--default_units AS uoh,
				'Add',
				parent_entry_id,
				entry_id AS ID,
				oc.internal_catalog_id
			FROM
				catalog_entry_type,
				offering_catalog_entry oce,
				offering_catalog oc
			WHERE	oce.catalog_id = :1
			AND	oce.catalog_id = oc.internal_catalog_id
			AND	oc.org_internal_id = :2
			AND	oce.entry_type = catalog_entry_type.id
			ORDER BY
				entry_type,
				code,
				modifier
		},
	sqlvar_entityName => 'Contract_Catalog',
	sqlStmtBindParamDescr => ['Contract ID and Org Internal ID'],
	publishDefn => {
				columnDefn =>
				[
				{colIdx => 0, hAlign =>'left',head => 'Code',tDataFmt => '&{count:0} Entries'},
				{colIdx => 1, hAlign =>'left', head => 'Modifier', },
				{colIdx => 2, head => 'Procedure Type',dAlign=>'left',hAlign=>'left'},
				{colIdx => 3, head => 'Name',hAlign=>'left'},
				{colIdx => 4, head => 'Contract Type',dAlign=>'left',hAlign=>'left'},
				{colIdx => 5, head => 'Price', dformat => 'currency',summarize => 'sum'},
				{colIdx => 5, head => 'Actions', dataFmt=>
					q{
						<A HREF="/org/#param.org_id#/dlg-add-catalog-item/#9#/#8#"
						TITLE='Add Child Item'>
						<img src="/resources/icons/black_a.gif" BORDER=0></A>
						<A HREF="/org/#param.org_id#/dlg-update-catalog-item/#8#"
						TITLE='Modify Item'>
						<img src="/resources/icons/black_m.gif" BORDER=0></A>
						<A HREF="/org/#param.org_id#/dlg-remove-catalog-item/#8#"
											TITLE='Delete Item'>
						<img src="/resources/icons/black_d.gif" BORDER=0></A>
									  }
				},
				],
			banner =>
			{contentColor=>'#EEEEEE',
				actionRows =>
				[
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-catalog-item/#param.fee_schedule_detail#?home=#homeArl#'>Fee Schedule Item</A> } },
				],
			},
			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		frame => {
			heading => '#param.catalog_id#  : Fee Schedule Entries ',
					addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $contract_id,$org_id) = @_; $org_id = $page->session('org_internal_id'); $contract_id = $page->param('fee_schedule_detail');
	#Get Fee Schedule Catalog ID
	my $catalog = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$contract_id);
	$page->param('catalog_id',$catalog->{catalog_id});
	$STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.FSCatalogDetail', [$contract_id,$org_id], 'panel'); },
},


#----------------------------------------------------------------------------------------------------------------------
'org.fsCatalogEntry' => {
	sqlStmt => qq{
			SELECT	oce.code,oce.name,(SELECT caption FROM catalog_entry_type WHERE id = oce.entry_type), oce.entry_id,
			oce.unit_cost
			FROM 	offering_catalog_entry oce,offering_catalog oc
			WHERE 	oce.catalog_id = :1
			AND	oc.internal_catalog_id = oce.catalog_id
			ORDER BY 1
	},
	sqlvar_entityName => 'Org',
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
				bullets => '/org/#param.org_id#/dlg-update-catalog-item/#3#?home=#homeArl#',
				columnDefn => [
				{colIdx => 0, head => 'Code',hAlign=>'left', dAlign => 'left',tDataFmt => '&{count:0} Entries',},
				{colIdx => 1, head => 'Name', hAlign=>'left',dAlign => 'left'},
				{colIdx => 2, head => 'Code Type', hAlign=>'left',dAlign => 'left'},
				{colIdx => 4, head => 'Charge', hAlign=>'right',dAlign => 'left',dformat => 'currency' ,summarize=>'sum'},

],
			banner =>
			{
				actionRows =>
				[
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-catalog-item/#param.internal_catalog_id#?home=#homeArl#'>Fee Schedule Entry</A> } },
				],
			},

			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		#rowSepStr =>'',
		frame => {
			heading => 'Fee Schedule Entries',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
			#width=>'30%',
		flags=>0,
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.fsCatalogEntry', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.fsCatalogEntry', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.fsCatalogEntry', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.fsCatalogEntry', [$orgId], 'panelEdit'); },
},
#----------------------------------------------------------------------------------------------------------------------
'org.serviceCatalogEntry' => {
	sqlStmt => qq{
			SELECT	oce.code,(SELECT  name FROM ref_service_category WHERE oce.code = serv_category), oce.entry_id
			FROM 	offering_catalog_entry oce,offering_catalog oc
			WHERE 	oce.catalog_id = :1
			AND	oc.internal_catalog_id = oce.catalog_id
			ORDER BY 1
	},
	sqlvar_entityName => 'Org',
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
				bullets => '/org/#param.org_id#/dlg-update-service-catalog/#2#?home=#homeArl#',
				columnDefn => [
				{colIdx => 0, head => 'Code',hAlign=>'left', dAlign => 'left',tDataFmt => '&{count:0} Entries',},
				{colIdx => 1, head => 'Name', hAlign=>'left',dAlign => 'left'},

],
			banner =>
			{
				actionRows =>
				[
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-service-catalog/#param.internal_catalog_id#?home=#homeArl#'>Service Catalog Entry</A> } },
				],
			},

			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		#rowSepStr =>'',
		frame => {
			heading => 'Service Catalog Entries',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
			#width=>'30%',
		flags=>0,
	},
	publishDefn_panelTransp =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalogEntry', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalogEntry', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalogEntry', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('internal_catalog_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.serviceCatalogEntry', [$orgId], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.contactMethodsAndAddresses' => {
	sqlStmt => $SQLSTMT_CONTACTMETHODS_AND_ADDRESSES_INTERNAL_ORG,
		sqlvar_entityName => 'Org',
		sqlStmtBindParamDescr => ['Org ID for Attribute Table', 'Org ID for Address Table'],
		publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			separateDataColIdx => 2, # when the item_name is '-' add a row separator
			frame => {
				heading => 'Contact Methods/Addresses',
				editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
			separateDataColIdx => 2, # when the item_name is '-' add a row separator
			frame => { heading => 'Edit Contact Methods/Addresses' },
			banner => {
				actionRows =>
				[
					{ caption => qq{ Add
						<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgphone?home=#homeArl#'>Telephone</A>,
						<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgfax?home=#homeArl#'>Fax</A>,
						<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgemail?home=#homeArl#'>E-mail</A>,
						<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orginternet?home=#homeArl#'>Web Page (URL)</A>,
						<A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-contact-orgbilling?home=#homeArl#'>Billing Contact</A> }
					  },
					{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-address-org?home=#homeArl#'>Address</A> }, url => 'x', },

				],
			},
			stdIcons =>	{
				updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-#5#/#3#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-#5#/#3#?home=#homeArl#',
			},
		},
		publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses',
		[$page->param('org_id'),$page->session('org_internal_id')]); },
		publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses',
		[$page->param('org_id'),$page->session('org_internal_id')],'panel'); },
		publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses',
		[$page->param('org_id'),$page->session('org_internal_id')],'panelTransp'); },
		publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.contactMethodsAndAddresses',
		[$page->param('org_id'),$page->session('org_internal_id')] ,
		 'panelEdit'); },
},
#----------------------------------------------------------------------------------------------------------------------
'org.feeschedules'=>
{
	sqlStmt =>qq
	{SELECT	oc.catalog_id,
		oc.caption,
		oc.description,
		oc.internal_catalog_id,
		oa.item_id
	FROM    org_attribute oa,
		offering_catalog oc
	WHERE   oa.parent_id = :1
	AND	oa.item_name = 'Fee Schedule'
	AND	oa.item_type = 0
	AND	oa.value_type = @{[ App::Universal::ATTRTYPE_INTEGER ]}
	AND	oa.value_int = oc.internal_catalog_id
	ORDER BY oc.catalog_id
	},
	sqlvar_entityName => 'Org',
	sqlStmtBindParamDescr => ['Org Internal ID for Fee Schedules'],
	publishDefn =>
	{
		frame =>
		{
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-feeschedule-org?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
		columnDefn =>
			[
			{ head => 'Associated Fee Schedules', dataFmt => '<A HREF=/org/#param.org_id#/catalog/#3#/#0#>#0#</A>'  },
			{colIdx => 1,  dAlign => 'left'},
			],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-feeschedule-org/#4#?home=#homeArl#',
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => {
			heading => 'Associated Fee Schedules',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
			{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-feeschedule-org?home=#param.home#'>Associated Fee Schedules</A> }, url => 'x', },
			],
		},
		stdIcons =>
		{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-feeschedule-org/#4#?home=#param.home#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-feeschedule-org/#4#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId =$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id')); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeschedules', [$orgId]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId  =$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id')); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeschedules', [$orgId], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId  =$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id')); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeschedules', [$orgId], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId =$STMTMGR_ORG->getSingleValue($page, STMTMGRFLAG_NONE, 'selOrgId', $page->session('org_internal_id'), $page->param('org_id')); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeschedules', [$orgId], 'panelEdit'); },
},



#----------------------------------------------------------------------------------------------------------------------

'org.alerts' => {
	sqlStmt => qq{
		SELECT
			trans_id,
			trans_type,
			t.caption,
			detail,
			trans_subtype
		FROM 	transaction t, alert_priority a
		WHERE	trans_owner_type = 1
		AND 	trans_owner_id =
		(
			SELECT org_internal_id
			FROM org
			WHERE owner_org_id = :2 AND
			org_id = :1
		)
		AND	trans_type between 8000 and 8999
		AND	trans_status = 2
		AND     a.caption = t.trans_subtype
		ORDER BY a.id desc, trans_begin_stamp desc
		},
	sqlStmtBindParamDescr => ['Org ID for Transaction Table'],
	publishDefn => {
			columnDefn => [
				#{ colIdx => 0, dataFmt => '&{fmt_stripLeadingPath:0}:', dAlign => 'RIGHT' },
				#{ colIdx => 1,  dataFmt => '#1#', dAlign => 'LEFT' },
				{ head => 'Alerts', dataFmt => '<b>#4#</b>: #2#<br/><I>#3#</I>' },
			],
			bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-trans-#1#/#0#?home=#homeArl#',
			frame => {
				addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-alert-org?home=#homeArl#',
				editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-alert-org?home=#homeArl#'>Alert</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-trans-#1#/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-trans-#1#/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.alerts', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.generalInformation' => {
	sqlStmt => qq{
		select 	name_primary, name_trade, category, tax_id, org_id, org_internal_id
		from 	org
		where owner_org_id = :2 AND
		org_id = :1
		)
		},
	sqlStmtBindParamDescr => ['Org ID for Org Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 0, head => 'Primary Name', dataFmt => '<b>#0#</b> <br> Legal Name: #0# <br> Tax ID: #3# <br> Category: #2#' },
			#{ colIdx => 1, head => 'Trade Name', dataFmt => '#1#' },
			#{ colIdx => 2, head => 'Category', dataFmt => '#2#' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org/#4#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-attr-0?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-attr-0?home=#homeArl#'>General Information</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org/#4#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-org/#4#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.generalInformation', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.credentials' => {
	sqlStmt => qq{
		select  value_type, item_id, item_name, value_text
		from 	org_attribute
		where	parent_id =
		(select org_internal_id
						from org
						where owner_org_id = :2 AND
						org_id = :1
		)
		and 	value_type = @{[ App::Universal::ATTRTYPE_CREDENTIALS ]}
		},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Name', dataFmt => '&{fmt_stripLeadingPath:2}' },
			{ dataFmt => '#3#' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-credential?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-credential?home=#homeArl#'>Credentials</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.credentials', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.departments' => {
	sqlStmt => qq{
		select 	ocat.parent_id, org.name_primary, org.parent_org_id, org.org_id, org.org_internal_id
		from 	org org, org_category ocat
		where 	org.parent_org_id =
		(select org_internal_id
				from org
				where owner_org_id = :2 AND
				org_id = :1
		)
		and 	ocat.member_name = 'Department'
		and 	ocat.parent_id = org.org_internal_id
		},
	sqlStmtBindParamDescr => ['Org ID for Org Table'],
	publishDefn => {
		columnDefn => [
			#{ colIdx => 0, head => 'Org Category', dataFmt => '#0#' },
			{ colIdx => 1, head => 'Primary Name', dataFmt => '#1#:' },
			{ colIdx => 2, head => 'Org ID', dataFmt => '#3#' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-dept/#3#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-dept?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-dept?home=#homeArl#'>Department</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-dept/#3#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-org-dept/#3#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.departments', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.associatedOrgs' => {
	sqlStmt => qq{
			select 	item_id, value_type, item_name, value_text
			from 	org_attribute
			where	parent_id =
			(select org_internal_id
				from org
				where owner_org_id = :2 AND
				org_id = :1
			)
			and 	value_type = @{[ App::Universal::ATTRTYPE_RESOURCEORG ]}
		},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 2, head => 'Org', dataFmt => '&{fmt_stripLeadingPath:2}:' },
			{ colIdx => 3, head => 'Org ID', dataFmt => '#3#' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-resource-org?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-resource-org?home=#homeArl#'>Associated Organization</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-attr-#1#/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedOrgs', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.personnel' => {
	sqlStmt => qq{
			select 	p.simple_name, pa.category, pa.person_id, pa.org_internal_id
			from 	person_org_category pa, person p
			where	pa.org_internal_id =
				(select org_internal_id
							from org
							where owner_org_id = :2 AND
							org_id = :1
				)
				and pa.category in ('Physician', 'Nurse', 'Staff', 'Administrator', 'Superuser')
				and	p.person_id = pa.person_id
			order by pa.person_id, pa.category, p.complete_name
		},
	sqlStmtBindParamDescr => ['Org ID for org_id in Person_Org_Category Table'],
	publishDefn => {
		columnDefn => [
			{head => 'Name', colIdx => 0, dataFmt => '<A HREF = "/person/#2#/profile">#2# #0#</A>'},
			{head => 'Type', colIdx => 1, dataFmt => '#1#'},
		],
		bullets => [
			'/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-personnel/?_f_person_id=#2#&_f_category=#1#&home=/org/#param.org_id#/personnel',
			{	imgSrc => '/resources/icons/action-edit-update.gif',
				urlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-password/#2#/#3#?home=/org/#param.org_id#/personnel',
				title => 'Change Password',
			},
		],

		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-personnel?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Personnel' },
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
		frame => { heading => 'Edit Personnel' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-personnel?home=#homeArl#'>Personnel</A> }	},
				#{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-physician?home=#homeArl#'>Physician</A> }	},
				#{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-nurse?home=#homeArl#'>Nurse</A> }	},
				#{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-staff?home=#homeArl#'>Staff Member</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-personnel/?_f_person_id=#2#&_f_category=#1#&home=/org/#param.org_id#/personnel',
			delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-personnel/?_f_person_id=#2#&_f_category=#1#&home=/org/#param.org_id#/personnel',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$page->param('org_id'),$page->session('org_internal_id')] ); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_;  $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.personnel', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.associatedResourcesStats' => {
	sqlStmt => qq{
			select 	category, count(category), org_internal_id
			from 	person_org_category
			where	org_internal_id =
			(select org_internal_id
						from org
						where owner_org_id = :2 AND
						org_id = :1
			)
			group by category, org_internal_id
		},
	sqlStmtBindParamDescr => ['Org ID for org_id in Person_Org_Category Table'],
	publishDefn => {
		columnDefn => [
			{ head => 'Category', dataFmt => '#1# #0#(s)' },
		],
		#bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-personnel?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
		frame => { editUrl => 'personnel?home=#homeArl#' },
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-physician?home=#homeArl#'>Physician</A> }	},
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-nurse?home=#homeArl#'>Nurse</A> }	},
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-staff?home=#homeArl#'>Staff Member</A> }	},
			],
		},
		#stdIcons =>	{
		#	updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#1#/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-attr-#1#/#0#?home=#homeArl#',
		#},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats',[$page->param('org_id'),$page->session('org_internal_id')] ); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.associatedResourcesStats', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.feeSchedule' => {
	sqlStmt => qq{
			select 	oc.catalog_id, oc.caption, count(oce.entry_id)
			from	offering_catalog oc, offering_catalog_entry oce
			where	oc.catalog_id = oce.catalog_id (+)
			and	oc.org_internal_id =
			(select org_internal_id
				from org
				where owner_org_id = :2 AND
				org_id = :1
			)
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
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-catalog/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-catalog?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-catalog?home=#homeArl#'>Fee Schedule</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-catalog/#0#?home=#homeArl#',
			delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-catalog/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.feeSchedule', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.catalogItems' => {
	sqlStmt => qq{
			select 	oce.entry_id, oce.catalog_id, oce.code, oce.unit_cost
			from 	offering_catalog_entry oce, offering_catalog oc
			where	oc.catalog_id = oce.catalog_id
			and	oc.org_internal_id =
			(select org_internal_id
				from org
				where owner_org_id = :2 AND
				org_id = :1
			)
			order by oce.entry_type, oce.status, oce.name, oce.code
		},
	sqlStmtBindParamDescr => ['Org ID for offering catalog Table'],
	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Catalog ID', options => PUBLCOLFLAG_DONTWRAP },
			{ colIdx => 2, head => 'Code' },
			{ colIdx => 3, head => 'Cost' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-catalog-item/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-catalog-item?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-catalog-item?home=#homeArl#'>Catalog Item</A> }	},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-catalog-item/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-catalog-item/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.catalogItems', [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},


#----------------------------------------------------------------------------------------------------------------------

'org.billinginfo' => {
	sqlStmt => qq{
		(select	oa.value_type, oa.item_id, oa.value_text, %simpleDate:oa.value_date%,
			decode(oa.value_int, 0,'Per-Se',2,'THINet', 'Other'),
			decode(oa.value_intb, '1','Active', 'Inactive'),
			o.org_id, 2 as entity_type
		from	org o, org_attribute oa
		where	o.owner_org_id = :1
			and o.org_id = :2
			and	oa.parent_id = o.org_internal_id
			and	oa.item_name = 'Organization Default Clearing House ID'
			and	oa.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]})
		UNION
		(select	pa.value_type, pa.item_id, pa.value_text, %simpleDate:pa.value_date%,
			decode(pa.value_int, 0,'Per-Se', 2,'THINet', 'Other'),
			decode(pa.value_intb,'1','Active', 'Inactive'),
			pa.parent_id, 0 as entity_type
		from	Person_Attribute pa, Person_Org_Category poc
		where	poc.org_internal_id = :1
			and poc.category = 'Physician'
			and	pa.parent_id = poc.person_id
			and	pa.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]})
		UNION
		(select	-1 as value_type, -1 as item_id, '-' as value_text, '-' as value_date,
			'-', '-', '-', 1 as entity_type
			from dual
		)
		order by entity_type DESC
	},

	sqlStmtBindParamDescr => ['Org ID for Electronic Billing Information'],
	publishDefn => {
		columnDefn => [
			{	dataFmt => "#6# - <b>#5#</b> #4# ID: <b>#2#</b> (Effective: #3#)",
			},
		],

		separateDataColIdx => 2,

		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-attr-#0#/#1#/#7#?home=#homeArl#',
		frame => {
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
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
				{ caption => qq{
					Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-billinginfo/#param.org_id#/1?home=#param.home#'>Org Billing ID</A> &nbsp; &nbsp;
					Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-billinginfo//0?home=#param.home#'>Individual Billing ID</A>
				}},
			],
		},
		stdIcons =>	{
			delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-attr-#0#/#1#/#7#?home=#param.home#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billinginfo', [$page->session('org_internal_id'), $page->param('org_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billinginfo', [$page->session('org_internal_id'), $page->param('org_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billinginfo', [$page->session('org_internal_id'), $page->param('org_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billinginfo', [$page->session('org_internal_id'), $page->param('org_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.superbills' => {
	sqlStmt => qq{
		select	oc.internal_catalog_id, oc.catalog_id, oc.caption, oc.description
		from	Offering_Catalog oc
		where	oc.catalog_type = 4
		and	oc.org_internal_id = ?
		and	oc.flags = 1
	},

	sqlStmtBindParamDescr => ['Org ID for Electronic Billing Information'],

	publishDefn => {
		columnDefn => [
			{ colIdx => 1, head => 'Superbill ID', },
			{ colIdx => 2, head => 'Caption' },
			{ colIdx => 3, head => 'Description' },
			{ dataFmt => 'Print', url => '/org/#param.org_id#/superbills?action=printSample&superbillid=#0#' },
		],

#		separateDataColIdx => 2,

		bullets => '/org/#param.org_id#/superbills?action=edit&superbillid=#0#',
		banner =>
		{
			actionRows =>
			[
			{ caption => qq{ Add <A HREF= '/org/#param.org_id#/superbills?action=new'>Superbill</A> &nbsp; &nbsp; } },
			],
			contentColor=>'#EEEEEE',
		},
#		frame => {
#			editUrl => '/org/#param.org_id#/superbills?action=edit&superbillid=#0#',
#			addUrl => '/org/#param.org_id#/superbills?action=new',
#		},
	},
	publishDefn_panel =>
	{
		style => 'panel.transparent.static',
		frame => {
			heading => 'Superbill Catalog',
			addUrl => '/org/#param.org_id#/superbills?action=new',
		},
		stdIcons =>	{
			delUrlFmt => '/org/#param.org_id#/superbills?action=delete&superbillid=#0#',
		},
	},
	publishDefn_panelTransp =>
	{
		style => 'panel.transparent',
		inherit => 'panel',
	},
	publishDefn_panelEdit =>
	{
		style => 'panel.edit',
		frame => { heading => 'Edit Superbill' },
		banner => {
			actionRows =>
			[
				{ caption => qq{
					Add <A HREF= '/org/#param.org_id#/superbills?action=new'>Superbill</A> &nbsp; &nbsp;
				}},
			],
		},
		stdIcons =>	{
			delUrlFmt => '/org/#param.org_id#/superbills?action=delete&superbillid=#0#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.superbills', [$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.superbills', [$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.superbills', [$page->session('org_internal_id')], 'panelTransp'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.superbills', [$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.insurancePlans' => {
	sqlStmt => qq{
			SELECT
				insurance.ins_internal_id,
				insurance.parent_ins_id,
				insurance.product_name,
				decode(insurance.record_type, 1, 'product', 2, 'plan', 3, 'coverage') as record_type,
				insurance.plan_name,
				insurance.ins_internal_id,
				insurance.owner_org_id,
				claim_type.caption,
				insurance.ins_type,
				insurance.indiv_deductible_amt,
				insurance.family_deductible_amt,
				insurance.percentage_pay,
				insurance.copay_amt,
				org.org_id
			FROM
				insurance,
				claim_type,
				org
			WHERE
				org.org_id = :1 AND
				org.owner_org_id = :2 AND
				insurance.record_type in (1, 2) AND
				insurance.ins_type = claim_type.id AND
				insurance.ins_org_id = org.org_internal_id
			ORDER BY
				insurance.product_name,
				insurance.plan_name
		},
	#sqlStmt => qq{
	#		select 	o.plan_name, o.group_number,
	#			o.group_name, o.ins_internal_id,
	#			decode(o.record_type, 0, 'ins-', 1, 'ins-', 2, 'ins-', 3, 'ins-', 4, 'ins-', 5, 'ins-')||o.record_type as test
	#		from 	insurance o, claim_type ct
	#		where	ct.id = o.ins_type
	#		and	o.ins_org_internal_id = ?
	#		and	o.record_type in (0,1,2,3,4,5)
	#		and	o.ins_type != 6
	#		UNION ALL
	#		select 	o.plan_name, o.product_name, o.ins_org_id, o.ins_org_internal_id, o.ins_internal_id, decode(o.record_type, 5, 'ins-')||o.record_type as test
	#		from 	insurance o, claim_type ct
	#		where	ct.id = o.ins_type
	#		and	o.ins_org_internal_id = ?
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
			{ colIdx => 0, head => 'Policy Name',dataFmt => '&{level_indent:0} #2#(#3#): #4#, #13# (#7#)' },
			#{ head => 'Plan', dataFmt => '#2# (#1#)' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=#homeArl#',
		frame => {
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
					caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-ins-product?_f_ins_org_id=#param.org_id#&home=#param.home#'>Insurance Product</A> },
					hints => "Insurance Plan offered to org's customers"
				},
				{
					caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-ins-plan?_f_ins_org_id=#param.org_id#&home=#param.home#'>Insurance Plan</A> },
					hints => "Insurance Plan offered to org's customers"
				},
				#{
				#	caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-ins-newplan?home=#homeArl#'>Insurance Plan</A> },
				#	hints => "Insurance Plan offered to org's customers"
				#},
				#{
				#	caption => qq{ Add <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-ins-workerscomp?home=#homeArl#'>Workers Compensation Plan</A> },
				#	hints => "Worker's Compensation Plan offered to org's customers"
				#},
				#{
				#	caption => qq{ Choose <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-attachinsurance?home=#homeArl#'>Insurance Plan</A> },
				#	hints => "Insurance Plan offered to org's employees"
				#},
				#{
				#	caption => qq{ Choose <A HREF='/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-attachworkerscomp?home=#homeArl#'>Workers Compensation Plan</A> },
				#	hints => "Worker's Compensation Plan offered to org's employees"
				#},
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-ins-#3#/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-ins-#3#/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans',  [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHierHtml($page, $flags, ['org.insurancePlans', 0, 1],  [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
	#publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.insurancePlans',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHierHtml($page, $flags, ['org.insurancePlans', 0, 1],  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
},

#----------------------------------------------------------------------------------------------------------------------

'org.healthMaintenanceRule' => {
	sqlStmt => qq{
			select  rule_id, start_age, end_age, diagnoses, measure, directions, src_begin_date, src_end_date
			from 	Hlth_Maint_Rule
			where 	org_internal_id =
			(select org_internal_id
				from org
				where owner_org_id = :2 AND
				org_id = :1
			)
		},
	sqlStmtBindParamDescr => ['Org ID for HealthMaintenanceRule'],
	publishDefn => {
		columnDefn => [
			{ head => 'Rule', dataFmt => '#0#: #3#, #4#, #5# (#6#, #7#)' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-health-rule/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-health-rule?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
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
				{ caption => qq{ Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-health-rule?home=#homeArl#'>Health Maintenance Rule</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-health-rule/#0#?home=#homeArl#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-health-rule/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule',  [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule',  [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.healthMaintenanceRule',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------------
'org.miscNotes' => {
	sqlStmt => qq{
			SELECT
				value_type,
				item_id,
				parent_id,
				item_name,
				value_text,
				value_textB,
				%simpleDate:value_date%,
				%simpleDate:value_dateB%
				from  Org_Attribute
			WHERE  	parent_id =
				(
					SELECT org_internal_id
					FROM org
					WHERE owner_org_id = :2 AND
					org_id = :1
				)
			AND item_name = 'Org Notes'

		},
		sqlStmtBindParamDescr => ['Org ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{ dataFmt => 'Org Notes #4#: #5# (#6#, #7#)' },
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-notes/#1#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-notes?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Org Notes' },
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
		frame => { heading => 'Org Notes' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-notes?home=#param.home#'>Org Notes</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-notes/#1#?home=#param.home#', delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-org-notes/#1#?home=#param.home#',
		},
	},

	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.miscNotes',  [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.miscNotes',  [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.miscNotes',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.miscNotes',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
},

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
'org.listAssociatedOrgs' => {
	sqlStmt => qq{

			SELECT
				org_id,
				name_primary,
				org_internal_id,
				DECODE (o.org_internal_id, (SELECT oo.parent_org_id from org oo
					WHERE oo.org_id = :1 AND owner_org_id = :2), 'Parent Org', 'Child Org')
			FROM  	Org o
			WHERE  	org_internal_id =
				(
					SELECT parent_org_id
					FROM org
					WHERE owner_org_id = :2 AND
					org_id = :1
				)
			OR
				parent_org_id =
				(
					SELECT org_internal_id
					FROM org
					WHERE owner_org_id = :2 AND
					org_id = :1
				)
			AND rownum <= $LIMIT
			ORDER BY org_id

		},
		sqlStmtBindParamDescr => ['Org ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
			{
				colIdx => 3,
				dataFmt => {
					'Parent Org' => "#1# (<A HREF = '/org/#0#/profile'>#0#</A>, #3#)",
					'Child Org' => "#1# (<A HREF = '/org/#0#/profile'>#0#</A>, #3#)",
				},
			},

		],
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Parent And Child Orgs' },
	},
	publishDefn_panelTransp =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel.transparent',
		inherit => 'panel',
	},

	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.listAssociatedOrgs',  [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.listAssociatedOrgs',  [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.listAssociatedOrgs',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.listAssociatedOrgs',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
'org.billingEvents' => {
	sqlStmt => qq{
		SELECT
			item_id,
			value_int AS day,
			value_text AS name_begin,
			value_textb AS name_end,
			value_intb AS balance_condition,
			value_float AS balance_criteria
		FROM
			org_attribute
		WHERE
			parent_id = (SELECT org_internal_id FROM org WHERE owner_org_id = :2 AND org_id = :1) AND
			value_type = @{[ App::Universal::ATTRTYPE_BILLINGEVENT ]}
		ORDER BY
			day
	},
	sqlStmtBindParamDescr => ['Org ID for Attribute Table', 'Session Org Internal Id'],
	publishDefn =>
	{
		columnDefn => [
			{colIdx => 1, dataFmt => '<b>Day #1#</b>'},
			{
				colIdx => 2,
				dataFmt => "Name From '#2#' to '#3#'",
			},
			{
				colIdx => 4,
				dataFmt => {
					'1' => 'Balance > $#5#',
					'-1' => 'Balance < $#5#',
				},
			},
		],
		bullets => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-billing-event/#0#?home=#homeArl#',
		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-billing-event?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},
	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Billing Events' },
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
		inherit => 'panel',
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-org-billing-event?home=#param.home#'>Billing Event</A> } },
			],
		},
		stdIcons =>	{
			updUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-update-org-billing-event/#0#?home=#homeArl#',
			delUrlFmt => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-remove-org-billing-event/#0#?home=#homeArl#',
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billingEvents',  [$page->param('org_id'),$page->session('org_internal_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billingEvents',  [$page->param('org_id'),$page->session('org_internal_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billingEvents',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_internal_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.billingEvents',  [$page->param('org_id'),$page->session('org_internal_id')], 'panelTransp'); },
},
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
'org.closingDateInfo' => {
	sqlStmt => qq{
			SELECT
				o.org_id,
				a.value_date,
				DECODE (o.org_id, :1, 'Parent Org', 'Child Org') as parent_child,
				oc.member_name
			FROM  	org o, org_attribute a, org_category oc
			WHERE  	a.parent_id = o.org_internal_id

			AND     a.item_name = 'Retire Batch Date'

			AND	EXISTS
			(
			SELECT o1.org_id
			FROM org o1
			WHERE o1.org_id = :1
			AND   ( o1.org_internal_id = o.parent_org_id OR o1.org_internal_id = o.owner_org_id OR o1.org_internal_id = o.org_internal_id )
			)
			AND o.org_internal_id = oc.parent_id
			AND     UPPER(LTRIM(RTRIM(oc.member_name))) IN
			('CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE','DIAGNOSTIC SERVICES', 'DEPARTMENT', 'THERAPEUTIC SERVICES')

			ORDER BY parent_child DESC, o.org_id
		},
		sqlStmtBindParamDescr => ['Org ID for Attribute Table'],

	publishDefn =>
	{
		columnDefn => [
				{
					colIdx => 2,
					dataFmt => {
						'Parent Org' => "<A HREF = '/org/#0#/profile'>#0#</A> (Parent Org, #3#): #1#",
						'Child Org' => "<A HREF = '/org/#0#/profile'>#0#</A> (Child Org, #3#): #1#",
					},
				},

		],

		frame => {
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-close-date?home=#homeArl#',
			editUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
		},
	},

	publishDefn_panel =>
	{
		# automatically inherits columnDefn and other items from publishDefn
		style => 'panel',
		frame => { heading => 'Closing Date Information' },
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
		frame => { heading => 'Closing Date Information' },
		banner => {
			actionRows =>
			[
				{ caption => qq{ Add <A HREF= '/org/#param.org_id#/stpe-#my.stmtId#/dlg-add-close-date?home=#param.home#'>Closing Date Information</A> } },
			],
		},
	},
	publishComp_st => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.closingDateInfo',  [$page->param('org_id')]); },
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.closingDateInfo',  [$page->param('org_id')], 'panel'); },
	publishComp_stpe => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.closingDateInfo',  [$page->param('org_id')], 'panelEdit'); },
	publishComp_stpt => sub { my ($page, $flags, $orgId) = @_; $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.closingDateInfo',  [$page->param('org_id')], 'panelTransp'); },
},
#------------------------------------------------------------------------------------------------------------------------
'org.LabTestSummary' => {
	sqlStmt => qq{
				SELECT('Labs'),
				count (oce.entry_id),
				300,internal_catalog_id,oce.entry_type
				FROM offering_catalog oc,org o,
				offering_catalog_entry oce
				WHERE o.owner_org_id = :2
				AND	o.org_id = :1
				AND	o.org_internal_id = oc.org_internal_id
				AND	oce.entry_type (+)= 300
				AND	oce.catalog_id(+)=oc.internal_catalog_id
				AND	parent_entry_id is null
				AND	oc.catalog_type =5
				GROUP BY internal_catalog_id,oce.entry_type
				union
				SELECT ('Radiology'),
				count (oce.entry_id),
				310,internal_catalog_id,oce.entry_type
				FROM offering_catalog oc,org o,
				offering_catalog_entry oce
				WHERE o.owner_org_id = :2
				AND	o.org_id = :1
				AND	o.org_internal_id = oc.org_internal_id
				AND	oce.entry_type (+)= 310
				AND	oce.catalog_id(+)=oc.internal_catalog_id
				AND	parent_entry_id is null
				AND	oc.catalog_type =5
				GROUP BY internal_catalog_id	,oce.entry_type
				union				
				SELECT 'Other',
				count (oce.entry_id),
				999,internal_catalog_id,oce.entry_type
				FROM offering_catalog oc,org o,
				offering_catalog_entry oce
				WHERE o.owner_org_id = :2
				AND	o.org_id = :1
				AND	o.org_internal_id = oc.org_internal_id
				AND	oce.entry_type (+)= 999
				AND	oce.catalog_id(+)=oc.internal_catalog_id
				AND	parent_entry_id is null
				AND	oc.catalog_type =5
				GROUP BY internal_catalog_id	,oce.entry_type
			},
	sqlvar_entityName => 'OrgInternal ID for LAB',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn => {
				#bullets => '/org/#param.org_id#/dlg-update-contract/#6#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0, hAlign=>'left',  head => 'Test Type', url=>qq{/org/#param.org_id#/catalog?catalog=labtest_detail&labtest_detail=#4#&id=#3#}},
				{colIdx => 1,hAlign=>'left', head => 'Entries',tDataFmt => '&{sum:1} Entries', },
				{head=>'Action' ,dataFmt=>'Add', url=>'/org/#param.org_id#/dlg-add-lab-test/#3#?lab_type=#2#&home=#homeArl#'},
				],
			banner =>
			{
				actionRows =>
				[
				#{caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-contract?home=#homeArl#'>Lab </A> }},	
				 #{caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-contract?home=#homeArl#'>X-Ray </A> }},				
				 #{caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-contract?home=#homeArl#'>Other </A> }},								 
				],
				contentColor=>'#EEEEEE',
			},


			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		contentColor=>'#EEEEEE',
		frame => {
			heading => 'Lab Tests',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.LabTestSummary', [$orgId,$page->session('org_internal_id')], 'panel'); },
},
#-----------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------------------
'org.LabTestDetail' => {
	sqlStmt => qq{
				SELECT  oce.code,
					oce.name,
					oce.modifier,
					oce.entry_id,
					oce.catalog_id,
					oce.entry_type,
					oce.unit_cost,
					oce.data_num
				FROM 	offering_catalog oc,org o,
					offering_catalog_entry oce
				WHERE 	o.owner_org_id = :2
				AND	o.org_id = :1
				AND	o.org_internal_id = oc.org_internal_id
				AND	oce.entry_type = :3
				AND	oce.catalog_id=oc.internal_catalog_id
				AND	parent_entry_id is null
		},
	sqlvar_entityName => 'OrgInternal ID for LAB',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn => {
				#bullets => '/org/#param.org_id#/dlg-update-contract/#6#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0, tDataFmt => '&{count:0} Tests',hAlign=>'left', head => 'Test ID'},
				{colIdx => 1, hAlign=>'left', head => 'Test Name'},				
				{colIdx => 2, hAlign=>'left', head => 'Selection'},					
				{colIdx => 6, hAlign=>'left', head => 'Physician Cost',dformat=>'currency'},								
				{colIdx => 7, hAlign=>'left', head => 'Patient Cost',dformat=>'currency'},												
				{colIdx => 3,hAlign=>'left',head=>'Actions',
						dataFmt => q{<A HREF="/org/#param.org_id#/dlg-update-lab-test/#3#"
					TITLE='Modify Lab Test'>
					<img src="/resources/icons/black_m.gif" BORDER=0></A>
					<A HREF="/org/#param.org_id#/dlg-remove-lab-test/#3#"
										TITLE='Delete Lab Test'>
					<img src="/resources/icons/black_d.gif" BORDER=0></A> },
				},				
				],
			banner =>
			{
				actionRows =>
				[
				{caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-lab-test/#param.id#?home=#homeArl#'>Test</A> }},	
				],
				contentColor=>'#EEEEEE',
			},


			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		contentColor=>'#EEEEEE',
		frame => {
			heading =>"#param.caption# Tests",
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id');  
			#get Caption from catalog_entry_type
			my $caption = $STMTMGR_CATALOG->getSingleValue($page,STMTMGRFLAG_NONE,'selCatalogEntryTypeCapById',$page->param('labtest_detail')||undef);
			$page->param('caption',$caption);
			$STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.LabTestDetail', [$orgId,$page->session('org_internal_id'),$page->param('labtest_detail')||undef], 'panel'); },
},
#------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------
'org.AllLabOrder' => {
	sqlStmt => qq{
			Select	org_id,primary_name,org_internal_id
			FROM	org ,ORG_CATEGORY oc
			WHERE  	owner_org_id= :1 
			AND	oc.parent_id = org.org_internal_id
			AND	oc.member_name='Lab'			
			order by org_id
			},
	sqlvar_entityName => 'OrgInternal ID for LAB',
	sqlStmtBindParamDescr => ['Org Internal ID'],
	publishDefn => {
				#bullets => '/org/#param.org_id#/dlg-update-contract/#6#?home=#homeArl#',
				columnDefn =>
				[
				{colIdx => 0, hAlign=>'left', head => 'Lab ID'},
				{colIdx => 1, hAlign=>'left', head => 'Lab Name'},				
				{colIdx => 3,hAlign=>'left',head=>'Actions',
						dataFmt => q{<A HREF="/org/#param.org_id#/dlg-add-lab-order/#3#"
					TITLE='Modify Lab Test'>
					<img src="/resources/icons/black_m.gif" BORDER=0></A>},				
				}
				],
			banner =>
			{
				actionRows =>
				[
				{caption => qq{ Add <A HREF='/org/#param.org_id#/dlg-add-lab-test?home=#homeArl#'>Test</A> }},	
				],
				contentColor=>'#EEEEEE',
			},


			},
	publishDefn_panel =>
	{
		# automatically inherites columnDefn and other items from publishDefn
		style => 'panel.transparent.static',
		contentColor=>'#EEEEEE',
		frame => {
			heading => 'Lab Tests',
			addUrl => '/org/#param.org_id#/stpe-#my.stmtId#?home=#homeArl#',
			},
	},
	publishComp_stp => sub { my ($page, $flags, $orgId) = @_; $orgId ||= $page->param('org_id'); $STMTMGR_COMPONENT_ORG->createHtml($page, $flags, 'org.AllLabOrder', [$orgId,$page->session('org_internal_id')], 'panel'); },
},
#------------------------------------------------------------------------------------------------------------------------

),

1;
