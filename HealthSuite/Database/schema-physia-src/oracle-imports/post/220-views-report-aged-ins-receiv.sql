create or replace view agedinsdataone as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) >= (sysdate - 30)
and trunc(i.invoice_date) <= sysdate
group by ib.bill_to_id;

create or replace view agedinsdatatwo as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) >= (sysdate - 60)
and trunc(i.invoice_date) <= (sysdate - 31)
group by ib.bill_to_id;

create or replace view agedinsdatathree as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) >= (sysdate - 90)
and trunc(i.invoice_date) <= (sysdate - 61)
group by ib.bill_to_id;

create or replace view agedinsdatafour as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) >= (sysdate - 120)
and trunc(i.invoice_date) <= (sysdate - 91)
group by ib.bill_to_id;

create or replace view agedinsdatafive as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) >= (sysdate - 150)
and trunc(i.invoice_date) <= (sysdate - 121)
group by ib.bill_to_id;

create or replace view agedinsdatasix as
select nvl(ib.bill_to_id, 'UNKNOWN') as insurance, 
sum(i.balance) as balance, count(distinct(client_id)) as patients
from invoice i, invoice_billing ib
where i.invoice_type = 0
and i.invoice_id = ib.invoice_id
and i.invoice_subtype not in (0,7)
and trunc(i.invoice_date) <= (sysdate - 151)
group by ib.bill_to_id;

create or replace view agedinsdata as
select id1.insurance as insurance, id1.patients as patients, nvl(id1.balance,0) as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, (nvl(id1.balance,0)+0+0+0+0+0) as total
from agedinsdataone id1
union all
select id2.insurance as insurance, id2.patients as patients, 0 as ageperiod1, nvl(id2.balance, 0) as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, (0+0+nvl(id2.balance, 0)+0+0+0) as total
from agedinsdatatwo id2
union all
select id3.insurance as insurance, id3.patients as patients, 0 as ageperiod1, 0 as ageperiod2,
nvl(id3.balance, 0) as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
0 as ageperiod6, (0+0+nvl(id3.balance, 0)+0+0+0) as total
from agedinsdatathree id3
union all
select id4.insurance as insurance, id4.patients as patients, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  nvl(id4.balance, 0) as ageperiod4, 0 as ageperiod5,
0 as ageperiod6,
(0+0+0+nvl(id4.balance, 0)+0+0) as total
from agedinsdatafour id4
union all
select id5.insurance as insurance, id5.patients as patients, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, nvl(id5.balance, 0) as ageperiod5,
0 as ageperiod6, (0+0+0+0+nvl(id5.balance, 0)+0) as total
from agedinsdatafive id5
union all
select id6.insurance as insurance, id6.patients as patients, 0 as ageperiod1, 0 as ageperiod2,
0 as ageperiod3,  0 as ageperiod4, 0 as ageperiod5,
nvl(id6.balance, 0) as ageperiod6,  (0+0+0+0+0+nvl(id6.balance, 0)) as total
from agedinsdatasix id6;


--/*************************************************************************
--select 	insurance, sum(patients), sum(ageperiod1), sum(ageperiod2), sum(ageperiod3), 
--		sum(ageperiod4), sum(ageperiod5), sum(ageperiod6), sum(total)
--from 	agedinsdata
--group by insurance

--**************************************************************************/


--/*************************************************************************
--insert into Invoice values (430,NULL,TO_DATE('03/16/2000', 'MM/DD/YYYY'), 
--NULL, 
--NULL,429,NULL,4,0,3,TO_DATE('03/16/2000','MM/DD/YYYY'),NULL,1,'003,008','REF 
--TEST 
--DATA','SJONES',4908,1,'CLMEDGRP',0,'RHACKETT',1,'AETNA',NULL,500,2,0,1000,0,0,0)
--*************************************************************************/



