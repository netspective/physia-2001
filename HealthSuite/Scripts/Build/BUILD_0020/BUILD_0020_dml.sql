whenever sqlerror exit sql.sqlcode rollback


--bug 1930 (Munir Faridi)

insert into transaction_type (id, caption, group_name, remarks) values (9040, 'On Call', 'Action', 'This type is created when a provider is on call');

--BUG 2008 (FKM) Move data to new columns in offering_catalog_entry
update offering_catalog_entry
set data_text = modifier,
modifier = name,
name = description
where catalog_id IN
(SELECT internal_catalog_id from offering_catalog where
catalog_type = 5);

commit;
