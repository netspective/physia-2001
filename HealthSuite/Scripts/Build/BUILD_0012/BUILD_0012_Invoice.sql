drop index INVOICE_INVOICE_STATUS;
create index INVOICE_INVOICE_STATUS on Invoice (invoice_status) TABLESPACE TS_INDEXES;
