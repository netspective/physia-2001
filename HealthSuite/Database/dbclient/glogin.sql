--
--  $Header: /home/engineer/cvs2git/physia/HealthSuite/Database/dbclient/glogin.sql,v 1.2 2000-05-23 14:53:15 alex_hillman Exp $
--  Copyright (c) Oracle Corporation 1988, 1994, 1995.  All Rights Reserved.
--
--  SQL*Plus Global Login startup file.
--
--  This is the global login file for SQL*Plus.
--  Add any sqlplus commands here that are to be
--  executed when a user invokes sqlplus

-- Used by Trusted Oracle
column ROWLABEL format A15

-- Used for the SHOW ERRORS command
column LINE/COL format A8
column ERROR    format A65  WORD_WRAPPED

-- For backward compatibility
set pagesize 14

-- Defaults for SET AUTOTRACE EXPLAIN report
column id_plus_exp format 990 heading i
column parent_id_plus_exp format 990 heading p
column plan_plus_exp format a60 
column object_node_plus_exp format a8
column other_tag_plus_exp format a29
column other_plus_exp format a44

-- Showing username and database name in SQLPLUS prompt

set numwidth 9
set linesize 2000
set pagesize 24

set termout off
define user_prompt=''
column value new_value user_prompt

select 'SQL:'||username||':'||substr(global_name,1,instr(global_name,'.')-1) value
from user_users,global_name;

set sqlprompt "&user_prompt>"
set termout on

SET SERVEROUTPUT ON SIZE 1000000

