--bug 1811

alter table offering_catalog add(flags number(16));
alter table offering_catalog_aud add(flags number(16));

analyze table Offering_Catalog compute statistics for table for all indexes for all columns;
analyze table Offering_Catalog_Aud compute statistics for table for all indexes for all columns;

start tables-code/Offering_Catalog

--bug 1803

start tables-code/Invoice_Item_totals
start tables-code/Invoice_Item_Adjust_totals

--bug 1824

start pre/pkg-set

--bug 1827

start tables/Person_Lab_Order
start tables/Person_Lab_Order_Icd
start tables-code/Person_Lab_Order

analyze table Lab_Order compute statistics for table for all indexes for all columns;
alter table Lab_Order monitoring;
analyze table Lab_Order_Icd compute statistics for table for all indexes for all columns;
alter table Lab_Order_Icd monitoring;


start tables/Lab_Order_Entry
start tables/Lab_Order_Entry_Options
start tables-code/Lab_Order_Entry

analyze table Lab_Order_Entry compute statistics for table for all indexes for all columns;
alter table Lab_Order_Entry monitoring;
analyze table Lab_Order_Entry_Options compute statistics for table for all indexes for all columns;
alter table Lab_Order_Entry_Options monitoring;

start tables/Lab_Order_Status
start data/Lab_Order_Status

analyze table Lab_Order_Status compute statistics for table for all indexes for all columns;
alter table Lab_Order_Status monitoring;

start tables/Lab_Order_Priority 
start data/Lab_Order_Priority

analyze table Lab_Order_Priority compute statistics for table for all indexes for all columns;
alter table Lab_Order_Priority monitoring;

start tables/Lab_Order_Transmission
start data/Lab_Order_Transmission 

analyze table Lab_Order_Transmission compute statistics for table for all indexes for all columns;
alter table Lab_Order_Transmission monitoring;

--bug 1762

alter table Document Add (DOC_DEST_IDS VARCHAR2(1024));
alter table Document_Aud Add (DOC_DEST_IDS VARCHAR2(1024));
start tables-code/Document


--bug 1863, 1913, (1899, 1908, 1903 - M.F.)

alter table person_medication add (sale_units varchar2(32));
alter table person_medication_aud add (sale_units varchar2(32);

alter table person_medication add (record_type number(8), first_dose varchar2(64), ongoing number(1), sig varchar2(1024), prescribed_by varchar2(32), label number(1), label_in_spanish number(1), signed number(1));
alter table person_medication_aud add (record_type number(8), first_dose varchar2(64), ongoing number(1), sig varchar2(1024), prescribed_by varchar2(32), label number(1), label_in_spanish number(1), signed number(1));


alter table person_medication modify (dose number(20,6), quantity number(20,6));
alter table person_medication_aud modify (dose number(20,6), quantity number(20,6));

start tables-code/Person_Medication

start tables/Medication_Record_Type
start data/Medication_Record_Type


-- Semnet loading

start pre/create_unique_person_id
