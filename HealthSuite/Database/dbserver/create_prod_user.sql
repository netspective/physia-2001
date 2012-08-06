/* This script creates user (user name as a parameter) and gives it object privileges to all objects of user
   SDE_PRIME and execute privileges to all procedures, functions and packages of user SDE_PRIME. 
   Also it creates privite synonyms for tables, views, procedures, packages, functions and sequences
   owned by SDE_PRIME
   
   called as /NOLOG @script_name prod_user_name password
   
*/

connect system/phtem@sdedbs02

drop user &&1 cascade;

create user &&1 identified by &&2 default tablespace TS_DATA temporary tablespace TEMP;

grant create session to &&1;
grant unlimited tablespace to &&1;

clear columns
clear breaks
clear computes
ttitle off
btitle off

set serveroutput on size 1000000 format wrapped
set linesize 160
set trimspool on
set feedback off
set timing off
set verify off
set heading off

spool ./tmp/create_prod_user.tmp 

select 'connect sde_prime/sde@sdedbs02' from dual;

select 'grant execute on '||name||' to &&1;' from dba_source where type in ( 'PROCEDURE', 'FUNCTION', 'PACKAGE') and owner = 'SDE_PRIME' group by name;
select 'grant all on '||table_name||' to &&1;' from dba_tables where owner = 'SDE_PRIME';
select 'grant all on '||view_name||' to &&1;' from dba_views where owner = 'SDE_PRIME';
select 'grant select on '||sequence_name||' to &&1;' from dba_sequences where sequence_owner = 'SDE_PRIME';

select 'connect system/phtem@sdedbs02' from dual;

select 'create sysnonym &&1..'||name||' for SDE_PRIME.'||name||';' from dba_source where type in ( 'PROCEDURE', 'FUNCTION', 'PACKAGE') and owner = 'SDE_PRIME' group by name;
select 'create sysnonym &&1..'||table_name||' for SDE_PRIME.'||table_name||';' from dba_tables where owner = 'SDE_PRIME';
select 'create sysnonym &&1..'||view_name||' for SDE_PRIME.'||view_name||';' from dba_views where owner = 'SDE_PRIME';
select 'create sysnonym &&1..'||sequence_name||' for SDE_PRIME.'||sequence_name||';' from dba_sequences where sequence_owner = 'SDE_PRIME';

select 'disconnect' from dual;


spool off

--start create_sde_prod.tmp


set trimspool on
set feedback on
set timing on
set verify on
set heading on
set termout on

clear columns
clear breaks
clear computes
ttitle off
btitle off

--exit