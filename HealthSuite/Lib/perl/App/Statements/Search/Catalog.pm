##############################################################################
package App::Statements::Search::Catalog;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Data::Publish;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_CATALOG_SEARCH $CATALOGENTRY_COLUMNS $CATALOGITEM_COLUMNS
	$STMTRPTDEFN_DEFAULT $STMTRPTDEFN_NAME_DEFAULT $STMTRPTDEFN_DEFAULT_ITEM );
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_CATALOG_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

use vars qw($STMTFMT_SEL_CATALOG $STMTFMT_SEL_CATALOGENTRY $STMTFMT_SEL_CATENTRYBYID );

$STMTFMT_SEL_CATALOG = qq{
	SELECT
		oc.catalog_id,
		count(oce.entry_id) entries_count,
		oc.caption,
		oc.description,
		oc.parent_catalog_id,
		oc.internal_catalog_id,
		'Add',
		DECODE(oc_a.value_int, 1, '(Capitated)', null) AS capitated
	FROM
		ofcatalog_Attribute oc_a,
		offering_catalog oc,
		offering_catalog_entry oce
	WHERE
		oce.catalog_id (+) = oc.internal_catalog_id
		AND oc_a.parent_id (+) = oc.internal_catalog_id 
		AND (oc.org_internal_id is null or oc.org_internal_id = ?)
		%whereCond%
		AND rownum <= $LIMIT
	GROUP BY
		oc.catalog_id,
		oc.internal_catalog_id,
		oc.caption,
		oc.description,
		oc.parent_catalog_id %extraCols%,
		oc_a.value_int
	ORDER BY
		oc.catalog_id
};

$STMTFMT_SEL_CATALOGENTRY = qq{
	SELECT
		entry_id AS ID,
		catalog_entry_type.caption AS Type,
		code AS code,
		modifier AS modifier,
		description AS description,
		unit_cost AS price,
		default_units AS uoh,
		'Add',
		parent_entry_id,
		name,
		DECODE(flags, 0, null, 1, '(FFS)')
	FROM
		catalog_entry_type,
		offering_catalog_entry
	WHERE
		catalog_id = ?
		AND	offering_catalog_entry.entry_type = catalog_entry_type.id
		AND rownum <= $LIMIT
	ORDER BY
		entry_type,
		code,
		modifier
};



$STMTFMT_SEL_CATENTRYBYID = qq{
	SELECT
		oce.entry_id AS id,
		catalog_entry_type.caption AS type,
		oce.code AS code,
		oce.modifier AS modifier,
		oce.description AS description,
		oce.unit_cost AS price,
		oce.default_units AS uoh,
		'Add',
		oce.parent_entry_id,
		oce.name,
		decode(flags, 0, null, 1, '(FFS)')
	FROM
		catalog_entry_type,
		offering_catalog_entry oce,
		offering_catalog oc
	WHERE 	
		oc.org_internal_id =  ?
		AND oc.catalog_id = ?
		AND oce.catalog_id = oc.internal_catalog_id
		AND	oce.entry_type = catalog_entry_type.id
		AND rownum <= $LIMIT
	ORDER BY entry_type, code, modifier
},



$STMTRPTDEFN_NAME_DEFAULT =
{
	banner =>
	{
		actionRows =>
		[
			{
				caption => "<a href='/org/#session.org_id#/dlg-add-catalog'>Add Fee Schedule</a>",
				url => '/org/#session.org_id#/dlg-add-catalog'
			},
		],
	},

	stdIcons =>
	{
		#addUrlFmt => '/org/#session.org_id#/dlg-add-catalog',
		updUrlFmt => '/org/#session.org_id#/dlg-update-catalog/#0#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog/#5#',
	},
	columnDefn =>
	[
		{ head => 'ID', hint => 'Fee Schedule ID #5#', 			
			url => 'javascript:chooseItem("/search/catalog/name/#0#", "#0#", false)',
			#dataFmt => '&{level_indent:0}#0#', 
			tDataFmt => '&{count:0} Schedules', 
			options => PUBLCOLFLAG_DONTWRAP,
		},
		{ head => 'Name', dataFmt => '<B>#2#</B><BR><I>#3#</I>'},
		{	head => 'Contract', dataFmt => '#7#'},
		{ head => 'Entries', 
			colIdx => 1, 
			dAlign => 'CENTER', 
			tAlign=>'CENTER',
			summarize => 'sum'
		},
	],
	bullets => '/org/#session.org_id#/dlg-update-catalog/#5#',
};





