insert into Transaction_Type (id, caption, group_name, icon_img_summ, remarks) 
	values (8025, 'Patient Accounting Alert', 'Alert', 'alert_btn.gif', 
	'Alert requiring action on a patient account');
	
drop index TRANS_OWNER_ID;
	
create index TRANS_OWNER_ID on Transaction (trans_owner_id) TABLESPACE TS_INDEXES;	