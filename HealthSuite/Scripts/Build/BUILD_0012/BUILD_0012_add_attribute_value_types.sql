/* I incidentally performed this actions on production but we can do it again - no harm, inserts will not work because of 
   integrity constrain */



insert into Attribute_Value_Type (id, caption, dialog_params, group_name, remarks)
values (550, 'Insurance Company Provider Id', 'type="text"', 'Certificate', 'This is the id code assigned by an insurance company to a provider code which authorizes the provider to bill the insurance company for service rendered');
insert into Attribute_Value_Type (id, caption, dialog_params, group_name, remarks)
values (570, 'Tax Id', 'type="text"', 'Certificate', 'Code assigned by a government to a person or a corporation for tax purposes');

update person_attribute pa set pa.name_sort = (select org_id from org where 
org_internal_id = pa.cr_org_internal_id) where item_name in 
('DEA', 'DPS', 'IRS', 'Board 
Certification', 'BCBS', 'Nursing/License', 'Memorial Sisters Charity', 'EPSDT');

update person_attribute pa set pa.value_type = 550, pa.name_sort =
(select org_id from org where org_internal_id = pa.cr_org_internal_id)
where item_name in ('Medicaid', 'Medicare', 'UPIN', 'Tax ID', 'Railroad Medicare', 'Champus', 'WC#', 'National Provider Identification');

commit;

