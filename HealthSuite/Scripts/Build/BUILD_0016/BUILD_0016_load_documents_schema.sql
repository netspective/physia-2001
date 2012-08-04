start tables/Document_Specification
start data/Document_Specification

start tables/Document_Event_Type
start data/Document_Event_Type

start tables/Document_Source_Type
start data/Document_Source_Type

start tables/Document_Association_Type
start data/Document_Association_Type

start tables/Document_Association_Status
start data/Document_Association_Status

start tables/Document
start tables-code/Document

start tables/Document_Association
start tables-code/Document_Association

start tables/Document_Attribute
start tables-code/Document_Attribute

start tables/Document_Keyword
start tables-code/Document_Keyword

start tables/Observation
start tables-code/Observation

start tables/Observation_Result
start tables-code/Observation_Result

start tables/Document_Event
start tables-code/Document_Event

alter table Transaction add ( PARENT_DOC_ID NUMBER(16) );

alter table Transaction add constraint TRANS_PARENT_DOC_ID_FK
  FOREIGN KEY(parent_doc_id) references Document(doc_id) on delete cascade;
	
create index TRANS_PARENT_DOC_ID on Transaction (parent_doc_id) TABLESPACE TS_INDEXES;

alter table Transaction_AUD add ( PARENT_DOC_ID NUMBER(16) );

start tables-code/Transaction


