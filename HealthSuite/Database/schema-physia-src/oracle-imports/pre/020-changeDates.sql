create or replace procedure changeDates(p_days in number,
                                        p_logfiledir in varchar2 := '.') is    
/*                                      p_continue in number) is  */
                                        
	v_table_name user_tab_columns.table_name%type;
	v_column_name user_tab_columns.column_name%type;
	v_table_name_old user_tab_columns.table_name%type := ' ';
	
	i number := 0;
	v_sql_stmt varchar2(500);
	v_ins_stmt varchar2(255);
	v_col_nmbr number;
	v_operation char := '+';
	v_days_nmbr number := p_days;

/*   	output_file UTL_FILE.FILE_TYPE; */
   	
    	
        cursor c_tbl_colmn is select table_name, column_name from user_tab_columns u 
                        where u.data_type='DATE'  and not exists 
                          (select 'x' from user_views c where u.table_name=c.view_name)
			order by u.table_name;
		
begin

        disable_triggers;

        if p_days < 0 then
        	v_operation := '-';
        	v_days_nmbr := -p_days;
        end if;

 /*  	output_file := UTL_FILE.FOPEN(p_logfiledir, 'chng_date__'||TO_CHAR(SYSDATE, 'MMDDYY_HH:MI_AM')||'.log', 'w');  */
                  
/*	if p_continue > 0
	then
	        execute immediate 'truncate table change_date';
	end if;
*/
	open c_tbl_colmn;
	
	loop
		fetch c_tbl_colmn into v_table_name, v_column_name;
		
		if c_tbl_colmn%notfound
		then
			if i > 0
			then
/*				UTL_FILE.PUT_LINE (output_file, v_sql_stmt);
				UTL_FILE.FFLUSH (output_file);
*/
				
				execute immediate v_sql_stmt;
/*			
				v_ins_stmt := 'insert into change_date values ('''||v_table_name_old||''')';
				execute immediate v_ins_stmt;

				commit;
*/
				exit;
			end if;
			
			exit;
		end if;
		
		i := i + 1;
		if i = 1
		then
			v_table_name_old := v_table_name;
			v_sql_stmt := 'update '||v_table_name||' set ';
			v_col_nmbr := 0;
		end if;
		
		if v_table_name_old = v_table_name
		then
			v_col_nmbr := v_col_nmbr + 1;
			if v_col_nmbr > 1
			then
				v_sql_stmt := v_sql_stmt||', ';
			end if;
			v_sql_stmt := v_sql_stmt||v_column_name||' = '||v_column_name||v_operation||v_days_nmbr;
			
		else
/*			UTL_FILE.PUT_LINE (output_file, v_sql_stmt);
			UTL_FILE.FFLUSH (output_file);
*/
			execute immediate v_sql_stmt;
/*
			v_ins_stmt := 'insert into change_date values ('''||v_table_name_old||''' )';
			-- execute immediate v_ins_stmt;

			commit;
*/

			v_table_name_old := v_table_name;
			v_sql_stmt := 'update '||v_table_name||' set '||v_column_name||' = '||v_column_name||v_operation||v_days_nmbr;
			
			v_col_nmbr := 1;
			
		end if;
		
	end loop;
	
	commit;
	
	enable_triggers;
	
/*   	UTL_FILE.FCLOSE(output_file);   */
   	
end;
/
show errors;
