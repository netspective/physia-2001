/* This script creates web database user. it should be called as
   sqlplus /NOLOG @create_prod_owner user_name password
*/

connect system/phtem@sdedbs02

drop user &&1 cascade;


create user &&1 identified by &&2 default tablespace TS_DATA temporary tablespace TEMP;

grant webuser to &&1;
grant unlimited tablespace to &&1;
