##############################################################################
package App::Statements::Search::Code;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use Devel::ChangeLog;

use vars qw(@ISA @EXPORT @CHANGELOG
	$STMTMGR_CATALOG_CODE_SEARCH
	$STMTMGR_CPT_CODE_SEARCH
	$STMTMGR_HCPCS_CODE_SEARCH
	$STMTMGR_SERVICETYPE_CODE_SEARCH
	$STMTMGR_SERVICEPLACE_CODE_SEARCH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$STMTMGR_CATALOG_CODE_SEARCH
	$STMTMGR_CPT_CODE_SEARCH
	$STMTMGR_HCPCS_CODE_SEARCH
	$STMTMGR_SERVICETYPE_CODE_SEARCH
	$STMTMGR_SERVICEPLACE_CODE_SEARCH);

use vars qw(
	$STMTFMT_SEL_CATALOG_CODE
	$STMTFMT_SEL_CPT_CODE
	$STMTFMT_SEL_HCPCS_CODE
	$STMTFMT_SEL_SERVICETYPE_CODE
	$STMTFMT_SEL_SERVICEPLACE_CODE
	$STMTRPTDEFN_ICD
	$STMTRPTDEFN_CPT
	$STMTRPTDEFN_HCPCS
	$STMTRPTDEFN_SERVCODE);

$STMTFMT_SEL_CATALOG_CODE = qq{
			select icd, name, descr, decode(sex, 'M','MALE', 'F','FEMALE') as sex,
				decode(age, 'N','NEWBORN', 'P','PEDIATRIC', 'M','MATERNAL', 'A','ADULT') as age,
				non_specific_code, major_diag_category, comorbidity_complication,
				medicare_secondary_payer, manifestation_code, questionable_admission,
				unacceptable_primary_wo, unacceptable_principal, unacceptable_procedure,
				non_specific_procedure, non_covered_procedure, cpts_allowed
			from REF_ICD
			where
				%whereCond%
};
$STMTFMT_SEL_CPT_CODE = qq{
			select cpt, name, description, comprehensive_compound_cpts, mutual_exclusive_cpts,
			decode(sex, 'M','MALE', 'F','FEMALE') as sex, unlisted, questionable, asc_, non_rep,
			non_cov
			from REF_CPT
			where
				%whereCond%
};
$STMTFMT_SEL_HCPCS_CODE = qq{
			select hcpcs, name, description from REF_HCPCS
			where
				%whereCond%
};

$STMTFMT_SEL_SERVICEPLACE_CODE = qq{
			select abbrev, caption
			from hcfa1500_service_place_code
			where
				%whereCond%
};

$STMTFMT_SEL_SERVICETYPE_CODE = qq{
			select abbrev, caption
			from hcfa1500_service_type_code
			where
				%whereCond%
};

$STMTRPTDEFN_ICD =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'ICD Codes',
	#},
	columnDefn =>
	[
		{ head => 'Code', url => 'javascript:chooseItem2("/lookup/icd/detail/#&{?}#", "#&{?}#", true)', hint => 'Lookup Detailed Data' },
		{ head => 'Name' },
		{ head => 'Description' },
		{ head => 'Sex' },
		{ head => 'Age' },
	],
	#rowSepStr => '',
};

$STMTRPTDEFN_CPT =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'ICD Codes',
	#},
	columnDefn =>
	[
		{ head => 'Code', url => 'javascript:chooseItem2("/lookup/cpt/detail/#&{?}#", "#&{?}#", true)', hint => 'Lookup Detailed Data' },
		{ head => 'Name' },
		{ head => 'Description' },
	],
	#rowSepStr => '',
};

$STMTRPTDEFN_HCPCS =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'ICD Codes',
	#},
	columnDefn =>
	[
		{ head => 'Code', url => 'javascript:chooseEntry("#&{?}#")' },
		{ head => 'Name' },
		{ head => 'Description' },
	],
	#rowSepStr => '',
};

$STMTRPTDEFN_SERVCODE =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'ICD Codes',
	#},
	columnDefn =>
	[
		{ head => 'Code', url => 'javascript:chooseEntry("#&{?}#")' },
		{ head => 'Name' },
	],
	#rowSepStr => '',
};


$STMTMGR_CATALOG_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_icd_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG_CODE,
			whereCond => 'icd = ?',
			publishDefn => $STMTRPTDEFN_ICD,
		},
	'sel_icd_description' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG_CODE,
			whereCond => 'descr = ?',
			publishDefn => $STMTRPTDEFN_ICD,
		},
	'sel_icd_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG_CODE,
			 whereCond => 'icd like ?',
			publishDefn => $STMTRPTDEFN_ICD,
		},
	'sel_icd_description_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG_CODE,
			whereCond => 'descr like ?',
			publishDefn => $STMTRPTDEFN_ICD,
		},
	'sel_detail_icd' =>
		{
			_stmtFmt => $STMTFMT_SEL_CATALOG_CODE,
			whereCond => 'icd = ?',
			publishDefn => $STMTRPTDEFN_ICD,
		},
);

$STMTMGR_CPT_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_cpt_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'cpt = ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(name) = ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_description' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(description) = ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_nameordescr' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(name) = ? or upper(description) = ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'cpt like ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(name) like ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_description_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(description) like ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_cpt_nameordescr_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'upper(name) like ? or upper(description) like ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
	'sel_detail_cpt' =>
		{
			_stmtFmt => $STMTFMT_SEL_CPT_CODE,
			whereCond => 'cpt = ?',
			publishDefn => $STMTRPTDEFN_CPT,
		},
);

$STMTMGR_HCPCS_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_hcpcs_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'hcpcs = ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(name) = ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_description' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(description) = ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_nameordescr' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(name) = ? or upper(description) = ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'hcpcs like ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(name) like ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_description_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(description) like ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
	'sel_hcpcs_nameordescr_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_HCPCS_CODE,
			whereCond => 'upper(name) like ? or upper(description) like ?',
			publishDefn => $STMTRPTDEFN_HCPCS,
		},
);

$STMTMGR_SERVICEPLACE_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_place_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'abbrev = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_place_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'caption = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_place_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			 whereCond => 'abbrev like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_place_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'caption like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
);

$STMTMGR_SERVICETYPE_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_type_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'abbrev = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_type_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'caption = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_type_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			 whereCond => 'abbrev like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
	'sel_type_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'caption like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE,
		},
);

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/06/2000', 'MAF',
		'Search/Code',
		'Updated the Code select statements by replacing them with _stmtFmt.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/19/2000', 'MAF',
		'Search/Code',
		'Created simple reports instead of using createOutput function.'],
);

1;
