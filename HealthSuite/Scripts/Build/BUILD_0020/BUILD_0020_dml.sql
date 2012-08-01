whenever sqlerror exit sql.sqlcode rollback


--BUG 1930 (MAF)
insert into transaction_type (id, caption, group_name, remarks) values (9040, 'On Call', 'Action', 'This type is created when a provider is on call');


--BUG 2008 (FKM) Move data to new columns in offering_catalog_entry
update offering_catalog_entry
set data_text = modifier,
modifier = substr(name,1,32),
name = description
where catalog_id IN
(SELECT internal_catalog_id from offering_catalog where
catalog_type = 5);


--NO BUG (MAF)
update invoice_item_adjust iia set parent_inv_id = (select ii.parent_id from 
invoice_item ii where ii.item_id = iia.parent_id);



commit;
