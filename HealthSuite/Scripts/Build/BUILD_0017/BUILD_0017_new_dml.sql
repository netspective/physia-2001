whenever sqlerror exit sql.sqlcode rollback

prompt Inserting into HCFA1500_Modifier_Code

insert into HCFA1500_Modifier_Code (id, caption, abbrev, result) values (116, 'Item or service prov. as routine care in an apprv. clin. trial', 'QV', 2);
insert into HCFA1500_Modifier_Code (id, caption, abbrev, result) values (117, 'Waived test', 'QW', 2);

prompt Inserting into Payment_Type

insert into payment_type (id, caption, group_name) values (8, 'Copay', 'personal');

prompt Populating Invoice_History

delete from invoice_history;

insert into Invoice_History (
	cr_stamp,
	cr_user_id,
	cr_org_internal_id,
	cr_session_id,
	parent_id,
	value_text,
	value_textb,
	value_int,
	value_intb,
	value_float,
	value_floatb,
	value_date,
	value_dateend,
	value_datea,
	value_dateb
)
select
	cr_stamp,
	cr_user_id,
	cr_org_internal_id,
	cr_session_id,
	parent_id,
	value_text,
	value_textb,
	value_int,
	value_intb,
	value_float,
	value_floatb,
	value_date,
	value_dateend,
	value_datea,
	value_dateb
from Invoice_Attribute where item_name = 'Invoice/History/Item';

prompt Add new attribute value type

insert into Attribute_Value_Type (id, caption, dialog_params, group_name, remarks) values (560, 'Board Certification', 'type="text"', 'Certificate', 'This is the board name assigned to a provider code');

insert into Offering_Catalog_Type (id, caption) values (4, 'Superbill');

insert into person_medication
(
	CR_SESSION_ID,
	CR_STAMP,
	CR_USER_ID,
	CR_ORG_INTERNAL_ID,
	PARENT_ID,
	START_DATE,
	APPROVED_BY,
	MED_NAME,
	QUANTITY,
	NUM_REFILLS,
	ALLOW_GENERIC,
	NOTES
)
select cr_session_id,
       cr_stamp,
       cr_user_id,
       cr_org_internal_id,
       trans_owner_id,
       trans_begin_stamp,
       provider_id,
       caption,
       quantity,
       data_num_a,
       data_flag_b,
       data_text_a||' '||detail||' '||data_text_b
from transaction
  where trans_type between 7000 and 7999;
       

commit;
