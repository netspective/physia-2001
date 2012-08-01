##############################################################################
package App::Statements::Search::Code;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

my $LIMIT = App::Universal::SEARCH_RESULTS_LIMIT;

use vars qw(@ISA @EXPORT
	$STMTMGR_CATALOG_CODE_SEARCH
	$STMTMGR_CPT_CODE_SEARCH
	$STMTMGR_HCPCS_CODE_SEARCH
	$STMTMGR_SERVICETYPE_CODE_SEARCH
	$STMTMGR_SERVICEPLACE_CODE_SEARCH
	$STMTMGR_MODIFIER_CODE_SEARCH
	$STMTMGR_EPSDT_CODE_SEARCH
	$STMTMGR_MISC_PROCEDURE_CODE_SEARCH);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw(
	$STMTMGR_CATALOG_CODE_SEARCH
	$STMTMGR_CPT_CODE_SEARCH
	$STMTMGR_HCPCS_CODE_SEARCH
	$STMTMGR_SERVICETYPE_CODE_SEARCH
	$STMTMGR_SERVICEPLACE_CODE_SEARCH
	$STMTMGR_MODIFIER_CODE_SEARCH
	$STMTMGR_EPSDT_CODE_SEARCH
	$STMTMGR_MISC_PROCEDURE_CODE_SEARCH);

use vars qw(
	$STMTFMT_SEL_CATALOG_CODE
	$STMTFMT_SEL_CPT_CODE
	$STMTFMT_SEL_HCPCS_CODE
	$STMTFMT_SEL_SERVICETYPE_CODE
	$STMTFMT_SEL_SERVICEPLACE_CODE
	$STMTFMT_SEL_MODIFIER_CODE
	$STMTFMT_SEL_EPSDT_CODE
	$STMTFMT_SEL_MISC_PROCEDURE
	$STMTRPTDEFN_ICD
	$STMTRPTDEFN_CPT
	$STMTRPTDEFN_HCPCS
	$STMTRPTDEFN_SERVCODE_AND_MODIFIER
	$STMTRPTDEFN_EPSDT
	$STMTRPTDEFN_MISC_PROCEDURE);



$STMTFMT_SEL_MISC_PROCEDURE = qq{
	SELECT code,caption,detail
	FROM Transaction
	WHERE
		%whereCond%
		AND trans_subtype = 'Misc Procedure Code'
		AND rownum < $LIMIT
};


