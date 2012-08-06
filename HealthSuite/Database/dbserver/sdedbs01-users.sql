drop user sde01 cascade;
create user sde01 identified by sde;
grant dba to sde01;

drop user pilot01 cascade;
create user pilot01 identified by pilot;
grant dba to pilot01;

exit;
