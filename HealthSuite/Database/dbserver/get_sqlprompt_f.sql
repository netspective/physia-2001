create or replace function get_sqlprompt_f
return varchar2
is

v_host_name varchar2(12);
v_dbname varchar2(10);
v_session_id varchar2(6);
v_serial_nm varchar2(6);
v_user_name varchar2(10);

begin

SELECT d.name into v_dbname from v$database d;

select substr(s.machine,1,decode (instr(s.machine,'.'), 0, length(s.machine), instr(s.machine,'.') - 1)) into v_host_name
FROM V$SESSION s WHERE s.SID=1;

select rtrim(to_char(sid)), rtrim(to_char(serial#)) into v_session_id, v_serial_nm
FROM v$session WHERE audsid = userenv('SESSIONID');

select user into v_user_name from dual;

return v_host_name||':'||v_dbname||':'||v_user_name||':'||v_session_id||':'||v_serial_nm||'->';

end get_sqlprompt_f;
/
show errors;