$STMTRPTDEFN_DEFAULT =
{
	banner =>
	{
		actionRows =>
		[
			{
				caption => "<a href='/org/#session.org_id#/dlg-add-catalog'>Add Fee Schedule</a>",
				url => '/org/#session.org_id#/dlg-add-catalog'
			},
		],
	},

	stdIcons =>
	{
		#addUrlFmt => '/org/#session.org_id#/dlg-add-catalog',
		updUrlFmt => '/org/#session.org_id#/dlg-update-catalog/#0#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog/#5#',
	},
	columnDefn =>
	[
		{ head => 'ID', hint => 'Fee Schedule ID #5#', 
			url => 'javascript:chooseItem("/search/catalog/detail/#5#", "#5#", false)',
			#url => 'javascript:chooseItem("/search/catalog/detailname/#0#", "#0#", false)',
			#dataFmt => '&{level_indent:0}#0#', 
			tDataFmt => '&{count:0} Schedules', 
			options => PUBLCOLFLAG_DONTWRAP,
		},
		{ head => 'Name', dataFmt => '<B>#2#</B><BR><I>#3#</I>'},
		{	head => 'Contract', dataFmt => '#7#'},
		{ head => 'Entries', 
			colIdx => 1, 
			dAlign => 'CENTER', 
			tAlign=>'CENTER',
			summarize => 'sum'
		},
	],
	bullets => '/org/#session.org_id#/dlg-update-catalog/#5#',
};









my $STMTRPTDEFN_ORG =
{
	banner =>
	{
		actionRows =>
		[
			{
				caption => qq{
					<a href='/org/#session.org_id#/dlg-add-catalog'>Add Fee Schedule</a> |
					<a href='/org/#session.org_id#/dlg-add-feescheduledataentry'>Add Fee Schedule Entries</a> |
					<a href='/org/#session.org_id#/dlg-add-catalog-copy'>Copy Fee Schedule and its Entries</a>
				},
			},
		],
	},

	stdIcons =>
	{
		#addUrlFmt => '/org/#session.org_id#/dlg-add-catalog',
		updUrlFmt => '/org/#session.org_id#/dlg-update-catalog/#0#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog/#5#',
	},
	columnDefn =>
	[
		{ head => 'ID', hint => 'Fee Schedule ID #5#', 
			url => '/org/#session.org_id#/catalog/#5#/#0#', 
			dataFmt => '&{level_indent:0}#0#', 
			tDataFmt => '&{count:0} Schedules', 
			options => PUBLCOLFLAG_DONTWRAP
		},
		{ head => 'Name', dataFmt => '<B>#2#</B><BR><I>#3#</I>'},
		{	head => 'Contract', dataFmt => '#7#'},		
		{ head => 'Entries', colIdx => 1, dAlign => 'CENTER', tAlign=>'CENTER', 
			summarize => 'sum',
		},
		{ head => '', colIdx => 6, hint => 'Add Child Schedule', 
			url => '/org/#session.org_id#/dlg-add-catalog/#5#' 
		},
	],
	bullets => '/org/#session.org_id#/dlg-update-catalog/#5#',
};

$STMTRPTDEFN_DEFAULT_ITEM =
{
	stdIcons =>
	{
		#location => 'trail',
		addUrlFmt => '/org/#session.org_id#/dlg-add-catalog-item/#param.search_expression#',
		updUrlFmt => '/org/#session.org_id#/dlg-update-catalog-item/#0#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog-item/#0#',
	},
	columnDefn =>
	[
		{ head => 'ID',
			url => 'javascript:chooseItem("/org/#session.org_id#/dlg-update-catalog-item/#0#", "#0#", false)',
			dAlign => 'center',
			#dataFmt => '&{level_indent:0}#0#',
			tDataFmt => '&{count:0} Entries',
			options => PUBLCOLFLAG_DONTWRAP
		},
		{ head => 'Type' },
		{ head => 'Code' },
		{ head => 'Modifier' },
		{ head => 'Description' },
		{ head => 'Price', dformat => 'currency', tAlign => 'RIGHT', 
			tDataFmt => '&{avg_currency:&{?}}<BR>&{sum_currency:&{?}}' 
		},
		{ head => 'UOH', hint => 'Units', dAlign => 'CENTER' },
		{ head => 'Name', colIdx => 9},
		{ head => '', colIdx => 10, dAlign => 'center'},
	],
};

