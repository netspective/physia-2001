--
--  $Header: /home/engineer/cvs2git/physia/HealthSuite/Database/dbclient/glogin.sql,v 1.3 2000-06-02 22:18:36 alex_hillman Exp $
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

variable sql_prompt varchar2(50)

declare
 v_count number;
 v_sql_prompt varchar2(50);
begin
 select count(*) into v_count from all_synonyms where synonym_name = 'GET_SQLPROMPT_F';
 :sql_prompt := 'SQL->';
 if v_count > 0 then
  execute immediate 'select rtrim(get_sqlprompt_f) from dual' into v_sql_prompt;
  :sql_prompt := v_sql_prompt;
 end if;
end;
/

column x new_value user_prompt

select :sql_prompt x from dual;

set sqlprompt "&user_prompt"

set termout on

SET SERVEROUTPUT ON SIZE 1000000

