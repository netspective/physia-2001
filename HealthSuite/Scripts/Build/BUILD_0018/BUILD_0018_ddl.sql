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

start tables/Lab_Order
start tables-code/Lab_Order

analyze table Lab_Order compute statistics for table for all indexes for all columns;
alter table Lab_Order monitoring;

start tables/Lab_Order_Entry
start tables-code/Lab_Order_Entry

analyze table Lab_Order_Entry compute statistics for table for all indexes for all columns;
alter table Lab_Order_Entry monitoring;

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

