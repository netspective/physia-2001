##############################################################################
package App::Statements::Person;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;
use App::Universal;

use vars qw(@ISA @EXPORT $STMTMGR_PERSON $PUBLDEFN_CONTACTMETHOD_DEFAULT);
@ISA    = qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_PERSON);

$PUBLDEFN_CONTACTMETHOD_DEFAULT = {
	columnDefn => [
		{ head => 'P', hHint => 'Preferred Method', comments => 'Boolean value indicating whether the contact method is a preferred method or not',
			dataFmt => ['', '<IMG SRC="/resources/icons/checkmark.gif">'], },
		{ head => 'Type', comments => 'The type of contact method (phone, fax, etc)',
			dataFmt => {

			},
		},
		{ head => 'Name', dataFmt => "&{fmt_stripLeadingPath:2}:", dAlign => 'RIGHT' },
		{ head => 'Value' },
	],
};

$STMTMGR_PERSON = new App::Statements::Person(
	'selPersonExists' => qq{
		select person_id
		from person
		where person_id = ?
		},
	'selPersonSimpleNameById' => qq{
			select complete_name from person where person_id = ?
		},
	'selRegistry' => qq{
		select person_id, ssn, name_first, name_middle, name_last, gen.caption as gender_caption, complete_name,
			mar.caption  as marstat_caption,
			pkg_entity.getPersonAge(date_of_birth) as Age,
			to_char(date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT') as date_of_birth,
			 short_sortable_name, ethnicity, person_ref, simple_name
		from person, gender gen, marital_status mar
		where person_id = ?
		and person.gender = gen.id
		and person.marital_status = mar.id
		},
	'selRegistryBySSN' => qq{
		select person_id, ssn, name_first, name_middle, name_last, gen.caption as gender_caption, complete_name,
			mar.caption  as marstat_caption,
			pkg_entity.getPersonAge(date_of_birth) as Age,
			to_char(date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT') as date_of_birth,
			 short_sortable_name, ethnicity, person_ref, simple_name
		from person, gender gen, marital_status mar
		where ssn = ?
		and person.gender = gen.id
		and person.marital_status = mar.id
		},
	'selRegistryByLastAndFirstNameAndDOB' => qq{
		select person_id, ssn, name_first, name_middle, name_last, gen.caption as gender_caption, complete_name,
			mar.caption  as marstat_caption,
			pkg_entity.getPersonAge(date_of_birth) as Age,
			to_char(date_of_birth, '$SQLSTMT_DEFAULTDATEFORMAT') as date_of_birth,
			 short_sortable_name, ethnicity, person_ref, simple_name
		from person, gender gen, marital_status mar
		where name_last = ?
		and name_first = ?
		and date_of_birth = to_date(?, '$SQLSTMT_DEFAULTDATEFORMAT')
		and person.gender = gen.id
		and person.marital_status = mar.id
		},
	'selFirstLastName' => qq{
			select p.name_first, p.name_last, p.ssn as ssn, p.person_id as person_id
			from person p, person_org_category pcat
			where p.person_id = pcat.person_id and pcat.org_internal_id = ?
		},

	'selssn' => qq{
		select p.ssn,p.person_id
		from person p,person_org_category pcat where p.person_id = pcat.person_id and pcat.org_internal_id = ?
		},

	'selCategory' => qq{
		select category
		from person_org_category
		where person_id = ? and org_internal_id = ?
		order by category
		},

	'selVerifyCategory' => qq{
		select category
		from person_org_category
		where person_id = ? and org_internal_id = ? and category = ?
		},

	'selPersonBySessionOrgAndCategory' => q{
			select distinct person_id
			  	from person_org_category
			  	where org_internal_id = ?
			  	 and category = ?
		},
	'selAttribute' => qq{
		select item_id, permissions, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateEnd,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateB,
			value_block, parent_org_id
		from person_attribute
		where parent_id = ? and item_name = ?
		},
	'selAttributeByItemNameAndValueTypeAndParent' => qq{
		select item_id, permissions, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateEnd,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateB,
			value_block, parent_org_id
		from person_attribute
		where parent_id = ? and item_name = ? and value_type = ?
		},
	'selAttributeById' => qq{
		select item_id, permissions, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateend,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateb,
			value_block, parent_org_id
		from person_attribute
		where item_id = ?
		},
	'selAttributeByValueInt' => qq{
		select item_id, permissions, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateend,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateb,
			value_block, parent_org_id
		from person_attribute
		where value_int = ?
		},
	'selAttributeByPersonAndValueType' => qq{
		select item_id, permissions, parent_id, item_type, item_name, value_type, value_text, value_textB, value_int, value_intB, value_float, value_floatB,
			to_char(value_date, '$SQLSTMT_DEFAULTDATEFORMAT') as value_date, to_char(value_dateEnd, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateend,
			to_char(value_dateA, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateA, to_char(value_dateB, '$SQLSTMT_DEFAULTDATEFORMAT') as value_dateb,
			value_block, parent_org_id
		from person_attribute
		where parent_id = ? and value_type = ?
		},
	'selEmergencyAssociations' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type = @{[App::Universal::ATTRTYPE_EMERGENCY]}
		},
	'selFamilyAssociations' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type = @{[App::Universal::ATTRTYPE_FAMILY]}
		},
	'selResourceAssociations' => qq{
		select distinct p.person_id, p.complete_name from person p, person_org_category pcat
		 where p.person_id=pcat.person_id
		 and pcat.org_internal_id= ?
		 and category='Physician'
		},
	'selSessionPhysicians' => qq{
		select *
		from person_attribute
		where value_type =  @{[App::Universal::ATTRTYPE_RESOURCEPERSON]}
		and item_name = 'SessionPhysicians'
		and value_int = 1
		and parent_id = ?
		},
	'selProviderAssociations' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type =  @{[App::Universal::ATTRTYPE_PROVIDER]}
		},
	'selPrimaryPhysicianOrProvider' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type = @{[App::Universal::ATTRTYPE_PROVIDER]}
		and value_int = 1
		},
	'selEmploymentAssociations' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
		},
	'selEmpStatus' => qq{
		select id, caption from attribute_value_type
		where id between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
		},
	'selEmploymentStatusCaption' => qq{
		select value_type, value_text, value_textB, value_int, caption
		from person_attribute, attribute_value_type
		where parent_id = ?
			and value_type between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
			and value_type = id
		},
	'selBloodTypeCaption' => q{
		select caption from Blood_Type
		where id = ?
		},
	'selRelationship' => qq{
		select caption from resp_party_relationship
		},
	'selPatientSign' => qq{
		select abbrev, caption from auth_signature
		},
	'selProviderAssign' => qq{
		select abbrev, caption from auth_assign
		},
	'selOrgEmployee' => qq{
		select distinct p.person_id, p.complete_name
		from person p, person_org_category pcat,person_attribute patt
		where p.person_id=pcat.person_id and p.person_id=patt.parent_id and pcat.org_internal_id= ? and patt.value_type in (220, 221)  and patt.value_text= ?
		},
	'selContactMethods' => qq{
		select * from person_attribute
		where parent_id = ?
		and value_type in (
					@{[App::Universal::ATTRTYPE_PHONE]},
				   	@{[App::Universal::ATTRTYPE_FAX]},
				    	@{[App::Universal::ATTRTYPE_PAGER]},
				    	@{[App::Universal::ATTRTYPE_EMAIL]},
				   	@{ [App::Universal::ATTRTYPE_URL]}
				    )
		order by name_sort, item_name
		},
	'selHomePhone' => qq{
		select value_text
		from person_attribute
		where parent_id = ?
		 and item_name = 'Home'
		},
	'selHomeAddress' => qq{
		select *
		from person_address
		where parent_id = ?
		 and address_name = 'Home'
		},
	'selPersonAddressById' => qq{
		select *
		from person_address
		where item_id = ?
		},
	'selPersonAddressByAddrName' => qq{
		select *
		from person_address
		where parent_id = ?
		and address_name = ?
		},
	'selAddresses' => qq{
		select parent_id, address_name, complete_addr_html
		from person_address where parent_id = ?
		order by address_name
		},
	'selAllergicRxn' => qq{
		select id from allergen_reaction
		where caption = ?
		},
	'selAlerts' => qq{
		select trans_type, trans_id, caption, detail, to_char(trans_begin_stamp, '$SQLSTMT_DEFAULTDATEFORMAT') as trans_begin_stamp, trans_end_stamp, trans_subtype
		from transaction
		where
			(
			(trans_owner_type = 0 and trans_owner_id = ?)
			)
			and
			(
			trans_type between @{[App::Universal::TRANSTYPE_ALERTORG]} and @{[App::Universal::TRANSTYPE_ALERTRANGE]}
			)
			and
			(
			trans_status = @{[App::Universal::TRANSSTATUS_ACTIVE]}
			)
		order by trans_begin_stamp desc
		},
	'updClearPreferredPhoneFlag' => qq{
		update person_attribute
		set value_int = 0
		where value_type = @{[App::Universal::ATTRTYPE_PHONE]}
			and (value_int is not null and value_int <> 0)
			and parent_id = ?
		},
	'updClearPreferredFaxFlag' => qq{
		update person_attribute
		set value_int = 0
		where value_type = @{[App::Universal::ATTRTYPE_FAX]}
			and (value_int is not null and value_int <> 0)
			and parent_id = ?
		},
	'updClearPreferredPagerFlag' => qq{
		update person_attribute
		set value_int = 0
		where value_type = @{[App::Universal::ATTRTYPE_PAGER]}
			and (value_int is not null and value_int <> 0)
			and parent_id = ?
		},
	'updClearPreferredEmailFlag' => qq{
		update person_attribute
		set value_int = 0
		where value_type = @{[App::Universal::ATTRTYPE_EMAIL]}
			and (value_int is not null and value_int <> 0)
			and parent_id = ?
		},
	'updClearPreferredInternetFlag' => qq{
		update person_attribute
		set value_int = 0
		where value_type = @{[App::Universal::ATTRTYPE_URL]}
			and (value_int is not null and value_int <> 0)
			and parent_id = ?
		},
	'updClearPrimaryPhysician' => qq{
			update person_attribute
			set value_int = ''
			where value_type = @{[App::Universal::ATTRTYPE_PROVIDER]}
				and item_id = ?
		},
	'selSpecialtySequence' => qq{
					select value_int, item_id
					from person_attribute
					where value_type = @{[App::Universal::ATTRTYPE_SPECIALTY]}
					and parent_id = ?
					and value_int = ?
		},
	'selSpecialtyExists' => qq{
				select value_text, item_id
				from person_attribute
				where value_type = @{[App::Universal::ATTRTYPE_SPECIALTY]}
				and parent_id = ?
				and value_text = ?
		},
	'selPhysicianSpecialty' => qq{
					select value_textB, item_id
					from person_attribute
					where value_type = @{[App::Universal::ATTRTYPE_PROVIDER]}
					and parent_id = ?
					and value_text = ?
					and value_textB = ?
		},
	'selEmploymentStatus' => qq{
		select caption
			from attribute_value_type
			where id = ?
		},
	'selPersonAssociation' => qq{
		select value_textB as phone_number, value_date as begin_date, value_dateEnd as end_date,
				value_int, item_name, value_type
			from person_attribute
			where item_id = ?
		},
	'selPersonEmpIdAssociation' => qq{
		select value_text as rel_id
			from person_attribute
			where item_id = ?
		},
	'selPersonEmpNameAssociation' => qq{
		select value_text as rel_name
			from person_attribute
			where item_id = ?
		},
	'selPersonData' => qq{
		select *
			from Person
			where person_id = ?
		},
	'selPersonEncounterProvider' => qq{
		select provider_id, complete_name
		from transaction, person
		where trans_id = ?
			and person_id = provider_id
		},
	'selPatientAge' => qq{
		select pkg_entity.getPersonAge(date_of_birth) as Age
			from person
			where person_id = ?
		},
	'selPayerInfo' => qq{
		select complete_name as payer_name, person_id as payer_id
		from person
		where person_id = ?
		},
	'selLogin' => qq{
		select person_id, org_internal_id, password, quantity
		from person_login
		where person_id = ?
		and org_internal_id is null
		},
	'selLoginOrg' => qq{
		select person_id, org_internal_id, password, quantity
		from person_login
		where person_id = ? and org_internal_id = ?
		},
	'updPersonLogin' => qq{
		update Person_Login
		set password = ?,
			quantity = ?
		where person_id = ?
			and org_internal_id = ?
	},
	'insPersonLogin' => qq{
		insert into Person_Login
		(cr_session_id, cr_stamp, cr_user_id, cr_org_internal_id, person_id, org_internal_id, password, quantity)
		values
		(?            , sysdate , ?         , ?        , ?        , ?     , ?       , ?)
	},
	'updSessionsTimeout' => qq{
		update person_session set status = 2
		where status = 0 and person_id = ?
		},
	'updSessionsTimeoutOrg' => qq{
		update person_session set status = 2
		where status = 0 and person_id = ? and org_internal_id = ?
		},
	'selSessions' => qq{
		select person_id, org_internal_id, remote_host, remote_addr, to_char(first_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') as first_access, to_char(last_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') as last_access from person_session
		where status = 0 and person_id = ?
		},
	'selSessionsOrg' => qq{
		select person_id, org_internal_id, remote_host, remote_addr, to_char(first_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') as first_access, to_char(last_access, '$SQLSTMT_DEFAULTSTAMPFORMAT') as last_access from person_session
		where status = 0 and person_id = ? and org_internal_id = ?
		},
	'selPhysStateLicense' => q{
		select * from person_attribute
		where parent_id = ? and value_type = @{[App::Universal::ATTRTYPE_STATE]} and value_int = ?
		},
	'selPrimaryPhysician' => q{
			select p.person_id, p.complete_name, pcat.person_id,pcat.org_internal_id, patt.value_text as phy, patt.parent_id
			from person p, person_org_category pcat, person_attribute patt
			where p.person_id=pcat.person_id
			and p.person_id=patt.value_text
			and patt.item_name like 'Primary%'
			and pcat.category = 'Physician'
			and pcat.org_internal_id = ?
			and patt.parent_id = ?
		},
	'selAuthSignatureCaption' => q{
			select caption from auth_signature
			where abbrev = ?
		},
	'selAuthAssignCaption' => q{
			select caption from auth_assign
			where abbrev = ?
		},
	'selMedicalSpecialtyCaption' => q{
			select caption from medical_specialty
			where abbrev = ?
		},
	'selTaxIdType' => q{
			select id, caption
			from tax_id_type
		},
	'selMedicalSpeciality' => q{
			select caption, abbrev
			from Medical_Specialty
		},
	'selAssocNurse' => q{
			select distinct p.person_id, p.complete_name
			  	from person p, person_org_category pcat
				where p.person_id=pcat.person_id and pcat.org_internal_id = ? and category='Physician'
		},
	'selEmpStatus' => q{
			select id, caption
			  	from Attribute_Value_Type
				where id between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
		},
	'selReferralReason' => q{
			select id, caption
			  	from Referral_Reason
		},

	'selPrimaryMail' => q{
			select *
				from person_attribute
				where parent_id = ?
				and value_type = @{[App::Universal::ATTRTYPE_EMAIL]}
				and item_name = 'Primary'
		},

	'selRoleNameExists' => q{
			select role_name, role_name_id
				from role_name
				where role_name = ?
		},

	'selPreferredPhoneExists' => q{
			select value_text
				from person_attribute
				where value_type = @{[App::Universal::ATTRTYPE_PHONE]}
				and parent_id = ?
				and value_int = 1
		},
	#
	# Registration and profile statements/definitions
	#
	'sel_Person_ContactMethods' => {
			sqlStmt => qq{
				select value_int, value_type, item_name, value_text, item_id from person_attribute
				where parent_id = ?
				and value_type in (
							@{[App::Universal::ATTRTYPE_PHONE]},
							@{[App::Universal::ATTRTYPE_FAX]},
							@{[App::Universal::ATTRTYPE_PAGER]},
							@{[App::Universal::ATTRTYPE_EMAIL]},
							@{[App::Universal::ATTRTYPE_URL]}
						)
				order by name_sort, item_name
			},
			sqlStmtBindParamDescr => ['Person ID'],
			publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
			publishDefn_panel =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel',
				frame => { heading => 'Contact Methods' },
			},
			publishDefn_panelEdit =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel.edit',
				frame => { heading => 'Modify Contact Methods' },
				banner => {
					actionRows =>
					[
						{ caption => 'Hello #session.user_id#', url => 'test' },
					],
				},
				stdIcons =>	{
					updUrlFmt => 'dlg-update-person-attr/#4#', delUrlFmt => 'dlg-remove-person-attr/#4#',
				},
			},
		},

	'sel_Person_ContactMethods_And_Addresses' => {
			sqlStmt => qq{
				select value_int as preferred, value_type, item_name, value_text, item_id
				from person_attribute pa
				where parent_id = ?
				and value_type in (
							@{[App::Universal::ATTRTYPE_PHONE]},
							@{[App::Universal::ATTRTYPE_FAX]},
							@{[App::Universal::ATTRTYPE_PAGER]},
							@{[App::Universal::ATTRTYPE_EMAIL]},
							@{[App::Universal::ATTRTYPE_URL]}
						)
				union all
				select 0 as preferred, 9998 as value_type, '-' as item_name, '-' as value_text, -1
				from dual
				union all
				select 0 as preferred, 9999 as value_type, address_name as item_name, complete_addr_html as value_text, -1
				from person_address
				where parent_id = ?
				order by value_type, item_name
			},
			sqlStmtBindParamDescr => ['Person ID for Attribute Table', 'Person ID for Address Table'],
			publishDefn => $PUBLDEFN_CONTACTMETHOD_DEFAULT,
			publishDefn_panel =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel',
				separateDataColIdx => 2, # when the item_name is '-' add a row separator
				frame => { heading => 'Contact Methods/Addresses' },
			},
			publishDefn_panelEdit =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel.edit',
				separateDataColIdx => 2, # when the item_name is '-' add a row separator
				frame => { heading => 'Modify Contact Methods/Addresses' },
				banner => {
					actionRows =>
					[
						{ caption => 'Hello #session.user_id#', url => 'test' },
					],
				},
				stdIcons =>	{
					updUrlFmt => 'dlg-update-person-attr/#4#', delUrlFmt => 'dlg-remove-person-attr/#4#',
				},
			},
		},

	'sel_Person_Addresses' => {
			sqlStmt => qq{
				select address_name, complete_addr_html
				from person_address
				where parent_id = ?
				order by address_name
			},
			sqlStmtBindParamDescr => ['Person ID'],
			publishDefn => {
				columnDefn => [
					{ dataFmt => '<IMG SRC="/resources/icons/address.gif">', },
					{ colIdx => 0, head => 'Name' },
					{ colIdx => 1, head => 'Address' },
				],
			},
			publishDefn_panel =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel',
				frame => { heading => 'Addresses' },
			},
			publishDefn_panelEdit =>
			{
				# automatically inherites columnDefn and other items from publishDefn
				style => 'panel.edit',
				frame => { heading => 'Modify Addresses' },
				banner => {
					actionRows =>
					[
						{ caption => 'Hello #session.user_id#', url => 'test' },
					],
				},
				stdIcons =>	{
					updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
				},
			},
		},
	#
	# Session activity statements/sefinitions
	#
	'insSessionActivity' => qq{
		insert into PerSess_Activity
		(session_id, activity_type, action_type, action_scope, action_key, detail_level, activity_data, person_id ) values
		(?         , ?            , ?          , ?           , ?         , ?           , ?            , ?)
		},
	'selSessionActivity' => {
		sqlStmt => qq{
				select to_char(a.activity_stamp, '$SQLSTMT_DEFAULTSTAMPFORMAT') as activity_date, b.caption as caption, a.activity_data as data, a.action_scope as scope, a.action_key as action_key from  perSess_Activity a,  Session_Action_Type b
					where  activity_stamp > (select max(activity_stamp) - 1 from perSess_Activity) and
					a.session_id = ? and
						a.action_type = b.id and
						rownum <= 20
					order by activity_date desc
			},
		publishDefn =>
			{
				columnDefn => [
					{ head => 'Time'},
					{ head => 'Event' },
					{ head => 'Details'},
					{ head => 'Scope', colIdx => 3,
						dataFmt =>
						{
							'person' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
							'org' => 'Organization <A HREF=\'/org/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
							'insurance' => 'Organization <A HREF=\'/org/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
							'insurance' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
							'person_attribute' => 'Person <A HREF=\'/person/#4#/profile \' STYLE="text-decoration:none">#4#</A>',
							'offering_catalog' => 'FeeSchedule <A HREF=\'/search/catalog/detail/#4#/\' STYLE="text-decoration:none">#4#</A>',
							'offering_catalog_entry' => 'FeeSchedule <A HREF=\'/search/catalog/detail/#4#/ \' STYLE="text-decoration:none">#4#</A>',
							'invoice' => 'Claim <A HREF=\'/invoice/#4#/summary\' STYLE="text-decoration:none">#4#</A>',
							'invoice_item' => 'Claim <A HREF=\'/invoice/#4#\' STYLE="text-decoration:none">#4#</A>',
							'transaction' => 'Person <A HREF=\'/person/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
							'person_address' => 'Person <A HREF=\'/person/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
							'org_attribute' => 'Organization <A HREF=\'/org/#4#/profile\' STYLE="text-decoration:none">#4#</A>',
							'_DEFAULT' => '#4#',
						},
					},
				],
			},
		},

	'sel_Person_EmploymentAssociations' => {
		sqlStmt => qq{
				select	pa.item_name, pa.value_text, pa.value_int, avt.caption
				from 	person_attribute pa, attribute_value_type avt
				where	pa.parent_id = ?
				and	pa.value_type = avt.id
				and	pa.value_type between @{[App::Universal::ATTRTYPE_EMPLOYEDFULL]} and @{[App::Universal::ATTRTYPE_EMPLOYUNKNOWN]}
			},
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'employment', dataFmt => '&{fmt_stripLeadingPath:0}: #1# - #2#' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Employment' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Employment' },
			banner => {
				actionRows =>
				[
					{ caption => 'Add', url => '<A HREF = "test">Employment</A>' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	},
	'sel_Person_EmergencyAssociations' => {
		sqlStmt => qq{
				select 	item_name, value_text, value_textb
				from 	person_attribute
				where	parent_id = ?
				and 	value_type  = @{[App::Universal::ATTRTYPE_EMERGENCY]}

			},
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'emergency', dataFmt => '&{fmt_stripLeadingPath:0}: #1#  (#2#)' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherits columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Emergency' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherits columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Emergency' },
			banner => {
				actionRows =>
				[
					{ caption => 'Add', url => '<A HREF = "test">Employment</A>' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	},
	'sel_Person_FamilyAssociations' => {
		sqlStmt => qq{
				select	item_name, value_text, value_textb
				from 	person_attribute
				where	parent_id = ?
				and	value_type  = @{[App::Universal::ATTRTYPE_FAMILY]}
			},
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'familyAssociations', dataFmt => '&{fmt_stripLeadingPath:0}: #1#  (#2#)' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Family Contacts' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Family Contacts' },
			banner => {
				actionRows =>
				[
					{ caption => 'Add', url => '<A HREF = "test">Employment</A>' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	},

	########### to be completed
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'familyAssociations', dataFmt => '#&{?}#: #1#  (#2#)' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Family Contacts' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Family Contacts' },
			banner => {
				actionRows =>
				[
					{ caption => 'Add', url => '<A HREF = "test">Employment</A>' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	'sel_Person_Alerts' => {
		sqlStmt => qq{
				select 	caption, detail
				from 	transaction
				where	trans_type between @{[App::Universal::TRANSTYPE_ALERTORG]} and @{[App::Universal::TRANSTYPE_ALERTRANGE]}
				and	trans_owner_type = 0
				and 	trans_owner_id = ?
				and	trans_status = @{[App::Universal::TRANSSTATUS_ACTIVE]}
				order by trans_begin_stamp desc
			},
		sqlStmtBindParamDescr => ['Person ID'],
		publishDefn => {
			columnDefn => [
				{ head => 'Alerts', dataFmt => '<B>#&{?}#</B><br/> #1#' },
			],
		},
		publishDefn_panel =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel',
			frame => { heading => 'Alerts' },
		},
		publishDefn_panelEdit =>
		{
			# automatically inherites columnDefn and other items from publishDefn
			style => 'panel.edit',
			frame => { heading => 'Alerts' },
			banner => {
				actionRows =>
				[
					{ caption => 'Add', url => '<A HREF = "test">Employment</A>' },
				],
			},
			stdIcons =>	{
				updUrlFmt => 'dlg-update-person-address/#0#', delUrlFmt => 'dlg-remove-person-address/#0#',
			},
		},

	},

);

1;