$STMTFMT_SEL_EPSDT_CODE = qq{
	SELECT epsdt,name,description
	FROM ref_epsdt
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_CATALOG_CODE = qq{
	SELECT icd, name, replace(descr, '''', '`') as descr, DECODE(sex, 'M','MALE', 'F','FEMALE') AS sex,
		DECODE(age, 'N','NEWBORN', 'P','PEDIATRIC', 'M','MATERNAL', 'A','ADULT') AS age,
		non_specific_code, major_diag_category, comorbidity_complication,
		medicare_secondary_payer, manifestation_code, questionable_admission,
		unacceptable_primary_wo, unacceptable_principal, unacceptable_procedure,
		non_specific_procedure, non_covered_procedure, cpts_allowed
	FROM ref_icd
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_CPT_CODE = qq{
	SELECT cpt, name, replace(description, '''', '`') as description, comprehensive_compound_cpts,
		mutual_exclusive_cpts, DECODE(sex, 'M','MALE', 'F','FEMALE') AS sex, unlisted, questionable,
		asc_, non_rep, non_cov
	FROM ref_cpt
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_HCPCS_CODE = qq{
	SELECT hcpcs, name, replace(description, '''', '`') as description
	FROM REF_HCPCS
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_MODIFIER_CODE = qq{
	SELECT abbrev, caption
	FROM hcfa1500_modifier_code
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_SERVICEPLACE_CODE = qq{
	SELECT abbrev, caption
	FROM hcfa1500_service_place_code
	WHERE
		%whereCond%
		AND rownum < $LIMIT
};

$STMTFMT_SEL_SERVICETYPE_CODE = qq{
	SELECT abbrev, caption
	FROM hcfa1500_service_type_code
	WHERE
		%whereCond%
		AND rownum < $LIMIT
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
		{ head => 'Code', url => q{javascript:chooseItem('/lookup/icd/detail/#&{?}#', '#&{?}#', true, '#2#')}, hint => 'Lookup Detailed Data' },
		{ head => 'Name'},
		{ head => 'Description', },
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
		{ head => 'Code', url => q{javascript:chooseItem('/lookup/cpt/detail/#&{?}#', '#&{?}#', true, '#2#')}, hint => 'Lookup Detailed Data' },
		{ head => 'Name' },
		{ head => 'Description', },
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
		{ head => 'Code', url => q{javascript:chooseItem('/lookup/hcpcs/detail/#&{?}#', '#&{?}#', true, '#2#')}, hint => 'Lookup Detailed Data' },
		{ head => 'Name'},
		{ head => 'Description', },
	],
	#rowSepStr => '',
};

$STMTRPTDEFN_SERVCODE_AND_MODIFIER =
{
	#style => 'pane',
	#frame =>
	#{
	#	heading => 'ICD Codes',
	#},
	columnDefn =>
	[
		{ head => 'Code', url => q{javascript:chooseEntry('#&{?}#')}, },
		{ head => 'Name' },
	],
	#rowSepStr => '',
};

$STMTRPTDEFN_EPSDT =
{
	columnDefn =>
	[
		{ head => 'Code', url => q{javascript:chooseEntry('#&{?}#')}, },
		#{ head => 'Name' },
		{ head => 'Description' },
	],
};

$STMTRPTDEFN_MISC_PROCEDURE =
{
	columnDefn =>
	[
		{ head => 'Code', url => q{javascript:chooseEntry('#&{?}#')}, },
		{ head => 'Name' },
		{ head => 'Description' },
	],
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

$STMTMGR_MODIFIER_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_modifier_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_MODIFIER_CODE,
			whereCond => 'abbrev = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_modifier_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_MODIFIER_CODE,
			whereCond => 'upper(caption) = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_modifier_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_MODIFIER_CODE,
			 whereCond => 'abbrev like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_modifier_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_MODIFIER_CODE,
			whereCond => 'upper(caption) like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
);

$STMTMGR_SERVICEPLACE_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_place_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'abbrev = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_place_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'upper(caption) = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_place_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			 whereCond => 'abbrev like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_place_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICEPLACE_CODE,
			whereCond => 'upper(caption) like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
);

$STMTMGR_SERVICETYPE_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_type_code' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'abbrev = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_type_name' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'upper(caption) = ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_type_code_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			 whereCond => 'abbrev like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
	'sel_type_name_like' =>
		{
			_stmtFmt => $STMTFMT_SEL_SERVICETYPE_CODE,
			whereCond => 'upper(caption) like ?',
			publishDefn => $STMTRPTDEFN_SERVCODE_AND_MODIFIER,
		},
);

$STMTMGR_EPSDT_CODE_SEARCH = new App::Statements::Search::Code(
	'sel_epsdt_code' =>
	{
		_stmtFmt => $STMTFMT_SEL_EPSDT_CODE,
		whereCond => 'epsdt = ?',
		publishDefn => $STMTRPTDEFN_EPSDT,
	},

	'sel_epsdt_description' =>
	{
		_stmtFmt => $STMTFMT_SEL_EPSDT_CODE,
		whereCond => 'upper(desciption) = ?',
		publishDefn => $STMTRPTDEFN_EPSDT,
	},
	'sel_epsdt_code_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_EPSDT_CODE,
		whereCond => 'epsdt like ?',
		publishDefn => $STMTRPTDEFN_EPSDT,
	},

	'sel_epsdt_description_like' =>
	{
		_stmtFmt => $STMTFMT_SEL_EPSDT_CODE,
		whereCond => 'upper(description) like ?',
		publishDefn => $STMTRPTDEFN_EPSDT,
	},

);



$STMTMGR_MISC_PROCEDURE_CODE_SEARCH = new App::Statements::Search::Code(
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

);


1;
