whenever sqlerror exit sql.sqlcode rollback

set feedback off
set verify off
set echo off 
set heading off
set termout off

spool update_cr_ret_timestamps.sql

select 'update '||table_name||' set cr_stamp=cr_stamp+5/24, ret_stamp=ret_stamp+5/24;'  from user_tables where table_name like '%AUD';

select 'update '||table_name||' set cr_stamp=cr_stamp+5/24;' from user_tables a where table_name not like '%AUD' and exists
  (select 1 from user_tab_columns b where b.table_name=a.table_name and b.column_name='CR_STAMP');

spool off

set feedback on
set verify on
set echo on 
set heading on
set termout on

exec disable_triggers;

start update_cr_ret_timestamps.sql

host rm update_cr_ret_timestamps.sql


update event set start_time=start_time+5/24, scheduled_stamp=scheduled_stamp+5/24,
checkin_stamp=checkin_stamp+5/24, checkout_stamp=checkout_stamp+5/24, discard_stamp=discard_stamp+5/24;

update SCH_TEMPLATE set start_time=start_time+5/24, end_time=end_time+5/24;

update PERSON_SESSION set first_access=first_access+5/24, last_access=last_access+5/24;

update PERSESS_ACTIVITY set activity_stamp=activity_stamp+5/24;

update PERSESS_VIEW_COUNT set view_init=view_init+5/24, view_latest=view_latest+5/24;

update TRANSACTION set trans_begin_stamp=trans_begin_stamp+5/24, trans_end_stamp=trans_end_stamp+5/24;

commit;

exec enable_triggers;





