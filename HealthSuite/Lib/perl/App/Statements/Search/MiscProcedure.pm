##############################################################################
package App::Statements::Search::MiscProcedure;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT
	$STMTMGR_MISC_PROCEDURE_CODE_SEARCH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$STMTMGR_MISC_PROCEDURE_CODE_SEARCH);

use vars qw(
	$STMTFMT_SEL_MISC_PROCEDURE
	$STMTFMT_SEL_MISC_PROCEDURE_DETAIL
	$STMTRPTDEFN_MISC_PROCEDURE
	$STMTRPTDEFN_MISC_PROCEDURE_DETAIL);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;
my $CPT_CODE =App::Universal::CATALOGENTRYTYPE_CPT;
my $HCPCS_CODE = App::Universal::CATALOGENTRYTYPE_HCPCS;
my $MISC_CODE = App::Universal::CATALOGENTRYTYPE_MISC_PROCEDURE;

$STMTFMT_SEL_MISC_PROCEDURE = qq{
	SELECT	oce.code,
		oce.name AS name,
		oce.description AS description,
		(
			SELECT 	count (*)
			FROM 	offering_catalog_entry 
			WHERE 	parent_entry_id = oce.entry_id			
		),
		entry_id 
	FROM 	Offering_catalog oc,offering_catalog_entry oce
	WHERE 
	%whereCond%			
	AND 	oc.catalog_type =2
	AND 	oc.org_internal_id = ?
	AND 	oce.catalog_id = oc.internal_catalog_id 
	AND 	oce.entry_type = $MISC_CODE
	AND 	rownum <= $LIMIT
};

$STMTFMT_SEL_MISC_PROCEDURE_DETAIL = qq
{
	SELECT	oce.code,
		oce.modifier,
		cet.caption,
		oce.name,
		oce.entry_id
	FROM    offering_catalog_entry oce,
		catalog_entry_type cet
	WHERE
		%whereCond%
	AND	oce.entry_type = cet.id (+)		
	AND 	rownum <= $LIMIT
};


$STMTRPTDEFN_MISC_PROCEDURE =
{
	banner =>
	{
		actionRows =>
		[
			{
				caption => '<a href=/org/#session.org_id#/dlg-add-misc-procedure>Add Misc Procedure Code</a>',
				url => '/org/#session.org_id#/dlg-add-misc-procedure'
			},
		],
	},
	stdIcons =>
	{
		
		updUrlFmt => '/org/#session.org_id#/dlg-update-misc-procedure/#4#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-misc-procedure/#4#',
	},
	columnDefn =>
	[
		{ head => 'Code', 		
		url => q{javascript:chooseItem('/search/miscprocedure/detail/#4#', '#0#', false)},		
		},	
		{ head => 'Name' },
		{ head => 'Description' },
		{ head => 'Entries',summarize => 'sum',dAlign => 'CENTER', 
			tAlign=>'CENTER', },
	],	
	bullets => '/org/#session.org_id#/dlg-update-misc-procedure/#4#',
};





$STMTRPTDEFN_MISC_PROCEDURE_DETAIL =
{	
	banner =>
	{
		actionRows =>
		[
			{
				caption => '<a href=/org/#session.org_id#/dlg-add-misc-procedure-item/#param.search_expression#>Add Procedure Item to #param.code_value#</a>',
				url => '/org/#session.org_id#/dlg-add-misc-procedure-item/#param.search_expression#'
			},
		],
	},
	stdIcons =>
	{		

		delUrlFmt => '/org/#session.org_id#/dlg-remove-misc-procedure-item/#4#',
		updUrlFmt => '/org/#session.org_id#/dlg-update-misc-procedure-item/#4#',		
	},
	columnDefn =>
	[
		{ head => 'Code',
		tDataFmt => '&{count:0} Entries',tAlign=>'left',
		},	
		{ head => 'Modifier' },		
		{ head => 'Code Type' },		
		{ head => 'Name' },	
	],	
	bullets => '/org/#session.org_id#/dlg-update-misc-procedure-item/#4#',
};


$STMTMGR_MISC_PROCEDURE_CODE_SEARCH = new App::Statements::Search::MiscProcedure(
	'sel_misc_procedure_code' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'oce.code = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	'sel_misc_procedure_description' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(oce.description) = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	}, 
	'sel_misc_procedure_name' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(oce.name) = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	}, 
	'sel_misc_procedure_code_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'oce.code like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},

	'sel_misc_procedure_description_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(oce.description) like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	'sel_misc_procedure_name_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(oce.name) like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	'sel_misc_procedure_detail' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE_DETAIL,
		whereCond => ' oce.parent_entry_id = ? ',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE_DETAIL,
	}
);


1;
