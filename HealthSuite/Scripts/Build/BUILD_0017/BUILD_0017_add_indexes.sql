drop index INVOICE_OWNER_ID;
create index INVOICE_OWNER_ID on Invoice (owner_id) TABLESPACE TS_INDEXES;

