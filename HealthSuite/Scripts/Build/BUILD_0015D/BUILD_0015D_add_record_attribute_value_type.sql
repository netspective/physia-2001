insert into attribute_value_type (id, caption, group_name, remarks)
values (20000, 'Notes', 'Invoice', 'value_text are the notes, value_textb is the user');

insert into attribute_value_type (id, caption, group_name, remarks) VALUES 
(650, 'Billing Event', 'Billing', 'value_int = day,value_text = name_begin, value_textb = name_end, value_float = balance_criteria, value_intb = balance_criteria (1 = greater than, -1 = less than)');

commit;



