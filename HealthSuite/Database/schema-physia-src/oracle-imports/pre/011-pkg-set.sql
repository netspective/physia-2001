create or replace package Pkg_Set as

	procedure AssignSetMembers(
				p_tableName in varchar2,
				p_parentId in varchar2,
				p_membersList in varchar2,
				p_delim in char := ',');
	
end Pkg_Set;
/
show errors;

create or replace package body Pkg_Set as

	procedure AssignSetMembers(
				p_tableName in varchar2,
				p_parentId in varchar2,
				p_membersList in varchar2,
				p_delim in char := ',') is
		v_cursor number;
		v_numRows number;
		v_delim_comma NUMBER := INSTR(p_membersList, p_delim);
		v_activeMember varchar2(32);
		v_remainingMembers varchar2(512) := p_membersList;	
	begin
		begin
			v_cursor := DBMS_SQL.OPEN_CURSOR;
			DBMS_SQL.PARSE(v_cursor, 'delete from ' || p_tableName || ' where parent_id = ''' || p_parentId || '''', DBMS_SQL.NATIVE);
			v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
			DBMS_SQL.CLOSE_CURSOR(v_cursor);
		exception
			when others then null;
		end;

		v_cursor := DBMS_SQL.OPEN_CURSOR;
		DBMS_SQL.PARSE(v_cursor, 'insert into ' || p_tableName || ' (parent_id, member_name) values (''' || p_parentId || ''', :member_name)', DBMS_SQL.NATIVE);

		if v_delim_comma > 0 then
			while v_delim_comma > 0 
			loop
				v_activeMember := substr(v_remainingMembers, 1, v_delim_comma-1);
				DBMS_SQL.BIND_VARIABLE(v_cursor, 'member_name', v_activeMember);
				v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
				v_remainingMembers := substr(v_remainingMembers, v_delim_comma+1);
				v_delim_comma := INSTR(v_remainingMembers, p_delim);
			end loop;
		end if;
		if length(v_remainingMembers) > 0 then 
			DBMS_SQL.BIND_VARIABLE(v_cursor, 'member_name', v_remainingMembers);
			v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
		end if;

		DBMS_SQL.CLOSE_CURSOR(v_cursor);
	end;
	
end Pkg_Set;
/
show errors;

