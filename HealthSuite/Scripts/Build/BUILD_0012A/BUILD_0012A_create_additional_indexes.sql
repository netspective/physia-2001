drop index trans_owner_id_trans_type;
drop index invitem_parent_id;
drop index invitemadj_parent_id;
drop index invoice_client_id;
drop index invoice_client_id_type;
drop index trans_invoice_id;

create index trans_owner_id_trans_type on transaction (trans_owner_id, trans_type) tablespace ts_indexes;
create index invoice_client_id_type on invoice (client_id, client_type) tablespace ts_indexes;
create index trans_invoice_id on transaction (trans_invoice_id) tablespace ts_indexes;
create index invitem_parent_id on invoice_item (parent_id) tablespace ts_indexes;
create index invitemadj_parent_id on invoice_item_adjust (parent_id) tablespace ts_indexes;







