@tables/Sch_Verify
@tables-code/Sch_Verify

alter table Sch_Template add (
	SLOT_WIDTH NUMBER(8)
);
alter table Sch_Template_AUD add (
	SLOT_WIDTH NUMBER(8)
);

alter table Appt_Type add (
	APPT_WIDTH NUMBER(8)
);
alter table Appt_Type_AUD add (
	APPT_WIDTH NUMBER(8)
);

@tables-code/Sch_Template
@tables-code/Appt_Type
