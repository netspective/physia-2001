start post/views-report-aged-patient-receiv

set long 32000

alter table ref_cpt_usage disable constraint CPTUSG_PARENT_ID_FK;

truncate table ref_cpt;

copy from sde01/sde@sdedbs04 to pro_test/pro@sdedbs04 insert ref_cpt using select * from ref_cpt;

alter table ref_cpt_usage enable constraint CPTUSG_PARENT_ID_FK;



