
--BUG 642 - FKM - Add New Table Person_Refferal_Note table
start tables/Person_Referral_Note
start tables-code/Person_Referral_Note

--BUG 1482 - TVN - Add new column xraycopay to table Sch_Verify
alter table Sch_Verify     add (XRAYCOPAY NUMBER(12,2));
alter table Sch_Verify_Aud add (XRAYCOPAY NUMBER(12,2));
start tables-code/Sch_Verify

-BUG 2008 - FKM - Added new columns to lab_order_entry table
alter table Lab_Order_Entry add (CAPTION            VARCHAR2(64));
alter table Lab_Order_Entry add (LAB_CODE           VARCHAR2(64));
alter table Lab_Order_Entry add (CHARGE_CODE        VARCHAR2(64));
alter table Lab_Order_Entry add (PHYSICIAN_COST     NUMBER(12,2));
alter table Lab_Order_Entry add (PATIENT_COST       NUMBER(12,2));
alter table Lab_Order_Entry  add(MODIFIER           VARCHAR2(64));
alter table Lab_Order_Entry  add(PANEL_TEST_NAME    VARCHAR2(512));

alter table Lab_Order_Entry_Aud add (CAPTION            VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (LAB_CODE           VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (CHARGE_CODE        VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (PHYSICIAN_COST     NUMBER(12,2));
alter table Lab_Order_Entry_Aud add (PATIENT_COST       NUMBER(12,2));
alter table Lab_Order_Entry_Aud add (MODIFIER           VARCHAR2(64));
alter table Lab_Order_Entry_Aud add (PANEL_TEST_NAME    VARCHAR2(512));
start tables-code/Lab_Order_Entry

