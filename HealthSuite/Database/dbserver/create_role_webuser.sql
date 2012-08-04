drop role webuser;
create role webuser;

grant create session to webuser;
grant alter session to webuser;
grant create table to webuser;
grant create view to webuser;
grant create procedure to webuser;
grant create sequence to webuser;
grant create synonym to webuser;
grant create trigger to webuser;
grant create database link to webuser;

grant select on v_$mystat to webuser;
grant select on v_$statname to webuser;
grant query_rewrite to webuser;