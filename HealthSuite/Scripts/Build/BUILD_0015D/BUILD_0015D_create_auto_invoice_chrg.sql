start tables/Auto_Invoice_Chrg
start tables-code/Auto_Invoice_Chrg

start pre/pkg-inv-trig

start tables-code/Invoice_denorm
start tables-code/Transaction_denorm
start tables-code/Invoice_Attribute_denorm
start tables-code/Invoice_Item_totals
start tables-code/Invoice_Item_Adjust_totals

start post/views-report-month-audit-recap

--Query One for charges
	INSERT INTO Auto_Invoice_Chrg
	(invoice_id,trans_id,item_id,invoice_date,batch_date,batch_id,
	charges,invoice_type,item_type,units,unit_cost,
	service_facility_id,billing_facility_id,provider_id,care_provider_id,service_begin_date,
	service_end_date,code,rel_diags,submitter_id,client_type,client_id,
	hcfa_service_type,ffs_flag,owner_org_id,billing_id,trans_type,
	parent_invoice_id,invoice_subtype,caption,invoice_status)
	SELECT	i.invoice_id,t.trans_id,ii.item_id,i.invoice_date,	ia.value_date ,	ia.value_text ,
		extended_cost,	i.invoice_type,	ii.item_type,ii.quantity,	ii.unit_cost,
		t.service_facility_id,	t.billing_facility_id,	t.provider_id,	t.care_provider_id,ii.service_begin_date,
		ii.service_end_date,	ii.code as code, ii.rel_diags as rel_diags,i.SUBMITTER_ID,i.client_type,i.client_id,
		ii.hcfa_service_type,nvl(ii.data_num_a,0) as ffs_cap,o.owner_org_id,
		i.billing_id,t.trans_type, i.parent_invoice_id,	i.invoice_subtype, ii.caption,i.invoice_status
	FROM 	invoice i ,  transaction t , invoice_item ii,invoice_attribute ia ,
		org o
	WHERE   t.trans_id = i.main_transaction 			
		AND i.invoice_id = ia.parent_id  (+)
		AND ii.parent_id  = i.invoice_id
		AND ia.item_name (+) = 'Invoice/Creation/Batch ID'		
		AND NOT (invoice_status =15 AND parent_invoice_id is not null)
		AND o.org_internal_id = t.service_facility_id;

--FIRST QUERY TO GET BATCH DATE AND ID
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
		(SELECT owner_org_id FROM org where org_internal_id = service_facility_id) as owner_org_id, i.billing_id,
		t.trans_type,parent_invoice_id,i.invoice_subtype, ii.caption,i.invoice_status
	FROM 	invoice i ,  transaction t ,	
		invoice_item_adjust iia , invoice_item ii
	WHERE   t.trans_id = i.main_transaction 			
		AND ii.parent_id  = i.invoice_id
		AND iia.parent_id = ii.item_id
		AND NOT (invoice_status =15 AND parent_invoice_id is not null);

commit;





