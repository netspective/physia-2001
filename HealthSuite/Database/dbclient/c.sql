connect &1

set termout off
define user_prompt=''

variable sql_prompt varchar2(50)

declare
 v_count number;
 v_sql_prompt varchar2(50);
begin
 select count(*) into v_count from all_synonyms where synonym_name = 'GET_SQLPROMPT_FS';
 :sql_prompt := 'SQL->';
 if v_count > 0 then
  execute immediate 'select rtrim(get_sqlprompt_fs) from dual' into v_sql_prompt;
  :sql_prompt := v_sql_prompt;
 end if;
end;
/

column x new_value user_prompt

select :sql_prompt x from dual;

set sqlprompt "&user_prompt"

set termout on

