
-- /* Start of views for the daily audit report  which lists net charges and receipts per day*/

create or replace view invoice_charges as
SELECT	invoice_id,
	adjustment_id as adjustment_id,
	batch_date as invoice_date ,
	(decode(invoice_type,0,nvl(charges, 0),0)) as total_charges, 
	(decode(invoice_type,1,nvl(charges, 0),0)) as misc_charges ,
	decode (adjustment_type,0,nvl(adjustment_amount,0),0) as person_pay ,
	nvl(plan_paid,0) as insurance_pay,	
	( nvl(writeoff_amount,0) ) * -1 as charge_adjust ,	
	decode(adjustment_type,2,nvl(net_adjust,0),0) as balance_transfer,
	decode(nvl(payer_type,1),1,nvl(decode(nvl(writeoff_code,0),8,0,9,0,writeoff_amount),0),0)	 as insurance_write_off ,
	decode(payer_type,0,nvl(decode(nvl(writeoff_code,0),8,0,9,0,writeoff_amount),0),0) as person_write_off ,
	0 as a_r,
	nvl(decode(item_type,7,-units ,units),0) as units ,
	nvl(decode(item_type,7,-unit_cost,unit_cost),0) as unit_cost,
	service_facility_id as facility,
	nvl(provider_id,care_provider_id) as provider,
	care_provider_id as care_provider_id,
	batch_id,
	item_type,
	service_begin_date,
	service_end_date,
	code, 
	rel_diags,
	caption,
	SUBMITTER_ID,
	client_id,
	hcfa_service_type,
	invoice_type,
	invoice_subtype,
	ffs_flag as ffs_cap,
	decode(adjustment_type,1,nvl(adjustment_amount,0),0) +
 	decode(writeoff_code,9,writeoff_amount,8,writeoff_amount,0)		 refund,
	pay_method as pay_type,
	trans_id,
	trans_type,
	payer_type,
	payer_id,
	billing_id,
	owner_org_id,
	invoice_status,
	invoice_date as real_invoice_date
FROM	AUTO_INVOICE_CHRG
WHERE 	NOT (invoice_status =15 AND parent_invoice_id is not null);

