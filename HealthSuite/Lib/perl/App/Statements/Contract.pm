##############################################################################
package App::Statements::Contract;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_CONTRACT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CONTRACT);



$STMTMGR_CONTRACT = new App::Statements::Contract(
	'selContractByID' => qq
	{
		SELECT *
		FROM contract_catalog
		WHERE internal_contract_id = :1
	},	
	'selContractByNameOrg' =>qq
	{
		SELECT *
		FROM contract_catalog
		WHERE contract_id = :1	
		AND	org_internal_id = :2
	},
	'selContractPriceByEntryContractID'=>qq
	{
		SELECT 	cc.contract_id,
			cc.internal_contract_id,
			cc.caption,
			oce.code,
			oce.modifier
		FROM	Offering_catalog_entry oce,
			Contract_Catalog cc
		WHERE	cc.internal_contract_id = :1	
		AND	cc.parent_catalog_id = oce.catalog_id
		AND	oce.entry_id = :2									
	},
	'selContractPriceByPriceID'=>qq
	{
		SELECT 	cc.contract_id,
			cc.internal_contract_id,
			cc.caption,
			oce.code,
			oce.modifier,
			ocp.expected_cost,
			ocp.allowed_cost,
			oce.entry_id			
		FROM	Offering_catalog_entry oce,
			Contract_Catalog cc,
			Offering_CatEntry_Price ocp
		WHERE	cc.internal_contract_id = ocp.internal_contract_id 	
		AND	cc.parent_catalog_id = oce.catalog_id
		AND	oce.entry_id = ocp.entry_id  
		AND	ocp.price_id = :1
	},
	'selContractPriceByPrEntryContractID'=>qq
	{
			SELECT 	cc.contract_id,
				cc.internal_contract_id
			FROM	Offering_CatEntry_Price ocp,
				Contract_Catalog cc
			WHERE	cc.internal_contract_id = :1	
			AND	ocp.internal_contract_id = :1
			AND	ocp.entry_id = :2									
	},
	'selContractMatch'=>qq
	{
		SELECT 	contract_id,
			internal_contract_id
		FROM	Contract_Catalog
		WHERE 	org_internal_id = :1
		AND	parent_catalog_id = :2
		AND	product_ins_id = :3			
			
	},
);

1;
