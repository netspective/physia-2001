/* This script creates web database user. 
   Shoud be run by user with DBA privileges from svrmgrl or sqlplus
   
   Should be called as sqlplus userid/passwd@alias @create_prod_owner user_name password 
*/


drop user &&1 cascade;


create user &&1 identified by &&2 default tablespace TS_DATA temporary tablespace TEMP;

grant webuser to &&1;
grant unlimited tablespace to &&1;


