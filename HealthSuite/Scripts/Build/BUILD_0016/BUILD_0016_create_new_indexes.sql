alter session set sort_area_size=200000000;

create index INSREC_OOID_PR_PLAN_RECT on Insurance (owner_org_id, product_name, plan_name, record_type)
       TABLESPACE TS_INDEXES;
       
       
create index INVITEM_ITYPE_PARENT_ID on Invoice_Item (item_type, parent_id) TABLESPACE TS_INDEXES;
       

create index ORG_OWNER_ORG_ID on Org (org_id, owner_org_id) TABLESPACE TS_INDEXES;

create index org_owner_int_id on org (owner_org_id, org_internal_id) tablespace ts_indexes;    
       
       
create index PEROCATG_OID_PID_CAT on person_org_category (org_internal_id, person_id, category);
       
       
create index persess_person_id_data on person_session
       (person_id, status, org_internal_id, remote_host, remote_addr, first_access, last_access); 
       
       
create index trans_type_data on transaction (trans_type, trans_subtype, trans_status, trans_invoice_id); 


create index invoice_client_id on invoice (client_id) tablespace ts_indexes;




create index ORGATTR_PAR_VAL_ITM on Org_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index ORGATTR_VTEXT_PARENT_ID on Org_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index ORGATTR_VTEXTB_PARENT_ID on Org_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index ORGATTR_VINT_PARENT_ID on Org_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index ORGATTR_VDATE_PARENT_ID on Org_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index PERATTR_PAR_VAL_ITM on PERSON_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index PERATTR_VTEXT_PARENT_ID on PERSON_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index PERATTR_VTEXTB_PARENT_ID on PERSON_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index PERATTR_VINT_PARENT_ID on PERSON_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index PERATTR_VDATE_PARENT_ID on PERSON_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index TRANSATTR_PAR_VAL_ITM on TRANS_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index TRANSATTR_VTEXT_PARENT_ID on TRANS_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index TRANSATTR_VTEXTB_PARENT_ID on TRANS_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index TRANSATTR_VINT_PARENT_ID on TRANS_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index TRANSATTR_VDATE_PARENT_ID on TRANS_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index INSATTR_PAR_VAL_ITM on INSURANCE_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index INSATTR_VTEXT_PARENT_ID on INSURANCE_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index INSATTR_VTEXTB_PARENT_ID on INSURANCE_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index INSATTR_VINT_PARENT_ID on INSURANCE_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index INSATTR_VDATE_PARENT_ID on INSURANCE_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index INVATTR_PAR_VAL_ITM on invoice_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index INVATTR_VTEXT_PARENT_ID on invoice_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index INVATTR_VTEXTB_PARENT_ID on invoice_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index INVATTR_VINT_PARENT_ID on invoice_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index INVATTR_VDATE_PARENT_ID on invoice_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index eventattr_PAR_VAL_ITM on event_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index eventattr_VTEXT_PARENT_ID on event_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index eventattr_VTEXTB_PARENT_ID on event_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index eventattr_VINT_PARENT_ID on event_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index eventattr_VDATE_PARENT_ID on event_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;


create index ofcatattr_PAR_VAL_ITM on ofcatalog_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index ofcatattr_VTEXT_PARENT_ID on ofcatalog_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index ofcatattr_VTEXTB_PARENT_ID on ofcatalog_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index ofcatattr_VINT_PARENT_ID on ofcatalog_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index ofcatattr_VDATE_PARENT_ID on ofcatalog_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index ofcatentattr_PAR_VAL_ITM on ofcatentry_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index ofcatentattr_VTEXT_PARENT_ID on ofcatentry_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index ofcatentattr_VTEXTB_PARENT_ID on ofcatentry_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index ofcatentattr_VINT_PARENT_ID on ofcatentry_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index ofcatentattr_VDATE_PARENT_ID on ofcatentry_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;

create index documattr_PAR_VAL_ITM on document_Attribute (parent_id, value_type, item_name) TABLESPACE TS_INDEXES;
create index documattr_VTEXT_PARENT_ID on document_Attribute (value_text, parent_id) TABLESPACE TS_INDEXES;
create index documattr_VTEXTB_PARENT_ID on document_Attribute (value_textb, parent_id) TABLESPACE TS_INDEXES;
create index documattr_VINT_PARENT_ID on document_Attribute (value_int, parent_id) TABLESPACE TS_INDEXES;
create index documattr_VDATE_PARENT_ID on document_Attribute (value_date, parent_id) TABLESPACE TS_INDEXES;