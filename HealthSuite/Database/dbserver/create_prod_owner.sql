/* This script creates web database user. 
   Shoud be run by user with DBA privileges from svrmgrl or sqlplus
   
   Should be called as sqlplus userid/passwd@alias @create_prod_owner user_name password 
*/


set feedback off
set verify off
set echo off 
set heading off
set termout off

spool kill_owner_sessions.sql

select 'alter system kill session '''||rtrim(to_char(sid))||','||rtrim(to_char(serial#))||''';'
from v$session where username=upper('&&1');

spool off

set feedback on
set verify on
set echo on 
set heading on
set termout on

start kill_owner_sessions

host rm kill_owner_sessions.sql

drop user &&1 cascade;

create user &&1 identified by &&2 default tablespace TS_DATA temporary tablespace TEMP;

grant webuser to &&1;
grant unlimited tablespace to &&1;


