alter table transaction add (invoice_id number(16));

update transaction set invoice_id=data_num_a where data_num_a is not null and data_num_a>0;

commit;