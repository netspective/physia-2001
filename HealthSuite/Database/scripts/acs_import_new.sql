/* create hds tables *

drop table hds_bill;
drop table hds_corporate;
drop table hds_location;
drop table hds_fees;
drop table hds_service_description;


create table hds_bill
( bill_id number(16),
  corp_id number(16),
  provider_id varchar2(50),
  bill_name varchar2(30),
  bill_dated date,
  bill_notes varchar2(50),
  loc_id number(16),
  bill_address varchar2(50),
  bill_state varchar2(2),
  bill_city varchar2(20),
  bill_zip varchar2(15),
  bill_num varchar2(20),
  bill_phone varchar2(20),
  bill_fax varchar2(20)
);



create table hds_corporate
( corp_id number(16),
  provider_id varchar2(50),
  corp_name varchar2(56),
  corp_address varchar2(50),
  corp_city varchar2(40),
  corp_state varchar2(2),
  corp_zip varchar2(15),
  corp_fax varchar2(20),
  corp_e_mail varchar2(20),
  corp_phone varchar2(20),
  category_id varchar2(3),
  category varchar2(20),
  corp_tax_id varchar2(20),
  corp_notes long
);


create table hds_location
( loc_id number(16),
  corp_id number(16),
  provider_id varchar2(50),
  loc_name varchar2(30),
  loc_address varchar2(50),
  loc_city varchar2(20),
  loc_county varchar2(20),
  loc_state varchar2(2),
  loc_zip varchar2(15),
  loc_fax varchar2(20),
  loc_email varchar2(20),
  loc_phone varchar2(20),
  loc_notes long,
  loc_tax_id varchar2(20),
  category_id varchar2(3),
  category varchar2(20)
);


create table hds_fees
( fee_id number(16),
  corp_id number(16),
  provider_id varchar2(50),
  fee_cpt varchar2(10),
  fee number(10,2),
  effective date,
  term date,
  date_date date,
  loc_id number(16),
  fee_comments varchar2(50)
);


create table hds_fees_excp
( fee_id number(16),
  corp_id number(16),
  provider_id varchar2(50),
  fee_cpt varchar2(10),
  fee number(10,2),
  effective date,
  term date,
  date_date date,
  loc_id number(16),
  fee_comments varchar2(50)
);



create table hds_service_description
( services_id number(16),
  service_code varchar2(5),
  description varchar2(60)
);


create table hds_services_provided
( ser_provided_id number(16),
  corp_id number(16),
  loc_id number(16),
  services_id number(16)
);





/* Create oracle tables from access tables.
   Clean them - check if there are records with duplicate provider_id - saw them in bill table - 
*/

/* print duplicates from bill table 

select * from hds_bill where provider_id in
  (select provider_id from 
     (select provider_id, count(*) group_count from hds_bill group by provider_id having count(*)>1));


delete duplicates from bill table 

*/


   alter table org add (corp_id number(16));
   
   create index org_corp_id on org(corp_id);


/* Create ACS main org with org_id='ACS'
   org_internal_id of ACS - ACSoii
*/

   insert into org (cr_user_id, org_id, name_primary)
   values ('ACS Import', 'ACS', 'ACS Main');
   
   update org set owner_org_id=org_internal_id, cr_org_internal_id=org_internal_id
     where org_id='ACS' and parent_org_id is null;
     
   
   variable ACSoii number;


   begin   
     select org_internal_id into :ACSoii from org where org_id='ACS' and parent_org_id is null;
   end;


