/* create template org */

whenever sqlerror exit sql.sqlcode rollback

variable TEMPLoii number;
variable NewOrgoii number;

begin   
   select org_internal_id into :TEMPLoii from org where org_id='PHYS_SMALL_TMPL' and parent_org_id is null;
end;
/

insert into org (org_id, name_primary, category, tax_id) values ('&&1', '&&2', '&&3', '&&4');

begin   
   select org_internal_id into :NewOrgoii from org where org_id='&&1' and parent_org_id is null;
end;
/

update org set owner_org_id=:NewOrgoii where org_internal_id=:NewOrgoii;

insert into org (org_id, name_primary, category, parent_org_id, owner_org_id)
select org_id, name_primary, category, :NewOrgoii, :NewOrgoii from org where parent_org_id=:TEMPLoii;


insert into person_login (person_id, org_internal_id, password, quantity)
select person_id, :NewOrgoii, password, 1000 from person_login where
org_internal_id=:TEMPLoii;


insert into person_org_category (person_id, org_internal_id, category)
select person_id, org_internal_id, 'Administrator' from person_login where org_internal_id=:NewOrgoii;

insert into person_org_category (person_id, org_internal_id, category)
values ('PHYSIA_ADMIN', :newOrgoii, 'Superuser');



