create or replace package pkg_inv_trig as

  type t_inv_item_adj_parent_id is table of invoice_item_adjust.parent_id%type index by binary_integer;
  
  type t_inv_item_parent_id is table of invoice_item.parent_id%type index by binary_integer;
  
  v_inv_item_adj_parent_id t_inv_item_adj_parent_id;
  v_inv_item_adj_parent_id_dist t_inv_item_adj_parent_id;
  v_ind_inv_item_adj binary_integer;
  v_ind_inv_item_adj_sort binary_integer;
  
  
  v_inv_item_parent_id t_inv_item_parent_id;
  v_inv_item_parent_id_dist t_inv_item_parent_id;
  v_ind_inv_item binary_integer;
  v_ind_inv_item_sort binary_integer;
  
  
  procedure sort_inv_item_adj;
  procedure sort_inv_item;
    
end pkg_inv_trig;
/
show errors;


    