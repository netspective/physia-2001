start post/views-report-aged-patient-receiv

set long 32000

truncate table ref_cpt;

copy from sde01/sde@sdedbs04 to pro_test/pro@sdedbs04 insert ref_cpt using select * from ref_cpt;
