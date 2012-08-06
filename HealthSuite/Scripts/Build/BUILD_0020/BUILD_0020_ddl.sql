alter session set sort_area_size=200000000

--BUG 642 - FKM - Add New Table Person_Refferal_Note table
start tables/Person_Referral_Note
start tables-code/Person_Referral_Note

analyze table Person_Referral_Note compute statistics for table for all indexes for all columns;
alter table Person_Referral_Note monitoring;

--BUG 1482 - TVN - Add new column xraycopay to table Sch_Verify

alter table Sch_Verify     add (XRAYCOPAY NUMBER(12,2));
alter table Sch_Verify_Aud add (XRAYCOPAY NUMBER(12,2));

analyze table Sch_Verify  compute statistics for table for all indexes for all columns;

start tables-code/Sch_Verify

--BUG 2008 - FKM - Added new columns to lab_order_entry table
alter table Lab_Order_Entry add (CAPTION            VARCHAR2(64));
alter table Lab_Order_Entry add (LAB_CODE           VARCHAR2(64));
alter table Lab_Order_Entry add (CHARGE_CODE        VARCHAR2(64));
alter table Lab_Order_Entry add (PHYSICIAN_COST     NUMBER(12,2));
alter table Lab_Order_Entry add (PATIENT_COST       NUMBER(12,2));
alter table Lab_Order_Entry  add(MODIFIER           VARCHAR2(64));
alter table Lab_Order_Entry  add(PANEL_TEST_NAME    VARCHAR2(512));
alter table Lab_Order_Entry  add(PARENT_ENTRY_ID    NUMBER(16));
create index LABORDENT_PARENT_ENTRY_ID on Lab_Order_Entry (parent_entry_id) TABLESPACE TS_INDEXES;

alter table Lab_Order_Entry_Aud add (CAPTION            VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (LAB_CODE           VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (CHARGE_CODE        VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (PHYSICIAN_COST     NUMBER(12,2));
alter table Lab_Order_Entry_Aud add (PATIENT_COST       NUMBER(12,2));
alter table Lab_Order_Entry_Aud add (MODIFIER           VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (PANEL_TEST_NAME    VARCHAR2(512));
alter table Lab_Order_Entry_Aud add(PARENT_ENTRY_ID    NUMBER(16));

analyze table Lab_Order_Entry  compute statistics for table for all indexes for all columns; 

start tables-code/Lab_Order_Entry

--NO BUG - MAF - Added new column to invoice_item_adjust table

alter table Invoice_Item_Adjust add (PARENT_INV_ID	NUMBER(16));
alter table Invoice_Item_Adjust_Aud add (PARENT_INV_ID	NUMBER(16));

analyze table Invoice_Item_Adjust compute statistics for table for all indexes for all columns; 

start tables-code/Invoice_Item_Adjust
