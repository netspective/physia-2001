##############################################################################
package App::Statements::WorklistCollection;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

my $PERSON_ASSOC_VALUE_TYPE = App::Universal::ATTRTYPE_RESOURCEPERSON;
my $RESOURCE_ORG_VALUE_TYPE = App::Universal::ATTRTYPE_RESOURCEORG;
my $TEXT_VALUE_TYPE = App::Universal::ATTRTYPE_TEXT;
my $INT_VALUE_TYPE = App::Universal::ATTRTYPE_INTEGER;
my $FLOAT_VALUE_TYPE = App::Universal::ATTRTYPE_FLOAT;
my $INSURANCE_TYPE_PRODUCT = App::Universal::INSURANCE_PRIMARY;

use vars qw(@ISA @EXPORT $STMTMGR_WORKLIST_COLLECTION);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_COLLECTION);

# -------------------------------------------------------------------------------------------
$STMTMGR_WORKLIST_COLLECTION = new App::Statements::WorklistCollection (	
	'del_worklist_person_assoc' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and value_type = $PERSON_ASSOC_VALUE_TYPE
			and item_name = ?
	},
	'del_worklist_orgvalue' => qq{
		delete from Person_Attribute
		where 
			parent_id = ?
			and parent_org_id = ?
			and value_type = $RESOURCE_ORG_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Org'
	},
	'del_worklist_textvalue' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and value_type = $TEXT_VALUE_TYPE
			and item_name = ?
	},
	'del_worklist_associated_physicians' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $PERSON_ASSOC_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Physician'
	},

	'sel_worklist_available_products' => qq{
		select ins_internal_id as product_id, product_name 
		from Insurance where record_type = $INSURANCE_TYPE_PRODUCT
	},
	'sel_worklist_associated_products' => qq{
		select pa.value_int as product_id, i.product_name
		from Person_Attribute pa, Insurance i
		where 
			parent_id = ?
			and parent_org_id = ?
			and i.ins_internal_id = pa.value_int
			and pa.value_type = $INT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Product'
	},
	'del_worklist_associated_products' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $INT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Product'
	},

	'del_worklist_lastname_range' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $TEXT_VALUE_TYPE
			and item_name = 'WorkListCollectionLNameRange'
	},
	'sel_worklist_lastname_range' => qq{
		select value_text, value_textB as lnameto
		from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $TEXT_VALUE_TYPE
			and item_name = 'WorkListCollectionLNameRange'
	},
	'del_worklist_balance_age_range' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $INT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-BalanceAge-Range'
	},
	'sel_worklist_balance_age_range' => qq{
		select value_int, value_intB as balance_age_to from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $INT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-BalanceAge-Range'
	},
	'del_worklist_balance_amount_range' => qq{
		delete from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $FLOAT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-BalanceAmount-Range'
	},
	'sel_worklist_balance_amount_range' => qq{
		select value_float, value_floatB as balance_amount_to
		from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $FLOAT_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-BalanceAmount-Range'
	},
	'sel_worklist_person_assoc' => qq{
		select value_text as resource_id
		from Person_Attribute
		where parent_id = ?
			and value_type = $PERSON_ASSOC_VALUE_TYPE
			and item_name = ?
	},
	'sel_worklist_unassociated_physicians' => qq{
		select distinct p.person_id, p.complete_name
		from person p, person_org_category pcat
		where p.person_id=pcat.person_id
			and pcat.org_id= ?
			and category='Physician'
			and p.person_id not in 
				(select value_text as person_id
				from Person_Attribute
				where parent_id = ?
				and value_type = $PERSON_ASSOC_VALUE_TYPE
				and item_name = 'WorkList-Collection-Setup-Physician')
	},
	'sel_worklist_available_physicians' => qq{
		select distinct p.person_id, p.complete_name
		from person p, person_org_category pcat
		where p.person_id=pcat.person_id
			and pcat.org_id= ?
			and category='Physician'
	},
	'sel_worklist_associated_physicians' => qq{
		select pa.value_text as person_id, p.complete_name
		from Person_Attribute pa, Person p
		where 
			parent_id = ?
			and p.person_id = pa.value_text
			and value_type = $PERSON_ASSOC_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Physician'
	},
	'sel_worklist_text' => qq{
		select value_text as resource_id
		from Person_Attribute
		where parent_id = ?
			and value_type = $TEXT_VALUE_TYPE
			and item_name = ?
	},
	'sel_worklist_textB' => qq{
		select value_textB as resource_id
		from Person_Attribute
		where parent_id = ?
			and value_type = $TEXT_VALUE_TYPE
			and item_name = ?
	},
	'sel_worklist_facilities' => qq{
		select value_text as facility_id
		from Person_Attribute
		where parent_id = ?
			and parent_org_id = ?
			and value_type = $RESOURCE_ORG_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Org'
	},
	'selPhysicianFromOrg' => qq{
		select distinct p.person_id, p.complete_name from person p, person_org_category pcat
		 where p.person_id=pcat.person_id
		 and pcat.org_id= ?
		 and category='Physician'
	},
	
	'selSchedulePreferences' => qq{
		select item_id, value_text as resource_id, value_textb as facility_id,
			value_int as column_no, value_intb as offset
		from Person_Attribute
		where parent_id = ?
			and item_name = ?
		order by column_no
	},
);

1;
