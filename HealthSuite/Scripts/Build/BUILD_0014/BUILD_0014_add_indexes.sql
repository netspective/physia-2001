exec execarbitrarysql('drop index TRANS_TRANS_TYPE');
exec execarbitrarysql('drop index EVENT_START_TIME');
exec execarbitrarysql('drop index SESACT_PERSON_ID');
exec execarbitrarysql('drop index SESACT_ACTIVITY_STAMP');

create index TRANS_TRANS_TYPE on Transaction (trans_type) TABLESPACE TS_INDEXES;
create index EVENT_START_TIME on Event (start_time) TABLESPACE TS_INDEXES;
create index SESACT_PERSON_ID on PerSess_Activity (person_id) TABLESPACE TS_INDEXES;
create index SESACT_ACTIVITY_STAMP on PerSess_Activity (activity_stamp) TABLESPACE TS_INDEXES;