whenever sqlerror exit sql.sqlcode;

spool create_db.log 

startup nomount pfile = $ORACLE_HOME/dbs/initSDEDBS02.ora
CREATE DATABASE "SDEDBS02"
   maxdatafiles 254
   maxinstances 8
   maxlogfiles 32
   character set US7ASCII
   national character set US7ASCII
DATAFILE '/u02/oradata/SDEDBS02/SDEDBS02_system01.dbf' SIZE 200M
logfile group 1 ('/u05/oradata/SDEDBS02/SDEDBS02_redo01_a.log',
                 '/u07/oradata/SDEDBS02/SDEDBS02_redo01_b.log') size 10M,
        group 2 ('/u05/oradata/SDEDBS02/SDEDBS02_redo02_a.log',
                 '/u07/oradata/SDEDBS02/SDEDBS02_redo02_b.log') size 10M,
        group 3 ('/u05/oradata/SDEDBS02/SDEDBS02_redo03_a.log',
                 '/u07/oradata/SDEDBS02/SDEDBS02_redo03_b.log') size 10M;

CREATE ROLLBACK SEGMENT r0 TABLESPACE SYSTEM
STORAGE (INITIAL 16K NEXT 16K MINEXTENTS 2 MAXEXTENTS 20);
ALTER ROLLBACK SEGMENT r0 ONLINE;

REM ************** TABLESPACE FOR ROLLBACK *****************
CREATE TABLESPACE RBS DATAFILE '/u02/oradata/SDEDBS02/SDEDBS02_rbs_01.dbf' SIZE 500M 
DEFAULT STORAGE ( INITIAL 1M NEXT 1M  MINEXTENTS 20 MAXEXTENTS 1024 PCTINCREASE 0);

REM ************** TABLESPACE FOR TEMPORARY *****************
CREATE TABLESPACE TEMP DATAFILE '/u02/oradata/SDEDBS02/SDEDBS02_temp_01.dbf' SIZE 300M 
DEFAULT STORAGE ( INITIAL 2M NEXT 2M MINEXTENTS 1 MAXEXTENTS UNLIMITED PCTINCREASE 0) TEMPORARY;

create tablespace USERS datafile '/u03/oradata/SDEDBS02/SDEDBS02_ts_users_01.dbf'
size 70M default storage (pctincrease 0);

create tablespace TOOLS datafile '/u03/oradata/SDEDBS02/SDEDBS02_ts_tools_01.dbf'
size 70M default storage (pctincrease 0);

create tablespace TS_DATA datafile '/u03/oradata/SDEDBS02/SDEDBS02_ts_data_01.dbf'
size 500M minimum extent 1M default storage (initial 1M next 1M maxextents 1024 pctincrease 0);

alter tablespace TS_DATA add datafile '/u03/oradata/SDEDBS02/SDEDBS02_ts_data_02.dbf' size 500M;
alter tablespace TS_DATA add datafile '/u03/oradata/SDEDBS02/SDEDBS02_ts_data_03.dbf' size 500M;


create tablespace TS_INDEXES datafile '/u04/oradata/SDEDBS02/SDEDBS02_ts_indexes_01.dbf'
size 500M minimum extent 1M default storage (initial 1M next 1M maxextents 1024 pctincrease 0);

alter tablespace TS_INDEXES add datafile '/u04/oradata/SDEDBS02/SDEDBS02_ts_indexes_02.dbf' size 500M;
alter tablespace TS_INDEXES add datafile '/u04/oradata/SDEDBS02/SDEDBS02_ts_indexes_03.dbf' size 500M;
alter tablespace TS_INDEXES add datafile '/u04/oradata/SDEDBS02/SDEDBS02_ts_indexes_04.dbf' size 500M;



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

connect system/manager
@$ORACLE_HOME/sqlplus/admin/pupbld.sql

alter user system identified by phtem;
alter user sys identified by phsys;


spool off