/* corporate table */

   insert into org (cr_user_id, cr_org_internal_id, owner_org_id, org_id, parent_org_id, category, tax_id, name_primary, corp_id)
   select 
     'ACS_Import', :ACSoii, :ACSoii, provider_id, :ACSoii, 'main_dir_entry', corp_tax_id, corp_name, corp_id
   from hds_corporate;

  
   insert into org_address (cr_user_id, cr_org_internal_id, parent_id, address_name, line1, city, state, zip)
   select 
    'ACS_Import', :ACSoii,
    (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'Street', corp_address, corp_city, corp_state, corp_zip
    from hds_corporate h;

      
  insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
    ( select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'phone', 10, corp_phone
    from hds_corporate h;
   
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
    (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'fax', 15, corp_fax
    from hds_corporate h;
   
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
    (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'e-mail', 40, corp_e_mail
    from hds_corporate h;
    
    
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_block)
   select
    'ACS_Import', :ACSoii,
    (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'notes', 5,
    to_lob(corp_notes)
    from hds_corporate h;
    
    commit;
    
/* delete from org table all orgs with location - owner_org_id=:ACSoii and corp_id is null except main org */

   delete from org where owner_org_id = :ACSoii and corp_id is null and org_internal_id <> :ACSoii;
    
/* location table */    

   insert into org (cr_user_id, cr_org_internal_id, owner_org_id, org_id, parent_org_id, category, tax_id, name_primary)
   select 
     'ACS_Import', :ACSoii, :ACSoii, provider_id,
     (select org_internal_id from org where corp_id=h.corp_id), 
     'location_dir_entry', loc_tax_id, nvl(loc_name, '***')
   from hds_location h;  
   
   
   insert into org_address (cr_user_id, cr_org_internal_id, parent_id, address_name, line1, city, state, zip)
   select 
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'Street', loc_address, loc_city, loc_state, loc_zip
    from hds_location h; 
  
 
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'phone', 10, loc_phone
    from hds_location h;
    
    
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'fax', 15, loc_fax
    from hds_location h;
   
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'e-mail', 40, loc_email
    from hds_location h;
    
    
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_block)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'notes', 5,
    to_lob(loc_notes)
    from hds_location h;
    
    
    commit;


/* bill table */

   delete from org_address where cr_org_internal_id = :ACSoii and address_name = 'Billing';


   insert into org_address (cr_user_id, cr_org_internal_id, parent_id, address_name, line1, city, state, zip)  
   select 
    'ACS_Import', :ACSoii,
    (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii),
    'Billing', bill_address, bill_city, bill_state, bill_zip
    from hds_bill h;

    
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'billing phone', 10, bill_phone
    from hds_bill h;
    
    
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, value_type, value_text)
   select
    'ACS_Import', :ACSoii,
     (select org_internal_id from org where org_id=h.provider_id and owner_org_id=:ACSoii), 
    'billing fax', 15, bill_fax
    from hds_bill h;
    
    
    commit;

    
/* fee schedules */

   insert into offering_catalog (cr_user_id, cr_org_internal_id, catalog_id, caption, org_internal_id, catalog_type)
   select 
    'ACS_Import', :ACSoii,
    org_id||'_Fee_Schedule', org_id||'_Fee_Schedule', owner_org_id, 0
    from org
    where corp_id is not null;
    
   
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog where catalog_id=h.provider_id||'_Fee_Schedule'),
    100, 1, fee_cpt, null, 1, fee_comments, fee
   from hds_fees h
   where length(fee_cpt) = 5 and 
   (exists (select 1 from ref_hcpcs a where a.hcpcs=fee_cpt) or exists (select 1 from ref_cpt a where a.cpt=fee_cpt));
   
   
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog where catalog_id=h.provider_id||'_Fee_Schedule'),
    100, 1, substr(fee_cpt, 1, 5),
    substr(fee_cpt, 6, length(fee_cpt)),
    1, fee_comments||' 1 month rental', fee
   from hds_fees h
   where length(fee_cpt) = 7 and substr(fee_cpt, 6, 2)='RR' and 
     (exists (select 1 from ref_hcpcs a where a.hcpcs=substr(fee_cpt, 1, 5))
      or exists (select 1 from ref_cpt a where a.cpt=substr(fee_cpt, 1, 5)));
      
      
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog where catalog_id=h.provider_id||'_Fee_Schedule'),
    100, 1, substr(fee_cpt, 1, 5),
    substr(fee_cpt, 6, length(fee_cpt)),
    1, fee_comments, fee
   from hds_fees h
   where length(fee_cpt) > 5 and substr(fee_cpt, 6, length(fee_cpt))<>'RR' and 
     (exists (select 1 from ref_hcpcs a where a.hcpcs=substr(fee_cpt, 1, 5))
      or exists (select 1 from ref_cpt a where a.cpt=substr(fee_cpt, 1, 5)));
   
   
   insert into hds_fees_excp
   select * from hds_fees
   where not exists (select 1 from ref_hcpcs a where a.hcpcs=substr(fee_cpt, 1, 5)) and
         not exists (select 1 from ref_cpt b where b.cpt=substr(fee_cpt, 1, 5));
         
         
   commit;
   

