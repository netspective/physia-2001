Client Oracle Connectivity

To be able to establish Oracle session from SQL*PLUS, other Oracle tools, from programms written 
on Pro*C or OCI or using ODBC or DBI in Physia environment two files
tnsnames.ora and sqlnet.ora should be copied from this directory to 

ORACLE_HOME/network/admin on unix platforms - all versions of Oracle 
ORACLE_HOME\network\admin on WIN platforms - all versions of Oracle 


ORACLE_HOME\net80\admin for NT and Oracle version 8.0.5 or 8.0.6

where ORACLE_HOME is a directory where Oracle was installed.


If using SQL*PLUS files glogin.sql, login.sql, get_prompt.sql and c.sql should be copied from this directory
into directory ORACLE_HOME/sqlplus/admin on unix or ORACLE_HOME\sqlplus\admin on WIN.

Also value of SQLPATH should be changed. 
On unix export SQLPATH=$ORACLE_HOME/sqlplus/admin
On WIN we need to change value of SQLPATH in registry - under HKEY_LOCAL_MACHINE
                                                                  SOFTWARE
                                                                     ORACLE
                                                                        HOME0
