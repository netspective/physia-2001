spool create_db.log 

startup nomount pfile = $ORACLE_HOME/dbs/initSDETEST.ora
CREATE DATABASE "SDETEST"
   maxdatafiles 254
   maxinstances 8
   maxlogfiles 32
   character set US7ASCII
   national character set US7ASCII
DATAFILE '/u02/oradata/SDETEST/SDETEST_system01.dbf' SIZE 200M
logfile group 1 ('/u03/oradata/SDETEST/SDETEST_redo01_a.log',
                 '/home/u01/app/oradata/SDETEST/SDETEST_redo01_b.log') size 10M,
group 2 ('/u03/oradata/SDETEST/SDETEST_redo02_a.log',
                 '/home/u01/app/oradata/SDETEST/SDETEST_redo02_b.log') size 10M,
group 3 ('/u03/oradata/SDETEST/SDETEST_redo03_a.log',
                 '/home/u01/app/oradata/SDETEST/SDETEST_redo03_b.log') size 10M;

CREATE ROLLBACK SEGMENT r0 TABLESPACE SYSTEM
STORAGE (INITIAL 16K NEXT 16K MINEXTENTS 2 MAXEXTENTS 20);
ALTER ROLLBACK SEGMENT r0 ONLINE;

REM ************** TABLESPACE FOR ROLLBACK *****************
CREATE TABLESPACE RBS DATAFILE '/u04/oradata/SDETEST/SDETEST_rbs01.dbf' SIZE 500M 
DEFAULT STORAGE ( INITIAL 1M NEXT 1M  MINEXTENTS 20 MAXEXTENTS 1024 PCTINCREASE 0);

REM ************** TABLESPACE FOR TEMPORARY *****************
CREATE TABLESPACE TEMP DATAFILE '/u05/oradata/SDETEST/SDETEST_temp01.dbf' SIZE 300M 
DEFAULT STORAGE ( INITIAL 2M NEXT 2M MINEXTENTS 1 MAXEXTENTS UNLIMITED PCTINCREASE 0) TEMPORARY;

create tablespace USERS datafile '/u06/oradata/SDETEST/SDETEST_ts_users.dbf'
size 70M default storage (pctincrease 0);

create tablespace TOOLS datafile '/u06/oradata/SDETEST/SDETEST_ts_tools.dbf'
size 70M default storage (pctincrease 0);

create tablespace TS_DATA datafile '/u06/oradata/SDETEST/SDETEST_ts_data_1.dbf'
size 500M minimum extent 1M default storage (initial 1M next 1M maxextents 1024 pctincrease 0);

alter tablespace TS_DATA add datafile '/u06/oradata/SDETEST/SDETEST_ts_data_2.dbf' size 500M;

create tablespace TS_INDEXES datafile '/u07/oradata/SDETEST/SDETEST_ts_indexes_1.dbf'
size 1500M minimum extent 1M default storage (initial 1M next 1M maxextents 1024 pctincrease 0);


REM **** Creating four rollback segments ****************
CREATE ROLLBACK SEGMENT r01 TABLESPACE RBS;
CREATE ROLLBACK SEGMENT r02 TABLESPACE RBS;
CREATE ROLLBACK SEGMENT r03 TABLESPACE RBS;
CREATE ROLLBACK SEGMENT r04 TABLESPACE RBS;

ALTER ROLLBACK SEGMENT r01 ONLINE;
ALTER ROLLBACK SEGMENT r02 ONLINE;
ALTER ROLLBACK SEGMENT r03 ONLINE;
ALTER ROLLBACK SEGMENT r04 ONLINE;

ALTER ROLLBACK SEGMENT r0 OFFLINE;

DROP ROLLBACK SEGMENT r0;

REM **** SYS and SYSTEM users ****************
alter user sys temporary tablespace TEMP;
alter user system default tablespace TOOLS temporary tablespace TEMP;


@$ORACLE_HOME/rdbms/admin/catalog.sql
@$ORACLE_HOME/rdbms/admin/catproc.sql
@$ORACLE_HOME/rdbms/admin/catblock.sql
@$ORACLE_HOME/rdbms/admin/catparr.sql

@$ORACLE_HOME/rdbms/admin/dbmspool.sql
@$ORACLE_HOME/rdbms/admin/prvtpool.plb

@$ORACLE_HOME/rdbms/admin/utltkprf.sql
@$ORACLE_HOME/sqlplus/admin/plustrce.sql

connect system/manager
@$ORACLE_HOME/sqlplus/admin/pupbld.sql

alter user system identified by phtem;
alter user sys identified by phsys;


spool off




