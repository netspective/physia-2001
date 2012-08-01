-- This script will copy tables REF_CPT, REF_ICD, REF_HCPCS
-- This script should be executed under schema where tables are copied

set long 40000

delete from ref_cpt;
delete from ref_icd;
delete from ref_hcpcs;
commit;

copy from demo01/demo@sdedbs02 insert ref_cpt using select * from ref_cpt;

copy from demo01/demo@sdedbs02 append ref_icd using select * from ref_icd;

copy from demo01/demo@sdedbs02 append ref_hcpcs using select * from ref_hcpcs;

exit


	