Create or Replace view yearToDateReceiptProcAnalysis as
select 	t.provider_id as ProviderId,
	short_sortable_name as Name,
        tt.caption||' '||tt.group_name as DepartmentName,
        ii.code as cptcode, 
        cpt.name as cptname,
        sum(ii.quantity) as YearUnits,
	sum(ii.extended_cost) as YearAmount
from 	Transaction t, Invoice i, Invoice_Item ii, 
	Transaction_type tt, 
	ref_cpt cpt, Person_Org_Category poc, person p
where 	t.trans_id = i.main_transaction
and 	i.invoice_id = ii.parent_id
and 	tt.id = t.trans_type 
and 	ii.code = cpt.cpt
and 	poc.person_id = t.provider_id
and 	poc.org_internal_id = t.service_facility_id
and 	poc.person_id = p.person_id
and 	poc.category = 'Physician'
and	ii.item_type in (1,2)
and	trunc(i.invoice_date) >= ( select to_date('01/'||'01/'||to_char(sysdate, 'yyyy'), 'mm/dd/yyyy') from dual)
and	trunc(i.invoice_date) <= sysdate
group by t.provider_id, short_sortable_name, t.trans_type, tt.caption||' '||tt.group_name, ii.code, cpt.name;



Create or Replace view monthToDateReceiptProcAnalysis as
select 	t.provider_id as ProviderId,
	short_sortable_name as Name,
        tt.caption||' '||tt.group_name as DepartmentName,
        ii.code as cptcode, 
        cpt.name as cptname,
        sum(ii.quantity) as MonthUnits,
	sum(ii.extended_cost) as MonthAmount
from 	Transaction t, Invoice i, Invoice_Item ii, 
	Transaction_type tt, 
	ref_cpt cpt, Person_Org_Category poc, person p
where 	t.trans_id = i.main_transaction
and 	i.invoice_id = ii.parent_id
and 	tt.id = t.trans_type 
and 	ii.code = cpt.cpt
and 	poc.person_id = t.provider_id
and 	poc.org_internal_id = t.service_facility_id
and 	poc.person_id = p.person_id
and 	poc.category = 'Physician'
and	ii.item_type in (1,2)
and	trunc(i.invoice_date) >= ( select to_date(to_char(sysdate, 'mm')||'/01/'||to_char(sysdate, 'yyyy'), 'mm/dd/yyyy') from dual)
and	trunc(i.invoice_date) <= sysdate
group by t.provider_id, short_sortable_name, t.trans_type, tt.caption||' '||tt.group_name, ii.code, cpt.name;




-- select 	y.PROVIDERID,
--	y.NAME,
--	y.DEPARTMENTNAME,
--	y.CPTCODE,
--	y.CPTNAME,
--	m.MONTHUNITS,
--	m.MONTHAMOUNT,
--	y.YEARUNITS,
--	y.YEARAMOUNT
--from 	monthToDateReceiptProcAnalysis m, yearToDateReceiptProcAnalysis y
--where	m.PROVIDERID(+) = y.PROVIDERID
--and	m.CPTCODE(+) = y.CPTCODE
--and	m.CPTNAME(+) = y.CPTNAME
--and	m.DEPARTMENTNAME(+) = y.DEPARTMENTNAME 

