create tablespace TS_DATA datafile '/u06/oradata/sdedbs02/ts_data_1.dbf'
size 500M minimum extent 1M default storage (initial 1M next 1M maxextents 1024 pctincrease 0);

create tablespace TS_INDEXES datafile '/u07/oradata/sdedbs02/ts_indexes_1.dbf'
size 500M minimum extent 128K default storage (initial 128K next 128K maxextents 1024 pctincrease 0);

