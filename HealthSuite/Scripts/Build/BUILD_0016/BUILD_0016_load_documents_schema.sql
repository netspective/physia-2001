start schema-physia/tables/Document_Specification
start schema-physia/tables-code/Document_Specification
start schema-physia/data/Document_Specification

start schema-physia/tables/Document_Event_Type
start schema-physia/tables-code/Document_Event_Type
start schema-physia/data/Document_Event_Type

start schema-physia/tables/Document_Source_Type
start schema-physia/tables-code/Document_Source_Type
start schema-physia/data/Document_Source_Type

start schema-physia/tables/Document_Association_Type
start schema-physia/tables-code/Document_Association_Type
start schema-physia/data/Document_Association_Type

start schema-physia/tables/Document_Association_Status
start schema-physia/tables-code/Document_Association_Status
start schema-physia/data/Document_Association_Status

start schema-physia/tables/Document
start schema-physia/tables-code/Document

start schema-physia/tables/Document_Association
start schema-physia/tables-code/Document_Association

start schema-physia/tables/Document_Attribute
start schema-physia/tables-code/Document_Attribute

start schema-physia/tables/Document_Keyword
start schema-physia/tables-code/Document_Keyword

start schema-physia/tables/Observation
start schema-physia/tables-code/Observation

start schema-physia/tables/Observation_Result
start schema-physia/tables-code/Observation_Result

start schema-physia/tables/Document_Event
start schema-physia/tables-code/Document_Event

alter table Transaction add ( PARENT_DOC_ID NUMBER(16) );

alter table Transaction add constraint TRANS_PARENT_DOC_ID_FK
  FOREIGN KEY(parent_doc_id) references Document(doc_id) on delete cascade;
	
create index TRANS_PARENT_DOC_ID on Transaction (parent_doc_id) TABLESPACE TS_INDEXES;

alter table Transaction_AUD add ( PARENT_DOC_ID NUMBER(16) );

start tables-code/Transaction
start tables-code/Transaction_Aud


