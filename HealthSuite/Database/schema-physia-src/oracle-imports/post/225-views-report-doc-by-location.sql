--***************************************************************************************************

create or replace view PROVIDER_INS_RECEIPTS as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	t.provider_id as providerid, nvl(sum(i.total_cost), 0) as charges
from 	invoice i, transaction t, invoice_billing ib
where 	ib.bill_party_type in (2,3)
and 	i.invoice_id = ib.invoice_id
and 	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, t.provider_id;

create or replace view PROVIDER_PER_RECEIPTS as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	t.provider_id as providerid, nvl(sum(i.total_cost), 0) as charges
from 	invoice i, transaction t, invoice_billing ib
where 	ib.bill_party_type in (0,1)
and 	i.invoice_id = ib.invoice_id
and 	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, t.provider_id;

create or replace view PROVIDER_TOTAL_CHARGES_ADJUST as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	t.provider_id as providerid, nvl(sum(i.total_cost), 0) as charges,
	nvl(sum(i.total_adjust), 0) as charge_adjust
from 	invoice i, transaction t
where	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, t.provider_id;

create or replace view PROVIDER_TOTAL_MISC_CHARGES as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	ii.item_type, t.provider_id as providerid , nvl(sum(ii.extended_cost), 0) as misc_charges
from 	invoice i, transaction t, invoice_item ii
where 	ii.parent_id = i.invoice_id
and 	ii.item_type = 0
and 	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, ii.item_type, t.provider_id;

create or replace view PROVIDER_TOTAL_WRITEOFF_AMOUNT as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	t.provider_id as providerid, nvl(sum(ii.writeoff_amount), 0) as writeoff_amount
from 	invoice i , invoice_item ii, transaction t
where 	ii.parent_id = i.invoice_id
and	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, t.provider_id;

create or replace view PROVIDER_BALANCE_TRANSFERS as
select 	to_char(iia.cr_stamp, 'mm/dd/yyyy') as invoicedate, i.owner_id as org_id,
	t.provider_id as providerid, sum(iia.adjustment_amount) as balance_transfers
from 	Invoice i, Invoice_Item ii, Invoice_Item_Adjust iia, transaction t
where 	i.invoice_id = ii.parent_id
and 	ii.item_id = iia.parent_id
and 	iia.adjustment_type = 2
and	i.main_transaction = t.trans_id
group by to_char(iia.cr_stamp, 'mm/dd/yyyy'),i.owner_id, t.provider_id;

create or replace view PROVIDER_ENDING_AR as
select 	to_char(i.invoice_date, 'mm/dd/yyyy') as invoicedate,
	i.owner_id as org_id, t.provider_id as providerid,
	nvl(sum(i.balance), 0) as ending_ar
from 	invoice i, transaction t
where 	i.invoice_status not in (14, 15)
and	i.main_transaction = t.trans_id
group by to_char(i.invoice_date, 'mm/dd/yyyy'), i.owner_id, t.provider_id;


--***************************************************************************************************

create or replace view PROVIDER_BY_LOCATION as
select 	ptca.invoicedate as DAY_OF_MONTH,
	ptca.org_id as ORG_ID, ptca.providerid as PROVIDER,
	ptca.charges as CHARGES,
	0 as MISC_CHARGES,
	ptca.charge_adjust as CHARGE_ADJUST,
	ptwa.writeoff_amount as INSURANCE_WRITE_OFF,
	(ptca.charges+0+ptca.charge_adjust+ptwa.writeoff_amount) as NET_CHARGES,
	0 as BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, 0+0+0 as TOTAL_RECEIPTS,
	(ptca.charges+0+ptca.charge_adjust+ptwa.writeoff_amount) - (0+0+0) as CHANGE_A_R,
	pea.ending_ar as ENDING_A_R
from 	provider_total_charges_adjust ptca, provider_total_writeoff_amount ptwa,
	provider_ending_ar pea
where 	ptca.invoicedate = ptwa.invoicedate
and 	ptca.invoicedate = pea.invoicedate
and 	ptca.org_id = ptwa.org_id
and 	ptca.org_id = pea.org_id
and 	ptca.providerid = ptwa.providerid
and 	ptca.providerid = pea.providerid
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, providerid as PROVIDER,
	0 as CHARGES,
	MISC_CHARGES,
	0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0+MISC_CHARGES+0+0 as NET_CHARGES, 0 as BALANCE_TRANSFERS,
	0 as PERSONAL_RECEIPTS, 0 as INSURANCE_RECEIPTS,
	0 as TOTAL_RECEIPTS, (0+MISC_CHARGES+0+0) - 0 as CHANGE_A_R,
	0 as ENDING_A_R
from 	provider_total_misc_charges
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, providerid as PROVIDER, 0 as CHARGES,
	0 as MISC_CHARGES, 0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0 as NET_CHARGES, BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, BALANCE_TRANSFERS+0+0 as TOTAL_RECEIPTS,
	0 - BALANCE_TRANSFERS as CHANGE_A_R, 0 as ENDING_A_R
from 	provider_balance_transfers
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, providerid as PROVIDER, 0 as CHARGES,
	0 as MISC_CHARGES, 0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF,
	0 as NET_CHARGES, 0 as BALANCE_TRANSFERS, charges as PERSONAL_RECEIPTS,
	0 as INSURANCE_RECEIPTS, 0+charges+0 as TOTAL_RECEIPTS,
	0 as CHANGE_A_R, 0 as ENDING_A_R
from 	provider_per_receipts
UNION ALL
select 	invoicedate as DAY_OF_MONTH, ORG_ID, providerid as PROVIDER, 0 as CHARGES,
	0 as MISC_CHARGES, 0 as CHARGE_ADJUST, 0 as INSURANCE_WRITE_OFF, 0 as NET_CHARGES,
	0 as BALANCE_TRANSFERS, 0 as PERSONAL_RECEIPTS, charges as INSURANCE_RECEIPTS,
	0+0+charges as TOTAL_RECEIPTS, 0 as CHANGE_A_R, 0 as ENDING_A_R
from 	provider_ins_receipts;
