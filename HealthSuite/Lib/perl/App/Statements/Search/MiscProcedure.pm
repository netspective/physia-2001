##############################################################################
package App::Statements::Search::MiscProcedure;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

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



$STMTFMT_SEL_MISC_PROCEDURE = qq{
		select code,caption as name ,detail as description,
		(select count (*) from  trans_attribute ta
			where
			t.trans_id = ta.parent_id
			and ta.item_name = '@{[App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT]}'
			and ta.value_type = @{[App::Universal::ATTRTYPE_CPT_CODE]}
		)
		 ,trans_id
		FROM Transaction t
		where 
		%whereCond%			
		and t.trans_subtype = '@{[App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT]}'	
		and t.trans_status = @{[App::Universal::TRANSSTATUS_ACTIVE]}
};


$STMTFMT_SEL_MISC_PROCEDURE_DETAIL = qq
{
	select ta.value_text,ta.value_textB,r.name,t.caption, t.trans_id,ta.item_id
	FROM transaction t , trans_attribute ta, REF_CPT r
	WHERE  %whereCond%
		and ta.value_type = 310 
		and ta.item_name = '@{[App::Universal::TRANSSUBTYPE_MISC_PROC_TEXT]}'
		and ta.value_text = r.CPT		
		and t.trans_type = 4000		
		and t.trans_id = ta.parent_id
		
	
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
		url => 'javascript:chooseItem("/search/miscprocedure/detail/#4#", "#0#", false)'
		#url => 'javascript:chooseItem("#&{?}#")'
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

		delUrlFmt => '/org/#session.org_id#/dlg-remove-misc-procedure-item/#5#',
	},
	columnDefn =>
	[
		{ head => 'CPT Code',
		tDataFmt => '&{count:0} Entries',
		url =>'/org/#session.org_id#/dlg-update-misc-procedure-item/#5#'},	
		{ head => 'Modifier' },	
		{ head => 'Name' },		
	],	
	#bullets => '/org/#session.org_id#/dlg-update-misc-procedure-item/#5#',
};


$STMTMGR_MISC_PROCEDURE_CODE_SEARCH = new App::Statements::Search::MiscProcedure(
	'sel_misc_procedure_code' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'code = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	

	'sel_misc_procedure_description' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(detail) = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	}, 
	'sel_misc_procedure_name' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(caption) = ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	}, 
	'sel_misc_procedure_code_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'code like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},

	'sel_misc_procedure_description_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(detail) like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	'sel_misc_procedure_name_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE,
		whereCond => 'upper(caption) like ?',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE,
	},
	'sel_misc_procedure_detail' =>
	{
		_stmtFmt => $STMTFMT_SEL_MISC_PROCEDURE_DETAIL,
		whereCond => ' t.trans_id = ? ',
		publishDefn => $STMTRPTDEFN_MISC_PROCEDURE_DETAIL,
	}


);


1;
