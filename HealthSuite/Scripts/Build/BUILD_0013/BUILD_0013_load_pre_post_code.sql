@load_pre
@load_post
@load_tables-code

select object_type, object_name from user_objects where status='INVALID' order by object_type;

select constraint_name, constraint_type from user_constraints where status='DISABLED' order by constraint_name;