##############################################################################
package App::Statements::IntelliCode;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_INTELLICODE);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_INTELLICODE);

$STMTMGR_INTELLICODE = new App::Statements::IntelliCode(

	'selIcdData' => qq{
		select * from REF_ICD where icd = ?
	},

	'selCptData' => qq{
		select * from REF_CPT where cpt = ?
	},

	'selIcdUsage1' => qq{
		select parent_id from REF_ICD_USAGE where parent_id = ? and person_id = ? and org_id = ?
	},

	'selIcdUsage2' => qq{
		select parent_id from REF_ICD_USAGE where parent_id = ? and person_id is NULL and org_id = ?
	},

	'updIcdUsage1' => qq{
		update REF_ICD_USAGE set read_count = read_count +1
		where parent_id = ? and person_id = ? and org_id = ?
	},

	'updIcdUsage2' => qq{
		update REF_ICD_USAGE set read_count = read_count +1
		where parent_id = ? and person_id is NULL and org_id = ?
	},

	'selCptUsage1' => qq{
		select parent_id from REF_CPT_USAGE where parent_id = ? and person_id = ? and org_id = ?
	},

	'selCptUsage2' => qq{
		select parent_id from REF_CPT_USAGE where parent_id = ? and person_id is NULL and org_id = ?
	},

	'updCptUsage1' => qq{
		update REF_CPT_USAGE set read_count = read_count +1
		where parent_id = ? and person_id = ? and org_id = ?
	},

	'updCptUsage2' => qq{
		update REF_CPT_USAGE set read_count = read_count +1
		where parent_id = ? and person_id is NULL and org_id = ?
	},

	'selHcpcsUsage1' => qq{
		select parent_id from REF_HCPCS_USAGE where parent_id = ? and person_id = ? and org_id = ?
	},

	'selHcpcsUsage2' => qq{
		select parent_id from REF_HCPCS_USAGE where parent_id = ? and person_id is NULL and org_id = ?
	},

	'updHcpcsUsage1' => qq{
		update REF_HCPCS_USAGE set read_count = read_count +1
		where parent_id = ? and person_id = ? and org_id = ?
	},

	'updHcpcsUsage2' => qq{
		update REF_HCPCS_USAGE set read_count = read_count +1
		where parent_id = ? and person_id is NULL and org_id = ?
	},

	'insIcdUsage' => qq{
		insert into REF_ICD_USAGE (parent_id, person_id, org_id, read_count)
		values (?, ?, ?, 1)
	},

	'insCptUsage' => qq{
		insert into REF_CPT_USAGE (parent_id, person_id, org_id, read_count)
		values (?, ?, ?, 1)
	},

	'insHcpcsUsage' => qq{
		insert into REF_HCPCS_USAGE (parent_id, person_id, org_id, read_count)
		values (?, ?, ?, 1)
	},
	
	# ----RVRBS CALCS ---------------------------------------------------------------------
	
	'sel_pfs_rvu_by_code_modifier' => qq{
		select * from Ref_Pfs_Rvu 
		where code = upper(:1)
			and modifier = :2
			and eff_begin_date <= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT')
			and eff_end_date >= to_date(:3, '$SQLSTMT_DEFAULTDATEFORMAT')
	},

	'sel_pfs_rvu_by_code' => qq{
		select * from Ref_Pfs_Rvu 
		where code = upper(:1)
			and modifier is NULL
			and eff_begin_date <= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
			and eff_end_date >= to_date(:2, '$SQLSTMT_DEFAULTDATEFORMAT')
	},
	
	'sel_gpci' => qq{
		select * from Ref_Gpci
		where gpci_id = ?
	},

);

1;
