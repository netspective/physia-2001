create or replace package Pkg_TextSearch as

	UPDATE_WORDS boolean := TRUE;

	procedure ParseWords(p_tableName in varchar2,
				p_parentId in varchar2,
				p_text in varchar2);
	
end Pkg_TextSearch;
/
show errors;

create or replace package body Pkg_TextSearch as

	procedure ParseWords(p_tableName in varchar2,
				p_parentId in varchar2,
				p_text in varchar2) is
		v_cursor number;
		v_numRows number;
		v_alphaNum varchar2(64) := 'abcdefghijklmnopqrstuvwxyz012345678-_';
		v_currIdx number := 1;
		v_lastIdx number := length(p_text);
		v_activeWord varchar2(64) := '';
		v_word_num number := 1;
		v_text varchar2(4096) := lower(p_text);
		v_letter char;
	begin
		if not UPDATE_WORDS then
			return;
		end if;
			
		begin
			v_cursor := DBMS_SQL.OPEN_CURSOR;
			DBMS_SQL.PARSE(v_cursor, 'delete from ' || p_tableName || ' where parent_id = ''' || p_parentId || '''', DBMS_SQL.NATIVE);
			v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
			DBMS_SQL.CLOSE_CURSOR(v_cursor);
		exception
			when others then null;
		end;
		
		if(v_lastIdx > 0) then
			v_cursor := DBMS_SQL.OPEN_CURSOR;
			DBMS_SQL.PARSE(v_cursor, 'insert into ' || p_tableName || ' (parent_id, word, word_loc) values (''' || p_parentId || ''', :word, :wordloc)', DBMS_SQL.NATIVE);
		
			for v_currIdx in 1..v_lastIdx loop
				v_letter := substr(v_text, v_currIdx, 1);
				if INSTR(v_alphaNum, v_letter) > 0 then
					v_activeWord := v_activeWord || v_letter;
				else
					if length(v_activeWord) > 0 then
						DBMS_SQL.BIND_VARIABLE(v_cursor, 'word', v_activeWord);
						DBMS_SQL.BIND_VARIABLE(v_cursor, 'wordloc', v_word_num);
						v_word_num := v_word_num + 1;
						v_NumRows := DBMS_SQL.EXECUTE(v_cursor);						
					end if;
					v_activeWord := '';
				end if;
			end loop;
			
			if length(v_activeWord) > 0 then
				DBMS_SQL.BIND_VARIABLE(v_cursor, 'word', v_activeWord);
				DBMS_SQL.BIND_VARIABLE(v_cursor, 'wordloc', v_word_num);
				v_NumRows := DBMS_SQL.EXECUTE(v_cursor);
			end if;
			DBMS_SQL.CLOSE_CURSOR(v_cursor);
		end if;
	end;
	
end Pkg_TextSearch;
/
show errors;

