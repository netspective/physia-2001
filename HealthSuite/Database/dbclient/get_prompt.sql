set termout off
define user_prompt=''

variable sql_prompt varchar2(50)

declare

 v_count_source number;
 v_count_object number;
 v_sql_prompt varchar2(50);
 
begin

 select count(*) into v_count_source from all_source where name = 'GET_SQLPROMPT_F' and owner='SYS';
 Select count(*) into v_count_object from all_objects where owner='SYS' and object_name='GET_SQLPROMPT_F'
 and status='VALID' and object_type='FUNCTION';
 
 :sql_prompt := 'SQL->';
 if v_count_source > 0 and v_count_object > 0 then
  execute immediate 'select rtrim(sys.get_sqlprompt_f) from dual' into v_sql_prompt;
  :sql_prompt := v_sql_prompt;
 end if;
end;
/

column x new_value user_prompt

select :sql_prompt x from dual;

set sqlprompt "&user_prompt"

set termout on

