truncate table Invoice_History;

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

commit;