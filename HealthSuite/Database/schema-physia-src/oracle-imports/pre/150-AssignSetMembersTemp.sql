create or replace procedure AssignSetMembersTemp(
				p_prnt_table_name in varchar2,
				p_prnt_pk in varchar2,
				p_prnt_set_col_name in varchar2) is

		type cv_type is ref cursor;
		
		v_child_table_name varchar2(32) := p_prnt_table_name||'_'||p_prnt_set_col_name;
		v_prnt_table_cursor cv_type;
		v_set_member_name varchar2(512);
		v_member_name varchar2(32);
		v_parent_id varchar2(32);
		v_delim char := ',';
		v_delim_comma integer;	
		v_member_begin integer;
		v_set_len integer;
		v_set_len_beg integer;
		v_insert_stmt varchar2(256);

	begin
		--dbms_output.enable;
	
		execute immediate('truncate table '||v_child_table_name);
	
		open v_prnt_table_cursor for
		  'select '||p_prnt_pk||', '||p_prnt_set_col_name||' from '||p_prnt_table_name||' where '||p_prnt_set_col_name||' is not null';

		loop
		  fetch v_prnt_table_cursor into v_parent_id, v_set_member_name;
		  exit when v_prnt_table_cursor%notfound;
		  
		  --dbms_output.put_line('v_parent_id='||v_parent_id||'  v_set_member_name='||v_set_member_name||chr(10));
		  
		  v_member_begin := 1;
		  
		  v_set_len_beg := length(v_set_member_name);
		  v_set_len := v_set_len_beg;
		  
		  --dbms_output.put_line('begin loop: v_set_len='||v_set_len||chr(10));
			
		  while v_set_len > 0 loop
		  
		    v_delim_comma := INSTR(v_set_member_name, v_delim, v_member_begin);
		    
		    --dbms_output.put_line('v_delim_comma='||v_delim_comma||chr(10));
		    
		    if v_delim_comma = 0 then
		      v_delim_comma := v_set_len_beg + 1;
		    end if;
		    
		    --dbms_output.put_line('v_delim_comma='||v_delim_comma||chr(10));
	
		    v_member_name := substr(v_set_member_name, v_member_begin, v_delim_comma-1);
		    
		    --dbms_output.put_line('v_member_name='||v_member_name||chr(10));
		    
		    --dbms_output.put_line('inserting'||chr(10));
		    
		    v_insert_stmt := 'insert into '||v_child_table_name||' values ('''||v_parent_id||''', '''||v_member_name||''')';
		    
		    --dbms_output.put_line('v_insert_stmt='||v_insert_stmt||chr(10));
		    
		    execute immediate(v_insert_stmt);
		    		    
		    v_member_begin := v_delim_comma + 1;
		    
		    v_set_len := v_set_len - v_delim_comma - 1;
		    
		  end loop;

		end loop;
		
		close v_prnt_table_cursor;
		
		execute immediate('commit');

	end;
	
/
show errors;