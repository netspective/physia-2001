
--BUG 642 - FKM - Add New Table Person_Refferal_Note table
start tables/Person_Referral_Note
start tables-code/Person_Referral_Note

--BUG 1482 - TVN - Add new column xraycopay to table Sch_Verify
alter table Sch_Verify     add (XRAYCOPAY NUMBER(12,2));
alter table Sch_Verify_Aud add (XRAYCOPAY NUMBER(12,2));
start tables-code/Sch_Verify