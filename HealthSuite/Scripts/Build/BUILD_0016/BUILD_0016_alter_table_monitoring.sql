set feedback off
set verify off
set echo off 
set heading off
set termout off

spool alter_table_monitoring.sql

select 'alter table '||table_name||' monitoring;' from user_tables;
  
spool off

set feedback on
set verify on
set echo on 
set heading on
set termout on

  
start alter_table_monitoring


