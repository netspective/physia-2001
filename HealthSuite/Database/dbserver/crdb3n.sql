spool crdb3n.log 
@$ORACLE_HOME/rdbms/admin/catalog.sql
@$ORACLE_HOME/rdbms/admin/catproc.sql
@$ORACLE_HOME/rdbms/admin/catblock.sql
@$ORACLE_HOME/rdbms/admin/caths.sql
@$ORACLE_HOME/rdbms/admin/otrcsvr.sql
@$ORACLE_HOME/rdbms/admin/utlsampl.sql
connect system/manager
@$ORACLE_HOME/sqlplus/admin/pupbld.sql
spool off
