create or replace procedure disable_triggers
                                     is 
                                     
       	v_trig_name user_triggers.trigger_name%type;
	v_sql_stmt varchar2(200);
  	
        cursor c_trig_name is select trigger_name from user_triggers;
		
begin

	open c_trig_name;
	
	loop
		fetch c_trig_name into v_trig_name;
		
		exit when c_trig_name%notfound;
		
		v_sql_stmt := 'alter trigger '||v_trig_name||' disable';

		execute immediate v_sql_stmt;
		
	end loop;
	
end;
/
show errors;
