create or replace procedure enable_FK_constraints
                                     is 
                                     
       	v_constr_name user_constraints.constraint_name%type;
       	v_table_name user_constraints.table_name%type;
       	
	v_sql_stmt varchar2(200);
  	
        cursor c_constr_name is select table_name, constraint_name from user_constraints
                                       where constraint_type='R';
		
begin

	open c_constr_name;
	
	loop
		fetch c_constr_name into v_table_name, v_constr_name;
		
		exit when c_constr_name%notfound;
		
		v_sql_stmt := 'alter table '||v_table_name||' enable constraint '||v_constr_name;

		execute immediate v_sql_stmt;
		
	end loop;
	
end;
/
show errors;
