create or replace view yearToDateReceiptAnalysis as
select 	t.provider_id as ProviderId,
	p.short_sortable_name as Name,
	decode(iia.payer_type,0,'Personal Receipts', 'Insurance Receipts') as Category_Name, 
	decode(iia.payer_type,0,pm.caption,'PAYMENT') as Transaction_Type,
	ins.plan_name as PolicyName,
	sum(iia.adjustment_amount) as PersonalYearAmount, 
	sum(iia.plan_paid) as InsuranceYearAmount
from 	Transaction t, Invoice i, invoice_billing ib, Invoice_Item ii, 
	Invoice_Item_Adjust iia, Insurance ins, 
	Person_Org_Category poc, person p, payment_method pm
where 	t.trans_id = i.main_transaction
and 	i.invoice_id = ii.parent_id
and 	ii.item_id = iia.parent_id
and 	poc.person_id = t.provider_id
and 	poc.org_id = t.service_facility_id
and	i.invoice_id = ib.invoice_id
and 	ib.bill_ins_id = ins.ins_internal_id(+) 
and 	poc.category = 'Physician'
and 	poc.person_id = p.person_id
and	iia.pay_method = pm.id
and	trunc(iia.pay_date) >= ( select to_date('01/'||'01/'||to_char(sysdate, 'yyyy'), 'mm/dd/yyyy') from dual)
and	trunc(iia.pay_date) <= sysdate
group by t.provider_id,short_sortable_name,decode(iia.payer_type,0,'Personal Receipts', 'Insurance Receipts'),decode(iia.payer_type,0,pm.caption,'PAYMENT'),ins.plan_name
order by Category_Name desc;




create or replace view monthToDateReceiptAnalysis as
select 	iia.pay_date as PayDate,
	t.provider_id as ProviderId,
	p.short_sortable_name as Name,
	decode(iia.payer_type,0,'Personal Receipts', 'Insurance Receipts') as Category_Name, 
	decode(iia.payer_type,0,pm.caption,'PAYMENT') as Transaction_Type,
	ins.plan_name as PolicyName,
	sum(iia.adjustment_amount) as PersonalMonthAmount, 
	sum(iia.plan_paid) as InsuranceMonthAmount
from 	Transaction t, Invoice i, invoice_billing ib, Invoice_Item ii, 
	Invoice_Item_Adjust iia, Insurance ins, 
	Person_Org_Category poc, person p, payment_method pm
where 	t.trans_id = i.main_transaction
and 	i.invoice_id = ii.parent_id
and 	ii.item_id = iia.parent_id
and 	poc.person_id = t.provider_id
and 	poc.org_id = t.service_facility_id
and	i.invoice_id = ib.invoice_id
and 	ib.bill_ins_id = ins.ins_internal_id(+) 
and 	poc.category = 'Physician'
and 	poc.person_id = p.person_id
and	iia.pay_method = pm.id
and	trunc(iia.pay_date) >= ( select to_date(to_char(sysdate, 'mm')||'/01/'||to_char(sysdate, 'yyyy'), 'mm/dd/yyyy') from dual)
and	trunc(iia.pay_date) <= sysdate
group by iia.pay_date,t.provider_id,short_sortable_name,decode(iia.payer_type,0,'Personal Receipts', 'Insurance Receipts'),decode(iia.payer_type,0,pm.caption,'PAYMENT'),ins.plan_name
order by Category_Name desc;




-- select 	y.PROVIDERID,
--	y.NAME,
--	y.CATEGORY_NAME,
--	y.TRANSACTION_TYPE,
--	y.POLICYNAME,
--	decode(y.POLICYNAME, NULL,m.PERSONALMONTHAMOUNT,m.INSURANCEMONTHAMOUNT) as MONTHAMOUNT,
--	decode(y.POLICYNAME, NULL,y.PERSONALYEARAMOUNT,y.INSURANCEYEARAMOUNT) as YEARAMOUNT
--from 	monthToDateReceiptAnalysis m, yearToDateReceiptAnalysis y
--where	m.PROVIDERID(+) = y.PROVIDERID
--and	m.CATEGORY_NAME(+) = y.CATEGORY_NAME
--and	m.TRANSACTION_TYPE(+) = y.TRANSACTION_TYPE
--order by y.CATEGORY_NAME desc 

