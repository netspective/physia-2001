##############################################################################
package App::Statements::Catalog;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_CATALOG);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CATALOG);

my $SEL_CATALOG_ENTRY = qq{
	select * from Offering_Catalog_Entry
	where code = upper(?)
		%modifierWhereClause%
		and entry_type = ?
		and catalog_id = ?
};

$STMTMGR_CATALOG = new App::Statements::Catalog(
	'selInternalIdByCatalog' => qq
	{
		SELECT internal_catalog_id
		FROM offering_catalog
		WHERE catalog_id = ?
	},
	'selFeeScheduleEntryTypes'=>qq
	{
		SELECT id,caption
		FROM catalog_entry_type
		WHERE ID NOT IN (80,110,120,150,160,200)
	},	
	'selMiscProcChildren' => qq
	{
		SELECT 	oce2.code, oce2.modifier
		FROM 	offering_catalog oc, offering_catalog_entry oce, offering_catalog_entry oce2
		WHERE 	oc.org_internal_id = ?
		AND	oc.catalog_type = 2
		AND	oce.catalog_id = oc.internal_catalog_id
		AND	oce.entry_id = oce2.parent_entry_id
		AND	oce.code = upper(?)
	},
	'selOrgIdLinkedFS' =>qq
	{
		SELECT  org_id
		FROM	org o, org_attribute oa, offering_catalog oc
		WHERE 	o.org_internal_id = oa.parent_id 
		AND	oc.internal_catalog_id= oa.value_int
		AND	oa.item_name = 'Fee Schedule'
		AND	oc.internal_catalog_id = :1
	},
	'selPersonIdLinkedFS' =>qq
	{
		SELECT  parent_id as person_id
		FROM	person_attribute pa, offering_catalog oc
		WHERE 	oc.internal_catalog_id= pa.value_int
		AND	pa.item_name = 'Fee Schedule'
		AND	oc.internal_catalog_id = :1
	},
	'selFSLinkedProductPlan' =>qq
	{
		SELECT  distinct oc.internal_catalog_id as internal_catalog_id, catalog_id
		FROM	insurance_attribute ia, offering_catalog oc
		WHERE 	oc.internal_catalog_id= ia.value_text
		AND	ia.item_name = 'Fee Schedule'
		AND	ia.parent_id in (:1,:2)	
	},
	'selInternalCatalogIdById' => qq
	{
		select * from Offering_catalog
		where org_internal_id = ?
		and upper(catalog_id) = (?)
	},
	'selPlanAllowedByProdAndCode' => qq
	{
		select ocp.allowed_cost
		from Offering_Catalog_Entry oce, Offering_CatEntry_Price ocp, Contract_Catalog cc
		where cc.internal_contract_id = ocp.internal_contract_id
		and ocp.entry_id = oce.entry_id
		and cc.product_ins_id = ?
		and cc.org_internal_id = ?
		and oce.code = ?		
	},
	'selInternalCatalogIdByIdType' => qq
	{
		select * from Offering_catalog
		where org_internal_id = ?
		and upper(catalog_id) = (?)
		and catalog_type = ?
	},	
	'selCatalogById' => qq{
		select *
		from offering_catalog
		where internal_catalog_id = ?
	},
	'sel_internalCatId_orgId' => qq{
		SELECT *
		FROM Offering_Catalog
		WHERE
			internal_catalog_id = ?
			AND org_internal_id = ?
	},
	'sel_internalCatId_orgId_type' => qq{
		SELECT 	*
		FROM 	Offering_Catalog
		WHERE 	internal_catalog_id = :1
		AND 	org_internal_id = :2
		AND	catalog_type = :3
	},	
	'sel_catalog_by_id_orgId' => qq{
		select * from Offering_catalog
		where catalog_id = ?
			and org_internal_id = ?
	},
	'selParentCatalogByOrgId' => q{
		select *
		from offering_catalog
		where org_internal_id = ?
			and parent_catalog_id is NULL
	},
	'selChildrenCatalogs' => q{
		select *
		from offering_catalog
		where parent_catalog_id = ?
	},
	'selCPTCatalogItems' => q{
		select *
		from offering_catalog_entry
		where catalog_id = ?
			and entry_type in (?,?)
	},
	'selCatalogItemsByParentItem' => q{
		select *
		from offering_catalog_entry
		where parent_entry_id = ?
	},
	'selCatalogItemsByCodeAndType' => q{
		select *
		from offering_catalog_entry
		where code = upper(?)
			and entry_type = ?
	},
	'selCatalogItemByRange' => q{
		SELECT entry_id
		FROM OFFERING_CATALOG_ENTRY
		WHERE code BETWEEN (:1) 
		AND (:2) 
		AND catalog_id = :3
		AND modifier IS NULL
	},
	'selMiscProcedureBySessionOrgAndCode' => qq
	{
		SELECT 	oce.entry_id, oce.catalog_id, oce.code, oce.modifier, oce.name, oce.default_units,
				oce.unit_cost, oce.description, oce.taxable
		FROM 	offering_catalog oc , offering_catalog_entry oce
		WHERE	oce.code = ?
		AND	oc.org_internal_id = ?
		AND	oce.catalog_id = oc.internal_catalog_id
		AND	oc.catalog_type = 2
	},
	'selCatalogItemsByOrgIdAndCode' => q{
		select oce.catalog_id, oce.parent_entry_id, oce.entry_type, oce.code, oce.modifier, oce.default_units,
				oce.unit_cost, oce.taxable
		from offering_catalog oc, offering_catalog_entry oce
		where oc.org_internal_id = ?
			and oc.catalog_id = oce.catalog_id
			and oce.cost_type != 0
			and oce.entry_type in (0,100)
			and oce.status = 1
			and oce.code = upper(?)
	},
	'selCatalogItemsByIdandType' => q{
		select *
		from offering_catalog_entry
		where catalog_id = ?
			and entry_type = ?
	},
	'selCatalogItemById' => q{
		select *
		from offering_catalog_entry
		where entry_id = ?
	},
	'selCatalogItemNameById' => q{
			select oce.flags,oce.units_avail,oce.entry_type, oce.name, oce.description,
						oce.unit_cost, oce.data_text,
						oc.catalog_id as catalog_id,oce.code,oce.modifier,oc.caption,
						oc.internal_catalog_id
						from offering_catalog oc, offering_catalog_entry oce
						where oce.entry_id = ?
			and oc.internal_catalog_id = oce.catalog_id
	},

	#---ACS Service Type Queries
	'selCodeByOrgIdCode'=>q{
				SELECT 	oce.code,oce.catalog_id
				FROM	offering_catalog_entry oce, offering_catalog oc
				WHERE 	upper(oce.code)= upper(:1)
				AND	oc.internal_catalog_id = :2
				AND	oce.catalog_id = oc.internal_catalog_id
				},
	'sel1CatalogByOrgIDType'=>q{
			SELECT	oc.internal_catalog_id
			FROM 	offering_catalog oc, org_attribute oa
			WHERE 	oa.parent_id = :1
			AND	oc.catalog_type = :2
			AND  	oa.item_name = 'Fee Schedule'
			AND   	oa.value_int = oc.internal_catalog_id	
			AND ROWNUM <2
		},
	#----CPT QUERIES

	'selGenericCPT_LikeCode' => q{
		select cpt, name, description
		from ref_cpt
		where cpt like upper(?)
	},
	'selGenericCPT_LikeText' => q{
		select cpt, name, description
		from ref_cpt
		where (name like ? or description like ?)
	},
	'selGenericCPTCode' => q{
		select cpt, name, description
		from ref_cpt
		where cpt = upper(?)
	},


	#----HCPCS QUERIES

	'selGenericHCPCS_LikeCode' => q{
		select hcpcs, name, description
		from ref_hcpcs
		where hcpcs like upper(?)
	},
	'selGenericHCPCS_LikeText' => q{
		select hcpcs, name, description
		from ref_hcpcs
		where (name like ? or description like ?)
	},
	'selGenericHCPCSCode' => q{
		select hcpcs, name, description
		from ref_hcpcs
		where hcpcs = upper(?)
	},


	#----EPSDT QUERIES

	'selGenericEPSDT_LikeCode' => q{
		select epsdt, name, description
		from ref_epsdt
		where epsdt like upper(?)
	},
	'selGenericEPSDT_LikeText' => q{
		select epsdt, name, description
		from ref_epsdt
		where (name like ? or description like ?)
	},
	'selGenericEPSDTCode' => q{
		select epsdt, name, description
		from ref_epsdt
		where epsdt = upper(?)
	},


	#----ICD QUERIES

	'selGenericICD_LikeCode' => q{
		select icd, descr
		from ref_icd
		where icd like upper(?)
	},
	'selGenericICD_LikeText' => q{
		select icd, descr
		from ref_icd
		where (descr like ?)
	},
	'selGenericICDCode' => q{
		select icd, descr
		from ref_icd
		where icd = upper(?)
	},


	#----MODIFIER QUERIES

	'selGenericModifier' => q{
		select caption
		from HCFA1500_Modifier_Code
		where abbrev = ?
	},
	'selGenericModifierCodeId' => q{
		select id
		from HCFA1500_Modifier_Code
		where abbrev = ?
	},
	'selModifierCode' => q{
		select caption
			from HCFA1500_Modifier_Code
			where id = ?
	},


	#----SERVICE PLACE QUERIES

	'selAllServicePlaceId' => q{
		select id
		from HCFA1500_Service_Place_Code
	},
	'selGenericServicePlaceId' => q{
		select id
		from HCFA1500_Service_Place_Code
		where id = ?
	},
	'selGenericServicePlaceById' => q{
		select abbrev
		from HCFA1500_Service_Place_Code
		where id = ?
	},
	'selGenericServicePlaceByAbbr' => q{
		select id
		from HCFA1500_Service_Place_Code
		where abbrev = ?
	},
	'selGenericServicePlace' => q{
		select caption
		from HCFA1500_Service_Place_Code
		where abbrev = ?
	},


	#----SERVICE TYPE QUERIES

	'selAllServiceTypeId' => q{
		select id
		from HCFA1500_Service_Type_Code
	},
	'selGenericServiceTypeId' => q{
		select id
		from HCFA1500_Service_Type_Code
		where id = ?
	},
	'selGenericServiceTypeById' => q{
		select abbrev
		from HCFA1500_Service_Type_Code
		where id = ?
	},
	'selGenericServiceTypeByAbbr' => q{
		select id
		from HCFA1500_Service_Type_Code
		where abbrev = ?
	},
	'selGenericServiceType' => q{
		select caption
		from HCFA1500_Service_Type_Code
		where abbrev = ?
	},


	#----OTHER QUERIES

	'selCatalogEntryTypeCapById' => q{
		select caption
			from catalog_entry_type
			where id = ?
	},
	'selCatalogItemByNameByType' => q{
		select name, entry_type, ct.caption, code, modifier
			from offering_catalog_entry c, catalog_entry_type ct
			where c.entry_type = ct.id
				and entry_type between 100 and 199
				and status = 1
			order by name, entry_type
	},
	'selCatalogItemByType' => q{
		select typ.caption, code, modifier, name, unit_cost, description, status,
			entry_id, entry_type
		from offering_catalog_entry c, catalog_entry_type typ
		where c.entry_type = ct.id
			and entry_type between 100 and 199
			and status = 1
		order by typ.caption, parent_entry_id, code, modifier, name, unit_cost
	},

	'selTop15CPTsByORG' => q{
		select distinct(parent_id), read_count
		from REF_CPT_Usage
		where org_internal_id = ?
		and parent_id is not null
		and rownum < 16
		order by read_count desc
	},
	'selTop15ICDsByORG' => q{
		select distinct(parent_id), read_count
		from REF_ICD_Usage
		where org_internal_id = ?
		and parent_id is not null
		and rownum < 16
		order by read_count desc
	},
	'selTop15CPTsByPerson' => q{
		select distinct(parent_id), read_count
		from REF_CPT_Usage
		where person_id = ?
		and parent_id is not null
		and rownum < 16
		order by read_count desc
	},
	'selTop15ICDsByPerson' => q{
		select distinct(parent_id), read_count
		from REF_ICD_Usage
		where person_id = ?
		and parent_id is not null
		and rownum < 16
		order by read_count desc
	},

	'sel_catalogEntry_by_catalogTypeCodeModifier' => {
		sqlStmt => $SEL_CATALOG_ENTRY,
		modifierWhereClause => 'and modifier = ?',
	},

	'sel_catalogEntry_by_catalogTypeCode' => {
		sqlStmt => $SEL_CATALOG_ENTRY,
		modifierWhereClause => 'and modifier is null',
	},

	'sel_Catalog_Attribute' => qq{
		select * from OfCatalog_Attribute
		where parent_id = ?
			and value_type = ?
			and item_name = ?
	},
	'sel_catalogEntry_by_code_modifier_catalog' => qq{
		select * from Offering_Catalog_Entry
		where code = upper(?)
			and (modifier = ? or modifier is NULL)
			and catalog_id = ?
	},
	'sel_catalogEntry_by_code_catalog' => qq{
		select * from Offering_Catalog_Entry
		where code = upper(?)
			and modifier is NULL
			and catalog_id = ?
	},

	'sel_catalogEntry_svcType_by_catalog' => qq{
			select oc.INTERNAL_CATALOG_ID ,entry_type,oc.catalog_id,data_text,h.caption
			from Offering_Catalog_Entry oce, HCFA1500_Service_Type_Code h,
			Offering_Catalog oc
			where oce.code = upper(?)
			and oce.modifier is NULL
			and oce.catalog_id = ?
			and oce.data_text (+) = h.abbrev
			and oc.internal_catalog_id = oce.catalog_id
	},
	'sel_catalogEntry_svcType_by_code_modifier_catalog' => qq{
				select oc.INTERNAL_CATALOG_ID,entry_type,oc.catalog_id,data_text,h.caption
				from Offering_Catalog_Entry oce, HCFA1500_Service_Type_Code h,
				Offering_Catalog oc
				where oce.code = upper(?)
				and (modifier = ? or modifier is NULL)
				and oce.catalog_id = ?
				and oce.data_text (+) = h.abbrev
				and oc.internal_catalog_id = oce.catalog_id
	},
	
	
	'sel_ProcedureInfoByCodeMod'=> qq
	{
		SELECT 	oc.internal_catalog_id,
			oce.entry_type,
			oc.catalog_id,
			oce.data_text,
			h.caption,
			oce.unit_cost,
			oce.flags		
		FROM	Offering_Catalog_Entry oce, HCFA1500_Service_Type_Code h,
			Offering_Catalog oc
		WHERE	oce.code = upper(:1)
		AND	(modifier = :2 or :2 is NULL)
		AND	oce.catalog_id = :3
		AND	oce.data_text  = h.abbrev (+)
		AND	oc.internal_catalog_id = oce.catalog_id
	},
	'selProcedureInfoByCodeModDate'=> qq
	{
		SELECT 	oc.internal_catalog_id,
			oce.entry_type,
			oc.catalog_id,
			oce.data_text,
			h.caption,
			oce.unit_cost,
			oce.flags		
		FROM	Offering_Catalog_Entry oce, HCFA1500_Service_Type_Code h,
			Offering_Catalog oc
		WHERE	oce.code = upper(:1)
		AND	(modifier = :2 or :2 is NULL)
		AND	oce.catalog_id = :3
		AND	(oc.effective_begin_date <= to_date(:4,'$SQLSTMT_DEFAULTDATEFORMAT') or oc.effective_begin_date is NULL)
		AND 	(oc.effective_end_date >= to_date(:4,'$SQLSTMT_DEFAULTDATEFORMAT') or oc.effective_end_date is NULL)
		AND	oce.data_text  = h.abbrev (+)
		AND	oc.internal_catalog_id = oce.catalog_id
	},
	
	#- DELETE Assoicated FS FOR Orgs and Phyisicians
	'delOrgIdLinkedFS' =>qq
	{
		DELETE
		FROM	org_attribute 
		WHERE 	value_int = :1
		AND	item_name = 'Fee Schedule'

	},
	'delPersonIdLinkedFS' =>qq
	{
		DELETE
		FROM	person_attribute 
		WHERE 	value_int = :1
		AND	item_name = 'Fee Schedule'
	},	
	
	#
	#SQL FOR MISC PROCEDURE
	'selMiscProcedureById' =>qq{
		SELECT	entry_id,entry_type,code,modifier,name,description, 1 as code_level,parent_entry_id
		FROM 	offering_catalog_entry oce
		WHERE	oce.entry_id= :1
		UNION
		SELECT	entry_id,entry_type,code,modifier,name,description, 2 as code_level,parent_entry_id
		FROM	offering_catalog_entry oce
		WHERE	rownum < 7
		AND	parent_entry_id IN
		(SELECT	entry_id as code_level 
		 FROM 	offering_catalog_entry oce
		 WHERE	oce.entry_id= :1
		)						
	},			
	'selMiscProcedureByChildId' =>qq{
		SELECT	entry_id,entry_type,code,modifier,name,description, 1 as code_level,parent_entry_id,catalog_id
		FROM 	offering_catalog_entry oce
		WHERE	oce.entry_id= :1
		UNION
		SELECT	entry_id,entry_type,code,modifier,name,description, 2 as code_level,parent_entry_id,catalog_id
		FROM	offering_catalog_entry oce
		WHERE	rownum <5
		AND	parent_entry_id IN
		(SELECT	entry_id as code_level 
		 FROM 	offering_catalog_entry oce
		 WHERE	oce.entry_id= :1
		)						
	},		
	'selMiscProcedureInternalID' =>qq
	{
		SELECT	internal_catalog_id
		FROM	Offering_Catalog 
		WHERE 	caption = 'Misc Procedure Code'
		AND	catalog_type  = 2
		AND 	org_internal_id = :1
	},
	'selMiscProcedureNameById' => qq
	{
		SELECT	code as proc_code, modifier, name, description,catalog_id
		FROM	Offering_Catalog_Entry
		WHERE 	entry_id = :1
	
	},
	'selMiscProcedureByCode' => qq
	{
		SELECT 	oce.entry_id
		FROM 	offering_catalog oc , offering_catalog_entry oce
		WHERE	oce.code = :1
		AND	oc.org_internal_id = :2
		AND	oce.catalog_id = oc.internal_catalog_id
		AND	oc.catalog_type = 2
	},

	'selMiscProcedureByChildId' =>qq
	{
		SELECT 	oce.entry_id as entry_id,
			oce.code , 
			oce.modifier,
			oce.catalog_id, 
			oce.parent_entry_id, 
			oce2.name, 
			oce2.code as proc_code, 
			oce2.description
		FROM 	offering_catalog_entry oce , offering_catalog_entry oce2
		WHERE	oce.entry_id= :1
		AND	oce2.entry_id = oce.parent_entry_id
	},

	'selFindDescByCode' =>qq
	{
		SELECT 	   NVL(NVL((
			       NVL((SELECT description FROM Ref_HCPCS WHERE UPPER(hcpcs) = UPPER(:1)),
			       	   (SELECT description FROM Ref_CPT WHERE UPPER(cpt) = UPPER(:1))
			       	   )),
		       		(SELECT 	oce.entry_id
		       		FROM 	offering_catalog oc , offering_catalog_entry oce
		       		WHERE	UPPER(oce.code) = UPPER(:1)
		       		AND	oc.org_internal_id = :2
		       		AND	oce.catalog_id = oc.internal_catalog_id
				AND	oc.catalog_type = 2)
				),NULL)	as  description       
				
		FROM DUAL
	},
	
);

1;
