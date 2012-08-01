##############################################################################
package App::Statements::Search::OrgDirectory;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_ORG_DIR_SEARCH $STMTRPTDEFN_DEFAULT $STMTRPTDEFN_SERVICE_DEFAULT $STMTRPTDEFN_DRILL_SERVICE_DEFAULT
	$STMTFMT_SEL_ORG_DIR $STMTFMT_SEL_ORG_SERVICE_DIR $STMTFMT_SEL_ORG_DRILL_SERVICE_DIR $STMTMGR_ORG_SERVICE_DIR_SEARCH
	$STMTFMT_SEL_ORG_SUB_DRILL_SERVICE_DIR);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG_DIR_SEARCH $STMTMGR_ORG_SERVICE_DIR_SEARCH);

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

$STMTFMT_SEL_ORG_DIR = qq{
	SELECT *
	FROM (
		SELECT
			DISTINCT o.org_id,
			o.name_primary,
			o.category,
			a.city,
			a.state,
			a.zip,
			o.tax_id,
			DECODE(t.group_name, 'other', 'main', t.group_name),
			 a.line1, pa.value_text as value_text,
			(NVL(
					(
						SELECT	 cc.internal_catalog_id
						FROM		offering_catalog cc
						WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
						AND     cc.org_internal_id = o.parent_org_id
					),
					(SELECT 		ca.internal_catalog_id
						FROM		offering_catalog ca, org gg
						WHERE 	upper(ca.catalog_id) = upper((gg.org_id)||'_Fee_Schedule')
						AND     gg.org_internal_id = o.parent_org_id
					)
				)
			)AS internal_catalog_id,
			(NVL(
					(
						SELECT catalog_id
						FROM offering_catalog cc
						WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
						AND     cc.org_internal_id = o.parent_org_id
					),
					(SELECT (g.org_id)||'_Fee_Schedule' FROM
							org g where g.org_internal_id = o.parent_org_id
					)
				)
			)AS catalog_id,
			(
				SELECT   tt.value_text
				FROM     org_attribute tt
				WHERE    tt.parent_id = o.org_internal_id
				AND      tt.item_name = 'Negotiated Contract Type'
				AND      tt.value_type = 0
			)AS type,
			po.org_id AS parent_org
		FROM
			org o,
			org po,
			org_category cat,
			org_type t,
			org_address a,
			 org_attribute pa
		WHERE
			cat.parent_id = o.org_internal_id
			AND a.parent_id = o.org_internal_id
			AND a.address_name = 'Street'
			AND	cat.member_name = t.caption
			AND	cat.member_name = (
				SELECT caption
				FROM org_type ot
				WHERE ot.id = (
					SELECT MIN(og.id)
					FROM
						org_type og,
						org_category oe
					WHERE
						oe.parent_id = o.org_internal_id
						AND og.caption = oe.member_name
				)
			)
			AND     pa.parent_id = o.org_internal_id
			AND     pa.item_name = 'Primary'
			AND 	  pa.value_type = 10
			AND 	  po.org_internal_id = o.parent_org_id
			AND	%whereCond%
			AND (
				 o.owner_org_id = ?
			)
		ORDER BY o.org_id
	)
	WHERE rownum <= $LIMIT
};

$STMTFMT_SEL_ORG_SERVICE_DIR = qq{

		SELECT  unique o.org_id,
			o.name_primary,
			a.city,
			a.state, a.line1, pa.value_text as value_text,
					(NVL(
							(
								SELECT	 cc.internal_catalog_id
								FROM		offering_catalog cc
								WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
								AND     cc.org_internal_id = o.parent_org_id
							),
							(SELECT 		ca.internal_catalog_id
								FROM		offering_catalog ca, org gg
								WHERE 	upper(ca.catalog_id) = upper((gg.org_id)||'_Fee_Schedule')
								AND     gg.org_internal_id = o.parent_org_id
							)
						)
					)AS internal_catalog_id,
					(NVL(
							(
								SELECT catalog_id
							  	FROM offering_catalog cc
						  	 	WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
						 	 	AND     cc.org_internal_id = o.parent_org_id
							),
							(SELECT (g.org_id)||'_Fee_Schedule' FROM
									org g where g.org_internal_id = o.parent_org_id
							)
						)
					)AS catalog_id,
					(
						SELECT   tt.value_text
						FROM     org_attribute tt
						WHERE    tt.parent_id = o.org_internal_id
						AND      tt.item_name = 'Negotiated Contract Type'
						AND      tt.value_type = 0
					)AS type,
					po.org_id AS parent_org
		FROM 	org o, org po, org_category cat, org_address a, offering_catalog c, offering_catalog_entry oc, org_attribute oa, org_attribute pa
		WHERE    oc.catalog_id = c.internal_catalog_id
		AND     a.parent_id = o.org_internal_id
		AND     a.address_name = 'Street'
		AND     cat.parent_id = o.org_internal_id
		AND     cat.member_name in ('main_dir_entry', 'location_dir_entry')
		AND     c.catalog_type = 1
		AND     c.org_internal_id = o.owner_org_id
		AND 	o.org_internal_id = oa.parent_id
		AND     oa.item_name = 'Fee Schedule'
		AND     oa.value_int = c.internal_catalog_id
		AND     pa.parent_id = o.org_internal_id
		AND     pa.item_name = 'Primary'
		AND 	  pa.value_type = 10
		AND 	  po.org_internal_id = o.parent_org_id
		AND	%whereCond%
		AND     o.owner_org_id = ?
		AND     rownum <= $LIMIT
		ORDER BY o.org_id
};

