##############################################################################
package App::Statements::Worklist::WorklistCollection;
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
my $ACCOUNT_RECK_DATE = App::Universal::TRANSTYPE_ACCOUNTRECKDATE;
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACCOUNT_NOTES = App::Universal::TRANSTYPE_ACCOUNTNOTES;


use vars qw(@ISA @EXPORT $STMTMGR_WORKLIST_COLLECTION);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_COLLECTION);

# -------------------------------------------------------------------------------------------
$STMTMGR_WORKLIST_COLLECTION = new App::Statements::Worklist::WorklistCollection (	

########################





#'selAccountWatchById'=>qq{
#			
#			select t1.trans_owner_id, p.complete_name, sum(i.balance) as balance
#			from transaction t1, transaction t2,person p, invoice i
#			where t1.provider_id = :1
#			and t1.trans_owner_id = p.person_id			
#			and t1.trans_type = 8520 			
#			and t2.provider_id = :1
#			and t2.trans_owner_id = p.person_id
#			and t2.trans_type = 8510 
#			and t2.trans_subtype = 'Owner' 
#			and t1.trans_owner_id (+)=i.client_id
#			and trunc(t1.trans_begin_stamp) <= to_date(:2,'MM/DD/YYYY')
#			group by t1.trans_owner_id,p.complete_name			
#	
#		     },


'selReckInfoById' =>qq
	{	
		select to_char(trans_begin_stamp,'MM/DD/YYYY') as trans_begin_stamp
		from transaction
		where trans_id = ?
	},
'selAccBalAgeById' =>qq
	{
		select sum (i.balance) as balance , max(round(to_date(:1,'MM/DD/YYYY') - i.invoice_date)) as age
		from  invoice i 
		where	i.client_id = :2		
		group by client_id
	},
				
'selReckDateById' =>qq
	{
		select trans_id,trans_begin_stamp
		from transaction 
		where trans_type = $ACCOUNT_RECK_DATE and
		trans_owner_id = :1 and
		provider_id = :2
		
	},
	
'insAccountOwner' =>qq
	{
		insert into transaction
		(trans_owner_id,provider_id,trans_owner_type,trans_begin_stamp,trans_type,trans_subtype,trans_status,initiator_type,
		initiator_id) 
		values
		( :1, :2, 0,sysdate,$ACCOUNT_OWNER,'Owner',2, 2,:3)
	},

'selPerCollByIdDate' =>qq
	{
		select distinct p2.person_id , 
		(select distinct trans_subtype from transaction t where p2.person_id  = t.trans_owner_id and :1 = provider_id and
		trans_type=$ACCOUNT_OWNER) trans_subtype ,
		(select  trans_id from transaction t where p2.person_id  = t.trans_owner_id and :1 = provider_id and
		trans_type=$ACCOUNT_OWNER) trans_id,
		(select trans_begin_stamp from transaction t3 where t3.trans_type=$ACCOUNT_RECK_DATE and provider_id = :1 and 
		trans_owner_id = p2.person_id )	as reck_date	
		from person p , person p2, person_attribute pan , invoice i, 
		person_attribute pad , person_attribute pat 
		where p.person_id = :1 and		 
		pan.parent_id = p.person_id and
		pad.parent_id = p.person_id and
		pat.parent_id = p.person_id and
		p2.person_id = i.client_id  and				
		pan.item_name = 'WorkListCollectionLNameRange'  and
		pad.item_name = 'WorkList-Collection-Setup-BalanceAge-Range' and
		pat.item_name = 'WorkList-Collection-Setup-BalanceAmount-Range' and
		( i.total_cost >= pat.value_float or pat.value_float is null) and
		( i.total_cost <= pat.value_floatb or pat.value_floatb is null) and
		upper(SUBSTR(p2.Name_last,1,1)) >= upper(pan.Value_Text) and
		upper(SUBSTR(p2.Name_last,1,1)) <= upper(pan.Value_TextB) and				
		( round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) >= pad.value_int or pad.value_int is null) and
		( round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) <= pad.value_intB or pad.value_intB is null) 		
		
		UNION
		
		select trans_owner_id , trans_subtype,trans_id ,
		(select trans_begin_stamp from transaction t3 where t3.trans_type=$ACCOUNT_RECK_DATE and provider_id = :1 and 
		t3.trans_owner_id = t.trans_owner_id )	as reck_date	
		from transaction t
		where provider_id = :1 and
		trans_owner_type = 0 and
		trans_type=$ACCOUNT_OWNER and trans_subtype = 'Owner'
		
		MINUS 
		
		select trans_owner_id , 'Owner', 
		(select  trans_id from transaction t2 where  t.trans_owner_id = t2.trans_owner_id and
		t2.provider_id = :1 and trans_type=$ACCOUNT_OWNER) trans_id,
		(select trans_begin_stamp from transaction t3 where t3.trans_type=$ACCOUNT_RECK_DATE and provider_id = :1 and 
		t3.trans_owner_id = t.trans_owner_id )	as reck_date			
		from transaction t
		where provider_id = :1 and
		trans_owner_type = 0 and
		( 
		 	(trans_type=$ACCOUNT_OWNER and trans_subtype !='Owner') or
		 	(trans_type=$ACCOUNT_RECK_DATE and  to_date(:2,'MM/DD/YYYY') < trunc(trans_begin_stamp) )
		)				
		order by 4 desc
	},
	'selNextApptById' => qq
	{
			select min(to_char(e.start_time,'MM/DD/YYYY')) as appt
			from event e, event_attribute ea
			where ea.item_name = 'Appointment/Attendee/Patient' and value_text = :1 and
			ea.parent_id = e.event_id and
			e.start_time - to_date(:2,'MM/DD/YYYY') >=0
	},
	
	'delAccountNotesById' =>qq
	{
		update transaction set trans_status = 3
		where provider_id = :1 and
		trans_owner_id = :2 and
		trans_type=$ACCOUNT_NOTES
	},
	'TranAccountNotesById' =>qq
	{
			update transaction set provider_id = :1
			where provider_id = :2 and
			trans_owner_id = :3 and
			trans_type=$ACCOUNT_NOTES
	},

#######################



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
			and pcat.org_internal_id= ?
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
