whenever sqlerror exit sql.sqlcode rollback



--bug 1202 Triggers for auto_invoice_chrg table have been changed to include closed copyed invoice so we need to
-- reload the auto_invoice_chgr table (FRANK MAJOR)

DELETE from Auto_Invoice_Chrg;

INSERT INTO Auto_Invoice_Chrg
(invoice_id,trans_id,item_id,invoice_date,batch_date,batch_id,
charges,invoice_type,item_type,units,unit_cost,
service_facility_id,billing_facility_id,provider_id,care_provider_id,service_begin_date,
service_end_date,code,rel_diags,submitter_id,client_type,client_id,
hcfa_service_type,ffs_flag,owner_org_id,billing_id,trans_type,
parent_invoice_id,invoice_subtype,caption,invoice_status)
SELECT	i.invoice_id,t.trans_id,ii.item_id,i.invoice_date,	
(SELECT ia.value_date FROM invoice_attribute ia WHERE  i.invoice_id = ia.parent_id AND ia.item_name  = 'Invoice/Creation/Batch ID'
and rownum < 2) as value_date,	
(SELECT ia.value_text  FROM invoice_attribute ia WHERE  i.invoice_id = ia.parent_id AND ia.item_name  = 'Invoice/Creation/Batch ID'
and rownum < 2) as value_text,
	extended_cost,	i.invoice_type,	ii.item_type,ii.quantity,	ii.unit_cost,
	t.service_facility_id,	t.billing_facility_id,	t.provider_id,	t.care_provider_id,ii.service_begin_date,
	ii.service_end_date,	ii.code as code, ii.rel_diags as rel_diags,i.SUBMITTER_ID,i.client_type,i.client_id,
	ii.hcfa_service_type,nvl(ii.data_num_a,0) as ffs_cap,i.owner_id,
	i.billing_id,t.trans_type,
	i.parent_invoice_id,	i.invoice_subtype, ii.caption,i.invoice_status
FROM 	invoice i ,  transaction t , invoice_item ii 
WHERE   t.trans_id = i.main_transaction 				
	AND ii.parent_id  = i.invoice_id;
	

INSERT INTO Auto_Invoice_Chrg
(invoice_id,trans_id,adjustment_id,item_id,invoice_date,batch_date,batch_id,
invoice_type,item_type,units,unit_cost,
service_facility_id,billing_facility_id,provider_id,care_provider_id,service_begin_date,
service_end_date,code,rel_diags,submitter_id,client_type,client_id,
hcfa_service_type,ffs_flag,writeoff_code,writeoff_amount,net_adjust,payer_type,payer_id,
pay_type,adjustment_type,adjustment_amount,plan_paid,pay_date,pay_method,
owner_org_id,billing_id,trans_type,
parent_invoice_id,invoice_subtype,caption,invoice_status)
SELECT	i.invoice_id,	t.trans_id,	iia.adjustment_id,	ii.item_id,i.invoice_date,
(
              SELECT ia.value_date FROM invoice_attribute ia WHERE ia.item_name = 'Invoice/Payment/Batch ID' 
	     AND ia.value_int = iia.adjustment_id and rownum < 2
	)batch_Date,		
(              SELECT ia.value_text FROM invoice_attribute ia WHERE ia.item_name = 'Invoice/Payment/Batch ID' 
	     AND ia.value_int = iia.adjustment_id and rownum < 2) as batch_id,
i.invoice_type,	ii.item_type, 0 as quantity,	0 as unit_cost,
t.service_facility_id,	t.billing_facility_id,	t.provider_id,	t.care_provider_id,ii.service_begin_date,	
service_end_date,ii.code,rel_diags,submitter_id,client_type,client_id,
hcfa_service_type,nvl(ii.data_num_a,0) as ffs_cap,iia.writeoff_code,iia.writeoff_amount,net_adjust,payer_type,payer_id,
pay_type,adjustment_type,adjustment_amount,plan_paid,pay_date,pay_method,
i.owner_id as owner_org_id, i.billing_id,
t.trans_type,parent_invoice_id,i.invoice_subtype, ii.caption,i.invoice_status
FROM 	invoice i ,  transaction t ,	
	invoice_item_adjust iia , invoice_item ii
WHERE   t.trans_id = i.main_transaction 			
	AND ii.parent_id  = i.invoice_id
	AND iia.parent_id = ii.item_id;
	


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
