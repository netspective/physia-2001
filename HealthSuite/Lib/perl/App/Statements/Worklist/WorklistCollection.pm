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

my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;




use vars qw(@ISA @EXPORT $STMTMGR_WORKLIST_COLLECTION);

@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_WORKLIST_COLLECTION);

# -------------------------------------------------------------------------------------------
$STMTMGR_WORKLIST_COLLECTION = new App::Statements::Worklist::WorklistCollection (	

########################

	'selAccountInfoById' =>qq
	{
  		SELECT 	trans_id,
  			data_num_a as invoice_id ,
  			(SELECT trans_id FROM transaction 
			 WHERE 	trans_owner_id = :1 
			 AND	provider_id = :2
			 AND	trans_status =$ACTIVE	
			 AND 	trans_type = $ACCOUNT_RECK_DATE 	
			 ) as trans_reck_id,
			 provider_id
		FROM 	transaction 
		WHERE	trans_owner_id = :1 
		AND	provider_id = :2
		AND	trans_owner_type= 0
		AND	trans_type = $ACCOUNT_OWNER
		AND	trans_subtype = 'Owner'
		AND	trans_status =$ACTIVE	

	},
	'selCollectionRecordById'=>qq
	{
		SELECT 	trans_id
		FROM	transaction
		WHERE	provider_id = :2
		AND	trans_owner_id = :1
		AND	trans_owner_type= 0
		AND	trans_type = $ACCOUNT_OWNER
		AND	trans_subtype = 'Owner'
		AND	trans_status =$ACTIVE	
		AND	data_num_a = :3
	},
	'delTransferColl' => qq
	{
		UPDATE 	transaction
		SET 	trans_status = $INACTIVE,
			trans_subtype = 'Account Closed',
			trans_status_reason = :1
		WHERE	trans_id in
		(SELECT parent_id
		 FROM 	transaction t, trans_attribute ta
		 WHERE 	ta.parent_id = t,trans_id
		 AND	t.trans_subtype = 'Account Transfered'
		 AND	t.trans_status = $ACTIVE
		 AND	t.trans_type = $ACCOUNT_OWNER
		 AND	trans_owner_id = :2
			AND trans_status = $ACTIVE
			AND trans_type = $ACCOUNT_OWNER
			AND provider_id = :3
		)
	},
	
	'selInColl' =>qq
	{
		SELECT	distinct trans_owner_id
		FROM	transaction
		WHERE	trans_owner_id = :1
		AND	trans_status = $ACTIVE
		AND	trans_subtype= 'Owner'
		AND	trans_type = $ACCOUNT_OWNER		
	},


	'selReckInfoById' => qq
	{
		SELECT 	trans_begin_stamp as reck_date , trans_id as reck_id 
		FROM 	transaction 
		WHERE 	trans_id = :1
	},

	'selReckInfoByOwner' => qq
	{
		SELECT 	trans_begin_stamp as reck_date , trans_id as reck_id 
		FROM 	transaction 
		WHERE 	trans_owner_id = :1
		AND 	trans_type (+)= $ACCOUNT_RECK_DATE 
		AND 	provider_id (+)= :2	
		AND 	trans_status (+)= $ACTIVE
	},

	'delCollectionById'=>qq
	{
		UPDATE 	transaction
		SET 	trans_subtype = 'Account Transfered',
			caption ='Transfer Account',
			trans_status_reason = :1
		WHERE	trans_owner_id = :2
		AND 	trans_status = $ACTIVE
		AND 	trans_type = $ACCOUNT_OWNER
		AND 	provider_id = :3
	
	},

	'closeCollectionById' => qq
	{
		UPDATE 	transaction
		SET 	trans_status = $INACTIVE,
			trans_subtype = 'Account Closed',
			trans_status_reason = :1
		WHERE	trans_owner_id = :2
			AND trans_status = $ACTIVE
			AND trans_type = $ACCOUNT_OWNER
			AND provider_id = :3
	},
	
	'delReckDateById' =>qq
	{
		UPDATE 	transaction 
		SET 	trans_status = $INACTIVE
		WHERE 	trans_type = $ACCOUNT_RECK_DATE 
		AND	trans_owner_id = :1 
		AND	provider_id = :2		
	},
	
	#The data 01/31/1800 is used to make sure the dates sort correctly
	'selPerCollByIdDate' =>qq
	{			
	
		
		SELECT	p.person_id ,NULL as reason,
			i.invoice_id,i.balance,round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) as age,
			(SELECT MIN(iia.comments) FROM invoice_item_adjust iia WHERE parent_id =
			  (SELECT MIN(item_id) FROM invoice_item ii WHERE ii.parent_id = i.invoice_id AND
			   ii.item_type in (0,1,2) )
			) as description ,
			to_number(NULL) as trans_id
		FROM 	person p, person_attribute pf,person_attribute pp,person_attribute pd ,
			person_attribute pl,person_attribute pa, person_attribute pb,
			transaction t, invoice i, invoice_billing ib, person_org_category pog
		WHERE	pf.parent_id = :1
		AND	pp.parent_id = :1
		AND	pd.parent_id = :1
		AND	pl.parent_id = :1
		AND	pa.parent_id = :1
		AND	pb.parent_id = :1
		AND	pf.item_name = 'WorkList-Collection-Setup-Org'
		AND	pp.item_name = 'WorkList-Collection-Setup-Product'
		AND	pd.item_name = 'WorkList-Collection-Setup-Physician' 
		AND	pl.item_name = 'WorkListCollectionLNameRange'
		AND	pa.item_name = 'WorkList-Collection-Setup-BalanceAge-Range'
		AND	pb.item_name = 'WorkList-Collection-Setup-BalanceAmount-Range'
		AND 	p.person_id = pog.person_id
		AND	pog.org_internal_id = :3

		AND NOT EXISTS
		(
			SELECT	trans_owner_id 
			FROM	transaction
			WHERE	trans_type = $ACCOUNT_OWNER
			AND 	trans_status = $ACTIVE
			AND 	provider_id = :1
			AND	trans_owner_id = i.client_id
			AND	trans_owner_id = p.person_id	
			AND	data_num_a = i.invoice_id
		)		
		AND	i.main_transaction = t.trans_id
		AND	i.client_id = p.person_id
		AND	i.invoice_id = ib.invoice_id
		AND	ib.bill_sequence = 1		
		AND 	( SUBSTR(p.name_last,1,1) >= upper(pl.Value_Text)  or pl.Value_Text is NULL)
		AND 	( SUBSTR(p.name_last,1,1) <= upper(pl.Value_TextB) or pl.Value_TextB is NULL)
		AND 	(i.balance >= pb.value_float  OR pb.value_float is null)
		AND 	(i.balance <= pb.value_floatb OR pb.value_floatb is null)
		AND 	(round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) >= pa.value_int OR pa.value_int is null)		
		AND 	(round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) <= pa.value_intB OR pa.value_intB is null) 	
		AND	(t.provider_id = pd.value_text)
		AND	(t.service_facility_id = pf.value_text)
		AND	(
			     ib.bill_party_type IN (0,1) 
			 OR  pp.value_int in
			     (SELECT    product.ins_internal_id	
			     FROM	insurance product, insurance plan
			     WHERE	plan.ins_internal_id = ib.bill_ins_id 
			     AND	plan.product_name = product.product_name
			     AND	product.record_type = $INSURANCE_TYPE_PRODUCT
			     AND	product.owner_org_id = plan.owner_org_id
			     )
			)			
		UNION
		SELECT 	distinct t.trans_owner_id  as person_id	,		
			t.trans_status_reason as reason,	
			i.invoice_id, 
			i.balance,
			round(to_date(:2,'MM/DD/YYYY') - i.invoice_date) as age,
			(SELECT MIN(iia.comments) FROM invoice_item_adjust iia WHERE parent_id =
			  (SELECT MIN(item_id) FROM invoice_item ii WHERE ii.parent_id = i.invoice_id AND
			   ii.item_type in (0,1,2) )
			) as description,
			t.trans_id as trans_id
		FROM 	transaction t ,invoice i
		WHERE 	t.trans_type = $ACCOUNT_OWNER
		AND 	t.trans_status = $ACTIVE
		AND 	t.trans_subtype = 'Owner'
		AND	t.provider_id = :1
		AND	t.data_num_a = i.invoice_id
		AND NOT EXISTS
		(SELECT tr.trans_owner_id
		FROM 	transaction tr
		WHERE	tr.trans_owner_id  = t.trans_owner_id
		AND 	tr.trans_type (+)= $ACCOUNT_RECK_DATE 
		AND 	tr.provider_id (+)= :1	
		AND 	tr.trans_status (+)= $ACTIVE
		AND	trunc(tr.trans_begin_stamp)>to_date(:2,'MM/DD/YYYY')
		)		
		ORDER by 1 

	},						
	'selectBalanceAgeById' => qq
	{
		SELECT 	sum(i.balance) as balance,  MAX(round(to_date(:2,'MM/DD/YYYY') - i.invoice_date)) as age
		FROM	invoice i
		WHERE	i.client_id = :1
		GROUP BY client_id
		
	},
	'selTransCollectionById'=>qq
	{
		SELECT 	tr.trans_begin_stamp reck_date, tr.trans_id as reck_date_id, t.trans_id as trans_id
		FROM 	transaction t, transaction tr
		WHERE 	t.trans_type = $ACCOUNT_OWNER
		AND 	t.trans_status = $ACTIVE
		AND 	t.trans_owner_id = :1
		AND 	t.trans_subtype = 'Owner'
		AND	t.provider_id = :2
		AND	t.data_num_a = :3
		AND 	tr.trans_owner_id (+) = t.trans_owner_id
		AND 	tr.trans_type (+)= $ACCOUNT_RECK_DATE 
		AND 	tr.provider_id (+)= :2	
		AND 	tr.trans_status (+)= $ACTIVE		
	},
	'selNextApptById' => qq
	{
		select min(to_char(e.start_time,'MM/DD/YYYY')) as appt
		from event e, event_attribute ea
		where ea.value_text = :1 
			and ea.item_name = 'Appointment' 
			and ea.value_type = 333
			and e.event_id  = ea.parent_id
			and e.start_time - to_date(:2,'MM/DD/YYYY') >=0
	},
	
	'delAccountNotesById' =>qq
	{
		UPDATE 	transaction set trans_status = $INACTIVE
		WHERE	provider_id = :1 
		AND	trans_owner_id = :2 
		AND	trans_type=$ACCOUNT_NOTES
	},	
	'selAccountTransferIdById' =>qq	
	{
		SELECT 	item_id,parent_id as trans_id
		FROM 	transaction t, trans_attribute ta
		WHERE 	t.trans_owner_id =:1
		AND	t.trans_type = $ACCOUNT_OWNER
		AND	t.trans_subtype = 'Account Transfered'
		AND	t.trans_status =$ACTIVE
		AND	ta.parent_id = t.trans_id
		AND	ta.value_text = :2
		AND	ta.value_textb = :1
	},
	'TransHistoryRecord' =>qq
	{
		INSERT INTO  Trans_Attribute (parent_id, item_type,item_name,value_type,value_text,cr_session_id,
					 cr_user_id,cr_org_internal_id,value_int)		
		SELECT	trans_id,1,'Account/Transfer/History',0,:3,:4,:5,:6,data_num_a
		FROM	transaction
		WHERE	trans_owner_id = :1 
		AND	provider_id = :2
		AND	trans_owner_type= 0
		AND	trans_type = $ACCOUNT_OWNER
		AND	trans_subtype = 'Owner'
		AND	trans_status =$ACTIVE	;

	},
	'TranCollectionById' =>qq
	{
	
		INSERT INTO TRANSACTION	(trans_owner_id,caption,provider_id,trans_owner_type,trans_begin_stamp,trans_type,
					 trans_subtype,trans_status,initiator_type,initiator_id,billing_facility_id,cr_session_id,
					 cr_user_id,cr_org_internal_id,trans_status_reason,data_num_a) 
  		SELECT 	trans_owner_id,'Account Owner',:3,trans_owner_type,trans_begin_stamp,trans_type,
		       	trans_subtype,trans_status,initiator_type,:2,billing_facility_id,:4,:5,:6,:7,data_num_a
		FROM 	transaction
		WHERE	trans_owner_id = :1 
		AND	provider_id = :2
		AND	trans_owner_type= 0
		AND	trans_type = $ACCOUNT_OWNER
		AND	trans_subtype = 'Owner'
		AND	trans_status =$ACTIVE	
		AND NOT EXIST
		(SELECT trans_owner_id
		 FROM transaction
		 WHERE	trans_owner_id = :1 
		 AND	provider_id = :3
		 AND	trans_owner_type= 0
		 AND	trans_type = $ACCOUNT_OWNER
		 AND	trans_subtype = 'Owner'
		 AND	trans_status =$ACTIVE				
		)       
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
		order by product_name
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
		order by i.product_name
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
		select distinct p.person_id, p.complete_name,p.name_last
		from person p, person_org_category pcat
		where p.person_id=pcat.person_id
			and pcat.org_internal_id= ?
			and category='Physician'
		order by p.name_last
	},
	'sel_worklist_associated_physicians' => qq{
		select pa.value_text as person_id, p.complete_name,p.name_last
		from Person_Attribute pa, Person p
		where 
			parent_id = ?
			and p.person_id = pa.value_text
			and value_type = $PERSON_ASSOC_VALUE_TYPE
			and item_name = 'WorkList-Collection-Setup-Physician'
		order by p.name_last
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
