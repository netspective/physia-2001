create or replace function get_version_f
                                     is 
        iv1 number(3); 
        iv2 number(3);
        iv3 number(3);        
	
begin
	select instr(version, '.', 1, 1),
	       instr(version, '.', 1, 2),
	       instr(version, '.', 1, 3)
	       into iv1, iv2, iv3 
	from product_component_version where product like '%Oracle%';
	
	dbms_output.put_line('iv1='||iv1||'  iv2='||iv2||'  iv3='||iv3);
	
	
	select to_number(substr(version, 1, iv1-1)),
	       to_number(substr(version, iv1+1, iv2-iv1-1)),
	       to_number(substr(version, iv2+1, iv3-iv2-1))
	into v1, v2, v3
	       from sys.product_component_version where product like '%Oracle%';

end get_version;
/
show errors;
