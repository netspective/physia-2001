whenever sqlerror exit sql.sqlcode

insert into HCFA1500_Modifier_Code (id, caption, abbrev, result) values (113, 'TWCC 73 form', '73', 2);
insert into HCFA1500_Modifier_Code (id, caption, abbrev, result) values (114, 'TWCC 73 form when requested by the carrier', 'RR', 2);
insert into HCFA1500_Modifier_Code (id, caption, abbrev, result) values (115, 'TWCC 73 form re-requested by the carrier', 'EC', 2);

commit;