/*
  This function is returning unique person id.
  Algoritm: concatenate first initial, middle initial(if exist) and last name with 
  length <= 13 (last characters of last name truncated if needed) - search_peson_id
  Search in DB of all person_id's with prefix like this concatenated person_id.
  If not found - person_id is search_person_id.
  If found - cicle thru concatenation of search_person_id + number where number originally 
  is a number of found person_id's in the database
*/

CREATE OR REPLACE Function 
create_unique_person_id(fname in varchar2, mi in varchar2, lname in varchar2) return varchar2
is

type t_person_id is table of person.person_id%type index by binary_integer;
v_t_person_id t_person_id;
v_t_person_id_ind binary_integer;

v_fi varchar2(1);
v_mi varchar2(1);
v_mi_len number(2);
v_fimi_len number(2);
v_search_person_id varchar2(17);
v_lname_len number(2);
v_search_person_id_len number(2);
v_res_person_id varchar2(16);
v_person_id_possbl varchar2(16);
v_nmbr_ids number(3);
v_find_person_id number(1);

cursor c_person_id (p_search_person_id varchar2) is
  select person_id from person where person_id like p_search_person_id;

begin

  dbms_output.enable;

  v_fi := upper(substr(fname,1,1));
  
  if mi is null or mi='' then
    v_mi := '';
    v_mi_len := 0;
  else
    v_mi := upper(substr(mi,1,1));
    v_mi_len := 1;
  end if;
  
  v_fimi_len := v_mi_len+1;
  
  v_lname_len := length(lname);
  
  if v_lname_len > 13 - v_fimi_len then
    v_lname_len := 13 - v_fimi_len;
  end if;

  v_search_person_id_len := v_lname_len + v_fimi_len;
  v_res_person_id := v_fi||v_mi||upper(substr(lname, 1, v_lname_len));
  v_search_person_id := v_res_person_id||'%';
 
 /*
  dbms_output.put_line('v_mi_len='||v_mi_len||chr(10));
  dbms_output.put_line('v_fimi_len='||v_fimi_len||chr(10));
  dbms_output.put_line('v_lname_len='||v_lname_len||chr(10));
  dbms_output.put_line('v_search_person_id_len='||v_search_person_id_len||chr(10));
  dbms_output.put_line('v_res_person_id='||v_res_person_id||chr(10));
  dbms_output.put_line('v_search_person_id='||v_search_person_id||chr(10));
 */
      
  v_t_person_id_ind := 0;
  
    for c1 in c_person_id(v_search_person_id) loop
    v_t_person_id_ind := v_t_person_id_ind + 1;
    v_t_person_id(v_t_person_id_ind) := c1.person_id;
    
  end loop;
  
  /*dbms_output.put_line('v_t_person_id_ind='||v_t_person_id_ind||chr(10));*/
   
  if v_t_person_id_ind = 0 then
    return v_res_person_id;
  end if;
  
  v_nmbr_ids := v_t_person_id_ind;
  
  loop
  
    v_find_person_id := 0;
  
    v_person_id_possbl := v_res_person_id||ltrim(to_char(v_nmbr_ids, '999'), ' ');
  
    for i in 1..v_t_person_id_ind loop
    
      if v_t_person_id(i) = v_person_id_possbl then
        v_find_person_id := 1;
        exit;
      end if;
      
    end loop;
    
    if v_find_person_id = 1 then
      v_nmbr_ids := v_nmbr_ids + 1;
      v_find_person_id := 0;
    else
      exit;
    end if;
    
  end loop;
  
  return v_person_id_possbl;
  
end create_unique_person_id;
/
show errors;