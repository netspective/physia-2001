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
		v_parent_id varchar2(32);
		
	begin
	
	        v_parent_id := p_parentID;
	
		begin
		        execute immediate 'delete from '||p_tableName||' where parent_id = :parent_id' using v_parent_id; 

		exception
			when others then null;
		end;


		if v_delim_comma > 0 then
			while v_delim_comma > 0 
			loop
				v_activeMember := substr(v_remainingMembers, 1, v_delim_comma-1);

				execute immediate 'insert into '||p_tableName||' (parent_id, member_name) values(:parent_id, :member_name)'
				using v_parent_id, v_activeMember;
				
				v_remainingMembers := substr(v_remainingMembers, v_delim_comma+1);
				v_delim_comma := INSTR(v_remainingMembers, p_delim);
			end loop;
		end if;
		
		if length(v_remainingMembers) > 0 then
		
		
			execute immediate 'insert into '||p_tableName||' (parent_id, member_name) values(:parent_id, :member_name)'
			  using v_parent_id, v_remainingMembers;

		end if;

	end;
	
end Pkg_Set;
/
show errors;

