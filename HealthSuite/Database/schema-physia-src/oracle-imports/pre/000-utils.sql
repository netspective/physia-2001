create or replace procedure execArbitrarySQL(p_sql in varchar2, p_message in varchar2 := NULL) is
	v_cursor number;
	v_NumRows number;
	v_dropSql varchar2(128);
begin
	v_cursor := DBMS_SQL.OPEN_CURSOR;
	DBMS_SQL.PARSE(v_cursor, p_sql, DBMS_SQL.NATIVE);
	v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
	DBMS_SQL.CLOSE_CURSOR(v_cursor);
	
	if p_message is not NULL then
		DBMS_OUTPUT.PUT_LINE(p_message);
	end if;

exception
	when others then
		DBMS_SQL.CLOSE_CURSOR(v_cursor);
end;
/
show errors;

create or replace procedure dropTable(p_tableName in user_tables.table_name%TYPE) is
	v_objectName user_tables.table_name%TYPE := upper(p_tableName);
begin
	execArbitrarySQL(
		'drop table ' || v_objectName || ' cascade constraints',
		'Dropped ' || v_objectName || '.');
exception
	when others then
		if SQLCODE <> -942 then
			raise;
		else
			DBMS_OUTPUT.PUT_LINE('Table ' || v_objectName || ' was not found, not dropped.');
		end if;
end;
/
show errors;

create or replace procedure dropSequence(p_seqName in user_sequences.sequence_name%TYPE) is
	v_objectName user_sequences.sequence_name%TYPE := upper(p_seqName);
begin
	execArbitrarySQL(
		'drop sequence ' || v_objectName,
		'Dropped ' || v_objectName || '.');
exception
	when others then
		if SQLCODE <> -2289 then
			raise;
		else
			DBMS_OUTPUT.PUT_LINE('Sequence ' || v_objectName || ' was not found, not dropped.');
		end if;
end;
/
show errors;


create or replace procedure dropAllObjects is
	v_cursor number;
	v_NumRows number;
	v_dropSql varchar2(128);
	v_objectName varchar2(32);
	cursor c_tables is select table_name from user_tables order by table_name;
	cursor c_seq is	select sequence_name from user_sequences order by sequence_name;
	cursor c_pkg is	select distinct(name) from user_source where type = 'PACKAGE' order by name;
	cursor c_trg is	select trigger_name from user_triggers order by trigger_name;
begin
	v_cursor := DBMS_SQL.OPEN_CURSOR;

	DBMS_OUTPUT.PUT_LINE('Dropping all user tables.');
	open c_tables;
	loop
		fetch c_tables into v_objectName;
		exit when c_tables%NOTFOUND;

		v_dropSql := 'drop table ' || v_objectName || ' cascade constraints';
		DBMS_SQL.PARSE(v_cursor, v_dropSql, DBMS_SQL.NATIVE);
		v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
		DBMS_OUTPUT.PUT_LINE('Dropped table ' || v_objectName || '.');
	end loop;
	close c_tables;

	DBMS_OUTPUT.PUT_LINE('Dropping all user sequences.');
	open c_seq;
	loop
		fetch c_seq into v_objectName;
		exit when c_seq%NOTFOUND;

		v_dropSql := 'drop sequence ' || v_objectName;
		DBMS_SQL.PARSE(v_cursor, v_dropSql, DBMS_SQL.NATIVE);
		v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
		DBMS_OUTPUT.PUT_LINE('Dropped sequence ' || v_objectName || '.');
	end loop;
	close c_seq;
	
	DBMS_OUTPUT.PUT_LINE('Dropping all user packages.');
	open c_pkg;
	loop
		fetch c_pkg into v_objectName;
		exit when c_pkg%NOTFOUND;

		v_dropSql := 'drop package ' || v_objectName;
		DBMS_SQL.PARSE(v_cursor, v_dropSql, DBMS_SQL.NATIVE);
		v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
		DBMS_OUTPUT.PUT_LINE('Dropped package ' || v_objectName || '.');
	end loop;
	close c_pkg;
	
	DBMS_OUTPUT.PUT_LINE('Dropping all user triggers.');
	open c_trg;
	loop
		fetch c_trg into v_objectName;
		exit when c_trg%NOTFOUND;

		v_dropSql := 'drop trigger ' || v_objectName;
		DBMS_SQL.PARSE(v_cursor, v_dropSql, DBMS_SQL.NATIVE);
		v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
		DBMS_OUTPUT.PUT_LINE('Dropped trigger ' || v_objectName || '.');
	end loop;
	close c_trg;
	
	DBMS_SQL.CLOSE_CURSOR(v_cursor);
exception
	when others then
		DBMS_SQL.CLOSE_CURSOR(v_cursor);
		raise;
end;
/
show errors;

create or replace function getLeadingToken(p_string in varchar, p_delim in varchar := '.', p_count in number := 1) return varchar is
	v_delimPos varchar(255) := INSTR(p_string, p_delim, 1, p_count);
begin
	if (v_delimPos <= 0) then
		return p_string;
	else
		return SUBSTR(p_string, 1, v_delimPos-1);
	end if;
end;
/
show errors;
