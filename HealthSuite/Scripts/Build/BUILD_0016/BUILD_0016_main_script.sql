whenever sqlerror exit sql.sqlcode rollback

insert into Attribute_Value_Type
values (960, 'Billing Info', NULL, 'Status', NULL, NULL,'value_text = billing id, value_textb = 0/1 (inactive/active), value_int = billing id type, parent_org_id = org_id for which this billing id is valid', NULL);

insert into Invoice_Status (id, caption, abbrev) values (18, 'Awaiting Client Payment', '');
update Invoice_Status set caption = 'Awaiting Insurance Payment' where id = 12;

delete from device_attribute where parent_id is null;
delete from event_attribute where parent_id is null;
delete from insurance_attribute where parent_id is null;
delete from invoice_attribute where parent_id is null;
delete from ofcatalog_attribute where parent_id is null;
delete from ofcatentry_attribute where parent_id is null;
delete from org_attribute where parent_id is null;
delete from person_attribute where parent_id is null;
delete from rsrc_attribute where parent_id is null;
delete from trans_attribute where parent_id is null;

alter table device_attribute modify (PARENT_ID NUMBER(16) constraint DEVATTR_PARENT_ID_REQ NOT NULL);
alter table event_attribute modify (PARENT_ID NUMBER(16) constraint EVENTATTR_PARENT_ID_REQ NOT NULL);
alter table insurance_attribute modify (PARENT_ID NUMBER(16) constraint INSATTR_PARENT_ID_REQ NOT NULL);
alter table invoice_attribute modify (PARENT_ID NUMBER(16) constraint INVATTR_PARENT_ID_REQ NOT NULL);
alter table ofcatalog_attribute modify (PARENT_ID NUMBER(16) constraint OCTATTR_PARENT_ID_REQ NOT NULL);
alter table ofcatentry_attribute modify (PARENT_ID NUMBER(16) constraint OCTENATTR_PARENT_ID_REQ NOT NULL);
alter table org_attribute modify (PARENT_ID NUMBER(16) constraint ORGATTR_PARENT_ID_REQ NOT NULL);
alter table person_attribute modify (PARENT_ID VARCHAR2(16) constraint PERATTR_PARENT_ID_REQ NOT NULL);
alter table rsrc_attribute modify (PARENT_ID NUMBER(16) constraint RSRCATTR_PARENT_ID_REQ NOT NULL);
alter table trans_attribute modify (PARENT_ID NUMBER(16) constraint TRANSATTR_PARENT_ID_REQ NOT NULL);


exec execarbitrarysql('drop Index PERSON_SESSION_PERSON_ID');
exec execarbitrarysql('drop Index INSURANCE_OWNER_PERSON_ID');

Create Index PERSON_SESSION_PERSON_ID on PERSON_SESSION ( PERSON_ID ) tablespace ts_indexes;
Create Index INSURANCE_OWNER_PERSON_ID on INSURANCE ( owner_person_id ) tablespace ts_indexes;


alter table invoice_item add (parent_code varchar2(32));
alter table invoice_item drop (reference);

alter table invoice_item_aud add (parent_code varchar2(32));
alter table invoice_item_aud drop (reference);

start tables-code/Invoice_Item

start tables/Ethnicity
start data/Ethnicity 

start post/views-report-aged-patient-receiv

set long 32000

truncate table ref_cpt;

copy from sde01/sde@sdedbs04 to pro_test/pro@sdedbs04 insert ref_cpt using select * from ref_cpt;



