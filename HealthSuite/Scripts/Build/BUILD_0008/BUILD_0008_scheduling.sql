@tables/Sch_Verify
@tables-code/Sch_Verify

insert into Session_Action_Type (id, caption) values (7, 'Confirm');
insert into Session_Action_Type (id, caption) values (8, 'Verify');

alter table Sch_Template_R_Ids modify (member_name VARCHAR2(64));
alter table Appt_Type_R_Ids modify (member_name VARCHAR2(64));