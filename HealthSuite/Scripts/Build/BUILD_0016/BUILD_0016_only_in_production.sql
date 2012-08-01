start tables/Referral_Reason
start data/Referral_Reason

start tables/Trans_Address
start tables-code/Trans_Address

create index TRANS_PARENT_TRANS_ID on Transaction (parent_trans_id) TABLESPACE TS_INDEXES;