Client Oracle Connectivity

To be able to establish Oracle session from SQL*PLUS, other Oracle tools, from programms written 
on Pro*C or OCI or using ODBC or DBI in Physia environment two files
tnsnames.ora and sqlnet.ora should be copied from this directory to 

ORACLE_HOME/network/admin on unix or NT platforms - all versions of Oracle plus to the directory

ORACLE_HOME/net80/admin for NT and Oracle version 8.0.5 or 8.0.6

where ORACLE_HOME is a directory where Oracle was installed.


If using SQL*PLUS file glogin.ora should be copied from this directory into directory ORACLE_HOME/sqlplus/admin

and file login.sql should be copied from this directory into directory ORACLE_HOME/dbs

