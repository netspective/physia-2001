##############################################################################
package App::Statements::Org;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@ISA @EXPORT $STMTMGR_ORG $PUBLISH_DEFN);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_ORG);

my $ATTRTYPE_PHONE = App::Universal::ATTRTYPE_PHONE;

$STMTMGR_ORG = new App::Statements::Org(
	'selOrgSimpleNameById' => qq{
			select name_primary from org where org_id = ?
		},
	'selRegistry' => qq{
		select *
		from org
		where org_id = ?
		},
	'selCategory' => qq{
		select category
		from org
		where org_id = ?
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
				and ocat.member_name = 'Department' and ocat.parent_id = org.org_id
	  	 },
	 'selInsOrgName' => qq{
	   	select name_primary, ins_org_id
	   		from org, insurance
	   		where product_name = ?
			and org_id = 'ins_org_id'
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
				cat.parent_id = o.org_id and
				cat.member_name = t.caption and
				cat.member_name = (
					select caption from org_type
					where id = (
						select min(id)
						from org_type, org_category
						where parent_id = o.org_id and caption = member_name
					)
				) and
			org_id = ?
		},
	'selOrgEligibilityInput' => qq{
			select *
			from org_eligibility_input
			where product_id = ?
			and org_id = ?
			order by field_order
		},
);

1;
