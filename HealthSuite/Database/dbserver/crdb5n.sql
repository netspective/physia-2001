drop user sde_prime cascade;
create user sde_prime identified by sde default tablespace TS_DATA temporary tablespace TEMP;
grant dba to sde_prime;
