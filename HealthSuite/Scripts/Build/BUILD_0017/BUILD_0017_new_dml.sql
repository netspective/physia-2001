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


commit;
