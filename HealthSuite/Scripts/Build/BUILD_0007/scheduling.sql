update Event_Attribute
	set value_textB = (select value_text from Event_Attribute ea
		where ea.parent_id = Event_Attribute.parent_id
			and ea.item_name = 'Appointment/Attendee/Physician')
where item_name = 'Appointment/Attendee/Patient';

delete from Event_Attribute where item_name = 'Appointment/Attendee/Physician';

update Event_Attribute set item_name = 'Appointment';

insert into Attribute_Value_Type (id, caption, dialog_params, group_name) 
	values (333, 'Appointment', 'type="text"', 'Code');
	
update Event_Attribute set value_type = 333;