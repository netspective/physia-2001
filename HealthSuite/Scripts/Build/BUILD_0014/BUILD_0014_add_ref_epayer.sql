whenever sqlerror exit sql.sqlcode rollback

insert into Electronic_Payer_Source (id, caption) values (3, 'Thin Net');

insert into Transaction_Type (id, caption, group_name, icon_img_summ, remarks) 
values (6030, 'Service Request Procedure', 'Referral', 'person.gif', 'Service Request Procedure');

start tables/REF_EPayer
start tables/REF_SERVICE_CATEGORY

--for real pro_test we will need to have to create db-link to SDEDBS04
--in SDEDBS04 select on sde01.ref_epayer and sde01.ref_service_category granted to pro_test

--insert into ref_epayer select * from sde01.ref_epayer;
--insert into ref_service_category select * from sde01.ref_service_category;

insert into ref_epayer select * from ref_epayer@sde01_link;
insert into ref_service_category select * from ref_service_category@sde01_link;


commit;