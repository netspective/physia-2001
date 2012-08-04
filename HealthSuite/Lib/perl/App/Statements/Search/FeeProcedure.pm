##############################################################################
package App::Statements::Search::FeeProcedure;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT
	$STMTMGR_FEE_PROCEDURE_CODE_SEARCH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$STMTMGR_FEE_PROCEDURE_CODE_SEARCH);

use vars qw(
	$STMTFMT_SEL_FEE_PROCEDURE
	$STMTFMT_SEL_FEE_PROCEDURE_DETAIL
	$STMTRPTDEFN_FEE_PROCEDURE
	$STMTRPTDEFN_FEE_PROCEDURE_DETAIL);



$STMTFMT_SEL_FEE_PROCEDURE = qq{
		SELECT oce.code,oce.name ,oce.description,ce.caption ,oc.catalog_id
		FROM  Offering_Catalog_Entry oce,Offering_Catalog oc,catalog_entry_type ce
		WHERE oce.catalog_id = oc.internal_catalog_id 
		AND   oce.entry_type = ce.id
		AND   oc.internal_catalog_id = ?
		AND   %whereCond%

};


$STMTRPTDEFN_FEE_PROCEDURE =
{
	
	columnDefn =>
	[
		{ hAlign => 'LEFT',head => 'Code', 		
		url => q{javascript:chooseEntry('#&{?}#')}},			
		{hAlign => 'LEFT',head => 'Name'  },				
		{hAlign => 'LEFT',colIdx=>3, head => 'Code Type' }
	],		
};





$STMTMGR_FEE_PROCEDURE_CODE_SEARCH = new App::Statements::Search::FeeProcedure(
	'sel_fee_procedure_code' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'code = ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	},
	

	'sel_fee_procedure_description' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'UPPER(oce.description) = ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	}, 
	'sel_fee_procedure_name' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'UPPER(oce.name) = ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	}, 
	'sel_fee_procedure_code_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'code like ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	},

	'sel_fee_procedure_description_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'UPPER(oce.description) like ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	},
	'sel_fee_procedure_name_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_FEE_PROCEDURE,
		whereCond => 'UPPER(oce.name) like ?',
		publishDefn => $STMTRPTDEFN_FEE_PROCEDURE,
	},
	

);


1;
