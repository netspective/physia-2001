drop user sde_prime cascade;


create user sde_prime identified by sde default tablespace TS_DATA temporary tablespace TEMP;

grant phsde to sde_prime;
grant unlimited tablespace to sde_prime;