--create or replace view invoice_charges as
--SELECT	i.invoice_id,
--	ia.value_date invoice_date ,
--	(decode(invoice_type,0,nvl(extended_cost, 0),0)) as total_charges, 
--	(decode(invoice_type,1,nvl(extended_cost, 0),0)) as misc_charges ,
--	0 as person_pay ,
--	0 as insurance_pay,
--	0 as charge_adjust ,
--	0 as net_charges,
--	0 as balance_transfer,
--	0 as insurance_write_off ,
--	0 as person_write_off,
--	0 as a_r,
--	nvl(decode(ii.item_type,7,-ii.quantity ,ii.quantity),0) as units ,
--	nvl(decode(ii.item_type,7,-ii.unit_cost,ii.unit_cost),0) as unit_cost,
--	service_facility_id as facility,
--	nvl(t.provider_id,t.care_provider_id) as provider,
--	ia.value_text as batch_id,
--	ii.item_type as item_type,
--	ii.service_begin_date as service_begin_date,
--	ii.service_end_date as service_end_date,
--	ii.code as code, 
--	ii.rel_diags as rel_diags,
--	ii.caption,
--	i.SUBMITTER_ID,
--	i.client_id,
--	ii.hcfa_service_type,
--	i.invoice_type,
--	i.invoice_subtype,
--	nvl(ii.data_num_a,0) as ffs_cap,
--	0 as refund,
--	NULL as pay_type,
--	t.trans_id,
--	trans_type,
--	i.total_items,
--	to_number(NULL) as payer_type,
--	NULL as payer_id,
--	i.billing_id as billing_id,
--	(SELECT owner_org_id FROM org where org_internal_id = service_facility_id) as owner_org_id
--FROM 	invoice i ,  transaction t , invoice_item ii,invoice_attribute ia 
--WHERE   t.trans_id = i.main_transaction 			
--	AND i.invoice_id = ia.parent_id 
--	AND ii.parent_id  = i.invoice_id
--	AND ia.item_name  = 'Invoice/Creation/Batch ID'		
--	AND NOT (invoice_status =15 AND parent_invoice_id is not null)
--	UNION ALL	
--SELECT	i.invoice_id,
--	(nvl(
---	     (
--              SELECT ia.value_date FROM invoice_attribute ia WHERE ia.item_name = 'Invoice/Payment/Batch ID' 
--	     AND ia.value_int = iia.adjustment_id
--             )
--            ,iia.pay_date
--	     )												
--	)invoice_date,
--	0 as total_charges, 
--	0 as misc_charges ,
--	decode (iia.adjustment_type,0,nvl(iia.adjustment_amount,0),0) as person_pay ,
--	nvl(iia.plan_paid,0) as insurance_pay,	
--	( nvl(iia.writeoff_amount,0) ) * -1 as charge_adjust ,	
--	decode(invoice_type,0,nvl(extended_cost, 0),0) + decode(invoice_type,1,nvl(extended_cost, 0),0) -   nvl(iia.writeoff_amount,0) 	 as net_charges,				
--	decode(iia.adjustment_type,2,nvl(iia.net_adjust,0),0) as balance_transfer,
--	decode(nvl(iia.payer_type,1),1,nvl(decode(nvl(iia.writeoff_code,0),8,0,9,0,iia.writeoff_amount),0),0)	as insurance_write_off ,			
--	decode(iia.payer_type,0,nvl(decode(nvl(iia.writeoff_code,0),8,0,9,0,iia.writeoff_amount),0),0) as person_write_off ,
--	0 as a_r,
--	0 as units ,
--	0 as unit_cost,
--	service_facility_id as facility,
--	nvl(t.provider_id,t.care_provider_id) as provider,
--	(nvl(
--	     (
--              SELECT ia.value_text FROM invoice_attribute ia WHERE ia.item_name = 'Invoice/Payment/Batch ID' 
--	     AND ia.value_int = iia.adjustment_id
--             )
--            ,'AUTO_CREATE_ID'
--	     )												
--	)batch_id,
--	ii.item_type as item_type,
--	ii.service_begin_date as service_begin_date,
--	ii.service_end_date as service_end_date,
--	ii.code as code, 
--	ii.rel_diags as rel_diags,
--	ii.caption,
--	i.SUBMITTER_ID,
--	i.client_id,
--	ii.hcfa_service_type,
--	i.invoice_type,
--	i.invoice_subtype,
--	nvl(ii.data_num_a,0) as ffs_cap,
--	decode(iia.adjustment_type,1,nvl(iia.adjustment_amount,0),0) +
--	decode(iia.writeoff_code,9,iia.writeoff_amount,8,iia.writeoff_amount,0)		as refund,
--	(select pm.caption  FROM payment_method pm WHERE
--	 pm.id = iia.pay_method) pay_type,
--	t.trans_id,
--	trans_type,
--	i.total_items,
--	iia.payer_type as payer_type,
--	iia.payer_id as payer_id,
--	i.billing_id as billing_id,
--	(SELECT owner_org_id FROM org where org_internal_id = service_facility_id) as owner_org_id
--FROM 	invoice i ,  transaction t ,	
---	invoice_item_adjust iia , invoice_item ii
--WHERE   t.trans_id = i.main_transaction 			
--	AND ii.parent_id  = i.invoice_id
--	AND iia.parent_id = ii.item_id
--	AND NOT (invoice_status =15 AND parent_invoice_id is not null);*/
-			

create or replace view REVENUE_COLLECTION as
select  ic.provider,
	ic.care_provider_id,
        ic.invoice_id,
        ic.invoice_date,
        decode(ic.ffs_cap,1,decode(h.ABBREV,'04',0,'05',0,(ic.total_charges)),0) as ffs_prof,
        decode(ffs_cap,1,decode(h.ABBREV,'04',(ic.total_charges),0),0) as x_ray,
        decode(ffs_cap,1,decode(h.ABBREV,'05',(ic.total_charges),0),0) as lab,
        decode(ffs_cap,0,decode(h.ABBREV,'04',0,'05',0,(ic.total_charges)),0) as cap_ffs_prof,
        decode(ffs_cap,0,decode(h.ABBREV,'04',(ic.total_charges),0),0) as cap_x_ray,
        decode(ffs_cap,0,decode(h.ABBREV,'05',(ic.total_charges),0),0) as cap_lab,
        decode(ffs_cap,0,decode(ic.invoice_type,0,(ic.person_pay+ic.insurance_pay),0),0) as cap_pmt,        
	0 as cap_month,	        
        decode(ic.ffs_cap,1,decode(ic.invoice_type,0,(ic.person_pay+ic.insurance_pay),0),0) as ffs_pmt,
        decode(ic.invoice_type,0,decode(h.ABBREV,'04',0,'05',0,(ic.person_pay+ic.insurance_pay)),0) as prof_pmt,
        decode(ic.invoice_type,0,decode(h.ABBREV,'05',(ic.person_pay+ic.insurance_pay),0),0) as lab_pmt,
        decode(ic.invoice_type,0,decode(h.ABBREV,'04',(ic.person_pay+ic.insurance_pay),0),0) as x_ray_pmt,
        decode(ic.invoice_type,1,(ic.person_pay+ic.insurance_pay),0) as ancill_pmt,
       	i.total_items,
        ic.misc_charges,
        ic.invoice_subtype,        
        h.abbrev,
        ic.hcfa_service_type,
        ic.invoice_type,
        ic.facility,
        ic.SUBMITTER_ID,
        ic.batch_id,
        ic.trans_type,
        ic.refund
