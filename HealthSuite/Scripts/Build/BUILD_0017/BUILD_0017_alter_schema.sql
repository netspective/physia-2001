alter table Org modify (time_zone varchar2(10));
alter table Org_Aud modify (time_zone varchar2(10));

alter table Invoice add (BUDGET_ID NUMBER(16));
alter table Invoice_Aud add (BUDGET_ID NUMBER(16));
start tables-code/Invoice

drop index INVOICE_BUDGET_ID;
create index INVOICE_BUDGET_ID on Invoice (budget_id) TABLESPACE TS_INDEXES;

drop index INVOICE_OWNER_ID;
create index INVOICE_OWNER_ID on Invoice (owner_id) TABLESPACE TS_INDEXES;

start tables/Invoice_Worklist
start tables-code/Invoice_Worklist

start tables/Transmission_Status
start data/Transmission_Status

start tables/Statement
start tables/Statement_Inv_ids
start tables-code/Statement

alter sequence STMT_INT_STATEMENT_ID_SEQ maxvalue 999999 cycle;

start tables/Invoice_History
start tables-code/Invoice_History

start tables/Invoice_Budget
start tables-code/Invoice_Budget
