whenever sqlerror exit sql.sqlcode rollback

--bug 1792

insert into Adjust_Method (id, caption, abbrev) values (4, 'Transfer to Next Payer', '');
insert into Adjust_Method (id, caption, abbrev) values (5, 'Reverse Transfer to Next Payer', '');
insert into Adjust_Method (id, caption, abbrev) values (6, 'Reverse Payment', '');
insert into writeoff_type (id, caption, abbrev) values (11, 'Transfer from Legacy System', '');

--bug 1813

insert into Ethnicity (id, caption) values (5, 'Other');

--bug 1795

insert into Session_Action_Type (id, caption) values (10, 'Prescribe');
insert into Session_Action_Type (id, caption) values (11, 'Refill');
insert into Session_Action_Type (id, caption) values (12, 'Approve');
insert into Session_Action_Type (id, caption) values (13, 'Deny');
insert into Session_Action_Type (id, caption) values (14, 'Submit');
insert into Session_Action_Type (id, caption) values (15, 'Resubmit');


--bug unknown - Thai?

insert into Transaction_Type (id, caption, group_name, icon_img_summ, remarks) 
	values (8026, 'Patient Appointment Alert', 'Alert', 'alert_btn.gif', 
	'Alert requiring action on a patient appointments');


--bug 1336

update INSURANCE_ADDRESS set state=upper(state);
update INSURANCE_ADDRESS_AUD set state=upper(state);
update INVOICE_ADDRESS set state=upper(state);
update INVOICE_ADDRESS_AUD set state=upper(state);
update ORG_ADDRESS set state=upper(state);
update ORG_ADDRESS_AUD set state=upper(state);
update PERSON_ADDRESS set state=upper(state);
update PERSON_ADDRESS_AUD set state=upper(state);
update TRANS_ADDRESS set state=upper(state);
update TRANS_ADDRESS_AUD set state=upper(state);


--bug 1833

update Adjust_Method set caption = 'Auto Capitated Service Adjustment' where id=3;


--bug 1827

insert into Catalog_Entry_Type (id, caption) values (300, 'Labs');
insert into Catalog_Entry_Type (id, caption) values (310, 'Radiology');
insert into Catalog_Entry_Type (id, caption) values (999, 'Other');

insert into Offering_Catalog_Type (id, caption) values (5, 'Lab Test');


--bug 1843

insert into Org_Type (id, caption, group_name) values (12, 'Ancillary Service', 'ancillary-service');



--bug 1652

insert into adjust_method (id, caption, abbrev) values (7, 'Payment Transfer', '');
update adjust_method set caption = 'Transfer Balance to Next Payer' where id = 4;
update adjust_method set caption = 'Reverse Transfer Balance to Next Payer' where id = 5;
update adjust_method set caption = 'Reverse Payment Transfer' where id = 6;
update invoice_item_adjust set adjustment_type = 7 where data_num_a = 1;


--bug 1906

insert into Org_Type (id, caption, group_name) values (13, 'Pharmacy', 'provider');


--bug 1363 Shahbaz Javeed

update OFFERING_CATALOG set flags=1 where catalog_type=4         


commit;