FROM    invoice_charges ic,HCFA1500_Service_Type_Code h,invoice i
WHERE   hcfa_service_type= h.id(+)
AND	i.invoice_id = ic.invoice_id
UNION ALL	
SELECT  provider_id as provider,
	provider_id as care_provider_id, 
	to_number(NULL)as invoice_id,
	(SELECT value_date FROM trans_attribute ia WHERE ia.item_name = 'Monthly Cap/Payment/Batch ID' 
	 AND parent_id = t.trans_id) as invoice_date,
	0 as ffs_prof,
	0 as x_ray,
	0 as lab,
	0 cap_ffs_prof,
	0 as cap_x_ray,
	0 as cap_lab,
	0 as cap_pmt,
	unit_cost as cap_month,	
	0 as ffs_pmt,
	0 as prof_pmt,
	0 as lab_pmt,
	0 as x_ray_pmt,
	0 as ancill_pmt,
	0 as total_items,
	0 as misc_charges,
	to_number(null) as invoice_subtype,
	null as addrev,
	to_number(null) as hcfa_service_type,
	to_number(null) as invoice_type,
	(SELECT to_number(receiver_id) FROM transaction tt WHERE tt.trans_id = t.trans_id) as facility,
	null as submitted_id,
	(SELECT value_text FROM trans_attribute ia WHERE ia.item_name = 'Monthly Cap/Payment/Batch ID' 
	 AND parent_id = t.trans_id) as batch_id,
	to_number(null) as trans_type,
	0 as refund
FROM	transaction t
WHERE	trans_type = 9030
AND	trans_status  = 7;


--view for total charges and charge_adjust
create or replace view total_charges_adjust as
select 	to_char(invoice_date, 'mm/dd/yyyy') as invoicedate, 
	owner_id as org_id, 
	nvl(sum(total_cost), 0) as charges, 
	nvl(sum(total_adjust), 0) as charge_adjust 
from 	invoice 
group by to_char(invoice_date, 'mm/dd/yyyy'), owner_id;


--view for total misc charges 
create or replace view total_misc_charges as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, 
	i.owner_id as org_id,
	ii.item_type, 
	nvl(sum(ii.extended_cost), 0) as misc_charges 
from 	invoice i , invoice_item ii 
where 	ii.parent_id = i.invoice_id 
and 	ii.item_type = 0 
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, ii.item_type;


--view for total writeoff amount 
create or replace view total_writeoff_amount as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, 
	i.owner_id as org_id,
	nvl(sum(ii.writeoff_amount), 0) as writeoff_amount 
from 	invoice i , invoice_item ii 
where 	ii.parent_id = i.invoice_id 
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id;


--view for personal receipts
create or replace view per_receipts as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate,
	i.owner_id as org_id,
	nvl(sum(i.total_cost), 0) as charges
from 	invoice i, invoice_billing ib
where 	ib.bill_party_type in (0,1)
and	i.invoice_id = ib.invoice_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id;


--view for insurance receipts
create or replace view ins_receipts as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate,
	i.owner_id as org_id,
	nvl(sum(i.total_cost), 0) as charges
from 	invoice i, invoice_billing ib
where 	ib.bill_party_type in (2,3)
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id;


--view for balance transfers
create or replace view balance_transfers as
select 	to_char(iia.cr_stamp, 'mm/dd/yyyy') as invoicedate, 
	i.owner_id as org_id,
	nvl(sum(iia.adjustment_amount), 0) as balance_transfers
from 	Invoice i, Invoice_Item ii, Invoice_Item_Adjust iia
where 	i.invoice_id = ii.parent_id
and     ii.item_id = iia.parent_id
and     iia.adjustment_type = 2
group by to_char(iia.cr_stamp, 'mm/dd/yyyy'),i.owner_id;


--view for accounts receivable
create or replace view ending_ar as
select 	to_char(invoice_date, 'mm/dd/yyyy') as invoicedate, 
	owner_id as org_id,
	nvl(sum(balance), 0) as ending_ar
