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

