

alter table transaction add (trans_invoice_id number(16));

alter table transaction_aud add (trans_invoice_id number(16));

update transaction set trans_invoice_id=data_num_a where data_num_a is not null and data_num_a>0;

commit;

