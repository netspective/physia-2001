##############################################################################
package App::Statements::Component;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Data::Publish;
use App::Universal;

use vars qw(
	@ISA @EXPORT $STMTMGR_COMPONENT $PUBLDEFN_CONTACTMETHOD_DEFAULT
	$SQLSTMT_CONTACTMETHODS $SQLSTMT_CONTACTMETHODS_AND_ADDRESSES $SQLSTMT_ADDRESSES
	);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$PUBLDEFN_CONTACTMETHOD_DEFAULT
	$SQLSTMT_CONTACTMETHODS $SQLSTMT_CONTACTMETHODS_AND_ADDRESSES $SQLSTMT_ADDRESSES
	);

$SQLSTMT_CONTACTMETHODS = qq{
	select value_int, value_type, item_name, value_text, item_id, 'attr-%sqlvar_entityName%-' as dialogid_suffix
	from %sqlvar_entityName%_Attribute
	where parent_id = ?	and
	value_type in (
			@{[ App::Universal::ATTRTYPE_PHONE ]},
			@{[ App::Universal::ATTRTYPE_FAX ]},
			@{[ App::Universal::ATTRTYPE_PAGER ]},
			@{[ App::Universal::ATTRTYPE_EMAIL ]},
			@{[ App::Universal::ATTRTYPE_URL ]}
		)
	order by value_type, name_sort, item_name
};

$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES = qq{
	select value_int as preferred, value_type, value_text || ' (' || item_name || ')', item_id, avt.caption as caption, 'attr-%sqlvar_entityName%-' || value_type as dialogid_suffix
	from %sqlvar_entityName%_attribute, Attribute_Value_Type avt
	where	parent_id = ? and
	value_type in (
			@{[ App::Universal::ATTRTYPE_PHONE ]},
			@{[ App::Universal::ATTRTYPE_FAX ]},
			@{[ App::Universal::ATTRTYPE_PAGER ]},
			@{[ App::Universal::ATTRTYPE_EMAIL ]},
			@{[ App::Universal::ATTRTYPE_URL ]}
		) and
			avt.id = value_type
	UNION ALL
	select 0 as preferred, 99998 as value_type, '-' as value_text, -1, '-', '-'
	from dual
	UNION ALL
	select 0 as preferred, @{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} as value_type, complete_addr_html as value_text, item_id, address_name as caption, DECODE('%sqlvar_entityName%', 'Person', 'attr-person-', 'Org', 'attr-org-' ) || @{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} as dialogid_suffix
	from %sqlvar_entityName%_address
	where parent_id = ?
	order by value_type
};

$SQLSTMT_ADDRESSES = qq{
	select address_name, complete_addr_html, item_id
	from %sqlvar_entityName%_address
	where parent_id = ?
	order by address_name
};

$PUBLDEFN_CONTACTMETHOD_DEFAULT = {
	bullets => 'stpe-#my.stmtId#/dlg-update-#5#/#3#?home=/#param.arl#',
	columnDefn => [
		{ head => 'P', hHint => 'Preferred Method', comments => 'Boolean value indicating whether the contact method is a preferred method or not',
			dataFmt => ['', '<IMG SRC="/resources/icons/checkmark.gif">'], hint => 'Preferred'},
		#{ head => 'Type', img => '/resources/icons/attrtype-#1#-sm.gif', hint => '#5#' },
		{ head => 'Type', dataFmt => '#4#:', dAlign => 'RIGHT' },
		#{ head => 'Name', dataFmt => "&{fmt_stripLeadingPath:2}:", dAlign => 'RIGHT' },
		{ head => 'Value' },
	],
};

1;
