/* This script creates user SDE_PROD and gives it object privileges to all objects of user SDE_PRIME 
   and execute privileges toall procedures, functions and packages of user SDE_PRIME  
*/

connect system/phtem

drop user sde_prod cascade;

create user sde_prod identified by sde default tablespace TS_DATA temporary tablespace TEMP;

grant create session to sde_prod;
grant unlimited tablespace to sde_prod;

clear columns
clear breaks
clear computes
ttitle off
btitle off

set serveroutput on size 1000000 format wrapped
set trimspool on
set feedback off
set timing off
set verify off
set heading off

spool create_sde_prod.tmp

select 'grant execute on '||name||' to sde_prod;' from dba_source where type in ( 'PROCEDURE', 'FUNCTION', 'PACKAGE') and owner = 'SDE_PRIME' group by name;
select 'grant all on '||table_name||' to sde_prod;' from dba_tables where owner = 'SDE_PRIME';
select 'grant select on '||sequence_name||' to sde_prod;' from dba_sequences where sequence_owner = 'SDE_PRIME';

spool off

connect sde_prime/sde

start create_sde_prod.tmp


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

exit