##############################################################################
package App::Statements::Report::PhysicianLicense;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;
use vars qw(@ISA @EXPORT $STMTMGR_REPORT_PHYSICIAN_LICENSE $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN $STMTRPTDEFN_PHYSICIAN_LICENSE);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_REPORT_PHYSICIAN_LICENSE $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN $STMTRPTDEFN_PHYSICIAN_LICENSE);

$STMTRPTDEFN_PHYSICIAN_LICENSE =
{
	columnDefn =>
		[
			{ colIdx => 0, head => 'Physician ID', dataFmt => '<A HREF = "/person/#0#/profile">#0#</A>' },
			{ colIdx => 1, head => 'Name', tAlign=>'left', ,dataFmt => '#1#',dAlign =>'left' },
			{ colIdx => 2, head => 'Facility ID', dataFmt => '#2#'},
			{ colIdx => 3, head => 'License Name', dataFmt => '#3#'},
			{ colIdx => 4, head => 'License No.', dataFmt => '#4#'},
			{ colIdx => 5, head => 'Expiry Date', dataFmt => '#5#'},
		],
};
#		and poc.category = 'Physician'

$STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN = qq
{

	SELECT
		p.person_id,
		p.simple_name,
		pa.name_sort facility_id,
		pa.item_name license_name,
		pa.value_text license_number,
		pa.value_dateend expiry_date
	FROM
		person p, person_attribute pa, person_org_category poc
	WHERE
		p.person_id = poc.person_id
		and poc.org_internal_id = :1
		and p.person_id = pa.parent_id
		and pa.value_type in (
			@{[ App::Universal::ATTRTYPE_LICENSE ]},
			@{[ App::Universal::ATTRTYPE_STATE ]},
			@{[ App::Universal::ATTRTYPE_ACCREDITATION ]},
			@{[ App::Universal::ATTRTYPE_SPECIALTY ]},
			@{[ App::Universal::ATTRTYPE_PROVIDER_NUMBER ]},
			@{[App::Universal::ATTRTYPE_BOARD_CERTIFICATION]}
		)
		and pa.item_name not in ('Nurse/Title', 'RN', 'Driver/License', 'Employee')
		%whereClause%
		order by name_last, name_first, pa.name_sort, pa.item_name

};

$STMTMGR_REPORT_PHYSICIAN_LICENSE = new App::Statements::Report::PhysicianLicense(
	'sel_physician_license' =>
	{
		sqlStmt => $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN,
		whereClause => "",
		publishDefn => $STMTRPTDEFN_PHYSICIAN_LICENSE,
	},

	'sel_physician_license_prov' =>
	{
		sqlStmt => $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN,
		whereClause => "and p.person_id = :2",
		publishDefn => $STMTRPTDEFN_PHYSICIAN_LICENSE,
	},

	'sel_physician_license_exp' =>
	{
		sqlStmt => $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN,
		whereClause => "and to_char(pa.value_dateend, 'mm/yyyy') = :2",
		publishDefn => $STMTRPTDEFN_PHYSICIAN_LICENSE,
	},

	'sel_physician_license_prov_exp' =>
	{
		sqlStmt => $STMTMGR_REPORT_PHYSICIAN_LICENSE_MAIN,
		whereClause => "and p.person_id = :2  and to_char(pa.value_dateend, 'mm/yyyy') = :3 ",
		publishDefn => $STMTRPTDEFN_PHYSICIAN_LICENSE,
	},

);

1;