<?xml version="1.0"?>

<xsl:stylesheet version="1.0">

<xsl:output method="html" disable-output-escaping="true"/>

<xsl:template match="demographics">
	<jsp:scriptlet>
		activeSql =
			"select complete_sortable_name as name, \n" +
				"complete_addr_html as address, \n" +
				"home.value_text as home_phone, \n" +
				"work.value_text as work_phone, \n" +
				"to_char(date_of_birth, 'mm/dd/yyyy') as dob, \n" +
				"decode(gender, 1, 'M', 2, 'F', 'U') as gender, \n" +
				"trunc((sysdate - date_of_birth)/365) as age \n" +
			"from person_attribute home, person_attribute work, person_address, person \n" +
			"where person_id = ? \n" +
				"and person_address.parent_id = person.person_id \n" +
				"and work.parent_id (+) = person.person_id \n" +
				"and work.item_name (+) = 'Work' \n" +
				"and home.parent_id (+) = person.person_id \n" +
				"and home.item_name (+) = 'Home' \n";

		try
		{
			stmt = dbms.prepareStatement(activeSql);
			<xsl:choose>
				<xsl:when test="@person-id">
					String personId = "<xsl:value-of select="@person-id"/>";
				</xsl:when>
				<xsl:otherwise>
					String personId = (String) session.getAttribute("user_id");
				</xsl:otherwise>
			</xsl:choose>

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						"<b>" + rs.getString(1) + "</b>" + "<br/>" +
						rs.getString(5) + " " +  rs.getString(6) + " " + rs.getString(7) + "<br>" +
						rs.getString(2) + "<br/>" +
						(rs.getString(3) != null ? rs.getString(3) + " - Home <br/>" : "") +
						(rs.getString(4) != null ? rs.getString(4) + " - Work <br/>" : "")
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="insurance">
	<jsp:scriptlet>
		activeSql =
			"SELECT \n" +
				"ins_internal_id, \n" +
				"parent_ins_id, \n" +
				"product_name, \n" +
				"DECODE(record_type, 3, 'coverage') AS record_type, \n" +
				"plan_name, \n" +
				"DECODE(bill_sequence,1,'Primary',2,'Secondary',3,'Tertiary',4,'Quaternary',5,'W. Comp', 98, 'Terminated', 99, 'InActive', 'Active'), \n" +
				"owner_person_id, \n" +
				"ins_org_id, \n" +
				"indiv_deductible_amt, \n" +
				"family_deductible_amt, \n" +
				"percentage_pay, \n" +
				"copay_amt, \n" +
				"guarantor_name, \n" +
				"decode(ins_type, 7, 'thirdparty', 'coverage') AS ins_type, \n" +
				"guarantor_id, \n" +
				"guarantor_type, \n" +
				"( \n" +
					"SELECT 	b.org_id \n" +
					"FROM org b \n" +
					"WHERE b.org_internal_id = i.ins_org_id \n" +
				") AS org_id, \n" +
				"( \n" +
					"SELECT 	g.org_id \n" +
					"FROM org g \n" +
					"WHERE guarantor_type = 1 \n" +
					"AND  g.org_internal_id = i.guarantor_id \n" +
				"), \n" +
				"i.coverage_begin_date, \n" +
				"i.coverage_end_date \n" +
			"FROM insurance i \n" +
			"WHERE record_type = 3 \n" +
			"AND owner_person_id = ? \n" +
			"ORDER BY bill_sequence \n";

		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						(rs.getString(16) != null ? "Third-Party: <b>" + rs.getString(13) + "</b>" :
							rs.getString(6) + ": <b>" + rs.getString(3) + "</b>" + "<br/>" )
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="active-medication">
	<jsp:scriptlet>
		activeSql =
			"SELECT \n" +
				"tr.trans_type, \n" +
				"tr.trans_id, \n" +
				"tr.caption, \n" +
				"to_char(tr.trans_begin_stamp, 'mm/dd/yy'), \n" +
				"tt.caption, \n" +
				"tr.provider_id, \n" +
				"tr.data_text_a \n" +
			"FROM \n" +
				"transaction tr, \n" +
				"transaction_type tt \n" +
			"WHERE \n" +
				"tr.trans_type BETWEEN 7000 AND 7999 \n" +
				"AND tr.trans_type = tt.id \n" +
				"AND tr.trans_owner_type = 0 \n" +
				"AND tr.trans_owner_id = ? \n" +
				"AND tr.trans_status = 2 \n" +
			"ORDER BY tr.trans_begin_stamp DESC";

		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						"<li>" + rs.getString(3) + " (" + rs.getString(5) + ")" +
						" -- " + rs.getString(4)
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="active-problem">
	<jsp:scriptlet>
		activeSql =
	    "select to_char(t.curr_onset_date, 'mm/dd/yy'), \n" +
	    	"ref.name, t.provider_id, \n" +
	    	"'(ICD ' || t.code || ')' as code \n" +
			"from ref_icd ref, transaction t \n" +
			"where t.trans_type = 3020 \n" +
				"and t.trans_owner_type = 0 and t.trans_owner_id = ? \n" +
				"and t.trans_status = 2 \n" +
				"and ref.icd (+) = t.code \n";
		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						"<li>" + rs.getString(2) + " " + rs.getString(4)
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="blood-type">
	<jsp:scriptlet>
		activeSql =
			"SELECT b.caption \n" +
			"FROM Blood_Type b, Person_Attribute p \n" +
			"WHERE p.parent_id = ? \n" +
				"AND p.item_name = 'BloodType' \n" +
				"AND b.id = p.value_text \n";
		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						rs.getString(1)
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="allergies">
	<jsp:scriptlet>
		activeSql =
			"select value_type, \n" +
				"item_id, \n" +
				"item_name, \n" +
				"value_text \n" +
			"from person_attribute \n" +
			"where parent_id = ? \n" +
				"and value_type in (410, 411, 412) \n";

		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						"<li>" + rs.getString(3) + "<br/>" +
						rs.getString(4)
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

<xsl:template match="surgical-historys">
	<jsp:scriptlet>
		activeSql =
	    "SELECT \n" +
	    	"to_char(t.curr_onset_date, 'mm/dd/yy'),  \n" +
	    	"ref.descr, \n" +
	    	"provider_id, \n" +
	    	"trans_type, \n" +
	    	"trans_id, \n" +
	    	"'(ICD ' || t.code || ')' AS code \n" +
			"FROM \n" +
				"transaction t, \n" +
				"ref_icd ref \n" +
			"WHERE \n" +
				"trans_type = 4050 \n" +
				"AND trans_owner_type = 0 \n" +
				"AND trans_owner_id = ? \n" +
				"AND t.code = ref.icd (+) \n" +
				"AND trans_status = 2 \n" +
			"UNION ALL ( \n" +
				"SELECT \n" +
					"to_char(t.curr_onset_date, 'mm/dd/yy'), \n" +
					"data_text_a, \n" +
					"provider_id, \n" +
					"trans_type, \n" +
					"trans_id, \n" +
					"'' AS code \n" +
				"FROM transaction t \n" +
				"WHERE \n" +
					"trans_type = 4050 \n" +
					"AND trans_owner_id = ? \n" +
					"AND trans_status = 2 \n" +
			") \n";

		try
		{
			stmt = dbms.prepareStatement(activeSql);

			int paramNum = 0;
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));
			stmt.setString(++paramNum, (String) session.getAttribute("active-person-id"));

			rs = stmt.executeQuery();
			while(rs.next())
			{
				<![CDATA[
					out.print(
						"<li>" + rs.getString(2) + "<br/>" +
						rs.getString(6)
					);
				]]>
			}
			rs.close();
		}
		catch(Exception e)
		{
			out.print(dbms.formatExceptionMsg(e, activeSql));
		}

	</jsp:scriptlet>
</xsl:template>

</xsl:stylesheet>