$STMTFMT_SEL_ORG_DRILL_SERVICE_DIR = qq{

		SELECT  unique  a.state,a.city
		FROM 	org o, org_category cat, org_address a, offering_catalog c, offering_catalog_entry oc, org_attribute oa
		WHERE    oc.catalog_id = c.internal_catalog_id
		AND     a.parent_id = o.org_internal_id
		AND     a.address_name = 'Street'
		AND     cat.parent_id = o.org_internal_id
		AND     cat.member_name in ('main_dir_entry', 'location_dir_entry')
		AND     c.catalog_type = 1
		AND     c.org_internal_id = o.owner_org_id
		AND 	o.org_internal_id = oa.parent_id
		AND     oa.item_name = 'Fee Schedule'
		AND     oa.value_int = c.internal_catalog_id
		AND	%whereCond%
		AND     o.owner_org_id = ?
		ORDER BY a.state, a.city
};

$STMTFMT_SEL_ORG_SUB_DRILL_SERVICE_DIR = qq{

		SELECT  unique o.org_id,
					o.name_primary,a.state, a.city, a.line1, pa.value_text as value_text,
					(NVL(
							(
								SELECT	 cc.internal_catalog_id
								FROM		offering_catalog cc
								WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
								AND     cc.org_internal_id = o.parent_org_id
							),
							(SELECT 		ca.internal_catalog_id
								FROM		offering_catalog ca, org gg
								WHERE 	upper(ca.catalog_id) = upper((gg.org_id)||'_Fee_Schedule')
								AND     gg.org_internal_id = o.parent_org_id
							)
						)
					)AS internal_catalog_id,
					(NVL(
							(
								SELECT catalog_id
							  	FROM offering_catalog cc
						  	 	WHERE 	upper(cc.catalog_id) = upper((o.org_id)||'_Fee_Schedule')
						 	 	AND     cc.org_internal_id = o.parent_org_id
							),
							(SELECT (g.org_id)||'_Fee_Schedule' FROM
									org g where g.org_internal_id = o.parent_org_id
							)
						)
					)AS catalog_id,
					(
						SELECT   tt.value_text
						FROM     org_attribute tt
						WHERE    tt.parent_id = o.org_internal_id
						AND      tt.item_name = 'Negotiated Contract Type'
						AND      tt.value_type = 0
					)AS type,
					po.org_id AS parent_org
		FROM 	org o, org po, org_category cat, org_address a, offering_catalog c, offering_catalog_entry oc,	org_attribute oa, org_attribute pa
		WHERE    oc.catalog_id = c.internal_catalog_id
		AND     a.parent_id = o.org_internal_id
		AND     cat.parent_id = o.org_internal_id
		AND     cat.member_name in ('main_dir_entry', 'location_dir_entry')
		AND     c.catalog_type = 1
		AND     c.org_internal_id = o.owner_org_id
		AND 	o.org_internal_id = oa.parent_id
		AND     oa.item_name = 'Fee Schedule'
		AND     oa.value_int = c.internal_catalog_id
		AND     pa.parent_id = o.org_internal_id
		AND     pa.item_name = 'Primary'
		AND 	  pa.value_type = 10
		AND 	  po.org_internal_id = o.parent_org_id
		AND     o.owner_org_id = ?
		AND     oc.code = ?
		AND     a.city = ?
		ORDER BY o.org_id
};

$STMTRPTDEFN_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'Code', url => q{javascript:if(isLookupWindow()) populateControl('#0#', true); else window.location.href = '/org/#0#/profile';},},
				{ head => 'Provider Name' },
				{ head => 'Category'},
				{ head => 'City'},
				{ head => 'State'},
				{ head => 'Zip Code'},
				{ head => 'Tax ID'},
				{head => 'Street', , dataFmt => '#8#'},
				{head => 'Phone', dataFmt => '#9#'},
				{head => 'Fee Schedule', dataFmt => '#11#', url => q{javascript:doActionPopup('/org/#0#/catalog/#10#/#11#')},},
				{head => 'Type',dataFmt => '#12#'},
				{head => 'Parent Provider',  dataFmt => "<img src=\"/resources/images/icons/hand-pointing-to-folder-sm.gif\" border=0></a>", url => q{javascript:doActionPopup('/org/#13#/profile')},  },
			],
};

