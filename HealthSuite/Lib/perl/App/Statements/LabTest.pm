##############################################################################
package App::Statements::LabTest;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_LAB_TEST);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_LAB_TEST);



$STMTMGR_LAB_TEST = new App::Statements::LabTest(
	'selLabTestByID' => qq
	{
		SELECT *
		FROM lab_test
		WHERE lab_test_id= :1
	},	
	'selLabTestPanelByID'=>qq
	{
		SELECT *
		FROM lab_test_panel
		WHERE parent_id= :1
	},
	'selTestType'=>qq
	{
		SELECT id,caption
		FROM catalog_entry_type
		WHERE id IN (300,310,999)
	},
	'countXray'=>qq
	{
		SELECT 	Count (*)
		FROM	Lab_Order_Entry loe,offering_catalog_entry oce
		WHERE	loe.parent_id= :1
		AND	oce.entry_type = 310
		AND	oce.entry_id = loe.test_entry_id
	},
	'selXrayOrder'=>qq
	{
			SELECT 	oce.entry_id, oce.entry_type,loe.options,
				oce.name,loe.entry_id as lab_entry_id,
				loe.test_entry_id
			FROM	Lab_Order_Entry loe,offering_catalog_entry oce
			WHERE	loe.parent_id= :1
			AND	oce.entry_type = 310
			AND	oce.entry_id = loe.test_entry_id
	},
	
	'selLabEntryOptions'=>qq
	{
		SELECT *
		FROM	Lab_Order_Entry_Options
		WHERE	parent_id = :1
	},
	'delPanelById'=>qq
	{
		DELETE 
		FROM lab_test_panel
		WHERE parent_id = :1
	},
	'sel_available_labs'=>qq
	{
		SELECT 	oce.entry_id,oce.name
		FROM 	offering_catalog oc, offering_catalog_entry oce			
		WHERE 	oc.org_internal_id= :1
		AND	oc.internal_catalog_id = oce.catalog_id
		AND	oce.entry_type =300
		AND	oce.parent_entry_id is NULL		
	},
	'sel_available_xray'=>qq
	{
		SELECT 	oce.entry_id,oce.name
		FROM 	offering_catalog oc, offering_catalog_entry oce			
		WHERE 	oc.org_internal_id= :1
		AND	oc.internal_catalog_id = oce.catalog_id
		AND	oce.entry_type =310
		AND	oce.parent_entry_id is NULL		
	},
	'sel_available_other'=>qq
	{
		SELECT 	oce.entry_id,oce.name
		FROM 	offering_catalog oc, offering_catalog_entry oce			
		WHERE 	oc.org_internal_id= :1
		AND	oc.internal_catalog_id = oce.catalog_id
		AND	oce.entry_type =999
		AND	oce.parent_entry_id is NULL
	},
	'selLabOrderByID'=>qq
	{
		SELECT 	l.*, o.org_id ,o.name_primary
		FROM 	person_lab_order l, org o
		WHERE 	lab_order_id = :1
		AND	l.lab_internal_id = o.org_internal_id
	},
	'selTestEntryByParentId'=>qq
	{
		SELECT	oce.*
		FROM	lab_order_entry loa,offering_catalog_entry oce
		WHERE 	loa.parent_id = :1
		AND	loa.test_entry_id = oce.entry_id
	},
	'delLabEntriesByOrderID'=>qq
	{
		DELETE 
		FROM lab_order_entry
		WHERE parent_id = :1
	},
);

1;