#<a href='/org/#session.org_id#/dlg-add-catalog-copy/#param.catalog_id#'>Copy Fee Schedule</a> |
my $STMTRPTDEFN_DEFAULT_ITEM_ORG =
{
	banner =>
	{
		actionRows =>
		[
			{
				caption => qq{<b style="font-size:10pt">#param.catalog_id# (Fee Schedule ID #param.internal_catalog_id#)</b> <br>
					<a href='/org/#session.org_id#/dlg-add-catalog/#param.internal_catalog_id#'>Add Fee Schedule</a> |
					<a href='/org/#session.org_id#/dlg-add-catalog-item/#param.internal_catalog_id#'>Add Item</a>
				},
			},
		],
	},

	stdIcons =>
	{
		#addUrlFmt => '/org/#session.org_id#/dlg-add-catalog-item',
		updUrlFmt => '/org/#session.org_id#/dlg-update-catalog-item/#0#',
		delUrlFmt => '/org/#session.org_id#/dlg-remove-catalog-item/#0#',
	},

	columnDefn =>
	[
		{ head => 'ID', url => '/org/#session.org_id#/dlg-update-catalog-item/#0#',
			#dataFmt => '&{level_indent:0}#0#',
			dAlign => 'center',
			tDataFmt => '&{count:0} Entries',
			options => PUBLCOLFLAG_DONTWRAP
		},
		{ head => 'Type' },
		{ head => 'Code' },
		{ head => 'Modifier' },
		{ head => 'Description' },
		{ head => 'Price', dformat => 'currency', tAlign => 'RIGHT', 
			tDataFmt => '&{avg_currency:&{?}}<BR>&{sum_currency:&{?}}' 
		},
		{ head => 'UOH', hint => 'Units', dAlign => 'CENTER' },
		{ head => '', hint => 'Add Child Entry', 
			url => '/org/#session.org_id#/dlg-add-catalog-item/#param.internal_catalog_id#/#0#' 
		},
		{ head => '', colIdx => 10, dAlign => 'center'},		
	],
};

$STMTMGR_CATALOG_SEARCH = new App::Statements::Search::Catalog(
	'sel_catalogs_all' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			#whereCond => '(oc.org_id is null or oc.org_id = ?)',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel__name_catalogs_all' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			#whereCond => '(oc.org_id is null or oc.org_id = ?)',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
	
	

	'sel_catalogs_all_org' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			#whereCond => '(oc.org_id is null or oc.org_id = ?)',
			publishDefn => $STMTRPTDEFN_ORG,
		},


	'sel_catalog_id' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.catalog_id = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
		
		
	'sel_name_catalog_id' =>		
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.catalog_id = ?',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
		
	'sel_catalog_id_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.catalog_id like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_catalog_id_like' =>
		{
				_stmtFmt => $STMTFMT_SEL_CATALOG,
				whereCond => 'and oc.catalog_id like ?',
				publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
	'sel_catalog_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.caption = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_catalog_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.caption = ?',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
		
	'sel_catalog_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.caption like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
		
	'sel_name_catalog_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.caption like ?',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},

	'sel_catalog_description' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.description = ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},

	'sel_name_catalog_description' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.description = ?',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
	'sel_catalog_description_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.description like ?',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_catalog_description_like' =>
	{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and oc.description like ?',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
	'sel_catalog_nameordescr' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and (oc.caption = ? or oc.description = ?)',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_catalog_nameordescr' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and (oc.caption = ? or oc.description = ?)',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},
		
	'sel_catalog_nameordescr_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and (oc.caption like ? or oc.description like ?)',
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_name_catalog_nameordescr_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG,
			whereCond => 'and (oc.caption like ? or oc.description like ?)',
			publishDefn => $STMTRPTDEFN_NAME_DEFAULT,
		},

	'sel_catalog_items_all' =>
		{
			sqlStmt => qq{
				select entry_id as ID, code as Code, unit_cost as Price
				from offering_catalog_entry
				where catalog_id = ?
				order by entry_type, status, name, code
				},
			publishDefn => $STMTRPTDEFN_DEFAULT_ITEM,
		},
	'sel_catalog_detail' =>
	
		{
			_stmtFmt => $STMTFMT_SEL_CATALOGENTRY,
			publishDefn => $STMTRPTDEFN_DEFAULT_ITEM,
		},
		
	'sel_catalog_detailname' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATENTRYBYID,
			publishDefn => $STMTRPTDEFN_DEFAULT_ITEM,
		},

	'sel_catalog_detail_org' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOGENTRY,
			publishDefn => $STMTRPTDEFN_DEFAULT_ITEM_ORG,
		},

);

1;
