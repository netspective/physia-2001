BEGIN
	execArbitrarySql('drop index PER_NAME_LAST_UPP_IND');
END;
/

BEGIN
	execArbitrarySql('drop index PER_ATRR_VALUE_TEXT_UPP_IND');
END;
/


create index PER_NAME_LAST_UPP_IND on person (upper(name_last));

create index PER_ATRR_VALUE_TEXT_UPP_IND on person_attribute (upper(value_text));