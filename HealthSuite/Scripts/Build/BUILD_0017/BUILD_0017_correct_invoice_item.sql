whenever sqlerror exit sql.sqlcode rollback

update invoice_item iic set data_num_a = (select data_num_a from invoice_item 
iip where iip.item_id = iic.parent_item_id) where iic.item_type = 7 and 
iic.data_num_a is NULL and exists (select data_num_a from invoice_item iip 
where iip.item_id = iic.parent_item_id);

update invoice_item iic set hcfa_service_place = (select hcfa_service_place 
from invoice_item iip where iip.item_id = iic.parent_item_id) where 
iic.item_type = 7 and iic.hcfa_service_place is NULL and exists (select 
hcfa_service_place from invoice_item iip where iip.item_id = iic.parent_item_id);

update invoice_item iic set hcfa_service_type = (select hcfa_service_type from 
invoice_item iip where iip.item_id = iic.parent_item_id) where iic.item_type = 
7 and iic.hcfa_service_type is NULL and exists (select hcfa_service_type from 
invoice_item iip where iip.item_id = iic.parent_item_id);

commit;
