alter table Org add (time_zone_temp varchar2(20));
update Org set time_zone_temp = time_zone where time_zone is not null;
update Org set time_zone = null where time_zone is not null;
alter table Org modify (time_zone varchar2(10));
alter table Org drop (time_zone_temp);

alter table Org_Aud add (time_zone_temp varchar2(20));
update Org_Aud set time_zone_temp = time_zone where time_zone is not null;
update Org_Aud set time_zone = null where time_zone is not null;
alter table Org_Aud modify (time_zone varchar2(10));
alter table Org_Aud drop (time_zone_temp);

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

start tables/Payment_Plan
start tables/Payment_Plan_Inv_ids
start tables-code/Payment_Plan

start tables/Payment_History
start tables-code/Payment_History

delete from Payment_Type where id = 9;
insert into Payment_Type (id, caption, group_name) values (9, 'Budget-payment', 'personal');

insert into Session_Action_Type (id, caption) values (9, 'Setup');
