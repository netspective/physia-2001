
-- /* Start of views for the daily audit report  which lists net charges and receipts per day*/

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


