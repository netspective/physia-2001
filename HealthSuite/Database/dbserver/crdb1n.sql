startup nomount pfile = $ORACLE_HOME/dbs/initsdedbs02.ora
CREATE DATABASE "SDEDBS02"
   maxdatafiles 254
   maxinstances 8
   maxlogfiles 32
   character set US7ASCII
   national character set US7ASCII
DATAFILE '/u02/oradata/sdedbs02/system01.dbf' SIZE 175M
logfile '/u03/oradata/sdedbs02/redo01_a.log' SIZE 10M, 
    '/u03/oradata/sdedbs02/redo02_a.log' SIZE 10M,
    '/u03/oradata/sdedbs02/redo03_a.log' size 10M;
