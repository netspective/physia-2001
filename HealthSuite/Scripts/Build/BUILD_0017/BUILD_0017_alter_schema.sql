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

commit;

-- Alter table Event
-- -----------------
alter table Event add (SUPERBILL_ID NUMBER(16));
alter table Event_AUD add (SUPERBILL_ID NUMBER(16));

alter table Event add constraint EVENT_SUPERBILL_ID_FK FOREIGN KEY(superbill_id) references 
	Offering_Catalog(internal_catalog_id) on delete cascade;
	
create index EVENT_SUPERBILL_ID on Event (superbill_id) TABLESPACE TS_INDEXES;

-- Re-create Event Triggers
-- ------------------------
start tables-code/Event.sql

-- Alter table Appt_Type
-- ---------------------
alter table Appt_Type add (SUPERBILL_ID NUMBER(16));
alter table Appt_Type_Aud add (SUPERBILL_ID NUMBER(16));

alter table Appt_Type add constraint APTYPE_SUPERBILL_ID_FK FOREIGN KEY(superbill_id) 
	references Offering_Catalog(internal_catalog_id) on delete cascade;
	
create index APTYPE_SUPERBILL_ID on Appt_Type (superbill_id) TABLESPACE TS_INDEXES;

-- Re-create Appt_Type Triggers
-- ----------------------------
start tables-code/Appt_Type.sql


-- Alter table Offering_Catalog
-- ----------------------------
alter table Offering_Catalog add (SEQUENCE NUMBER(8));
alter table Offering_Catalog_AUD add (SEQUENCE NUMBER(8));

-- Re-create Offering_Catalog Triggers
-- -----------------------------------
start tables-code/Offering_Catalog.sql


-- Alter table Offering_Catalog_Entry
-- ----------------------------------
alter table Offering_Catalog_Entry add (SEQUENCE NUMBER(8));
alter table Offering_Catalog_Entry_AUD add (SEQUENCE NUMBER(8));

-- Re-create Offering_Catalog_Entry Triggers
-- ----------------------------------------
start tables-code/Offering_Catalog_Entry.sql



create index INVOICE_PARENT_INVOICE_ID on Invoice (parent_invoice_id) TABLESPACE TS_INDEXES;

-- Create Person_Medication table

start tables/Person_Medication.sql
start tables-code/Person_Medication.sql



start post/views-report-month-audit-recap.sql