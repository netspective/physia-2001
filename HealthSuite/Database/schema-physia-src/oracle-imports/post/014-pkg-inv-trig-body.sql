create or replace package body pkg_inv_trig as

    procedure sort_inv_item_adj is
    
      v_parent_id invoice_item_adjust.parent_id%type;
    
    begin
    
      /*
      dbms_output.enable;
      dbms_output.put_line('v_ind_inv_item_adj='||v_ind_inv_item_adj||chr(10));
 
      for i in 1..v_ind_inv_item_adj loop
         v_parent_id := v_inv_item_adj_parent_id(i);
         dbms_output.put_line('v_inv_item_adj_parent_id('||i||')='||v_parent_id||chr(10));
      end loop;
      */
 
      
      for i in 1..v_ind_inv_item_adj loop
        for ii in 1..v_ind_inv_item_adj-i loop
        
          if v_inv_item_adj_parent_id(ii) > v_inv_item_adj_parent_id(ii+1) then
            v_parent_id := v_inv_item_adj_parent_id(ii);
            v_inv_item_adj_parent_id(ii) := v_inv_item_adj_parent_id(ii+1);
            v_inv_item_adj_parent_id(ii+1) := v_inv_item_adj_parent_id(ii);
          end if;
          
        end loop;
      end loop;
      
      for i in 1..v_ind_inv_item_adj loop
      
        if i=1 then 
          v_parent_id := 0;
        end if;
        
        if v_parent_id <> v_inv_item_adj_parent_id(i) then 
          v_parent_id := v_inv_item_adj_parent_id(i);
          v_ind_inv_item_adj_sort := v_ind_inv_item_adj_sort + 1;
          v_inv_item_adj_parent_id_dist(v_ind_inv_item_adj_sort) := v_parent_id;
        end if;
          
      end loop;
      
      /*
      dbms_output.put_line('v_ind_inv_item_adj_sort='||v_ind_inv_item_adj_sort||chr(10));
      
      for i in 1..v_ind_inv_item_adj_sort loop
         v_parent_id := v_inv_item_adj_parent_id_dist(i);
         dbms_output.put_line('v_inv_item_adj_parent_id_dist('||i||')='||v_parent_id||chr(10));
      end loop;
      */
      
    end sort_inv_item_adj;


    
    procedure sort_inv_item is
    
      v_parent_id invoice_item.parent_id%type;
    
    begin
    
     /*
      dbms_output.enable;
      dbms_output.put_line('v_ind_inv_item='||v_ind_inv_item||chr(10));
 
      for i in 1..v_ind_inv_item loop
         v_parent_id := v_inv_item_parent_id(i);
         dbms_output.put_line('v_inv_item_parent_id('||i||')='||v_parent_id||chr(10));
      end loop; 
      */
    
      for i in 1..v_ind_inv_item loop
        for ii in 1..v_ind_inv_item-i loop
        
          if v_inv_item_parent_id(ii) > v_inv_item_parent_id(ii+1) then
            v_parent_id := v_inv_item_parent_id(ii);
            v_inv_item_parent_id(ii) := v_inv_item_parent_id(ii+1);
            v_inv_item_parent_id(ii+1) := v_inv_item_parent_id(ii);
          end if;
          
        end loop;
      end loop;
      
      for i in 1..v_ind_inv_item loop
      
        if i=1 then 
          v_parent_id := 0;
        end if;
        
        if v_parent_id <> v_inv_item_parent_id(i) then 
          v_parent_id := v_inv_item_parent_id(i);
          v_ind_inv_item_sort := v_ind_inv_item_sort + 1;
          v_inv_item_parent_id_dist(v_ind_inv_item_sort) := v_parent_id;
        end if;
          
      end loop;
      
      /*
      dbms_output.put_line('v_ind_inv_item_sort='||v_ind_inv_item_sort||chr(10));
 
      for i in 1..v_ind_inv_item_sort loop
         v_parent_id := v_inv_item_parent_id_dist(i);
         dbms_output.put_line('v_inv_item_parent_id_dist('||i||')='||v_parent_id||chr(10));
      end loop; 
      */
      
    end sort_inv_item;
    
end pkg_inv_trig;
/
show errors;

    