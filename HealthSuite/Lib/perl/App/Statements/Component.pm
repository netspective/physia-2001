##############################################################################
package App::Statements::Component;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Data::Publish;
use App::Universal;

use vars qw(
	@ISA
	@EXPORT
	$STMTMGR_COMPONENT
	$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES_INTERNAL_ORG
	$SQLSTMT_CONTACTMETHODS
	$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES
	$SQLSTMT_ADDRESSES
	);
@ISA = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$SQLSTMT_CONTACTMETHODS
	$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES
	$SQLSTMT_ADDRESSES
	$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES_INTERNAL_ORG
	);

$SQLSTMT_CONTACTMETHODS = qq{
	SELECT
		value_int,
		value_type,
		item_name,
		value_text,
		item_id,
		'attr-%sqlvar_entityName%-' AS dialogid_suffix
	FROM %sqlvar_entityName%_Attribute
	WHERE
		parent_id = ?
		AND	value_type IN (
			@{[ App::Universal::ATTRTYPE_PHONE ]},
			@{[ App::Universal::ATTRTYPE_FAX ]},
			@{[ App::Universal::ATTRTYPE_PAGER ]},
			@{[ App::Universal::ATTRTYPE_EMAIL ]},
			@{[ App::Universal::ATTRTYPE_URL ]},
			@{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}
		)
	ORDER BY
		value_type,
		name_sort,
		item_name
};

$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES = qq{
	SELECT
		value_int AS preferred,
		value_type,
		value_text || ' (' || item_name || ')',
		item_id,
		avt.caption AS caption,
		'attr-%sqlvar_entityName%-' || value_type AS dialogid_suffix
	FROM
		%sqlvar_entityName%_attribute,
		attribute_value_type avt
	WHERE
		parent_id = ?
		AND	value_type IN (
			@{[ App::Universal::ATTRTYPE_PHONE ]},
			@{[ App::Universal::ATTRTYPE_FAX ]},
			@{[ App::Universal::ATTRTYPE_PAGER ]},
			@{[ App::Universal::ATTRTYPE_EMAIL ]},
			@{[ App::Universal::ATTRTYPE_URL ]},
			@{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}
		)
		AND	avt.id = value_type
	UNION ALL (
		SELECT
			0 as preferred,
			99998 AS value_type,
			'-' AS value_text,
			-1,
			'-',
			'-'
		FROM dual
	)
	UNION ALL (
		SELECT
			0 AS preferred,
			@{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} AS value_type,
			complete_addr_html AS value_text,
			item_id,
			address_name AS caption,
			DECODE('%sqlvar_entityName%', 'Person', 'attr-person-', 'Org', 'attr-org-' ) || @{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} AS dialogid_suffix
		FROM %sqlvar_entityName%_address
		WHERE parent_id = ?
	)
	ORDER BY value_type
};

$SQLSTMT_CONTACTMETHODS_AND_ADDRESSES_INTERNAL_ORG = qq{
	SELECT
		value_int AS preferred,
		value_type,
		value_text || ' (' || DECODE(value_type, @{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}, value_textb, item_name) || ')',
		item_id,
		avt.caption AS caption,
		'attr-%sqlvar_entityName%-' || value_type AS dialogid_suffix
	FROM
		%sqlvar_entityName%_attribute,
		attribute_value_type avt
	WHERE 
		parent_id = (
			SELECT org_internal_id
			FROM org
			WHERE
				owner_org_id = :2
				AND	org_id = :1
		)
		AND	value_type IN (
			@{[ App::Universal::ATTRTYPE_PHONE ]},
			@{[ App::Universal::ATTRTYPE_FAX ]},
			@{[ App::Universal::ATTRTYPE_PAGER ]},
			@{[ App::Universal::ATTRTYPE_EMAIL ]},
			@{[ App::Universal::ATTRTYPE_URL ]},
			@{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}
		)
		AND	avt.id = value_type
	UNION ALL (
		SELECT
			0 AS preferred,
			99998 AS value_type,
			'-' AS value_text,
			-1,
			'-',
			'-'
		FROM dual
	)
	UNION ALL (
		SELECT
			0 AS preferred,
			@{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} AS value_type,
			complete_addr_html AS value_text,
			item_id,
			address_name AS caption,
			DECODE('%sqlvar_entityName%', 'Person', 'attr-person-', 'Org', 'attr-org-' ) || @{[ App::Universal::ATTRTYPE_FAKE_ADDRESS() ]} AS dialogid_suffix
		FROM %sqlvar_entityName%_address
		WHERE
			parent_id = (
				SELECT org_internal_id
				FROM org
				WHERE
					owner_org_id = :2
					AND	org_id = :1
			)
	)
	ORDER BY value_type
};


$SQLSTMT_ADDRESSES = qq{
	SELECT
		address_name,
		complete_addr_html,
		item_id
	FROM %sqlvar_entityName%_address
	WHERE parent_id = ?
	ORDER BY address_name
};


1;
