create or replace package Pkg_Cache as

	procedure updateAssociation(
				p_cacheType in varchar2,
				p_colName in varchar2,
				p_fTableName in varchar2,
				p_fColName in varchar2,
				p_fPriKeyValue in varchar2,
				p_fColValue in varchar2);
	
end Pkg_Cache;
/
show errors;

