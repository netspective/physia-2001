
create or replace package Pkg_Entity as

	function cleanupEntityId(p_id in varchar2) return varchar2;
	
	procedure validateEntityId(p_type in integer, p_id in varchar2);
	
	function getEntityDisplay(
				p_type in integer, 
				p_id in varchar2, 
				p_onNotFound in varchar2 := NULL) return varchar2;
				
	PRAGMA RESTRICT_REFERENCES(cleanupEntityId, RNDS, WNDS, WNPS, RNPS);
	PRAGMA RESTRICT_REFERENCES(getEntityDisplay, WNDS, WNPS, RNPS);
	
	PNAMESTYLE_SHORT constant integer := 0;
	PNAMESTYLE_SIMPLE constant integer := 1;
	PNAMESTYLE_COMPLETE constant integer := 2;
	PNAMESTYLE_SHORT_SORTABLE constant integer := 3;
	PNAMESTYLE_SORTABLE constant integer := 4;
	
	ADDRSTYLE_HTML constant integer := 0;
	
	function getPersonAge(p_birthDate in date) return varchar2;
	
	function createPersonName(
				p_style in integer,
				p_name_Prefix in varchar2,
				p_name_First in varchar2,
				p_name_Middle in varchar2,
				p_name_Last in varchar2,
				p_name_Suffix in varchar2) return varchar2;
				
	function createAddress(
				p_style in integer,
				p_line1 in varchar2,
				p_line2 in varchar2,
				p_city in varchar2,
				p_state in varchar2,
				p_zip in varchar2) return varchar2;
				
	PRAGMA RESTRICT_REFERENCES(getPersonAge, WNDS, WNPS, RNPS);
	
end Pkg_Entity;
/
show errors;
