whenever sqlerror exit sql.sqlcode rollback


--bug 1930 (Munir Faridi)

insert into transaction_type (id, caption, group_name, remarks) values (9040, 'On Call', 'Action', 'This type is created when a provider is on call');

commit;