from 	Invoice
where 	invoice_status not in (14, 15)
group by to_char(invoice_date, 'mm/dd/yyyy'), owner_id;


-- view for adding misc charges and balance transfers to the totals
-- ***************************************************************************************************

create or replace view DAILY_AUDIT_RECAP as
select 	tca.invoicedate as DAY_OF_MONTH, tca.org_id as ORG_ID,
	tca.charges as CHARGES, 0 as MISC_CHARGES,
	tca.charge_adjust as CHARGE_ADJUST,
	twa.writeoff_amount as INSURANCE_WRITE_OFF,
	(tca.charges+0+tca.charge_adjust+twa.writeoff_amount) as NET_CHARGES,
	0 as BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, 0+0+0 as TOTAL_RECEIPTS,
	(tca.charges+0+tca.charge_adjust+twa.writeoff_amount) - (0+0+0) as CHANGE_A_R,
	ea.ending_ar as ENDING_A_R
from 	total_charges_adjust tca, total_writeoff_amount twa,
	ending_ar ea
where 	tca.invoicedate = twa.invoicedate
and 	tca.invoicedate = ea.invoicedate
and 	tca.org_id = twa.org_id
and 	tca.org_id = ea.org_id
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, 0 as CHARGES, MISC_CHARGES,
	0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0+MISC_CHARGES+0+0 as NET_CHARGES, 0 as BALANCE_TRANSFERS,
	0 as PERSONAL_RECEIPTS, 0 as INSURANCE_RECEIPTS,
	0 as TOTAL_RECEIPTS, (0+MISC_CHARGES+0+0) - 0 as CHANGE_A_R,
	0 as ENDING_A_R
from 	total_misc_charges
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, 0 as CHARGES,
	0 as MISC_CHARGES, 0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0 as NET_CHARGES, BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, BALANCE_TRANSFERS+0+0 as TOTAL_RECEIPTS,
	0 - BALANCE_TRANSFERS as CHANGE_A_R, 0 as ENDING_A_R
from 	balance_transfers
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, 0 as CHARGES,
	0 as MISC_CHARGES, 0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0 as NET_CHARGES, 0 as BALANCE_TRANSFERS, charges as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, 0+charges+0 as TOTAL_RECEIPTS,
	0 as CHANGE_A_R, 0 as ENDING_A_R
from 	per_receipts
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, 0 as CHARGES, 0 as MISC_CHARGES,
	0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF, 0 as NET_CHARGES,
	0 as BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS, charges as INSURANCE_RECEIPTS,
	0+0+charges as TOTAL_RECEIPTS, 0 as CHANGE_A_R, 0 as ENDING_A_R
from ins_receipts;

-- ***************************************************************************************************

-- sql statement to be used in perl for daily audit recap

-- select 	DAY_OF_MONTH, 
--	ORG_ID,
--	sum(charges) as CHARGES, 
--	sum(misc_charges) as MISC_CHARGES,
--	sum(charge_adjust) as CHARGE_ADJUST, 
--	sum(insurance_write_off) as INSURANCE_WRITE_OFF, 
--	sum(net_charges) as NET_CHARGES,
--	sum(balance_transfers) as BALANCE_TRANSFERS, 
--	sum(personal_receipts) as PERSONAL_RECEIPTS, 
--	sum(insurance_receipts) as INSURANCE_RECEIPTS,
--	sum(total_receipts) as TOTAL_RECEIPTS, 
--	sum(ending_a_r) as ENDING_A_R
-- from 	daily_audit_recap
-- group by DAY_OF_MONTH, ORG_ID

-- sql statement to be used in perl for monthly audit recap
-- select  to_char(to_date(DAY_OF_MONTH,'mm/dd/yyyy'), 'MON') as Month,
--    ORG_ID,
--    sum(charges) as CHARGES,
--    sum(misc_charges) as MISC_CHARGES,
--    sum(charge_adjust) as CHARGE_ADJUST,
--    sum(insurance_write_off) as INSURANCE_WRITE_OFF,
--    sum(net_charges) as NET_CHARGES,
--    sum(balance_transfers) as BALANCE_TRANSFERS,
--    sum(personal_receipts) as PERSONAL_RECEIPTS,
--    sum(insurance_receipts) as INSURANCE_RECEIPTS,
--    sum(total_receipts) as TOTAL_RECEIPTS,
--    sum(change_a_r) as CHANGE_A_R
--   from  daily_audit_recap */
--   where  day_of_month between '02/28/2000' and '02/28/2000'
--   and org_id = 'CLMEDGRP'
--   group by to_char(to_date(DAY_OF_MONTH,'mm/dd/yyyy'), 'MON'), ORG_ID 


