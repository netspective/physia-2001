
create or replace package body Pkg_Entity as

	function CleanupEntityId(p_id in varchar2) return varchar2 is
	begin
		if p_id is null then
			return null;
		else
			return upper(p_id);
		end if;
	end;
	
	procedure validateEntityId(p_type in integer, p_id in varchar2) is
	begin
		NULL;
	end;
	
	function getEntityDisplay(p_type in integer, p_id in varchar2, p_onNotFound in varchar2) return varchar2 is
		v_display varchar2(512) := NULL;
	begin
		if p_type = 0 then
			select SIMPLE_NAME into v_display from person 
			where person_id = p_id;
		elsif p_type = 1 then
			select NAME_PRIMARY into v_display from org
			where org_internal_id = p_id;
		end if;
		if v_display is null then
			if p_onNotFound is not null then
				v_display := p_onNotFound;
			else
				v_display := '"' || p_id || '" (' || p_type || ') not found';
			end if;
		end if;
		return v_display;
	end;

	function getPersonAge(p_birthDate in date) return varchar2 is
		v_ageMonths number;
	begin
		if p_birthDate is null then
			return null;
		else
			v_ageMonths := MONTHS_BETWEEN(SysDate, p_birthDate);
			if v_ageMonths > 12 then
				return to_char(trunc(v_ageMonths/12));
			elsif v_ageMonths > 1 then
				return to_char(trunc(v_ageMonths)) || ' months';
			elsif v_ageMonths = 1 then
				return to_char(trunc(v_ageMonths)) || ' month';
			else 
				return to_char(trunc(v_ageMonths * 30)) || ' days';
			end if;
		end if;
	end;
	
	function createPersonName(
				p_style in integer,
				p_name_Prefix in varchar2,
				p_name_First in varchar2,
				p_name_Middle in varchar2,
				p_name_Last in varchar2,
				p_name_Suffix in varchar2) return varchar2 is
		v_namePrefix varchar2(32);
		v_nameMiddle varchar2(64);
		v_nameSuffix varchar2(32);
	begin
		if p_name_Prefix is NULL then
			v_namePrefix := '';
		else
			v_namePrefix := p_name_Prefix || ' ';
		end if;
		if p_name_Middle is NULL then
			v_nameMiddle := '';
		else
			v_nameMiddle := ' ' || p_name_Middle;
		end if;
		if p_name_Suffix is NULL then
			v_nameSuffix := '';
		else
			v_nameSuffix := ' ' || p_name_Suffix;
		end if;
		
		if p_style = PNAMESTYLE_SHORT then
			return substr(p_name_first, 1, 1) || ' ' || p_name_Last;
		elsif p_style = PNAMESTYLE_SIMPLE then
			return p_name_First || v_nameMiddle || ' ' || p_name_Last || v_nameSuffix;
		elsif p_style = PNAMESTYLE_COMPLETE then
			return v_namePrefix || p_name_First || v_nameMiddle || ' ' || p_name_Last || v_nameSuffix;
		elsif p_style = PNAMESTYLE_SHORT_SORTABLE then
			return p_name_Last || ', ' || substr(p_name_first, 1, 1);
		else
			return p_name_Last || v_nameSuffix  || ', ' || p_name_First || v_nameMiddle;
		end if;
	end;	
								   
	function createAddress(
				p_style in integer,
				p_line1 in varchar2,
				p_line2 in varchar2,
				p_city in varchar2,
				p_state in varchar2,
				p_zip in varchar2) return varchar2 is
		v_address varchar2(512);
	begin
		v_address := p_line1;
		if not(p_line2 is NULL) and (length(p_line2) > 0) then
			v_address := v_address || '<br>' || p_line2;
		end if;
		v_address := v_address || '<br>' || p_city || ', ' || p_state || ' ' || p_zip;
		return v_address;
	end;
		
end Pkg_Entity;
/
show errors;

