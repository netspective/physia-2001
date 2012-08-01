create or replace view agedpayments as
SELECT 	i.client_id as person_ID , (i.invoice_id),
	decode(trunc((sysdate-ia.value_date)*6/181),0,ii.balance,0) as balance_0,
	decode(trunc((sysdate-ia.value_date)*6/181),1,ii.balance,0) as balance_31,
	decode(trunc((sysdate-ia.value_date)*6/181),2,ii.balance,0) as balance_61,
	decode(trunc((sysdate-ia.value_date)*6/181),3,ii.balance,0) as balance_91,
	decode(trunc((sysdate-ia.value_date)*6/181),4,ii.balance,0) as balance_121,			
	decode(trunc((sysdate-ia.value_date)*6/181),0,0,1,0,2,0,3,0,4,0,ii.balance) as balance_151,
	ii.balance as total_pending,
	ib.bill_party_type,
	ib.invoice_item_id,
	ii.item_type,
	decode(ib.bill_party_type,0,ib.bill_to_id,1,ib.bill_to_id,(select org_id FROM ORG WHERE org_internal_id = ib.bill_to_id)) as  bill_to_id,
	ib.bill_to_id as bill_plain,
	i.invoice_status,	
	ii.balance,
	ii.extended_cost,
	ii.total_adjust,
	decode(ii.item_type,5,0,7,0,1) as item_count,
	i.invoice_date,
	t.care_provider_id,
	t.service_facility_id,
	i.balance as entire_invoice_balance
FROM	invoice i, invoice_billing ib, invoice_attribute ia, invoice_item ii,Transaction t
WHERE	ib.invoice_id = i.invoice_id
AND	ii.parent_id = i.invoice_id
AND	ia.parent_id = i.invoice_id 
AND	i.main_transaction = t.trans_id
AND	(
		(ia.item_name = 'Invoice/Creation/Batch ID') 
	OR
		(ia.item_name = 'Invoice/Payment/Batch ID' AND t.trans_type = 9030	)
	)
AND 	(invoice_status !=15 or parent_invoice_id is null)
AND 	ib.bill_id = i.billing_id;


create or replace view agedpatientdataone as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) >= (sysdate - 30)
and trunc(i.invoice_date) <= sysdate
group by i.client_id;

create or replace view agedpatientdatatwo as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) >= (sysdate - 60)
and trunc(i.invoice_date) <= (sysdate - 31)
group by i.client_id;


create or replace view agedpatientdatathree as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) >= (sysdate - 90)
and trunc(i.invoice_date) <= (sysdate - 61)
group by i.client_id;

create or replace view agedpatientdatafour as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) >= (sysdate - 120)
and trunc(i.invoice_date) <= (sysdate - 91)
group by i.client_id;

create or replace view agedpatientdatafive as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) >= (sysdate - 150)
and trunc(i.invoice_date) <= (sysdate - 121)
group by i.client_id;


create or replace view agedpatientdatasix as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and trunc(i.invoice_date) <= (sysdate - 151)
group by i.client_id;

create or replace view copay as
select i.client_id as patient, sum(ii.balance) as balance
from invoice i, invoice_item ii
where i.invoice_type = 1
and ii.item_type = 3
and i.invoice_id = ii.parent_id
group by i.client_id;

create or replace view pendinginsurance as
select i.client_id as patient, sum(i.balance) as balance
from invoice i
where i.invoice_type = 0
and i.invoice_subtype not in (0,7)
group by i.client_id;

create or replace view agedpatientdata as
select pd1.patient, nvl(pd1.balance,0) as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, 0 as copay,
(pd1.balance+0+0+0+0+0+0) as total,
0 as insurance
from agedpatientdataone pd1
union all
select pd2.patient, 0 as ageperiod1, nvl(pd2.balance, 0) as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, 0 as copay,
(0+pd2.balance+0+0+0+0+0) as total,
0 as insurance
from agedpatientdatatwo pd2
union all
select pd3.patient, 0 as ageperiod1, 0 as ageperiod2,
nvl(pd3.balance, 0) as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, 0 as copay,
(0+0+pd3.balance+0+0+0+0) as total,
0 as insurance
from agedpatientdatathree pd3
union all
select pd4.patient, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  nvl(pd4.balance, 0) as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, 0 as copay,
(0+0+0+pd4.balance+0+0+0) as total,
0 as insurance
from agedpatientdatafour pd4
union all
select pd5.patient, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, nvl(pd5.balance, 0) as ageperiod5,
0 as ageperiod6, 0 as copay,
(0+0+0+0+pd5.balance+0+0) as total,
0 as insurance
from agedpatientdatafive pd5
union all
select pd6.patient, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
nvl(pd6.balance, 0) as ageperiod6, 0 as copay,
(0+0+0+0+0+pd6.balance+0) as total,
0 as insurance
from agedpatientdatasix pd6
union all
select c.patient, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, nvl(c.balance, 0) as copay,
(0+0+0+0+0+0+c.balance) as total,
0 as insurance
from copay c
union all
select pi.patient, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, 0 as copay, 0 as total, nvl(pi.balance, 0) as insurance
from pendinginsurance pi;


-- /*************************************************************************
-- select 	patient, sum(ageperiod1), sum(ageperiod2), sum(ageperiod3), sum(ageperiod4), 
--	sum(ageperiod5), sum(ageperiod6), sum(copay), sum(total), sum(insurance)
-- from agedpatientdata
-- group by patient

-- **************************************************************************/