/* misc. procedure code fee schedules  */   

   delete from offering_catalog where upper(catalog_id) like upper('%Misc_Procedure_code');
         
   insert into offering_catalog (cr_user_id, cr_org_internal_id, catalog_id, caption, org_internal_id, catalog_type)
   values ('ACS_Import', :ACSoii, 'ACS_Misc_Procedure_Code', 'ACS_Misc_Procedure_Code', :ACSoii, 2);
  
   variable MiscCatId number;
   

      begin   
        select internal_catalog_id into :MiscCatId from offering_catalog where catalog_id='ACS_Misc_Procedure_Code';
      end;

  
   print MiscCatId
  

   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code)
   select
    'ACS_Import', :ACSoii, :MiscCatId, 230, 1, fee_gr_cpt
   from 
   (select distinct substr(fee_cpt, 1, 5) fee_gr_cpt from hds_fees_excp) h;
    

   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog a where a.catalog_id = h.provider_id||'_Fee_Schedule'),
    230, 1, fee_cpt, null, 1, fee_comments, fee
   from hds_fees_excp h
   where length(fee_cpt) = 5;
   
   
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog a where a.catalog_id = h.provider_id||'_Fee_Schedule'),
    230, 1, substr(fee_cpt, 1, 5), substr(fee_cpt, 6, length(fee_cpt)), 1, fee_comments||' 1 month rental', fee
   from hds_fees_excp h
   where length(fee_cpt) = 7 and substr(fee_cpt, 6, 2)='RR';
      
      
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, modifier, cost_type, description, unit_cost)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog a where a.catalog_id = h.provider_id||'_Fee_Schedule'),
    230, 1, substr(fee_cpt, 1, 5), substr(fee_cpt, 6, length(fee_cpt)),
    1, fee_comments, fee
   from hds_fees_excp h
   where length(fee_cpt) > 5 and substr(fee_cpt, 6, length(fee_cpt))<>'RR';
   
   
   commit;
   

/* service type */

   insert into offering_catalog (cr_user_id, cr_org_internal_id, catalog_id, caption, org_internal_id, catalog_type)
   select 
    'ACS_Import', :ACSoii,
    org_id||'_ST', org_id||' Service Type', owner_org_id, 1
    from org
    where  owner_org_id=:ACSoii and org_internal_id <> :ACSoii;
   
   alter table hds_services_provided add (description varchar2(255), org_id varchar2(16), service_code varchar2(16));
   
   update hds_services_provided a 
     set a.service_code=(select b.service_code from hds_service_description b 
                        where b.services_id=a.services_id),
         a.description=(select b.description from hds_service_description b 
                        where b.services_id=a.services_id);
    
   update hds_services_provided a set
   org_id=(select org_id from org b where b.corp_id=a.corp_id)
   where a.corp_id is not null;
    
    
   update hds_services_provided a set
   org_id=(select provider_id from hds_location b where b.loc_id=a.loc_id)
   where a.loc_id is not null;
    
    
   insert into offering_catalog_entry
   (cr_user_id, cr_org_internal_id, catalog_id, entry_type, status, code, description)
   select
    'ACS_Import', :ACSoii,
    (select internal_catalog_id from offering_catalog where catalog_id=h.org_id||'_ST'),
    250, 1, service_code, description
   from hds_services_provided h;
   
   
   commit;
   
   
   /* additional changes */


   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, item_type, value_type, value_int)
   select 
    'ACS_Import', :ACSoii,
   (select org_internal_id from org a where a.org_id||'_Fee_Schedule' = catalog_id and owner_org_id=:ACSoii),
   'Fee Schedule', 0, 110,
   internal_catalog_id
   from offering_catalog
   where org_internal_id=:ACSoii;
   
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, item_type, value_type, value_int)
   select 
    'ACS_Import', :ACSoii,
   (select org_internal_id from org a where a.org_id||'_ST' = catalog_id and owner_org_id=:ACSoii),
   'Fee Schedule', 0, 110,
   internal_catalog_id
   from offering_catalog
   where org_internal_id=:ACSoii;
   
   insert into org_attribute (cr_user_id, cr_org_internal_id, parent_id, item_name, item_type, value_type, value_int)
   select 
   'ACS_Import', :ACSoii,
   (select org_internal_id from org a where a.org_id||'_Misc_Procedure_code' = catalog_id and owner_org_id=:ACSoii),
   'Fee Schedule', 0, 110,
   internal_catalog_id
   from offering_catalog
   where org_internal_id=:ACSoii;
   
   
   commit;


   select org_id, count(*) from org where cr_org_internal_id=:ACSoii group by org_id having count(*)>1;   