$STMTRPTDEFN_SERVICE_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'Code', url => q{javascript:if(isLookupWindow())  populateControl('#0#', true, '#1#'); else window.location.href = '/org/#0#/profile';},},
				{ head => 'Provider Name' },
				{ head => 'City'},
				{ head => 'State'},
				{head => 'Street', , dataFmt => '#4#'},
				{head => 'Phone', dataFmt => '#5#'},
				{head => 'Fee Schedule', dataFmt => '#7#', url => q{javascript:doActionPopup('/org/#0#/catalog/#6#/#7#')},},
				{head => 'Type',dataFmt => '#8#'},
				{head => 'Parent Provider',  dataFmt => "<img src=\"/resources/images/icons/hand-pointing-to-folder-sm.gif\" border=0></a>", url => q{javascript:doActionPopup('/org/#9#/profile')},  },
			],
};

$STMTRPTDEFN_DRILL_SERVICE_DEFAULT =
{
	columnDefn =>
			[
				{ head => 'City', dataFmt => '#1#',  url => q{javascript:location.href='#hrefSelf#&detail=service&city=#1#'},},
				{ head => 'State', dataFmt => '#0#'},
			],
};




$STMTMGR_ORG_DIR_SEARCH = new App::Statements::Search::OrgDirectory(
	'sel_statecityzip' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) = ? AND UPPER(a.city) = ? AND a.zip = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_statecityzip_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) LIKE ? AND UPPER(a.city) LIKE ? AND a.zip LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_statecity_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) LIKE ? AND UPPER(a.city) LIKE ? AND a.zip = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_statezip_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) LIKE ? AND UPPER(a.city) = ? AND a.zip LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_cityzip_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) = ? AND UPPER(a.city) LIKE ? AND a.zip LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_state_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) LIKE ? AND UPPER(a.city) = ? AND a.zip = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_city_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) = ? AND UPPER(a.city) LIKE ? AND a.zip = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_zip_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(a.state) = ? AND UPPER(a.city) = ? AND a.zip LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_taxid' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(o.tax_id) = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_taxid_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => " UPPER(o.tax_id) LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_vendor' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.org_id) = ? AND cat.member_name IN ('main_dir_entry', 'location_dir_entry')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_vendor_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.org_id) LIKE ? AND cat.member_name IN ('main_dir_entry', 'location_dir_entry')",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_provider' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.org_id) = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_provider_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.org_id) LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_providername' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.name_primary) = ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
	'sel_providername_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DIR,
			whereCond => "UPPER(o.name_primary) LIKE ?",
			publishDefn => $STMTRPTDEFN_DEFAULT,
		},
);



$STMTMGR_ORG_SERVICE_DIR_SEARCH = new App::Statements::Search::OrgDirectory(

	'sel_sservicestatecity' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => "UPPER(oc.code) = ? AND UPPER(a.state) = ? AND UPPER(a.city) = ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sservicestatecity_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) LIKE ? AND UPPER(a.city) LIKE ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sservicestate_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) LIKE ? AND UPPER(a.city) = ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sservicecity_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) = ? AND UPPER(a.city) LIKE ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sstatecity_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ? AND UPPER(a.state) LIKE ? AND UPPER(a.city) LIKE ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sservice_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) = ? AND UPPER(a.city) = ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_sstate_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ? AND UPPER(a.state) LIKE ? AND UPPER(a.city) = ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_scity_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ? AND UPPER(a.state) = ? AND UPPER(a.city) LIKE ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_onlyservice' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_onlyservice_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ?",
			publishDefn => $STMTRPTDEFN_SERVICE_DEFAULT,
		},
	'sel_donlyservicestate' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DRILL_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ? AND UPPER(a.state) = ?",
			publishDefn => $STMTRPTDEFN_DRILL_SERVICE_DEFAULT,
		},
	'sel_donlyservicestate_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DRILL_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) LIKE ?",
			publishDefn => $STMTRPTDEFN_DRILL_SERVICE_DEFAULT,
		},
'sel_donlyservice_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DRILL_SERVICE_DIR,
			whereCond => " UPPER(oc.code) LIKE ? AND UPPER(a.state) = ?",
			publishDefn => $STMTRPTDEFN_DRILL_SERVICE_DEFAULT,
		},
'sel_donlystate_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_ORG_DRILL_SERVICE_DIR,
			whereCond => " UPPER(oc.code) = ? AND UPPER(a.state) LIKE ?",
			publishDefn => $STMTRPTDEFN_DRILL_SERVICE_DEFAULT,
		},
	'sel_sub_service_search' =>
	{
		_stmtFmt => $STMTFMT_SEL_ORG_SUB_DRILL_SERVICE_DIR,
	}


);

1;
