##############################################################################
package App::Statements::Catalog;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

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
		SELECT org_internal_id
		FROM offering_catalog
		WHERE catalog_id = ?
	},
	'selInternalCatalogIdById' => qq
	{
		select * from Offering_catalog
		where org_internal_id = ?
		and catalog_id = ?
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
						oc.catalog_id as catalog_id,oce.code,oce.modifier
						from offering_catalog oc, offering_catalog_entry oce
						where oce.entry_id = ?
			and oc.internal_catalog_id = oce.catalog_id
	},
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
	'selGenericModifier' => q{
		select caption
		from HCFA1500_Modifier_Code
		where id = ?
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
	'selGenericModifierCodeId' => q{
		select id
		from HCFA1500_Modifier_Code
		where id = ?
	},
	'selModifierCode' => q{
		select caption
			from HCFA1500_Modifier_Code
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
	'selAllServicePlaceId' => q{
		select id
		from HCFA1500_Service_Place_Code
	},
	'selAllServiceTypeId' => q{
		select id
		from HCFA1500_Service_Type_Code
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
);

1;
