##############################################################################
package App::Statements::Org;
##############################################################################

use strict;
use Exporter;
use App::Universal;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_ORG $PUBLISH_DEFN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG);

my $ATTRTYPE_PHONE = App::Universal::ATTRTYPE_PHONE;

$STMTMGR_ORG = new App::Statements::Org(
	'selOrgServiceFFSByInternalId' =>qq{
		SELECT 	distinct org_internal_id,oa.value_int
		FROM	Org_Category oc, Org o,Org_Attribute oa
		WHERE   o.owner_org_id = :1
		AND	oc.parent_id = o.org_internal_id
		AND	UPPER(LTRIM(RTRIM(oc.member_name))) IN ('CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE')
		AND	oa.item_name ='Fee Schedules'
		AND	oa.value_type =0
		AND	oa.parent_id = o.org_internal_id
		},
	'selOrgSimpleNameById' => qq{
		select name_primary
		from org
		where org_internal_id = ?
		},
	'selCloseDateChildParentOrgIds' =>qq{
		SELECT	o.org_internal_id
		FROM	org o,Org_Category oc
		WHERE	o.owner_org_id = :1
		AND	( (o.parent_org_id = :2 AND :3 = 1) OR o.org_internal_id = :2 )
		AND	oc.parent_id = o.org_internal_id
		AND	UPPER(LTRIM(RTRIM(oc.member_name))) IN ('CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE')
	},
	'selOwnerOrg' => qq{
		select *
		from org
		where parent_org_id IS NULL AND
		org_id = ?
		},
	'selChildFacilityOrgs' => qq{
		SELECT
			org_id
		FROM 	org
		WHERE 	owner_org_id = ?
		AND     category IN ('Practice','Clinic','Facility/Site','Diagnostic Service','Department','Hospital','Therapeutical Services')
		},
	'selOwnerOrgId' => qq{
		select org_internal_id
		from org
		where parent_org_id IS NULL AND
		org_id = ?
		},
	'selOrg' => qq{
		select *
		from org
		where owner_org_id = ? AND
		org_id = ?
		},
	'selOrgId' => qq{
		select org_internal_id
		from org
		where owner_org_id = ? AND
		org_id = ?
		},
	'selId' => qq{
		select org_id
		from org
		where org_internal_id = ?
		},
	'selRegistry' => qq{
		select *
		from org
		where org_internal_id = ?
		},
	'selCategory' => qq{
		select category
		from org
		where org_internal_id = ?
		},
	'selTaxId' => qq{
		select tax_id
		from org
		where org_internal_id = ?
		},
	'selUpdateOwnerOrgId' => qq{
		update org
		set owner_org_id = ?
		where org_internal_id = ?
		},
	'selPersonCategory' => qq{
		select org_internal_id
		from Org
			where
			(
				owner_org_id in (select org_internal_id from Person_Org_Category where person_id = ?) or
				parent_org_id in (select org_internal_id from Person_Org_Category where person_id = ?)
			)
			and org_internal_id = ?
		},
	'selAttributeByIdValueIntParent' =>qq{
		SELECT	item_id
		FROM	Org_Attribute
		WHERE	parent_id = :1
		AND	value_int = :2
		AND	item_name = :3
		},

	'selAttribute' => qq{
		select * from org_attribute
		where parent_id = ? and item_name = ?
		},
	'selAttributeById' => qq{
		select * from org_attribute
		where item_id = ?
		},
	'selAttributeByValueType' => qq{
		select * from org_attribute
		where parent_id = ? and value_type = ?
		},
	'selAttributeByItemNameAndValueTypeAndParent' => qq{
		select * from org_attribute
		where parent_id = ? and item_name = ? and value_type = ?
		},
	'selAttributeItemDateByItemNameAndValueTypeAndParent' => qq{
		SELECT 	item_id,to_char(value_date,'$SQLSTMT_DEFAULTDATEFORMAT') as value_date,o.org_id
		FROM 	org_attribute oa,org o
		WHERE	oa.parent_id = ? and oa.item_name = ? and oa.value_type = ?
		AND	o.org_internal_id = oa.parent_id
		},		
	'selValueDateByItemNameAndValueTypeAndParent' =>qq{	
		SELECT to_char(value_date,'$SQLSTMT_DEFAULTDATEFORMAT') as value_date
		FROM org_attribute
		WHERE parent_id = :1 and item_name = :2 and value_type = :3
		},
	'selAlerts' => qq{
		select trans_type, trans_id, caption, detail, to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as trans_begin_stamp,
				trans_end_stamp, trans_subtype
		from transaction
		where
			(
			(trans_owner_type = 1 and trans_owner_id = ?)
			)
			and
			(
			trans_type between 8000 and 8999
			)
			and
			(
			trans_status = 2
			)
		order by trans_begin_stamp desc
		},
	'selContactMethods' => qq{
		select * from org_attribute
		where parent_id = ?
		and value_type  in (10, 15, 20, 40, 50)
		order by name_sort, item_name
		},
	'selOrgAddressByAddrName' => qq{
		select *
		from org_address
		where parent_id = ?
		and address_name = ?
		},
	'selOrgAddressById' => qq{
		select *
		from org_address
		where item_id = ?
		},
	'selAddresses' => qq{
		select parent_id, address_name, complete_addr_html
		from org_address where parent_id = ?
		order by address_name
		},
	'selDepartments' => qq{
		select *
					from org org, org_category ocat
					where org.parent_org_id = ?
				and ocat.member_name = 'Department' and ocat.parent_id = org.org_internal_id
	  	 },
	'selMemberNames' => qq{
		select member_name
			from org_category
			where parent_id = ?
		},
	'selHealthRule' => qq{
		select *
			from hlth_maint_rule
			where rule_id = ?
		},
	'selTimeMetric' => qq{
		select id, caption
			from Time_Metric
		},
	'selOrgCategory' => qq{
		select member_name
			from Org_Category
			where parent_id = ?
		},
	'selOrgCategoryRegistry' => qq{
			select distinct o.*, decode(t.group_name, 'other', 'main', t.group_name) as group_name
			from org o, org_category cat, org_type t
			where
				cat.parent_id = o.org_internal_id and
				cat.member_name = t.caption and
				cat.member_name = (
					select caption from org_type
					where id = (
						select min(id)
						from org_type, org_category
						where parent_id = o.org_internal_id and caption = member_name
					)
				) and
			org_internal_id = ?
		},
	'selOrgEligibilityInput' => qq{
			select *
			from org_eligibility_input
			where org_internal_id = ?
			order by field_order
		},
	'selReferralSource' => qq{
		SELECT
			id,
			caption
		FROM Referral_Source_Type
		},
	'selReferralPayor' => qq{
		SELECT
			id,
			caption
		FROM Referral_Payor
		},
	'selReferralService' => qq{
		SELECT
			id,
			caption
		FROM Referral_Service_Type
		},
	'selReferralDetail' => qq{
		SELECT
			id,
			caption
		FROM Referral_Service_Detail
		},
	'selReferralResult' => qq{
		SELECT
			id,
			caption
		FROM Referral_Result
		},
	'selReferralFollowup' => qq{
		SELECT
			id,
			caption
		FROM Referral_Followup_Status
		},
	'selReferralUnitType' => qq{
		SELECT
			id,
			caption
		FROM Referral_Unit_Type
		},
);

1;
